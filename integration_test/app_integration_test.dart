import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bojang/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('Complete App Flow - Splash to Level Selection to Quiz', (WidgetTester tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Should start on splash screen
      expect(find.text('bojang'), findsOneWidget);
      expect(find.byType(CircularContainer), findsOneWidget);

      // Wait for splash screen animation and navigation
      await tester.pump(const Duration(milliseconds: 1500)); // Animation duration
      await tester.pump(const Duration(milliseconds: 200)); // Delay
      await tester.pump(const Duration(milliseconds: 800)); // Transition
      await tester.pumpAndSettle();

      // Should now be on Level Selection screen
      expect(find.text('Learn Tibetan'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      // Wait for level data to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should see level content (if data loads successfully)
      // Note: This may show loading or actual content depending on asset loading
    });

    testWidgets('Navigation to Settings and Back', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate through splash
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Tap settings icon
      if (find.byIcon(Icons.settings).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Should be on notification settings screen
        expect(find.text('Notification Settings'), findsOneWidget);
        expect(find.text('Enable Daily Reminder'), findsOneWidget);

        // Toggle notification setting
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // Test notification button
        await tester.tap(find.text('Send Test Notification'));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show snackbar
        expect(find.byType(SnackBar), findsOneWidget);

        // Go back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Should be back on level selection
        expect(find.text('Learn Tibetan'), findsOneWidget);
      }
    });

    testWidgets('Quiz Flow - With Mock Data', (WidgetTester tester) async {
      // Set up mock quiz data
      const mockQuizData = '''
      {
        "exercises": [
          {
            "type": "character_recognition",
            "tibetanText": "ཀ",
            "options": ["ka", "ga", "kha"],
            "correctAnswerIndex": 0
          },
          {
            "type": "character_recognition",
            "tibetanText": "ག",
            "options": ["ka", "ga", "nga"],
            "correctAnswerIndex": 1
          }
        ]
      }
      ''';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString') {
            if (methodCall.arguments == 'assets/quiz_data/levels.json') {
              return '''
              {
                "levels": [
                  {
                    "level": 1,
                    "title": "Beginner",
                    "sublevels": [
                      {
                        "level": "1.1",
                        "name": "Alphabet",
                        "path": "assets/quiz_data/level-1/alphabet.json"
                      }
                    ]
                  }
                ]
              }
              ''';
            } else if (methodCall.arguments.toString().contains('alphabet.json')) {
              return mockQuizData;
            }
          }
          return null;
        },
      );

      app.main();
      await tester.pumpAndSettle();

      // Navigate through splash
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Wait for data to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Look for and tap a sublevel
      if (find.text('Alphabet').evaluate().isNotEmpty) {
        await tester.tap(find.text('Alphabet'));
        await tester.pumpAndSettle();

        // Should be on quiz screen
        expect(find.text('ALPHABET'), findsOneWidget);
        expect(find.text('ཀ'), findsOneWidget);
        expect(find.text('Score: 0'), findsOneWidget);

        // Answer first question correctly
        await tester.tap(find.text('ka'));
        await tester.pump(const Duration(milliseconds: 500));

        // Should show success dialog
        expect(find.text('ལེགས་སོ། Amazing!'), findsOneWidget);

        // Wait for dialog to dismiss and next question
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Should show second question with updated score
        if (find.text('ག').evaluate().isNotEmpty) {
          expect(find.text('ག'), findsOneWidget);
          expect(find.text('Score: 1'), findsOneWidget);

          // Answer second question correctly
          await tester.tap(find.text('ga'));
          await tester.pump(const Duration(milliseconds: 500));

          // Wait for completion
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();

          // Should show completion dialog
          expect(find.text('Quiz Completed!'), findsOneWidget);
          expect(find.text('Continue'), findsOneWidget);

          // Tap continue
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          // Should be back on level selection
          expect(find.text('Learn Tibetan'), findsOneWidget);
        }
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('Error Handling - Invalid Quiz Data', (WidgetTester tester) async {
      // Set up mock data that will cause errors
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString') {
            if (methodCall.arguments == 'assets/quiz_data/levels.json') {
              return '''
              {
                "levels": [
                  {
                    "level": 1,
                    "title": "Beginner",
                    "sublevels": [
                      {
                        "level": "1.1",
                        "name": "Test",
                        "path": "assets/quiz_data/level-1/test.json"
                      }
                    ]
                  }
                ]
              }
              ''';
            } else {
              return '{"invalid": "json"}'; // Invalid quiz format
            }
          }
          return null;
        },
      );

      app.main();
      await tester.pumpAndSettle();

      // Navigate through splash
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Wait for level data
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap sublevel
      if (find.text('Test').evaluate().isNotEmpty) {
        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        // Should show error screen
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Error loading questions'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);

        // Test retry functionality
        await tester.tap(find.text('Try Again'));
        await tester.pumpAndSettle();

        // Should still show error (since mock data is still invalid)
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Go back
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Should be back on level selection
        expect(find.text('Learn Tibetan'), findsOneWidget);
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('App Theme and Styling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Check app theme
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);

      final appWidget = tester.widget<MaterialApp>(materialApp);
      expect(appWidget.theme?.useMaterial3, isTrue);
      expect(appWidget.title, equals('Bojang - Tibetan Learning'));

      // Navigate to main screen
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Check consistent styling across screens
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Performance - App Launch Time', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      app.main();
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // App should launch within reasonable time (adjust threshold as needed)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      
      // Should show initial content
      expect(find.text('bojang'), findsOneWidget);
    });

    testWidgets('Memory Management - Multiple Screen Navigations', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate through multiple screens rapidly
      for (int i = 0; i < 3; i++) {
        // Go through splash
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Go to settings
        if (find.byIcon(Icons.settings).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.settings));
          await tester.pumpAndSettle();

          // Go back
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
      }

      // App should remain stable
      expect(tester.takeException(), isNull);
    });

    group('Accessibility Integration Tests', () {
      testWidgets('Screen Reader Support', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to main screen
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Check for semantic information
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('Large Text Support', (WidgetTester tester) async {
        // Test with large text scale
        await tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
        
        app.main();
        await tester.pumpAndSettle();

        // Navigate to main screen
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // App should handle large text without overflow
        expect(tester.takeException(), isNull);

        // Reset text scale
        await tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      });
    });

    group('Data Persistence Tests', () {
      testWidgets('Settings State Persistence', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to main screen and then settings
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        if (find.byIcon(Icons.settings).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.settings));
          await tester.pumpAndSettle();

          // Toggle setting
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();

          // Go back and forth
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.settings));
          await tester.pumpAndSettle();

          // State should persist within the same session
          final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
          expect(switchTile.value, isTrue);
        }
      });
    });

    group('Edge Cases Integration', () {
      testWidgets('Rapid Navigation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate through splash quickly
        await tester.pump(const Duration(milliseconds: 500));
        
        // Try to navigate before splash completes
        // Should handle gracefully
        expect(tester.takeException(), isNull);
        
        await tester.pumpAndSettle();
      });

      testWidgets('Device Orientation Changes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate rotation
        await tester.binding.setSurfaceSize(const Size(800, 400)); // Landscape
        await tester.pump();
        
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // App should handle orientation change
        expect(find.text('Learn Tibetan'), findsOneWidget);

        // Rotate back
        await tester.binding.setSurfaceSize(const Size(400, 800)); // Portrait
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Learn Tibetan'), findsOneWidget);

        // Reset
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}

// Helper class to find circular container (if it doesn't exist, we'll create a matcher)
class CircularContainer extends StatelessWidget {
  const CircularContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
    );
  }
}


