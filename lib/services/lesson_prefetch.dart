import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'pronunciation_voices.dart';

/// Downloads one URL; null when it can't be fetched.
typedef MediaDownloader = Future<Uint8List?> Function(String url);

/// The lesson audio and pictures kept on disk for offline lessons, capped at
/// [capBytes] (50 MB). When a new file would pass the cap, the files used
/// longest ago go first.
class OfflineMediaCache {
  OfflineMediaCache({
    required Future<Directory> Function() directory,
    this.capBytes = 50 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _directory = directory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final int capBytes;
  final DateTime Function() _clock;

  Directory? _dir;
  Map<String, _MediaEntry>? _entries;

  Future<Map<String, _MediaEntry>> _load() async {
    final loaded = _entries;
    if (loaded != null) return loaded;
    final dir = _dir = await _directory();
    await dir.create(recursive: true);
    final entries = <String, _MediaEntry>{};
    try {
      final manifest = File('${dir.path}/media.json');
      if (await manifest.exists()) {
        final raw = jsonDecode(await manifest.readAsString()) as Map;
        raw.forEach((url, value) {
          final e = _MediaEntry.fromJson(value);
          if (e != null && File('${dir.path}/${e.file}').existsSync()) {
            entries[url.toString()] = e;
          }
        });
      }
    } catch (e) {
      debugPrint('Offline media manifest unreadable: $e');
    }
    return _entries = entries;
  }

  Future<void> _save() async {
    final dir = _dir;
    final entries = _entries;
    if (dir == null || entries == null) return;
    try {
      await File('${dir.path}/media.json').writeAsString(
        jsonEncode({for (final e in entries.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }

  /// Bytes on disk.
  Future<int> totalBytes() async =>
      (await _load()).values.fold<int>(0, (sum, e) => sum + e.bytes);

  Future<bool> contains(String url) async => (await _load()).containsKey(url);

  /// The local copy of [url], or null. Counts as a use for eviction.
  Future<File?> fileFor(String url) async {
    final entries = await _load();
    final entry = entries[url];
    if (entry == null) return null;
    final file = File('${_dir!.path}/${entry.file}');
    if (!await file.exists()) {
      entries.remove(url);
      return null;
    }
    entries[url] = entry.copyWith(lastUsed: _clock());
    unawaited(_save());
    return file;
  }

  /// [fileFor] without the disk check, for widgets building synchronously.
  /// Null until the manifest has been loaded once.
  File? fileForSync(String url) {
    final entry = _entries?[url];
    final dir = _dir;
    if (entry == null || dir == null) return null;
    return File('${dir.path}/${entry.file}');
  }

  /// Stores [bytes] for [url], evicting the least recently used files to
  /// stay under the cap. A file bigger than the cap is not kept.
  Future<bool> put(String url, Uint8List bytes) async {
    if (bytes.length > capBytes) return false;
    final entries = await _load();
    final dir = _dir!;
    final name = sha1.convert(utf8.encode(url)).toString() + _extension(url);
    final file = File('${dir.path}/$name');
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    final now = _clock();
    entries[url] = _MediaEntry(name, bytes.length, now, now);
    await _evict(keep: url);
    await _save();
    return true;
  }

  Future<void> _evict({String? keep}) async {
    final entries = _entries!;
    var total = entries.values.fold<int>(0, (sum, e) => sum + e.bytes);
    if (total <= capBytes) return;
    final oldest =
        entries.entries.where((e) => e.key != keep).toList()
          ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
    for (final e in oldest) {
      if (total <= capBytes) break;
      entries.remove(e.key);
      total -= e.value.bytes;
      try {
        await File('${_dir!.path}/${e.value.file}').delete();
      } catch (_) {}
    }
  }

  /// Fetches [url] into the cache unless it is there already.
  Future<bool> ensure(String url, MediaDownloader download) async {
    if (await contains(url)) return true;
    final bytes = await download(url);
    if (bytes == null || bytes.isEmpty) return false;
    return put(url, bytes);
  }

  Future<void> clear() async {
    final entries = await _load();
    for (final e in entries.values) {
      try {
        await File('${_dir!.path}/${e.file}').delete();
      } catch (_) {}
    }
    entries.clear();
    await _save();
  }

  static String _extension(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || path.length - dot > 6) return '';
    return path.substring(dot).toLowerCase();
  }
}

@immutable
class _MediaEntry {
  const _MediaEntry(this.file, this.bytes, this.storedAt, this.lastUsed);

  final String file;
  final int bytes;
  final DateTime storedAt;
  final DateTime lastUsed;

  _MediaEntry copyWith({DateTime? lastUsed}) =>
      _MediaEntry(file, bytes, storedAt, lastUsed ?? this.lastUsed);

  Map<String, Object?> toJson() => {
    'file': file,
    'bytes': bytes,
    'stored_at': storedAt.toUtc().toIso8601String(),
    'last_used': lastUsed.toUtc().toIso8601String(),
  };

  static _MediaEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return _MediaEntry(
        json['file'] as String,
        json['bytes'] as int,
        DateTime.parse(json['stored_at'] as String),
        DateTime.parse(json['last_used'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Fetches a fresh server session for a level with the given query.
typedef SessionFetcher =
    Future<Map<String, dynamic>?> Function(
      String levelId,
      Map<String, String> query,
    );

/// Sessions fetched ahead for the active level so lessons work offline
/// (plan item #23, Duolingo's offline manifest).
///
/// After each lesson, and at start-up on Wi-Fi, [prefetch] keeps
/// [perLevel] unused sessions of the active level on disk with their audio
/// (in the learner's voice) and pictures. Offline, [take] hands one to the
/// quiz. Each was issued to this learner, so the server grades its
/// completion when the offline queue replays it (sessions stay valid 7
/// days; older ones are thrown away).
class LessonPrefetcher {
  LessonPrefetcher({
    required Future<Directory> Function() directory,
    required SessionFetcher fetchSession,
    required MediaDownloader download,
    required this.media,
    String Function()? voice,
    DateTime Function()? clock,
    this.perLevel = 2,
  }) : _directory = directory,
       _fetch = fetchSession,
       _download = download,
       _voice = voice ?? (() => PronunciationVoices.defaultVoice),
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final SessionFetcher _fetch;
  final MediaDownloader _download;
  final OfflineMediaCache media;
  final String Function() _voice;
  final DateTime Function() _clock;
  final int perLevel;

  static const Duration sessionTtl = Duration(days: 7);

  /// Lessons of the active level ready to play offline (Home shows it).
  final ValueNotifier<int> ready = ValueNotifier(0);

  _Manifest? _manifest;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final run = _tail.then((_) => job());
    _tail = run.then(
      (_) {},
      onError: (Object e, StackTrace _) {
        debugPrint('Prefetch error: $e');
      },
    );
    return run;
  }

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/sessions.json');
  }

  Future<_Manifest> _load() async {
    final loaded = _manifest;
    if (loaded != null) return loaded;
    var manifest = _Manifest();
    try {
      final file = await _file();
      if (await file.exists()) {
        manifest = _Manifest.fromJson(jsonDecode(await file.readAsString()));
      }
    } catch (e) {
      debugPrint('Offline sessions unreadable: $e');
    }
    _manifest = manifest;
    _dropExpired(manifest);
    _updateReady(manifest);
    return manifest;
  }

  Future<void> _save(_Manifest m) async {
    try {
      await (await _file()).writeAsString(jsonEncode(m.toJson()));
    } catch (_) {}
    _updateReady(m);
  }

  void _updateReady(_Manifest m) {
    final level = m.activeLevel;
    ready.value =
        level == null ? 0 : m.sessions.where((s) => s.levelId == level).length;
  }

  void _dropExpired(_Manifest m) {
    final now = _clock();
    m.sessions.removeWhere((s) => !s.expiresAt.isAfter(now));
  }

  /// Remembers [levelId] as the active level and the query its lessons use,
  /// so a prefetch builds the same kind of session.
  Future<void> setActiveLevel(String levelId, Map<String, String> query) =>
      _serial(() async {
        final m = await _load();
        m.activeLevel = levelId;
        m.queries[levelId] = Map.of(query);
        await _save(m);
      });

  Future<String?> activeLevel() async => (await _load()).activeLevel;

  /// Unused sessions ready for [levelId].
  Future<int> readyFor(String levelId) async =>
      (await _load()).sessions.where((s) => s.levelId == levelId).length;

  /// Tops up [levelId] (default: the active level) to [perLevel] sessions
  /// and downloads their media. Returns how many sessions were added.
  Future<int> prefetch([String? levelId]) => _serial(() async {
    final m = await _load();
    _dropExpired(m);
    final level = levelId ?? m.activeLevel;
    if (level == null) return 0;
    final query = m.queries[level] ?? const <String, String>{};
    var added = 0;
    while (m.sessions.where((s) => s.levelId == level).length < perLevel) {
      final session = await _fetch(level, query);
      final id = session?['session_id']?.toString();
      if (session == null || id == null) break;
      final expires =
          DateTime.tryParse(session['expires_at']?.toString() ?? '') ??
          _clock().add(sessionTtl);
      m.sessions.add(_StoredSession(id, level, _clock(), expires, session));
      added++;
      await _save(m);
      for (final url in mediaUrls(session, _voice())) {
        await media.ensure(url, _download);
      }
    }
    // Media for sessions stored earlier, in case a download failed.
    for (final s in m.sessions.where((s) => s.levelId == level)) {
      for (final url in mediaUrls(s.session, _voice())) {
        await media.ensure(url, _download);
      }
    }
    await _save(m);
    return added;
  });

  /// The oldest ready session for [levelId], removed from the store (a
  /// session is played once). Marked `offline: true`. Null when none.
  Future<Map<String, dynamic>?> take(String levelId) => _serial(() async {
    final m = await _load();
    _dropExpired(m);
    final i = m.sessions.indexWhere((s) => s.levelId == levelId);
    if (i < 0) return null;
    final stored = m.sessions.removeAt(i);
    await _save(m);
    return {...stored.session, 'offline': true};
  });

  Future<void> clear() => _serial(() async {
    final m = await _load();
    m.sessions.clear();
    m.activeLevel = null;
    m.queries.clear();
    await _save(m);
    await media.clear();
  });

  /// The audio (in [voice]) and pictures a session's exercises use.
  static List<String> mediaUrls(Map<String, dynamic> session, String voice) {
    final urls = <String>{};
    void add(Object? url) {
      final text = url?.toString().trim() ?? '';
      if (text.startsWith('http')) urls.add(text);
    }

    void word(Map item) {
      final raw = item['audio_urls'];
      final byVoice = <String, String>{
        if (raw is Map)
          for (final e in raw.entries)
            if (e.value != null) e.key.toString(): e.value.toString(),
      };
      add(
        PronunciationVoices.pick(
          byVoice,
          voice,
          fallbackUrl: item['audio_url']?.toString(),
        ),
      );
      if (item['type'] == 'picture_choice') add(item['image_url']);
    }

    for (final key in const ['exercises', 'adaptive_exercises']) {
      final list = session[key];
      if (list is! List) continue;
      for (final exercise in list) {
        if (exercise is! Map) continue;
        word(exercise);
        final options = exercise['options'];
        if (options is List) {
          for (final o in options) {
            if (o is Map && o['audio_urls'] != null) word(o);
          }
        }
      }
    }
    return urls.toList();
  }
}

class _StoredSession {
  _StoredSession(
    this.id,
    this.levelId,
    this.fetchedAt,
    this.expiresAt,
    this.session,
  );

  final String id;
  final String levelId;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final Map<String, dynamic> session;

  Map<String, Object?> toJson() => {
    'id': id,
    'level_id': levelId,
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'session': session,
  };

  static _StoredSession? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return _StoredSession(
        json['id'] as String,
        json['level_id'] as String,
        DateTime.parse(json['fetched_at'] as String),
        DateTime.parse(json['expires_at'] as String),
        Map<String, dynamic>.from(json['session'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

class _Manifest {
  String? activeLevel;
  final Map<String, Map<String, String>> queries = {};
  final List<_StoredSession> sessions = [];

  Map<String, Object?> toJson() => {
    'active_level': activeLevel,
    'queries': queries,
    'sessions': [for (final s in sessions) s.toJson()],
  };

  static _Manifest fromJson(Object? json) {
    final m = _Manifest();
    if (json is! Map) return m;
    m.activeLevel = json['active_level'] as String?;
    final queries = json['queries'];
    if (queries is Map) {
      queries.forEach((k, v) {
        if (v is Map) {
          m.queries[k.toString()] = {
            for (final e in v.entries) e.key.toString(): e.value.toString(),
          };
        }
      });
    }
    final sessions = json['sessions'];
    if (sessions is List) {
      for (final s in sessions) {
        if (_StoredSession.fromJson(s) case final stored?)
          m.sessions.add(stored);
      }
    }
    return m;
  }
}
