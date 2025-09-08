import 'package:mockito/annotations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/mockito.dart';

// Generate mock classes
@GenerateMocks([
  FlutterLocalNotificationsPlugin,
])
class MockNotifications {}

// Mock implementation for testing
class MockFlutterLocalNotificationsPlugin extends Mock 
    implements FlutterLocalNotificationsPlugin {
  
  bool _isInitialized = false;
  bool _hasActiveNotifications = false;
  List<Map<String, dynamic>> _scheduledNotifications = [];

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    _isInitialized = true;
    return true;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    dynamic scheduledDate,
    NotificationDetails notificationDetails, {
    String? payload,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (!_isInitialized) {
      throw Exception('Plugin not initialized');
    }

    _hasActiveNotifications = true;
    _scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'matchDateTimeComponents': matchDateTimeComponents,
      'androidScheduleMode': androidScheduleMode,
    });
  }

  @override
  Future<void> cancelAll() async {
    _hasActiveNotifications = false;
    _scheduledNotifications.clear();
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    _scheduledNotifications.removeWhere((notification) => notification['id'] == id);
    if (_scheduledNotifications.isEmpty) {
      _hasActiveNotifications = false;
    }
  }

  // Helper methods for testing
  bool get isInitialized => _isInitialized;
  bool get hasActiveNotifications => _hasActiveNotifications;
  List<Map<String, dynamic>> get scheduledNotifications => 
      List.unmodifiable(_scheduledNotifications);
  
  Map<String, dynamic>? getNotificationById(int id) {
    try {
      return _scheduledNotifications.firstWhere((n) => n['id'] == id);
    } catch (e) {
      return null;
    }
  }

  int get scheduledNotificationCount => _scheduledNotifications.length;

  void reset() {
    _isInitialized = false;
    _hasActiveNotifications = false;
    _scheduledNotifications.clear();
  }
}

