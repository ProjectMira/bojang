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
/// Messaging: the daily 10 AM morning reminder and streak-at-risk reminders
/// (the backend's hourly job), and announcements sent from the admin
/// endpoint.
///
/// iOS: at first launch the app asks for *provisional* authorization
/// (no prompt; pushes arrive quietly in Notification Centre), so every
/// install gets a token and the morning reminder from day one. The full
/// prompt (banners and sound) comes later, after the first lesson
/// (NotificationPrimer) or from Settings.
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

  /// SharedPreferences key of the "Daily reminder (10 AM)" switch (default
  /// on). Sent as `morning_reminder`; the backend sends that push.
  static const morningReminderKey = 'push_morning_reminder';

  /// The old local daily reminder (NotificationService, time picked in
  /// Settings). Retired once by [init]: the backend's 10 AM push replaces it.
  static const _legacyLocalReminderKey = 'notifications_enabled';
  /// The tab a tapped notification asked for; MainNavigationScreen follows it.
  static final ValueNotifier<String?> requestedScreen = ValueNotifier(null);

  bool _started = false;
  String? _registeredUid;
  String? _registeredToken;

  bool get _available => !kIsWeb && Firebase.apps.isNotEmpty;

  /// Message ids already handled by [handleOpened], so a push is counted
  /// once even if FCM reports it twice (getInitialMessage after a restart).
  final Set<String> _openedIds = {};

  /// Call after runApp. It does not ask for notification permission: that
  /// happens at a moment that matters (NotificationPrimer, after the first
  /// lesson or a streak) or from the Settings switches ([requestPermission]).
  /// The token is registered either way, so pushes work once allowed.
  Future<void> init() async {
    if (_started || !_available) return;
    _started = true;
    final messaging = FirebaseMessaging.instance;
    // Taps first, each on its own: a failure in the setup below used to skip
    // these listeners, and the push that launched the app was never counted.
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => handleOpened(m.data, messageId: m.messageId, launch: 'background'),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        handleOpened(initial.data, messageId: initial.messageId, launch: 'cold');
      }
    } catch (e) {
      debugPrint('Push open handling skipped: $e');
    }
    try {
      // iOS: show pushes as banners while the app is open too.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      var settings = await messaging.getNotificationSettings();
      Analytics.track('push_permission', {
        'status': settings.authorizationStatus.name,
        'source': 'launch',
      });
      if (!kIsWeb &&
          Platform.isIOS &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Quiet delivery, no prompt: the token registers for everyone.
        settings = await messaging.requestPermission(provisional: true);
        Analytics.track('push_permission', {
          'status': settings.authorizationStatus.name,
          'source': 'provisional',
        });
      }
      await _retireLocalDailyReminder();

      FirebaseMessaging.onMessage.listen(_onForeground);

      messaging.onTokenRefresh.listen((token) => unawaited(_register(token: token)));
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && user.uid != _registeredUid) unawaited(_register());
      });
      await _register();
    } catch (e) {
      debugPrint('Push setup skipped: $e');
    }
  }

  /// Two daily reminders would be one too many: an older build's local
  /// daily reminder is cancelled once (the 10 AM push takes over).
  Future<void> _retireLocalDailyReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_legacyLocalReminderKey) != true) return;
      await NotificationService().cancelAllNotifications();
      await prefs.setBool(_legacyLocalReminderKey, false);
      Analytics.track('local_daily_reminder_retired', {
        'hour': prefs.getInt('notification_hour'),
        'minute': prefs.getInt('notification_minute'),
      });
    } catch (e) {
      debugPrint('Local reminder cleanup skipped: $e');
    }
  }

  /// Re-sends the device settings (after the reminder switch changes).
  Future<void> syncSettings() => _register(force: true);

  /// The OS notification permission, without asking. Null when push is
  /// unavailable (web, no Firebase) or the platform call fails.
  Future<AuthorizationStatus?> permissionStatus() async {
    if (!_available) return null;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (_) {
      return null;
    }
  }

  /// Shows the OS permission prompt if it can still be shown (iOS and
  /// Android 13+), then re-registers the token. [source] says which moment
  /// asked (primer_streak, primer_freeze, settings). Returns whether
  /// notifications are allowed afterwards.
  Future<bool> requestPermission({required String source}) async {
    if (!_available) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final status = settings.authorizationStatus;
      Analytics.track('push_permission', {'status': status.name, 'source': source});
      final allowed = status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      if (allowed) unawaited(_register(force: true));
      return allowed;
    } catch (e) {
      debugPrint('Push permission request failed: $e');
      return false;
    }
  }

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
        'morning_reminder': prefs.getBool(morningReminderKey) ?? true,
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
      'line_id': message.data['line_id'],
      'foreground': true,
    });
    // iOS shows the banner itself (presentation options above); Android
    // does not show notification messages while the app is open.
    // The push's data rides along as the payload, so tapping that local
    // notification is counted like any other push (handleOpened).
    final n = message.notification;
    if (!kIsWeb && Platform.isAndroid && n != null) {
      unawaited(NotificationService().showNow(
        n.title ?? 'Bojang',
        n.body ?? '',
        pushData: message.data,
      ));
    }
  }

  /// A push was tapped. [launch] says how it reached the app: `cold` (it
  /// started the app, getInitialMessage), `background` (onMessageOpenedApp)
  /// or `foreground` (the local copy Android shows while the app is open).
  /// Records `push_opened` and `notification_opened` with the push's data,
  /// tells the backend (`POST /notifications/opened`), and asks
  /// MainNavigationScreen for the tab in `data.screen`. NotificationService
  /// calls it for taps on local notifications.
  void handleOpened(
    Map<String, dynamic> data, {
    String? messageId,
    required String launch,
  }) {
    if (messageId != null && !_openedIds.add(messageId)) return;
    String? field(String key) {
      final value = data[key];
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    final screen = field('screen');
    Analytics.track('push_opened', {
      'kind': field('kind'),
      'screen': screen,
      'campaign': field('campaign'),
      'state': field('state'),
      'line_id': field('line_id'),
      'notification_id': field('notification_id'),
      'launch': launch,
    });
    // Streak pushes carry the copy line they used, so PostHog can compare
    // open rates per line (backend logs each send as server_push_sent).
    Analytics.track('notification_opened', {
      'campaign': field('campaign'),
      'kind': field('kind'),
      'state': field('state'),
      'line_id': field('line_id'),
      'notification_id': field('notification_id'),
    });
    // Tells the backend this push was opened, so no streak saver follows.
    final id = field('notification_id');
    if (id != null) unawaited(_reportOpened(id, lineId: field('line_id')));
    if (screen != null) requestedScreen.value = screen;
  }

  /// Sends the open once someone is signed in. A push that launches the app
  /// arrives before the session is restored (or, for a new anonymous
  /// learner, created), and the request then went out without a token and
  /// was refused, so `opened_at` stayed empty.
  Future<void> _reportOpened(String id, {String? lineId}) async {
    if (!_available) return;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((user) => user != null)
            .timeout(const Duration(seconds: 30));
      }
      final ok = await ApiService().reportPushOpened(id, lineId: lineId);
      if (!ok) Analytics.track('push_open_report_failed', {'notification_id': id});
    } catch (e) {
      debugPrint('Push open report skipped: $e');
      Analytics.track('push_open_report_failed', {'notification_id': id});
    }
  }
}
