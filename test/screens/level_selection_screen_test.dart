import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/screens/notification_settings_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import '../test_helpers.dart';
import 'dart:typed_data';

void main() {
  group('LevelSelectionScreen Tests', () {
    TestHelpers.setupTestGroup();

    group('Basic UI Elements', () {
      testWidgets('displays app bar with title and settings button', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('has correct background color', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, equals(const Color(0xFFF7F7F7)));
      });

      testWidgets('shows loading indicator initially', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        
        // Should show loading initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Data Loading', () {
      testWidgets('loads and displays levels successfully', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Wait for data to load
        await TestHelpers.waitForAsync(tester);

        // Should show levels after loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('Intermediate'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
      });

      testWidgets('handles empty levels array', (WidgetTester tester) async {
        // Mock empty levels
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              final String assetPath = methodCall.arguments as String;
              if (assetPath == 'assets/quiz_data/levels.json') {
                return '{"levels": []}';
              } else if (assetPath == 'AssetManifest.json') {
                return '{}';
              } else if (assetPath == 'FontManifest.json') {
                return '[]';
              }
            } else if (methodCall.method == 'load') {
              return Uint8List.fromList([0, 0, 0, 0]);
            }
            return null;
          },
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await TestHelpers.waitForAsync(tester);

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('No levels found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('handles JSON loading error', (WidgetTester tester) async {
        // Mock JSON error
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              final String assetPath = methodCall.arguments as String;
              if (assetPath == 'assets/quiz_data/levels.json') {
                throw PlatformException(code: 'asset_error', message: 'Asset not found');
              } else if (assetPath == 'AssetManifest.json') {
                return '{}';
              } else if (assetPath == 'FontManifest.json') {
                return '[]';
              }
            } else if (methodCall.method == 'load') {
              return Uint8List.fromList([0, 0, 0, 0]);
            }
            return null;
          },
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await TestHelpers.waitForAsync(tester);

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });

    group('Level Display', () {
      testWidgets('displays levels with correct titles and numbers', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        // Check level numbers
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        // Check level titles
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('Intermediate'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
      });

      testWidgets('shows "Coming Soon" for levels without sublevels', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        // Level 3 (Advanced) has no sublevels
        expect(find.text('🔒 Coming Soon!'), findsOneWidget);
      });

      testWidgets('displays sublevels for levels that have them', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        // Check sublevel names
        expect(find.text('Alphabet'), findsOneWidget);
        expect(find.text('Vowels'), findsOneWidget);
        expect(find.text('Emotions'), findsOneWidget);

        // Check sublevel numbers
        expect(find.text('1.1'), findsOneWidget);
        expect(find.text('1.2'), findsOneWidget);
        expect(find.text('2.1'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('navigates to notification settings when settings tapped', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      });

      testWidgets('navigates to quiz screen when sublevel tapped', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        // Find and tap a sublevel
        final sublevelCards = find.byType(InkWell);
        if (sublevelCards.evaluate().isNotEmpty) {
          await tester.tap(sublevelCards.first);
          await tester.pumpAndSettle();

          expect(find.byType(QuizScreen), findsOneWidget);
        }
      });
    });

    group('Animations', () {
      testWidgets('has scale animation transitions', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        expect(find.byType(ScaleTransition), findsWidgets);
      });
    });

    group('Responsive Design', () {
      testWidgets('displays properly on different screen sizes', (WidgetTester tester) async {
        // Test small screen
        await tester.binding.setSurfaceSize(const Size(320, 568));
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);
        expect(find.byType(AppBar), findsOneWidget);

        // Test large screen
        await tester.binding.setSurfaceSize(const Size(414, 896));
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);
        expect(find.byType(AppBar), findsOneWidget);

        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Error Handling', () {
      testWidgets('retry button works when no levels found', (WidgetTester tester) async {
        // First show empty levels
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              final String assetPath = methodCall.arguments as String;
              if (assetPath == 'assets/quiz_data/levels.json') {
                return '{"levels": []}';
              } else if (assetPath == 'AssetManifest.json') {
                return '{}';
              } else if (assetPath == 'FontManifest.json') {
                return '[]';
              }
            } else if (methodCall.method == 'load') {
              return Uint8List.fromList([0, 0, 0, 0]);
            }
            return null;
          },
        );

        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await TestHelpers.waitForAsync(tester);

        expect(find.text('Retry'), findsOneWidget);

        // Mock successful loading for retry
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              final String assetPath = methodCall.arguments as String;
              if (assetPath == 'assets/quiz_data/levels.json') {
                return TestHelpers.mockLevelsData;
              } else if (assetPath == 'AssetManifest.json') {
                return '{}';
              } else if (assetPath == 'FontManifest.json') {
                return '[]';
              }
            } else if (methodCall.method == 'load') {
              return Uint8List.fromList([0, 0, 0, 0]);
            }
            return null;
          },
        );

        await tester.tap(find.text('Retry'));
        await TestHelpers.waitForAsync(tester);

        expect(find.text('Beginner'), findsOneWidget);
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('disposes controllers properly', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Replace widget to trigger dispose
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Test'))));

        // No exceptions should occur during disposal
        expect(tester.takeException(), isNull);
      });
    });

    group('Scrolling', () {
      testWidgets('is scrollable with multiple levels', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        await TestHelpers.waitForAsync(tester);

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });
  });
}
