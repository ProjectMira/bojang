import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/event_policy.dart';
import '../models/firebase_event_rules.dart';
import 'crash_reporting.dart';
import 'event_tracker.dart';

/// Product analytics, sent to three places:
/// - PostHog (project "Bojang", US cloud): named events, screens, person
///   profiles, session replay and error tracking.
/// - The Bojang backend (`app_events` table) through [EventTracker]: every
///   named event plus every tap, swipe, scroll, screen dwell time and app
///   session, with device context.
/// - Google Analytics for Firebase: named events, screen views, app session
///   start/end, user id and user properties, fitted to GA4's limits by
///   [FirebaseEventRules]. Not taps, scrolls or dwell time (volume), and no
///   names, emails or coordinates. Only where Firebase is configured
///   (`AppConfig.firebaseEnabled`); no advertising id, no ad signals.
///
/// Every call is fire-and-forget and never throws: analytics must not break a
/// lesson. Event names are snake_case `object_action`; the full catalog with
/// properties lives in ANALYTICS_EVENTS.md next to pubspec.yaml. Learners can
/// switch all of them off in Settings ([setOptOut]).
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

  /// Debug builds send to Firebase Analytics only with
  /// FIREBASE_ANALYTICS_IN_DEBUG=true (or POSTHOG_IN_DEBUG=true), for
  /// checking events in the Firebase console's DebugView.
  static const bool _firebaseInDebug = bool.fromEnvironment(
    'FIREBASE_ANALYTICS_IN_DEBUG',
  );

  static bool get _firebaseBuildSends => _buildSends || _firebaseInDebug;

  /// Firebase Analytics is collecting (configured, allowed, not opted out).
  static bool _firebaseOn = false;

  static bool get _firebaseAvailable {
    if (kIsWeb) return false;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Tracker events also sent to Firebase. Taps, scrolls, swipes and dwell
  /// time stay out: GA4 is for product events, and their volume would bury
  /// them.
  static const Set<String> _firebaseMirrored = {
    'app_session_started',
    'app_session_ended',
  };

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
    // Collection is off in Info.plist until this runs, and the setting
    // persists on the device, so it is applied on every launch.
    await _setFirebase(!_optedOut && _firebaseBuildSends);
    // Screen changes reach Firebase through the tracker's callbacks, which
    // fire even when the tracker itself is not recording (debug builds).
    _wireTracker();
    if (_optedOut || !_buildSends) return;
    await _startPosthog();
    await _startTracker();
  }

  /// Turns Firebase Analytics collection on or off. Off also clears the
  /// device's Analytics data (app instance id, unsent events).
  static Future<void> _setFirebase(bool on, {bool clear = false}) async {
    if (!_firebaseAvailable) {
      _firebaseOn = false;
      return;
    }
    try {
      final fa = FirebaseAnalytics.instance;
      if (on) {
        // Analytics only: no ad storage, ad user data or ad personalization.
        await fa.setConsent(
          analyticsStorageConsentGranted: true,
          adStorageConsentGranted: false,
          adUserDataConsentGranted: false,
          adPersonalizationSignalsConsentGranted: false,
        );
      }
      await fa.setAnalyticsCollectionEnabled(on);
      if (!on && clear) await fa.resetAnalyticsData();
      _firebaseOn = on;
    } catch (e) {
      _firebaseOn = false;
      debugPrint('Firebase Analytics ${on ? 'start' : 'stop'} failed: $e');
    }
  }

  static void _firebase(
    String what,
    Future<void> Function(FirebaseAnalytics fa) call,
  ) {
    if (!_firebaseOn) return;
    try {
      call(FirebaseAnalytics.instance).catchError(
        (Object e) => debugPrint('Firebase Analytics $what failed: $e'),
      );
    } catch (e) {
      debugPrint('Firebase Analytics $what failed: $e');
    }
  }

  static void _firebaseEvent(String event, Map<String, Object?> properties) {
    if (!_firebaseOn) return;
    final name = FirebaseEventRules.eventName(event);
    if (name == null) return;
    final params = FirebaseEventRules.params(properties);
    _firebase(
      'event',
      (fa) =>
          fa.logEvent(name: name, parameters: params.isEmpty ? null : params),
    );
  }

  static void _firebaseScreen(String screen) {
    if (!_firebaseOn || !allowsEvent(r'$screen')) return;
    final name = FirebaseEventRules.screenName(screen);
    _firebase(
      'screen',
      (fa) => fa.logScreenView(screenName: name, screenClass: 'Flutter'),
    );
  }

  static Future<void> _startTracker() async {
    _wireTracker();
    await EventTracker.instance.start();
  }

  static void _wireTracker() {
    final tracker = EventTracker.instance;
    tracker.filter = allowsEvent;
    tracker.onSessionStarted = (id) {
      register('bojang_session_id', id);
      // Ties GA4 events to the backend's app_events rows.
      _firebase(
        'session id',
        (fa) => fa.setDefaultEventParameters({'bojang_session_id': id}),
      );
    };
    // Every PostHog event (autocaptured rage clicks included) carries the
    // screen it happened on. Route pushes and Analytics.screen both land
    // here, so this is also where Firebase gets its screen views.
    tracker.onScreenChanged = (screen) {
      register('current_screen', screen);
      _firebaseScreen(screen);
    };
    // Taps, scrolls, swipes, dwell time and sessions go to PostHog as well as
    // to the backend's app_events table; session start/end to Firebase too.
    tracker.mirror = (event, screen, properties) {
      _mirrorToPosthog(event, screen, properties);
      if (_firebaseMirrored.contains(event)) {
        _firebaseEvent(event, properties);
      }
    };
  }

  static const String _installKey = 'analytics_install_id';
  static String? _install;

  /// A random id made on first launch and kept for the life of the install.
  static Future<String> installId() async {
    if (_install != null) return _install!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_installKey, id);
    }
    return _install = id;
  }

  static void _mirrorToPosthog(
    String event,
    String? screen,
    Map<String, Object?> properties,
  ) {
    if (!_enabled) return;
    final props = <String, Object>{
      for (final e in properties.entries)
        if (e.value != null) e.key: e.value!,
      if (screen != null) 'screen': screen,
    };
    Posthog()
        .capture(eventName: event, properties: props)
        .catchError((Object e) => debugPrint('Analytics mirror failed: $e'));
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
      final config =
          PostHogConfig(_projectToken)
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
      // One id per install, on every event: ties a phone's events together
      // even before (or without) an account.
      final install = await installId();
      await Posthog().register('install_id', install);
      EventTracker.instance.record('install_id', properties: {'id': install});
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
      await _setFirebase(false, clear: true);
      return;
    }
    _optedOut = false;
    await CrashReporting.setCollection(true);
    await _setFirebase(_firebaseBuildSends);
    if (!_buildSends) return;
    await _startPosthog();
    await _startTracker();
  }

  /// Records an event. Null property values are dropped.
  static void track(
    String event, [
    Map<String, Object?> properties = const {},
  ]) {
    if (!allowsEvent(event)) return;
    EventTracker.instance.record(event, properties: properties);
    _firebaseEvent(event, properties);
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
  static void screen(
    String name, [
    Map<String, Object?> properties = const {},
  ]) {
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
    // The Firebase uid as GA4 user id; email and name are left out.
    _firebase('identify', (fa) async {
      await fa.setUserId(id: userId);
      for (final e in FirebaseEventRules.userProperties(properties).entries) {
        await fa.setUserProperty(name: e.key, value: e.value);
      }
    });
    // The backend already knows the account; it gets the provider details
    // without repeating the email and name on every identify.
    EventTracker.instance.record(
      'identify',
      properties: {
        for (final e in properties.entries)
          if (e.key != 'email' && e.key != 'name') e.key: e.value,
      },
    );
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
    _firebase('user properties', (fa) async {
      for (final e in FirebaseEventRules.userProperties(properties).entries) {
        await fa.setUserProperty(name: e.key, value: e.value);
      }
    });
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
    _firebase('reset', (fa) => fa.setUserId(id: null));
    if (!_enabled) return;
    Posthog().reset().catchError(
      (Object e) => debugPrint('Analytics reset failed: $e'),
    );
  }

  static void captureException(
    Object error,
    StackTrace? stack, {
    String? where,
  }) {
    final message = error.toString();
    EventTracker.instance.record(
      r'$exception',
      properties: {
        'error_type': error.runtimeType.toString(),
        'message': message.length > 200 ? message.substring(0, 200) : message,
        'where': where,
      },
    );
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
