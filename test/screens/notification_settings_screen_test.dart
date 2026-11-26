import 'package:bojang/screens/notification_settings_screen.dart';
import 'package:bojang/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationSettingsScreen()));
    await tester.pumpAndSettle();
  }

  SwitchListTile tile(WidgetTester tester, String title) => tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, title),
      );

  testWidgets('daily 10 AM reminder and streak reminders are on by default', (tester) async {
    await pump(tester);
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(tile(tester, 'Daily reminder (10 AM)').value, isTrue);
    expect(tile(tester, 'Streak reminders').value, isTrue);
  });

  testWidgets('turning the daily reminder off is saved for the backend', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Daily reminder (10 AM)'));
    await tester.pumpAndSettle();
    expect(tile(tester, 'Daily reminder (10 AM)').value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PushService.morningReminderKey), isFalse);
    // The streak switch is separate.
    expect(prefs.getBool(PushService.streakRemindersKey), isNull);
  });

  testWidgets('a stored choice is shown', (tester) async {
    SharedPreferences.setMockInitialValues({PushService.morningReminderKey: false});
    await pump(tester);
    expect(tile(tester, 'Daily reminder (10 AM)').value, isFalse);
  });
}
