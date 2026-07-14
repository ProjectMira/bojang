import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get firebaseEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_FIREBASE');

  // Sign in with Apple runs through Firebase Auth, so it is only offered on
  // Apple platforms in builds where Firebase is configured.
  static bool get appleSignInEnabled => isIOS && firebaseEnabled;
}
