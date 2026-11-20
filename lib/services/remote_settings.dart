import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'analytics.dart';
import 'event_tracker.dart';

/// Firebase Remote Config: values the team changes in the Firebase console
/// without shipping a build. The app starts with the defaults below (or the
/// values fetched on the last launch), fetches fresh ones in the background,
/// and applies console changes live.
///
/// Experiments: a parameter whose name starts with `exp_` (set per user with
/// a "user in random percentile" condition) is attached to every analytics
/// event as a property of the same name, so PostHog can compare the groups.
class RemoteSettings {
  RemoteSettings._();

  static const Map<String, Object> defaults = {
    // Kill switches for the interaction tracking.
    'tap_capture_enabled': true,
    'backend_events_enabled': true,
    // Banner at the top of Home. Shown while the title is not empty; a new
    // id shows it again to learners who dismissed an earlier one.
    'home_announcement_id': '',
    'home_announcement_title': '',
    'home_announcement_body': '',
    'home_announcement_url': '',
  };

  /// Bumps whenever new values are activated (widgets listen to it).
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static bool _ready = false;
  static StreamSubscription<RemoteConfigUpdate>? _live;

  static Future<void> init() async {
    if (_ready || kIsWeb || Firebase.apps.isEmpty) {
      _apply();
      return;
    }
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.setDefaults(defaults);
      _ready = true;
      _apply();
      // Not awaited: start-up never waits for the network.
      unawaited(rc.fetchAndActivate().then((_) => _apply()).catchError(
            (Object e) => debugPrint('Remote Config fetch failed: $e'),
          ));
      _live = rc.onConfigUpdated.listen(
        (_) async {
          await rc.activate();
          _apply();
        },
        onError: (Object e) => debugPrint('Remote Config live updates off: $e'),
      );
    } catch (e) {
      debugPrint('Remote Config init skipped: $e');
      _apply();
    }
  }

  static bool getBool(String key) {
    if (_ready) {
      try {
        return FirebaseRemoteConfig.instance.getBool(key);
      } catch (_) {}
    }
    final value = defaults[key];
    return value is bool ? value : false;
  }

  static String getString(String key) {
    if (_ready) {
      try {
        return FirebaseRemoteConfig.instance.getString(key);
      } catch (_) {}
    }
    final value = defaults[key];
    return value is String ? value : '';
  }

  static void _apply() {
    final tracker = EventTracker.instance;
    tracker.captureTaps = getBool('tap_capture_enabled');
    tracker.uploadsEnabled = getBool('backend_events_enabled');

    if (_ready) {
      try {
        final all = FirebaseRemoteConfig.instance.getAll();
        final experiments = <String, Object?>{};
        for (final entry in all.entries) {
          if (entry.key.startsWith('exp_')) {
            final value = entry.value.asString();
            experiments[entry.key] = value;
            Analytics.register(entry.key, value);
          }
        }
        if (experiments.isNotEmpty) {
          Analytics.track('remote_config_activated', experiments);
        }
      } catch (_) {}
    }
    changes.value++;
  }

  @visibleForTesting
  static Future<void> dispose() async {
    await _live?.cancel();
    _live = null;
  }
}
