import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get firebaseEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_FIREBASE');

  // Sign in with Apple is native to Apple platforms and exchanges its token
  // through Firebase Auth, so it is offered only where both are available.
  static bool get appleSignInEnabled =>
      debugAppleSignInEnabled ?? (isIOS && firebaseEnabled);

  // When Apple refuses an authorization it is reported exactly like a
  // dismissal. TestFlight builds set this so the refusal reaches the on-screen
  // error dialog with its code and timestamp instead of vanishing.
  static bool get appleSignInDiagnosticsEnabled =>
      debugAppleSignInDiagnosticsEnabled ??
      const bool.fromEnvironment('APPLE_SIGN_IN_DIAGNOSTICS');

  /// Test-only override for [appleSignInEnabled]: the real value depends on
  /// the compile-time `ENABLE_IOS_FIREBASE` flag, which widget tests cannot
  /// set, so without this seam the Apple button can never be exercised.
  @visibleForTesting
  static bool? debugAppleSignInEnabled;

  /// Test-only override for [appleSignInDiagnosticsEnabled].
  @visibleForTesting
  static bool? debugAppleSignInDiagnosticsEnabled;
}
