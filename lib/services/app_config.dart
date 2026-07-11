import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get firebaseEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_FIREBASE');

  static bool get googleSignInEnabled =>
      !isIOS || const bool.fromEnvironment('ENABLE_IOS_GOOGLE_SIGN_IN');
}
