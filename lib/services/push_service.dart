import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Push notifications from the Bojang backend through Firebase Cloud
/// Messaging: streak-at-risk reminders (the backend's hourly job) and
/// announcements sent from the admin endpoint.
///
/// The FCM token is registered with the backend (`POST /notifications/devices`)
/// for whoever is signed in, including anonymous learners, and again when the
/// token rotates or another account signs in. A message's `data.screen`
/// (home, streak, games, profile) opens that tab when the learner taps it.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// SharedPreferences key of the "Streak reminders" switch (default on).
  static const streakRemindersKey = 'push_streak_reminders';

  /// The tab a tapped notification asked for; MainNavigationScreen follows it.
  static final ValueNotifier<String?> requestedScreen = ValueNotifier(null);

  bool _started = false;
  String? _registeredUid;
  String? _registeredToken;

  bool get _available => !kIsWeb && Firebase.apps.isNotEmpty;

  /// Call after runApp: iOS shows the notification permission prompt if the
  /// learner has not answered it yet.
  Future<void> init() async {
    if (_started || !_available) return;
    _started = true;
    final messaging = FirebaseMessaging.instance;
    try {
      // iOS: show pushes as banners while the app is open too.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final settings = await messaging.requestPermission();
      Analytics.track('push_permission', {
        'status': settings.authorizationStatus.name,
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpened(initial);

      messaging.onTokenRefresh.listen((token) => unawaited(_register(token: token)));
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && user.uid != _registeredUid) unawaited(_register());
      });
      await _register();
    } catch (e) {
      debugPrint('Push setup skipped: $e');
    }
  }

  /// Re-sends the device settings (after the reminder switch changes).
  Future<void> syncSettings() => _register(force: true);

  Future<void> _register({String? token, bool force = false}) async {
    if (!_available) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && Platform.isIOS) {
        // FCM needs the APNs token first; it can arrive a moment after launch.
        String? apns;
        for (var i = 0; i < 5 && apns == null; i++) {
          apns = await messaging.getAPNSToken();
          if (apns == null) await Future<void>.delayed(const Duration(seconds: 2));
        }
        if (apns == null) {
          Analytics.track('push_token_unavailable', {'reason': 'no_apns_token'});
          return;
        }
      }
      token ??= await messaging.getToken();
      if (token == null || token.isEmpty) return;
      if (!force && token == _registeredToken && user.uid == _registeredUid) return;

      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final ok = await ApiService().registerPushDevice({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'locale': Platform.localeName,
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        'app_version': info.version,
        'reminders_enabled': prefs.getBool(streakRemindersKey) ?? true,
      });
      if (ok) {
        _registeredToken = token;
        _registeredUid = user.uid;
        Analytics.track('push_token_registered', {'refresh': force});
      }
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  void _onForeground(RemoteMessage message) {
    Analytics.track('push_received', {
      'campaign': message.data['campaign'],
      'screen': message.data['screen'],
      'foreground': true,
    });
    // iOS shows the banner itself (presentation options above); Android
    // does not show notification messages while the app is open.
    final n = message.notification;
    if (!kIsWeb && Platform.isAndroid && n != null) {
      unawaited(NotificationService().showNow(n.title ?? 'Bojang', n.body ?? ''));
    }
  }

  void _onOpened(RemoteMessage message) {
    final screen = message.data['screen'];
    Analytics.track('push_opened', {
      'campaign': message.data['campaign'],
      'screen': screen,
    });
    if (screen != null && screen.isNotEmpty) requestedScreen.value = screen;
  }
}
