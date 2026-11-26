import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'dart:io';
import '../utils/yak_lines.dart';
import 'analytics.dart';
import 'push_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // No permission prompt at launch: NotificationPrimer asks after the
    // first streak or freeze, and the reminder switch in Settings asks too.
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) =>
          _onTapped(response.payload, launch: 'background'),
    );
    // A local notification (the daily reminder, or a push Android showed
    // while the app was open) that started the app.
    try {
      final launch =
          await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _onTapped(launch!.notificationResponse?.payload, launch: 'cold');
      }
    } catch (e) {
      debugPrint('Notification launch details unavailable: $e');
    }

    // Channel for pushes from the backend (FCM android channel_id).
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_announcements);
    }

  }

  /// Shows the OS notification permission prompt (Android 13+ and iOS) if
  /// the learner has not answered it. Call it only from a moment the learner
  /// chose: the Settings reminder switch, or NotificationPrimer.
  Future<void> requestPermissions({bool exactAlarms = false}) async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permission for Android 13+
      final granted =
          await androidImplementation?.requestNotificationsPermission();
      Analytics.track('notification_permission_result', {'granted': granted});

      // The daily reminder is an exact alarm (Android 14 opens a settings
      // page for this), so only ask when that reminder is switched on.
      if (exactAlarms) {
        await androidImplementation?.requestExactAlarmsPermission();
      }
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iOSImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final granted = await iOSImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      Analytics.track('notification_permission_result', {'granted': granted});
    }
  }

  static const AndroidNotificationChannel _announcements = AndroidNotificationChannel(
    'announcements',
    'Reminders and news',
    description: 'Streak reminders and news from Bojang',
    importance: Importance.high,
  );

  /// The daily reminder's payload, so its taps are counted as push opens.
  static const dailyReminderPayload = '{"kind":"daily_reminder","screen":"home"}';

  /// A tapped local notification: its payload is the push's data (or the
  /// daily reminder's), handed to [PushService.handleOpened].
  static void _onTapped(String? payload, {required String launch}) {
    var data = <String, dynamic>{};
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Not ours: still an open.
      }
    }
    data.putIfAbsent('kind', () => 'local');
    PushService.instance.handleOpened(data, launch: launch);
  }

  /// Shows a push that arrived while the app is open (Android only; iOS
  /// shows it itself). [pushData] is the push's data, kept as the payload
  /// so a tap is recorded like a tap on the push itself.
  Future<void> showNow(
    String title,
    String body, {
    Map<String, dynamic> pushData = const {},
  }) async {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _announcements.id,
          _announcements.name,
          channelDescription: _announcements.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(pushData),
    );
  }

  Future<void> scheduleDailyNotification([TimeOfDay? customTime]) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminder',
      channelDescription: 'Daily reminder to learn Tibetan',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      showProgress: false,
      autoCancel: true,
      ongoing: false,
      ticker: 'Time to learn Tibetan!',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Use custom time or default to 11:30 AM
    final TimeOfDay scheduledTime = customTime ?? const TimeOfDay(hour: 11, minute: 30);
    
    // The reminder speaks in the yak's voice. The wording is fixed when the
    // reminder is scheduled, so it changes whenever it is rescheduled.
    final when = _nextInstanceOfTime(scheduledTime);
    final (title, body) = YakLines.reminder(when);

    // Schedule notification for the specified time
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      title,
      body,
      when,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: dailyReminderPayload,
    );
  }

  // Test method to schedule a notification in 5 seconds
  Future<void> scheduleTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_notification',
      'Test Notifications',
      channelDescription: 'Test notifications for BoJang app',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      showProgress: false,
      autoCancel: true,
      ongoing: false,
      ticker: 'Test Notification',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // For Android emulators, immediate notification works better than scheduled
    if (Platform.isAndroid) {
      // Show immediate notification for better Android emulator compatibility
      await Future.delayed(const Duration(seconds: 1));
      await flutterLocalNotificationsPlugin.show(
        1, // Different ID from the daily notification
        'Test Notification',
        'This is a test notification for BoJang - Notifications are working! 🎉',
        platformChannelSpecifics,
      );
    } else {
      // Schedule notification for 5 seconds from now for iOS
      await flutterLocalNotificationsPlugin.zonedSchedule(
        1, // Different ID from the daily notification
        'Test Notification',
        'This is a test notification for BoJang',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
} 