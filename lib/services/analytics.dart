import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_policy.dart';
import 'crash_reporting.dart';
import 'event_tracker.dart';

/// Product analytics, sent to two places:
/// - PostHog (project "Bojang", US cloud): named events, screens, person
///   profiles, session replay and error tracking.
/// - The Bojang backend (`app_events` table) through [EventTracker]: every
///   named event plus every tap, swipe, scroll, screen dwell time and app
///   session, with device context.
///
/// Every call is fire-and-forget and never throws: analytics must not break a
/// lesson. Event names are snake_case `object_action`; the full catalog with
/// properties lives in ANALYTICS_EVENTS.md next to pubspec.yaml. Learners can
/// switch both off in Settings ([setOptOut]).
class Analytics {
  Analytics._();

  /// Write-only project token. PostHog designs it to ship inside public apps.
  /// Override with --dart-define=POSTHOG_KEY=... (an empty value disables).
  static const String _projectToken = String.fromEnvironment(
    'POSTHOG_KEY',
    defaultValue: 'phc_wBBXj9VZUS7hgJf9jxzNQSwzjT8RAr9dJHSMQ7nmbY4g',
  );
  static const String _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// Debug builds and tests send nothing unless POSTHOG_IN_DEBUG=true, so
  /// local development does not pollute the production numbers.
  static const bool _sendInDebug = bool.fromEnvironment('POSTHOG_IN_DEBUG');

  static const String _optOutKey = 'analytics_opt_out';

  static bool _enabled = false;
  static bool get enabled => _enabled;

  static bool _posthogReady = false;
  static bool _optedOut = false;

  /// True when the learner switched "Share usage analytics" off.
  static bool get optedOut => _optedOut;

  static bool get _buildSends => !kDebugMode || _sendInDebug;

  /// Blocklist and sampling from the server config (FeatureFlags).
  static EventPolicy _policy = EventPolicy.allowAll;

  /// Applied by FeatureFlags whenever the server config changes.
  static void setEventPolicy(EventPolicy policy) => _policy = policy;

  /// Whether [event] is sent in this app session, by the server's
  /// blocklist and sampling. Covers PostHog and the backend events
  /// (taps and scrolls included, through the tracker's filter).
  static bool allowsEvent(String event) =>
      _policy.allows(event, EventTracker.instance.sessionId);

  /// Tracks the screen on display for the backend events (route pushes,
  /// pops, dialogs). Add next to [observer] in navigatorObservers.
  static NavigatorObserver get screenObserver =>
      EventTracker.instance.routeObserver;

  /// Route observer that turns every pushed page into a `$screen` event.
  /// Routes without a name are labelled by their widget type (see
  /// [screenRoute]) so MaterialPageRoute pushes are still readable.
  static final PosthogObserver observer = PosthogObserver(
    nameExtractor: (settings) => settings.name,
  );

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _optedOut = prefs.getBool(_optOutKey) ?? false;
    } catch (_) {}
    await CrashReporting.setCollection(!_optedOut);
    if (_optedOut || !_buildSends) return;
    await _startPosthog();
    await _startTracker();
  }

  static Future<void> _startTracker() async {
    final tracker = EventTracker.instance;
    tracker.filter = allowsEvent;
    tracker.onSessionStarted = (id) => register('bojang_session_id', id);
    // Every PostHog event (autocaptured rage clicks included) carries the
    // screen it happened on.
    tracker.onScreenChanged = (screen) => register('current_screen', screen);
    await tracker.start();
  }

  static Future<void> _startPosthog() async {
    if (_projectToken.isEmpty) return;
    if (_posthogReady) {
      await Posthog().optIn().catchError(
        (Object e) => debugPrint('Analytics opt-in failed: $e'),
      );
      _enabled = true;
      return;
    }
    try {
      final config = PostHogConfig(_projectToken)
        ..host = _host
        ..captureApplicationLifecycleEvents = true
        ..personProfiles = PostHogPersonProfiles.always
        ..sessionReplay = true
        ..sessionReplayConfig.maskAllTexts = false
        ..sessionReplayConfig.maskAllImages = false
        ..errorTrackingConfig.captureFlutterErrors = true
        ..errorTrackingConfig.capturePlatformDispatcherErrors = true
        // Crashlytics owns native crashes: two crash reporters in one app
        // compete for the same signal handlers.
        ..errorTrackingConfig.captureNativeExceptions = false
        ..errorTrackingConfig.captureIsolateErrors = true
        ..debug = kDebugMode;
      await Posthog().setup(config);
      // An earlier opt-out is stored by the native SDK too.
      if (await Posthog().isOptOut()) await Posthog().optIn();
      _posthogReady = true;
      _enabled = true;

      final info = await PackageInfo.fromPlatform();
      await Posthog().register('app_version', info.version);
      await Posthog().register('app_build', info.buildNumber);
      await Posthog().register(
        'platform',
        kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    } catch (e) {
      debugPrint('Analytics init skipped: $e');
    }
  }

  /// Turns all analytics off (PostHog and backend events) or back on, and
  /// remembers the choice. Nothing is sent while it is off.
  static Future<void> setOptOut(bool optOut) async {
    if (optOut == _optedOut) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optOutKey, optOut);
    } catch (_) {}
    if (optOut) {
      _optedOut = true;
      if (_enabled) {
        _enabled = false;
        await Posthog().optOut().catchError(
          (Object e) => debugPrint('Analytics disable failed: $e'),
        );
      }
      await EventTracker.instance.stop();
      await CrashReporting.setCollection(false);
      return;
    }
    _optedOut = false;
    await CrashReporting.setCollection(true);
    if (!_buildSends) return;
    await _startPosthog();
    await _startTracker();
  }

  /// Records an event. Null property values are dropped.
  static void track(String event, [Map<String, Object?> properties = const {}]) {
    if (!allowsEvent(event)) return;
    EventTracker.instance.record(event, properties: properties);
    if (!_enabled) return;
    final props = <String, Object>{
      for (final e in properties.entries)
        if (e.value != null) e.key: e.value!,
    };
    Posthog()
        .capture(eventName: event, properties: props.isEmpty ? null : props)
        .catchError((Object e) => debugPrint('Analytics track failed: $e'));
  }

  /// Manually records a screen view, for tabs and sheets that are not routes.
  static void screen(String name, [Map<String, Object?> properties = const {}]) {
    if (!allowsEvent(r'$screen')) return;
    EventTracker.instance.manualScreen(name, properties);
    if (!_enabled) return;
    final props = <String, Object>{
      for (final e in properties.entries)
        if (e.value != null) e.key: e.value!,
    };
    Posthog()
        .screen(screenName: name, properties: props.isEmpty ? null : props)
        .catchError((Object e) => debugPrint('Analytics screen failed: $e'));
  }

  /// Links this device's events to an account (Firebase uid).
  static void identify(
    String userId, {
    Map<String, Object?> properties = const {},
    Map<String, Object?> setOnce = const {},
  }) {
    if (userId.isEmpty) return;
    CrashReporting.setUser(userId);
    // The backend already knows the account; it gets the provider details
    // without repeating the email and name on every identify.
    EventTracker.instance.record('identify', properties: {
      for (final e in properties.entries)
        if (e.key != 'email' && e.key != 'name') e.key: e.value,
    });
    if (!_enabled) return;
    Map<String, Object>? clean(Map<String, Object?> m) {
      final out = <String, Object>{
        for (final e in m.entries)
          if (e.value != null) e.key: e.value!,
      };
      return out.isEmpty ? null : out;
    }

    Posthog()
        .identify(
          userId: userId,
          userProperties: clean(properties),
          userPropertiesSetOnce: clean(setOnce),
        )
        .catchError((Object e) => debugPrint('Analytics identify failed: $e'));
  }

  /// Sets properties on the current person (settings, totals, preferences).
  static void setPersonProperties(Map<String, Object?> properties) {
    EventTracker.instance.record('person_properties', properties: properties);
    if (!_enabled) return;
    final props = <String, Object>{
      for (final e in properties.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (props.isEmpty) return;
    Posthog()
        .setPersonProperties(userPropertiesToSet: props)
        .catchError((Object e) => debugPrint('Analytics set failed: $e'));
  }

  /// Super property sent with every later event (e.g. current voice).
  static void register(String key, Object value) {
    if (!_enabled) return;
    Posthog()
        .register(key, value)
        .catchError((Object e) => debugPrint('Analytics register failed: $e'));
  }

  /// Forgets the identity on sign-out / account deletion.
  static void reset() {
    // Upload what this account did before the session token changes.
    unawaited(EventTracker.instance.flush());
    CrashReporting.setUser('');
    if (!_enabled) return;
    Posthog().reset().catchError(
      (Object e) => debugPrint('Analytics reset failed: $e'),
    );
  }

  static void captureException(Object error, StackTrace? stack, {String? where}) {
    final message = error.toString();
    EventTracker.instance.record(r'$exception', properties: {
      'error_type': error.runtimeType.toString(),
      'message': message.length > 200 ? message.substring(0, 200) : message,
      'where': where,
    });
    if (!_enabled) return;
    Posthog()
        .captureException(
          error: error,
          stackTrace: stack,
          properties: where == null ? null : {'where': where},
        )
        .catchError((Object e) => debugPrint('Analytics exception failed: $e'));
  }
}

/// Gives MaterialPageRoute pushes a screen name so [Analytics.observer]
/// reports them: `Navigator.push(context, screenRoute('quiz', (_) => ...))`.
MaterialPageRoute<T> screenRoute<T>(
  String name,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return MaterialPageRoute<T>(
    builder: builder,
    settings: RouteSettings(name: name),
    fullscreenDialog: fullscreenDialog,
  );
}
