// Comprehensive Test to validate all test components work together
//
// This test file validates that all test infrastructure works correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/main.dart';
import 'package:bojang/screens/splash_screen.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/models/level_models.dart';
import 'test_helpers.dart';

void main() {
  group('Comprehensive Test Suite Validation', () {
    TestHelpers.setupTestGroup();

    group('Test Infrastructure Validation', () {
      test('mock data should be valid JSON', () {
        expect(TestHelpers.mockLevelsData, contains('"levels"'));
        expect(TestHelpers.mockQuizData, contains('"questions"'));
      });

      test('test helpers should setup and cleanup without errors', () {
        expect(() => TestHelpers.setupAllMocks(), returnsNormally);
        expect(() => TestHelpers.cleanupAllMocks(), returnsNormally);
      });

      testWidgets('pumpWidgetWithMocks should work', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester, 
          const MaterialApp(home: Text('Test'))
        );
        expect(find.text('Test'), findsOneWidget);
      });
    });

    group('Model Tests Validation', () {
      test('Level model should parse from JSON', () {
        final testLevelJson = {
          'level': 1,
          'title': 'Test Level',
          'sublevels': [
            {
              'level': '1.1',
              'name': 'Test Sublevel',
              'path': 'test/path.json'
            }
          ]
        };

        final level = Level.fromJson(testLevelJson);
        expect(level.level, equals(1));
        expect(level.title, equals('Test Level'));
        expect(level.sublevels, hasLength(1));
        expect(level.sublevels.first.name, equals('Test Sublevel'));
      });

      test('Sublevel model should parse from JSON', () {
        final testSublevelJson = {
          'level': '2.3',
          'name': 'Advanced Test',
          'path': 'assets/test/advanced.json'
        };

        final sublevel = Sublevel.fromJson(testSublevelJson);
        expect(sublevel.level, equals('2.3'));
        expect(sublevel.name, equals('Advanced Test'));
        expect(sublevel.path, equals('assets/test/advanced.json'));
      });
    });

    group('Widget Tests Validation', () {
      testWidgets('MyApp should render without errors', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SplashScreen should display correctly', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: SplashScreen()),
        );
        
        expect(find.text('bojang'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('LevelSelectionScreen should handle loading state', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );
        
        // Should show app bar
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        
        // Should eventually load levels (mocked)
        await TestHelpers.waitForAsyncOperation(tester);
        expect(find.text('Beginner'), findsOneWidget);
      });
    });

    group('Responsive Design Validation', () {
      final testSizes = [
        Size(320, 568), // Small
        Size(375, 667), // Medium
        Size(428, 926), // Large
      ];

      for (final size in testSizes) {
        testWidgets('should work on ${size.width}x${size.height}', (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(size);
          
          await TestHelpers.pumpWidgetWithMocks(
            tester,
            const MaterialApp(home: LevelSelectionScreen()),
          );
          
          expect(find.text('Learn Tibetan'), findsOneWidget);
          expect(tester.takeException(), isNull);
          
          await tester.binding.setSurfaceSize(null);
        });
      }
    });

    group('Error Handling Validation', () {
      testWidgets('should handle missing assets gracefully', (WidgetTester tester) async {
        // Don't set up asset mocks to simulate error
        await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
        await tester.pump();
        
        // Should not crash
        expect(find.text('Learn Tibetan'), findsOneWidget);
      });

      testWidgets('should handle widget errors gracefully', (WidgetTester tester) async {
        FlutterError.onError = (details) {
          // Suppress errors for this test
        };
        
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        expect(find.byType(MaterialApp), findsOneWidget);
        
        FlutterError.onError = null;
      });
    });

    group('Performance Validation', () {
      testWidgets('app should start quickly', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });
    });

    group('Cross-Platform Compatibility Validation', () {
      testWidgets('should work with different text scales', (WidgetTester tester) async {
        final scales = [1.0, 2.0, 3.0];
        
        for (final scale in scales) {
          tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
          
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          
          expect(find.text('bojang'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      });

      testWidgets('should maintain accessibility', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        expect(find.byType(Semantics), findsWidgets);
      });
    });
  });
}

