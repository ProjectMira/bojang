import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Firebase Crashlytics (crashes and errors, symbolicated) and Performance
/// Monitoring (app start, API timings).
///
/// Crashlytics owns native crashes; PostHog still receives Dart errors
/// because its handlers chain to the ones installed here. Both follow the
/// "Share usage analytics" switch, and debug builds send nothing.
class CrashReporting {
  CrashReporting._();

  static bool _ready = false;
  static bool _collecting = false;

  /// True while Performance Monitoring records HTTP metrics.
  static bool get performanceOn => _ready && _collecting;

  static bool get _available => !kIsWeb && Firebase.apps.isNotEmpty;

  /// Installs the error handlers. Call before Analytics.init() so PostHog's
  /// handlers wrap these.
  static Future<void> init({required bool collect}) async {
    if (!_available || _ready) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      final previousFlutter = FlutterError.onError;
      FlutterError.onError = (details) {
        crashlytics.recordFlutterError(details);
        previousFlutter?.call(details);
      };

      final previousPlatform = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        // Uncaught async errors do not end the app, so they are non-fatal.
        crashlytics.recordError(error, stack, reason: 'uncaught async error');
        return previousPlatform?.call(error, stack) ?? false;
      };

      _ready = true;
      await setCollection(collect);
    } catch (e) {
      debugPrint('Crash reporting init skipped: $e');
    }
  }

  /// Follows the analytics switch. Off also deletes reports not yet sent.
  static Future<void> setCollection(bool collect) async {
    if (!_ready) return;
    final on = collect && !kDebugMode;
    _collecting = on;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on);
      if (!on) await FirebaseCrashlytics.instance.deleteUnsentReports();
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(on);
    } catch (e) {
      debugPrint('Crash reporting switch failed: $e');
    }
  }

  /// Ties crash reports to the account (Firebase uid); '' clears it.
  static void setUser(String uid) {
    if (!_ready) return;
    FirebaseCrashlytics.instance
        .setUserIdentifier(uid)
        .catchError((Object e) => debugPrint('Crashlytics user failed: $e'));
  }

  /// A key shown on every later crash report (screen, app state).
  static void setKey(String key, Object value) {
    if (!_ready) return;
    FirebaseCrashlytics.instance
        .setCustomKey(key, value)
        .catchError((Object e) => debugPrint('Crashlytics key failed: $e'));
  }

  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    if (!_ready) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason)
        .catchError((Object e) => debugPrint('Crashlytics record failed: $e'));
  }
}

/// Records each backend request as a Performance Monitoring HTTP metric
/// (Flutter's http package bypasses the SDK's automatic URLSession capture).
/// Query strings are dropped from the reported URL.
class PerformanceHttpClient extends http.BaseClient {
  PerformanceHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    HttpMetric? metric;
    if (CrashReporting.performanceOn) {
      try {
        final u = request.url;
        final url = Uri(scheme: u.scheme, host: u.host, port: u.port, path: u.path).toString();
        metric = FirebasePerformance.instance.newHttpMetric(url, _method(request.method))
          ..requestPayloadSize = request.contentLength;
        await metric.start();
      } catch (_) {
        metric = null;
      }
    }
    try {
      final response = await _inner.send(request);
      if (metric != null) {
        metric
          ..httpResponseCode = response.statusCode
          ..responsePayloadSize = response.contentLength
          ..responseContentType = response.headers['content-type'];
        unawaited(metric.stop().catchError((Object _) {}));
      }
      return response;
    } catch (_) {
      if (metric != null) unawaited(metric.stop().catchError((Object _) {}));
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  static HttpMethod _method(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return HttpMethod.Post;
      case 'PUT':
        return HttpMethod.Put;
      case 'PATCH':
        return HttpMethod.Patch;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'HEAD':
        return HttpMethod.Head;
      case 'OPTIONS':
        return HttpMethod.Options;
      default:
        return HttpMethod.Get;
    }
  }
}
