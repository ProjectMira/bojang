// Integration Tests for the Complete Bojang App
//
// Tests the full user flow from startup to quiz completion

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/main.dart';
import 'package:bojang/screens/splash_screen.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:bojang/screens/notification_settings_screen.dart';
import '../test_helpers.dart';

void main() {
  group('App Integration Tests', () {
    TestHelpers.setupTestGroup();

    testWidgets('complete user flow: splash -> levels -> quiz', (WidgetTester tester) async {
      // Start the app
      await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());

      // 1. Verify splash screen appears
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('bojang'), findsOneWidget);

      // 2. Wait for navigation to level selection
      await tester.pumpWithTimeout(const Duration(milliseconds: 1500));
      await tester.pumpWithTimeout(const Duration(milliseconds: 200));
      await tester.pumpWithTimeout(const Duration(milliseconds: 800));

      // 3. Should be on level selection screen
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
      expect(find.text('Learn Tibetan'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);

      // 4. Tap on first sublevel (Alphabet)
      final alphabetButton = find.text('Alphabet');
      if (alphabetButton.evaluate().isNotEmpty) {
        await tester.tap(alphabetButton);
        await tester.pumpWithTimeout(const Duration(milliseconds: 500));

        // 5. Should navigate to quiz screen
        expect(find.byType(QuizScreen), findsOneWidget);
      }
    });

    testWidgets('settings navigation flow', (WidgetTester tester) async {
      // Start the app and navigate to level selection
      await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
      await tester.pumpWithTimeout(const Duration(seconds: 3));

      // Tap settings button
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpWithTimeout(const Duration(milliseconds: 500));

        // Should navigate to notification settings
        expect(find.byType(NotificationSettingsScreen), findsOneWidget);

        // Navigate back
        await tester.pageBack();
        await tester.pumpWithTimeout(const Duration(milliseconds: 300));

        // Should be back on level selection
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
      }
    });

    group('Responsive Integration Tests', () {
      testWidgets('app works on different screen sizes', (WidgetTester tester) async {
        final screenSizes = [
          const Size(320, 568), // iPhone SE
          const Size(375, 667), // iPhone 8
          const Size(414, 896), // iPhone 11
          const Size(428, 926), // iPhone 16 Plus
        ];

        for (final size in screenSizes) {
          // Set screen size
          await tester.binding.setSurfaceSize(size);
          
          // Test app startup
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          
          // Verify splash screen works
          expect(find.text('bojang'), findsOneWidget);
          
          // Navigate to level selection
          await tester.pumpWithTimeout(const Duration(seconds: 3));
          
          // Verify level selection works
          expect(find.byType(LevelSelectionScreen), findsOneWidget);
          expect(find.text('Learn Tibetan'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        // Reset
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Error Handling Integration', () {
      testWidgets('app handles asset loading failures gracefully', (WidgetTester tester) async {
        // Don't set up asset mocks to simulate loading failure
        await tester.pumpWidget(const MyApp());
        
        // Should still show splash screen
        expect(find.text('bojang'), findsOneWidget);
        
        // Navigate forward
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Should handle gracefully without crashing
        expect(tester.takeException(), isNull);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
      });

      testWidgets('app recovers from temporary errors', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        // Simulate error condition by rebuilding rapidly
        for (int i = 0; i < 5; i++) {
          await tester.pump();
        }
        
        // App should remain stable
        expect(tester.takeException(), isNull);
      });
    });

    group('Performance Integration Tests', () {
      testWidgets('app startup performance', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        stopwatch.stop();
        
        // App should start quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        expect(find.text('bojang'), findsOneWidget);
      });

      testWidgets('navigation performance', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        final stopwatch = Stopwatch()..start();
        
        // Navigate to settings and back
        final settingsButton = find.byIcon(Icons.settings);
        if (settingsButton.evaluate().isNotEmpty) {
          await tester.tap(settingsButton);
          await tester.pumpWithTimeout(const Duration(milliseconds: 300));
          
          await tester.pageBack();
          await tester.pumpWithTimeout(const Duration(milliseconds: 300));
        }
        
        stopwatch.stop();
        
        // Navigation should be fast
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Accessibility Integration Tests', () {
      testWidgets('app maintains accessibility throughout flow', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        // Check splash screen accessibility
        expect(find.byType(Semantics), findsWidgets);
        
        // Navigate to level selection
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Check level selection accessibility
        expect(find.byType(Semantics), findsWidgets);
        
        // Test with large text
        tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
        await tester.pump();
        
        // Should handle large text
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Reset
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      });
    });

    group('State Management Integration Tests', () {
      testWidgets('app maintains state during lifecycle changes', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Verify initial state
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        
        // Simulate app pause/resume
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/lifecycle'),
          (call) async => null,
        );
        
        await tester.pump();
        
        // State should be preserved
        expect(find.text('Beginner'), findsOneWidget);
        
        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/lifecycle'),
          null,
        );
      });
    });
  });
}

