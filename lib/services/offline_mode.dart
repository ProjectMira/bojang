import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'api_service.dart';
import 'feature_flags.dart';
import 'lesson_prefetch.dart';
import 'offline_queue.dart';
import 'pronunciation_voices.dart';

/// Offline mode (plan item #23): the persisted write queue, the prefetched
/// lessons and the triggers that drive them (connectivity back, app
/// resumed, Wi-Fi at start-up). Behind the `offline_mode` kill switch in
/// [FeatureFlags]; with it off, or before [start] (tests), every write goes
/// straight to the server as before.
class OfflineMode with WidgetsBindingObserver {
  OfflineMode._();

  static final OfflineMode instance = OfflineMode._();

  static const String killSwitch = 'offline_mode';

  bool _started = false;
  StreamSubscription<ConnectivityResult>? _connectivity;

  /// False while the device reports no network. Starts true.
  final ValueNotifier<bool> online = ValueNotifier(true);

  /// Queue and prefetch are in use.
  bool get enabled => _started && FeatureFlags.instance.isEnabled(killSwitch);

  late final OfflineQueue queue = OfflineQueue(
    store: SqfliteQueueStore(),
    sender: _send,
    uid: _uid,
    analytics: Analytics.track,
  );

  late final LessonPrefetcher prefetcher = LessonPrefetcher(
    directory:
        () async => Directory(
          '${(await getApplicationSupportDirectory()).path}/offline',
        ),
    fetchSession: ApiService().fetchSessionForOffline,
    download: _download,
    media: media,
    voice: () => _voice,
  );

  late final OfflineMediaCache media = OfflineMediaCache(
    directory:
        () async => Directory(
          '${(await getApplicationSupportDirectory()).path}/offline/media',
        ),
  );

  String _voice = PronunciationVoices.defaultVoice;

  static String? _uid() {
    try {
      if (Firebase.apps.isEmpty) return 'none';
      return FirebaseAuth.instance.currentUser?.uid ?? 'none';
    } catch (_) {
      return 'none';
    }
  }

  static Future<SendResult> _send(QueuedRequest request) async {
    if (!ApiService().isAuthenticated)
      return const SendResult(SendOutcome.retry);
    final response = await ApiService().rawRequest(
      request.method,
      request.path,
      body: request.bodyForSend(DateTime.now()),
      timeout: const Duration(seconds: 15),
    );
    Map<String, dynamic>? body;
    try {
      final decoded = response == null ? null : jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return SendResult.fromStatus(response?.statusCode, body);
  }

  static Future<Uint8List?> _download(String url) async {
    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Wires the triggers. Safe to call more than once; never throws.
  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      WidgetsBinding.instance.addObserver(this);
      final prefs = await SharedPreferences.getInstance();
      _voice = prefs.getString('pronunciation_voice') ?? _voice;
      // Load the media manifest so lesson pictures find their local copy.
      unawaited(media.totalBytes().then((_) {}, onError: (Object _) {}));
      final now = await Connectivity().checkConnectivity();
      _setOnline(now);
      _connectivity = Connectivity().onConnectivityChanged.listen(
        _onConnectivity,
        onError: (Object _) {},
      );
      if (!enabled) return;
      unawaited(queue.flush(force: true));
      if (now == ConnectivityResult.wifi ||
          now == ConnectivityResult.ethernet) {
        unawaited(prefetchActive(reason: 'wifi_start'));
      }
    } catch (e) {
      debugPrint('Offline mode start skipped: $e');
    }
  }

  void _setOnline(ConnectivityResult result) {
    final was = online.value;
    online.value = result != ConnectivityResult.none;
    if (was != online.value) {
      Analytics.track(
        online.value ? 'offline_mode_back_online' : 'offline_mode_offline',
        {
          'pending': queue.pending.value,
          'lessons_ready': prefetcher.ready.value,
        },
      );
    }
  }

  void _onConnectivity(ConnectivityResult result) {
    final wasOnline = online.value;
    _setOnline(result);
    if (enabled && online.value && !wasOnline) {
      unawaited(queue.flush(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !enabled) return;
    unawaited(queue.flush(force: true));
  }

  /// Tops up the active level's offline lessons. Never throws.
  Future<void> prefetchActive({
    String? levelId,
    String reason = 'lesson',
  }) async {
    if (!enabled || !online.value) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _voice = prefs.getString('pronunciation_voice') ?? _voice;
      final added = await prefetcher.prefetch(levelId);
      if (added > 0) {
        Analytics.track('offline_lessons_prefetched', {
          'added': added,
          'ready': prefetcher.ready.value,
          'reason': reason,
          'media_mb': ((await media.totalBytes()) / (1024 * 1024))
              .toStringAsFixed(1),
        });
      }
    } catch (e) {
      debugPrint('Prefetch skipped: $e');
    }
  }

  /// Sign-out or reset: this account's writes and lessons go.
  Future<void> clear() async {
    if (!_started) return;
    try {
      await queue.clear();
      await prefetcher.clear();
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> debugStop() async {
    await _connectivity?.cancel();
    _started = false;
  }
}
