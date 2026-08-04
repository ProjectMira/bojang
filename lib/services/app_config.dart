import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get firebaseEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_FIREBASE');

  // Sign in with Apple runs through Firebase Auth, so it is only offered on
  // Apple platforms in builds where Firebase is configured.
  static bool get appleSignInEnabled =>
      debugAppleSignInEnabled ?? (isIOS && firebaseEnabled);

  // AuthenticationServices reports both a genuine sheet dismissal and the
  // server-side "Sign-Up Not Completed" failure as `canceled` (error 1001).
  // TestFlight builds enable this so that otherwise invisible Apple failures
  // reach the in-app error dialog with a timestamp and native error code.
  static bool get appleSignInDiagnosticsEnabled =>
      debugAppleSignInDiagnosticsEnabled ??
      const bool.fromEnvironment('APPLE_SIGN_IN_DIAGNOSTICS');

  /// Test-only override for [appleSignInEnabled]. The real value depends on
  /// the compile-time `ENABLE_IOS_FIREBASE` flag, which widget tests cannot
  /// set, so without this seam the Apple button can never be exercised.
  @visibleForTesting
  static bool? debugAppleSignInEnabled;

  /// Test-only override for [appleSignInDiagnosticsEnabled].
  @visibleForTesting
  static bool? debugAppleSignInDiagnosticsEnabled;
}
