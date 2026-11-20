import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Product analytics, backed by PostHog (project "Default project", US cloud).
///
/// Every call is fire-and-forget and never throws: analytics must not break a
/// lesson. Event names are snake_case `object_action`; the full catalog with
/// properties lives in ANALYTICS_EVENTS.md next to pubspec.yaml.
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

  static bool _enabled = false;
  static bool get enabled => _enabled;

  /// Route observer that turns every pushed page into a `$screen` event.
  /// Routes without a name are labelled by their widget type (see
  /// [screenRoute]) so MaterialPageRoute pushes are still readable.
  static final PosthogObserver observer = PosthogObserver(
    nameExtractor: (settings) => settings.name,
  );

  static Future<void> init() async {
    if (_projectToken.isEmpty) return;
    if (kDebugMode && !_sendInDebug) return;
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
        ..errorTrackingConfig.captureNativeExceptions = true
        ..errorTrackingConfig.captureIsolateErrors = true
        ..debug = kDebugMode;
      await Posthog().setup(config);
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

  /// Records an event. Null property values are dropped.
  static void track(String event, [Map<String, Object?> properties = const {}]) {
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
    if (!_enabled || userId.isEmpty) return;
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
    if (!_enabled) return;
    Posthog().reset().catchError(
      (Object e) => debugPrint('Analytics reset failed: $e'),
    );
  }

  static void captureException(Object error, StackTrace? stack, {String? where}) {
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
