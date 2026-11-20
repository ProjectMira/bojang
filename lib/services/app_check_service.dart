import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check: proves to the backend that a request comes from the
/// genuine Bojang app on a real device (DeviceCheck on iOS, Play Integrity on
/// Android). ApiService sends the token as `X-Firebase-AppCheck`; the
/// backend's APP_CHECK_MODE decides whether a missing token is only counted
/// (monitor) or refused (enforce).
///
/// Debug builds use the debug provider: the debug token printed in the Xcode
/// log must be added in the Firebase console for those requests to verify.
class AppCheckService {
  AppCheckService._();

  static bool _active = false;

  static Future<void> init() async {
    if (_active || kIsWeb || Firebase.apps.isEmpty) return;
    try {
      await FirebaseAppCheck.instance.activate(
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _active = true;
    } catch (e) {
      debugPrint('App Check init skipped: $e');
    }
  }

  /// The current token (cached by the SDK), or null when App Check is off or
  /// attestation failed. Never waits more than 3 seconds.
  static Future<String?> token() async {
    if (!_active) return null;
    try {
      return await FirebaseAppCheck.instance
          .getToken()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }
}
