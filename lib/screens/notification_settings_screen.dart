import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics.dart';
import '../services/push_service.dart';
import '../widgets/content_width.dart';

/// Settings > Notifications: the two pushes the backend sends.
///
/// - Daily reminder (10 AM): the backend's morning push at 10:00 local time
///   on days the learner has not practised yet (`morning_reminder`).
/// - Streak reminders: the evening nudge and late streak saver when the
///   streak would end at midnight (`reminders_enabled`).
///
/// Each switch is stored locally and re-sent with the FCM token
/// (`POST /notifications/devices`), so it follows the learner to the server.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _morningReminder = true;
  bool _streakReminders = true;
  AuthorizationStatus? _permission;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final permission = await PushService.instance.permissionStatus();
    if (!mounted) return;
    setState(() {
      _morningReminder = prefs.getBool(PushService.morningReminderKey) ?? true;
      _streakReminders = prefs.getBool(PushService.streakRemindersKey) ?? true;
      _permission = permission;
    });
  }

  Future<void> _toggleMorningReminder(bool value) async {
    setState(() => _morningReminder = value);
    Analytics.track('setting_changed', {
      'setting': 'morning_reminder',
      'value': value,
    });
    Analytics.setPersonProperties({'morning_reminder': value});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PushService.morningReminderKey, value);
    if (value) await _askPermission();
    await PushService.instance.syncSettings();
  }

  Future<void> _toggleStreakReminders(bool value) async {
    setState(() => _streakReminders = value);
    Analytics.track('setting_changed', {
      'setting': 'streak_reminders',
      'value': value,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PushService.streakRemindersKey, value);
    if (value) await _askPermission();
    await PushService.instance.syncSettings();
  }

  /// Turning a reminder on asks for banners if iOS can still show the
  /// prompt (undecided, or only quiet provisional delivery so far).
  Future<void> _askPermission() async {
    if (kIsWeb) return;
    final status = _permission;
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.denied) {
      return;
    }
    await PushService.instance.requestPermission(source: 'settings');
    final after = await PushService.instance.permissionStatus();
    if (mounted) setState(() => _permission = after);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _permission == AuthorizationStatus.denied;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ContentWidth(maxWidth: ContentWidth.reading, child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Reminder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Norbu sends a nudge at 10 AM your time to learn a little '
              'Tibetan. Days you have already practised are skipped.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Daily reminder (10 AM)'),
              value: _morningReminder,
              onChanged: _toggleMorningReminder,
            ),
            SwitchListTile(
              title: const Text('Streak reminders'),
              subtitle: const Text(
                'An evening nudge when your streak would end at midnight',
              ),
              value: _streakReminders,
              onChanged: _toggleStreakReminders,
            ),
            if (blocked) ...[
              const SizedBox(height: 16),
              const Text(
                'Notifications are turned off for Bojang. To get reminders, '
                'allow them in the iPhone Settings app under Notifications.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),),
    );
  }
}
