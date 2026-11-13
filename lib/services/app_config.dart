import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get firebaseEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_FIREBASE');

  // Apple's Sign in with Apple backend does not recognise com.bojang.app
  // (akd AKSQLError -6003; FB25056179, DTS case 22654569), so the sheet ends in
  // "Sign Up Not Completed" for everyone. App Review guideline 4.8 only allows
  // Google sign-in on iOS next to a working Sign in with Apple, so both stay
  // off on iOS until Apple repairs the registration. Build with
  // --dart-define=IOS_SOCIAL_SIGN_IN=true to bring them back.
  static bool get iosSocialSignInEnabled =>
      const bool.fromEnvironment('IOS_SOCIAL_SIGN_IN');

  static bool get googleSignInEnabled =>
      debugGoogleSignInEnabled ?? (!isIOS || iosSocialSignInEnabled);

  // Sign in with Apple is native to Apple platforms and exchanges its token
  // through Firebase Auth, so it is offered only where both are available.
  static bool get appleSignInEnabled =>
      debugAppleSignInEnabled ??
      (isIOS && firebaseEnabled && iosSocialSignInEnabled);

  // Email and password accounts live in Firebase Auth, whose ID token the
  // backend's /auth/sync accepts like any other provider's.
  static bool get emailSignInEnabled =>
      debugEmailSignInEnabled ?? (!kIsWeb && firebaseEnabled);

  // Every learner gets a Firebase anonymous account on first launch, so
  // progress syncs to the backend with no sign-up. Creating an account later
  // upgrades that same account (same uid), keeping the progress.
  static bool get anonymousSessionsEnabled =>
      debugAnonymousSessionsEnabled ?? (!kIsWeb && firebaseEnabled);

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

  /// Test-only override for [googleSignInEnabled].
  @visibleForTesting
  static bool? debugGoogleSignInEnabled;

  /// Test-only override for [emailSignInEnabled].
  @visibleForTesting
  static bool? debugEmailSignInEnabled;

  /// Test-only override for [anonymousSessionsEnabled].
  @visibleForTesting
  static bool? debugAnonymousSessionsEnabled;

  /// Test-only override for [appleSignInDiagnosticsEnabled].
  @visibleForTesting
  static bool? debugAppleSignInDiagnosticsEnabled;
}
