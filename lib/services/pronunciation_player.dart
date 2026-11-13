import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Plays word pronunciation recordings (Monlam TTS MP3s served from the
/// backend's `audio_url`).
///
/// Clips are downloaded once with Dart's HTTP client, cached on disk and
/// played from the local file rather than streamed by the platform player.
/// They are ~10 KB, so this makes replays instant and offline-safe, and it
/// sidesteps platform players that refuse remote sources (AVPlayer on some
/// iOS simulator builds fails every remote URL with "Unknown error").
///
/// Kept separate from the sound-effects player so a pronunciation never cuts
/// off the correct/incorrect chime, and vice versa. One shared player: a new
/// word replaces whatever is still playing.
class PronunciationPlayer {
  PronunciationPlayer._();

  static final PronunciationPlayer instance = PronunciationPlayer._();

  AudioPlayer? _player;
  Directory? _cacheDir;
  final Map<String, Future<File?>> _downloads = {};

  /// The URL that is playing right now, or null. Widgets listen to this to
  /// show a playing state on their speaker button.
  final ValueNotifier<String?> playingUrl = ValueNotifier<String?>(null);

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer(playerId: 'pronunciation');
    // Every stream needs an error handler: the plugin reports a failed
    // source on its event stream as well as from play().
    void onError(Object e) {
      debugPrint('Pronunciation player error: $e');
      _clear();
    }

    player.onPlayerComplete.listen((_) => _clear(), onError: onError);
    // Only completion clears here: stop() clears explicitly, and its async
    // "stopped" event would otherwise wipe the word that replaced it.
    player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) _clear();
    }, onError: onError);
    _player = player;
    return player;
  }

  void _clear() => playingUrl.value = null;

  Future<Directory> _dir() async {
    final cached = _cacheDir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/pronunciation');
    await dir.create(recursive: true);
    return _cacheDir = dir;
  }

  /// Local copy of [url], downloading it on first use. Null when offline or
  /// the file is missing; concurrent callers share one download.
  Future<File?> _localFile(String url) {
    return _downloads[url] ??= () async {
      try {
        final dir = await _dir();
        final name = sha1.convert(utf8.encode(url)).toString();
        final file = File('${dir.path}/$name.mp3');
        if (await file.exists() && await file.length() > 0) return file;
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
        }
        final tmp = File('${file.path}.part');
        await tmp.writeAsBytes(response.bodyBytes, flush: true);
        return await tmp.rename(file.path);
      } catch (e) {
        debugPrint('Pronunciation download failed for $url: $e');
        _downloads.remove(url); // let a later attempt retry
        return null;
      }
    }();
  }

  /// Warms the cache so a question's audio plays without a network wait.
  void prefetch(Iterable<String?> urls) {
    for (final url in urls) {
      if (url != null && url.isNotEmpty) unawaited(_localFile(url));
    }
  }

  /// Plays [url]. Failures (offline, missing file) are logged and swallowed:
  /// audio is an aid, never a reason to break the quiz.
  Future<void> play(String? url) async {
    if (url == null || url.isEmpty) return;
    playingUrl.value = url;
    final file = await _localFile(url);
    // Another word was requested while this one downloaded.
    if (playingUrl.value != url) return;
    if (file == null) {
      _clear();
      return;
    }
    try {
      final player = _audio;
      await player.stop();
      playingUrl.value = url; // stop() cleared it
      await player.setVolume(1.0);
      await player.play(DeviceFileSource(file.path, mimeType: 'audio/mpeg'));
    } catch (e) {
      debugPrint('Pronunciation playback failed for $url: $e');
      _clear();
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Pronunciation stop failed: $e');
    }
    _clear();
  }
}
