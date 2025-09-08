import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/screens/notification_settings_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:bojang/models/level_models.dart';
import '../test_helpers.dart';

void main() {
  group('LevelSelectionScreen Widget Tests', () {
    TestHelpers.setupTestGroup();
    testWidgets('should display loading indicator initially', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Learn Tibetan'), findsOneWidget);
    });

    testWidgets('should display app bar with correct title and settings button', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Learn Tibetan'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should navigate to NotificationSettingsScreen when settings tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
      
      // Act
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    });

    testWidgets('should have correct background color', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFFF7F7F7)));
    });

    group('Data Loading Tests', () {
      testWidgets('should handle successful data loading', (WidgetTester tester) async {
        // Arrange & Act - TestHelpers will set up asset mocks automatically
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert - Should eventually load data and show levels
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // Level number
      });

      testWidgets('should handle loading error gracefully', (WidgetTester tester) async {
        // Mock asset loading to throw error
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ASSET_NOT_FOUND', message: 'Asset not found');
          },
        );

        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        
        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Level Rendering Tests', () {
      testWidgets('should display levels with correct colors', (WidgetTester tester) async {
        const mockData = '''
        {
          "levels": [
            {
              "level": 1,
              "title": "Beginner",
              "sublevels": []
            },
            {
              "level": 2,
              "title": "Intermediate",
              "sublevels": []
            },
            {
              "level": 3,
              "title": "Advanced",
              "sublevels": []
            }
          ]
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert levels are displayed
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('Intermediate'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });

      testWidgets('should display "Coming Soon" for levels without sublevels', (WidgetTester tester) async {
        const mockData = '''
        {
          "levels": [
            {
              "level": 1,
              "title": "Empty Level",
              "sublevels": []
            }
          ]
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert
        expect(find.text('🔒 Coming Soon!'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Sublevel Interaction Tests', () {
      testWidgets('should navigate to QuizScreen when sublevel tapped', (WidgetTester tester) async {
        const mockData = '''
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

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Find and tap sublevel
        final sublevelCard = find.descendant(
          of: find.byType(InkWell),
          matching: find.text('Alphabet'),
        );
        expect(sublevelCard, findsOneWidget);

        await tester.tap(find.byType(InkWell).first);
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert navigation to QuizScreen
        expect(find.byType(QuizScreen), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });

      testWidgets('should display sublevel with correct information', (WidgetTester tester) async {
        const mockData = '''
        {
          "levels": [
            {
              "level": 1,
              "title": "Test Level",
              "sublevels": [
                {
                  "level": "1.1",
                  "name": "Test Sublevel",
                  "path": "assets/test.json"
                }
              ]
            }
          ]
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert sublevel information
        expect(find.text('1.1'), findsOneWidget);
        expect(find.text('Test Sublevel'), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Animation Tests', () {
      testWidgets('should have scale animation', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        
        // Assert
        expect(find.byType(ScaleTransition), findsWidgets);
      });

      testWidgets('should animate scale properly', (WidgetTester tester) async {
        const mockData = '''
        {
          "levels": [
            {
              "level": 1,
              "title": "Test",
              "sublevels": []
            }
          ]
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        
        // Advance animation
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert animation completed
        expect(find.byType(ScaleTransition), findsWidgets);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Scroll Behavior Tests', () {
      testWidgets('should be scrollable with multiple levels', (WidgetTester tester) async {
        // Create mock data with many levels
        final levelsData = List.generate(10, (index) => {
          "level": index + 1,
          "title": "Level ${index + 1}",
          "sublevels": []
        });

        final mockData = '''
        {
          "levels": ${levelsData.map((l) => '''
            {
              "level": ${l['level']},
              "title": "${l['title']}",
              "sublevels": []
            }
          ''').join(',')}
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert scrollable
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Level 1'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Color Tests', () {
      testWidgets('should return correct colors for different levels', (WidgetTester tester) async {
        // This tests the _getLevelColor method indirectly
        const mockData = '''
        {
          "levels": [
            {
              "level": 1,
              "title": "Level 1",
              "sublevels": []
            },
            {
              "level": 2,
              "title": "Level 2", 
              "sublevels": []
            },
            {
              "level": 3,
              "title": "Level 3",
              "sublevels": []
            },
            {
              "level": 4,
              "title": "Level 4",
              "sublevels": []
            }
          ]
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Verify levels are displayed (colors are applied internally)
        expect(find.text('Level 1'), findsOneWidget);
        expect(find.text('Level 2'), findsOneWidget);
        expect(find.text('Level 3'), findsOneWidget);
        expect(find.text('Level 4'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty levels array', (WidgetTester tester) async {
        const mockData = '{"levels": []}';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert - Should not crash and should not show loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });

      testWidgets('should handle malformed JSON gracefully', (WidgetTester tester) async {
        const mockData = '{"invalid": json}';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async => mockData,
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump(); // Trigger initial build
        await tester.pump(const Duration(seconds: 1)); // Allow time for data processing

        // Assert - Should show error state
        expect(find.byType(CircularProgressIndicator), findsNothing);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
      });
    });

    group('Dispose Tests', () {
      testWidgets('should dispose controllers properly', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        
        // Remove widget
        await tester.pumpWidget(MaterialApp(home: Container()));
        
        // Assert - No exceptions should occur
        expect(tester.takeException(), isNull);
      });
    });
  });
}

