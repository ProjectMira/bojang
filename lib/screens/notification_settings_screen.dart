import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../widgets/content_width.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = false;
  bool _streakReminders = true;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 11, minute: 30);
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadSettings();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.init();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _streakReminders = prefs.getBool(PushService.streakRemindersKey) ?? true;
      final hour = prefs.getInt('notification_hour') ?? 11;
      final minute = prefs.getInt('notification_minute') ?? 30;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('notification_hour', _selectedTime.hour);
    await prefs.setInt('notification_minute', _selectedTime.minute);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    Analytics.track('notifications_toggled', {'enabled': value});
    Analytics.setPersonProperties({'notifications_enabled': value});

    if (value) {
      // The app no longer asks at launch: switching a reminder on asks.
      await _askPermission(exactAlarms: true);
      await _notificationService.scheduleDailyNotification(_selectedTime);
    } else {
      await _notificationService.cancelAllNotifications();
    }
    
    await _saveSettings();
  }

  Future<void> _toggleStreakReminders(bool value) async {
    setState(() => _streakReminders = value);
    Analytics.track('setting_changed', {
      'setting': 'streak_reminders',
      'value': value,
    });
    if (value) await _askPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PushService.streakRemindersKey, value);
    await PushService.instance.syncSettings();
  }

  Future<void> _askPermission({bool exactAlarms = false}) async {
    if (kIsWeb) return;
    try {
      await _notificationService.requestPermissions(exactAlarms: exactAlarms);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      Analytics.track('reminder_time_changed', {
        'hour': picked.hour,
        'minute': picked.minute,
        'notifications_enabled': _notificationsEnabled,
      });
      Analytics.setPersonProperties({
        'reminder_time':
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
      });
      
      await _saveSettings();
      
      // If notifications are enabled, reschedule with new time
      if (_notificationsEnabled) {
        await _notificationService.scheduleDailyNotification(_selectedTime);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder time updated to ${_selectedTime.format(context)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
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
            Text(
              'Get reminded to learn Tibetan every day at ${_selectedTime.format(context)}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Daily Reminder'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            SwitchListTile(
              title: const Text('Streak reminders'),
              subtitle: const Text(
                'An evening nudge when your streak would end at midnight',
              ),
              value: _streakReminders,
              onChanged: _toggleStreakReminders,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _selectTime,
              icon: const Icon(Icons.access_time),
              label: Text('Change Time (${_selectedTime.format(context)})'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),),
    );
  }
} 