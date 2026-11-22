import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_policy.dart';
import '../models/server_config.dart';
import 'analytics.dart';
import 'api_service.dart';

/// Fetches `GET /v1/config` with the last ETag; returns null when offline.
typedef ServerConfigFetcher =
    Future<http.Response?> Function(Map<String, String> headers);

/// The server config (`GET /v1/config`) for the whole app: update wall,
/// kill switches, analytics policy, server-owned flags (plan item #20).
///
/// Start-up applies the config cached on the last launch at once, then
/// revalidates it in the background with its ETag (a 304 costs no body).
/// It is fetched again on resume at most every [refreshAfter]. Anything
/// that goes wrong keeps the last good config, and with none on record the
/// fail-open defaults apply: no update wall, every feature on, every event
/// sent.
///
/// ```dart
/// if (FeatureFlags.instance.isEnabled('leaderboard')) ...
/// FeatureFlags.instance.config.flagBool('double_xp_weekend')
/// ```
/// Rebuild on change with `ValueListenableBuilder(valueListenable:
/// FeatureFlags.instance.changes, ...)`.
class FeatureFlags {
  FeatureFlags({ServerConfigFetcher? fetcher, DateTime Function()? clock})
    : _fetcher = fetcher ?? _defaultFetcher,
      _clock = clock ?? DateTime.now;

  static final FeatureFlags instance = FeatureFlags();

  static Future<http.Response?> _defaultFetcher(Map<String, String> headers) =>
      ApiService().rawRequest(
        'GET',
        '/v1/config',
        headers: headers,
        timeout: const Duration(seconds: 6),
      );

  final ServerConfigFetcher _fetcher;
  final DateTime Function() _clock;

  @visibleForTesting
  static const String cacheKey = 'server_config_v1';

  static const Duration refreshAfter = Duration(minutes: 5);

  ServerConfig _config = ServerConfig.failOpen;
  String? _etag;
  DateTime? _checkedAt;
  Future<void>? _inflight;
  bool _loaded = false;
  bool _started = false;

  /// Bumps whenever a different config is applied.
  final ValueNotifier<int> changes = ValueNotifier(0);

  ServerConfig get config => _config;
  String? get etag => _etag;

  /// False only when the server switched [feature] off.
  bool isEnabled(String feature) => _config.isEnabled(feature);

  /// Applies the cached config, then revalidates in the background. Never
  /// waits for the network.
  Future<void> init() async {
    _started = true;
    await _loadCache();
    unawaited(refresh(force: true));
  }

  /// Revalidates unless that happened within [refreshAfter]. Never throws.
  /// Does nothing before [init] (tests, and code running before start-up).
  Future<void> refresh({bool force = false}) {
    if (!_started) return Future.value();
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final last = _checkedAt;
    if (!force && last != null && _clock().difference(last) < refreshAfter) {
      return Future.value();
    }
    final run = _fetch().whenComplete(() => _inflight = null);
    _inflight = run;
    return run;
  }

  /// The freshest config available after waiting at most [wait] for a fetch
  /// already under way (the update wall asks right after start-up).
  Future<ServerConfig> latest({
    Duration wait = const Duration(seconds: 5),
  }) async {
    if (!_loaded) await _loadCache();
    final inflight = _inflight;
    if (inflight != null) {
      try {
        await inflight.timeout(wait);
      } catch (_) {}
    }
    return _config;
  }

  Future<void> _loadCache() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) {
        _apply(ServerConfig.failOpen);
        return;
      }
      final cached = jsonDecode(raw) as Map<String, dynamic>;
      final body = cached['config'];
      if (body is Map) {
        _etag = cached['etag'] as String?;
        _apply(ServerConfig.fromJson(Map<String, dynamic>.from(body)));
      }
    } catch (e) {
      debugPrint('Server config cache unreadable: $e');
    }
  }

  Future<void> _fetch() async {
    try {
      final response = await _fetcher({
        if (_etag != null) 'If-None-Match': _etag!,
      });
      if (response == null) return;
      if (response.statusCode == 304) {
        _checkedAt = _clock();
        return;
      }
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body is! Map) return;
      final json = Map<String, dynamic>.from(body);
      _etag = response.headers['etag'];
      _checkedAt = _clock();
      _apply(ServerConfig.fromJson(json));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cacheKey,
        jsonEncode({'etag': _etag, 'config': json}),
      );
    } catch (e) {
      debugPrint('Server config fetch skipped: $e');
    }
  }

  void _apply(ServerConfig config) {
    _config = config;
    Analytics.setEventPolicy(
      EventPolicy(
        blocklist: config.eventBlocklist,
        sampling: config.eventSampling,
      ),
    );
    changes.value++;
  }

  @visibleForTesting
  void debugReset() {
    _config = ServerConfig.failOpen;
    _etag = null;
    _checkedAt = null;
    _inflight = null;
    _loaded = false;
    _started = false;
  }
}
