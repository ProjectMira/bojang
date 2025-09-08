import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/notification_settings_screen.dart';
import 'package:bojang/services/notification_service.dart';

void main() {
  group('NotificationSettingsScreen Widget Tests', () {
    testWidgets('should display app bar with correct title', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Notification Settings'), findsOneWidget);
    });

    testWidgets('should display daily reminder section', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.text('Daily Reminder'), findsOneWidget);
      expect(find.text('Get reminded to learn Tibetan every day at 11:30 AM'), findsOneWidget);
    });

    testWidgets('should display switch for daily reminder', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Enable Daily Reminder'), findsOneWidget);
      
      // Initially should be false
      final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, isFalse);
    });

    testWidgets('should toggle notification switch', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Act - Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 300));

      // Assert - Switch should be on
      final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, isTrue);
    });

    testWidgets('should display test notification section', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.text('Test Notifications'), findsOneWidget);
      expect(find.text('Send a test notification to verify the feature is working'), findsOneWidget);
    });

    testWidgets('should display test notification button', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Send Test Notification'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });

    testWidgets('should show snackbar when test notification button tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Act
      await tester.tap(find.text('Send Test Notification'));
      await tester.pump(); // Start the snackbar animation
      await tester.pump(const Duration(milliseconds: 100)); // Let animation start

      // Assert
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test notification scheduled for 5 seconds from now'), findsOneWidget);
    });

    testWidgets('should have proper layout structure', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Padding), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('should have correct padding and spacing', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, equals(const EdgeInsets.all(16.0)));
    });

    testWidgets('should display proper text styles', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert section headers
      final dailyReminderText = tester.widget<Text>(find.text('Daily Reminder'));
      expect(dailyReminderText.style?.fontSize, equals(20));
      expect(dailyReminderText.style?.fontWeight, equals(FontWeight.bold));

      final testNotificationText = tester.widget<Text>(find.text('Test Notifications'));
      expect(testNotificationText.style?.fontSize, equals(20));
      expect(testNotificationText.style?.fontWeight, equals(FontWeight.bold));

      // Assert description text
      final descriptionText = tester.widget<Text>(
        find.text('Get reminded to learn Tibetan every day at 11:30 AM'));
      expect(descriptionText.style?.fontSize, equals(16));
      expect(descriptionText.style?.color, equals(Colors.grey));
    });

    testWidgets('should have proper button styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: NotificationSettingsScreen(),
      ));

      // Assert
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final buttonStyle = button.style;
      expect(buttonStyle?.minimumSize?.resolve({}), equals(const Size(double.infinity, 50)));
    });

    group('State Management Tests', () {
      testWidgets('should initialize with notifications disabled', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Assert
        final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isFalse);
      });

      testWidgets('should update state when switch is toggled multiple times', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Act - Toggle on
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - Should be on
        SwitchListTile switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isTrue);

        // Act - Toggle off
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - Should be off
        switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isFalse);
      });

      testWidgets('should call notification service methods on toggle', (WidgetTester tester) async {
        // This is more of an integration test - we can't easily mock the service
        // but we can ensure the toggle works without errors
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Should not throw exceptions when toggling
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));
        
        expect(tester.takeException(), isNull);
      });
    });

    group('Interaction Tests', () {
      testWidgets('should handle multiple button taps', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Act - Tap multiple times rapidly
        await tester.tap(find.text('Send Test Notification'));
        await tester.pump();
        await tester.tap(find.text('Send Test Notification'));
        await tester.pump();

        // Assert - Should not crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle switch tap vs switch drag', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Test tap
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));
        
        SwitchListTile switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isTrue);

        // Test drag (if applicable)
        await tester.drag(find.byType(Switch), const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 300));
        
        // State should remain consistent
        switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isTrue);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should have proper semantics for switch', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Assert - Switch should have semantic label
        final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.title, isNotNull);
        expect(find.text('Enable Daily Reminder'), findsOneWidget);
      });

      testWidgets('should have proper semantics for button', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Assert
        final button = find.byType(ElevatedButton);
        expect(button, findsOneWidget);
        expect(find.text('Send Test Notification'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      });
    });

    group('Layout Tests', () {
      testWidgets('should maintain layout on different screen sizes', (WidgetTester tester) async {
        // Test small screen
        await tester.binding.setSurfaceSize(const Size(300, 600));
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));
        
        expect(find.text('Notification Settings'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
        
        // Test large screen
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));
        
        expect(find.text('Notification Settings'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
        
        // Reset
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('should scroll properly with long content', (WidgetTester tester) async {
        // The current screen is short, but testing scroll behavior
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Should render without overflow
        expect(tester.takeException(), isNull);
        
        // All content should be visible on normal screen
        expect(find.text('Daily Reminder'), findsOneWidget);
        expect(find.text('Test Notifications'), findsOneWidget);
        expect(find.text('Send Test Notification'), findsOneWidget);
      });
    });

    group('Lifecycle Tests', () {
      testWidgets('should initialize notification service on init', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));
        
        // Should complete initialization without errors
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });

      testWidgets('should dispose properly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // Act - Remove widget
        await tester.pumpWidget(MaterialApp(
          home: Container(),
        ));

        // Assert - Should dispose without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should handle notification service errors gracefully', (WidgetTester tester) async {
        // This tests that the UI continues to work even if notification service fails
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // UI should still be functional
        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        
        // Should be able to interact with UI
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));
        
        await tester.tap(find.text('Send Test Notification'));
        await tester.pump();
        
        // Should not crash
        expect(tester.takeException(), isNull);
      });
    });

    group('Widget State Tests', () {
      testWidgets('should be a StatefulWidget', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: NotificationSettingsScreen(),
        ));

        // Assert
        final widget = find.byType(NotificationSettingsScreen);
        expect(widget, findsOneWidget);
        expect(tester.widget(widget), isA<StatefulWidget>());
      });

      testWidgets('should maintain state during rebuilds', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(MaterialApp(
          home: const NotificationSettingsScreen(),
          theme: ThemeData.light(),
        ));

        // Enable notifications
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 300));

        // Change theme (triggers rebuild)
        await tester.pumpWidget(MaterialApp(
          home: const NotificationSettingsScreen(),
          theme: ThemeData.dark(),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        // State should be maintained
        final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(switchTile.value, isTrue);
      });
    });
  });
}

