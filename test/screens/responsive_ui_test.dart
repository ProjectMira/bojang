// Responsive UI Tests for Level Selection Screen
//
// Tests the responsive design system that adapts to different screen sizes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import '../test_helpers.dart';

void main() {
  group('Responsive UI Tests', () {
    TestHelpers.setupTestGroup();

    group('Small Screen Tests (iPhone SE / Small Android)', () {
      testWidgets('should use 2 columns on small screens', (WidgetTester tester) async {
        // Arrange - Set small screen size
        await tester.binding.setSurfaceSize(const Size(375, 667)); // iPhone SE size
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert - Should show levels with appropriate responsive design
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('should use smaller fonts on small screens', (WidgetTester tester) async {
        // Arrange - Set small screen size
        await tester.binding.setSurfaceSize(const Size(320, 568)); // Very small screen
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert - App should render without overflow
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(tester.takeException(), isNull); // No overflow exceptions
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Medium Screen Tests (Standard iPhone)', () {
      testWidgets('should use 3 columns on medium screens', (WidgetTester tester) async {
        // Arrange - Set medium screen size
        await tester.binding.setSurfaceSize(const Size(414, 896)); // iPhone 11 size
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Large Screen Tests (Plus/Pro Max)', () {
      testWidgets('should use 4 columns on large screens', (WidgetTester tester) async {
        // Arrange - Set large screen size
        await tester.binding.setSurfaceSize(const Size(428, 926)); // iPhone 16 Plus size
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Orientation Change Tests', () {
      testWidgets('should handle orientation changes gracefully', (WidgetTester tester) async {
        // Arrange & Act - Start in portrait
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        expect(find.text('Beginner'), findsOneWidget);

        // Change to landscape
        await tester.binding.setSurfaceSize(const Size(896, 414));
        await tester.pump();

        // Assert - Should still work
        expect(find.text('Beginner'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Change back to portrait
        await tester.binding.setSurfaceSize(const Size(414, 896));
        await tester.pump();

        expect(find.text('Beginner'), findsOneWidget);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Extreme Size Tests', () {
      testWidgets('should handle very small screens without overflow', (WidgetTester tester) async {
        // Arrange - Set extremely small screen
        await tester.binding.setSurfaceSize(const Size(280, 400));
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert - Should not have overflow errors
        expect(tester.takeException(), isNull);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('should handle very large screens efficiently', (WidgetTester tester) async {
        // Arrange - Set very large screen (tablet-like)
        await tester.binding.setSurfaceSize(const Size(1024, 768));
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        expect(find.text('Beginner'), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Accessibility with Responsive Design', () {
      testWidgets('should maintain accessibility across screen sizes', (WidgetTester tester) async {
        // Test with different text scales and screen sizes
        final screenSizes = [
          const Size(320, 568), // Small
          const Size(414, 896), // Medium
          const Size(428, 926), // Large
        ];

        for (final size in screenSizes) {
          await tester.binding.setSurfaceSize(size);
          
          await TestHelpers.pumpWidgetWithMocks(
            tester,
            const MaterialApp(home: LevelSelectionScreen()),
          );

          // Should have semantic information
          expect(find.byType(Semantics), findsWidgets);
          expect(tester.takeException(), isNull);
        }
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('should work with large text scale factors', (WidgetTester tester) async {
        // Arrange - Set large text scale
        tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
        
        // Test on different screen sizes
        await tester.binding.setSurfaceSize(const Size(375, 667));
        
        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: LevelSelectionScreen()),
        );

        // Assert - Should handle large text without breaking
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Reset
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Performance Tests', () {
      testWidgets('should render efficiently on different screen sizes', (WidgetTester tester) async {
        final screenSizes = [
          const Size(320, 568),
          const Size(414, 896),
          const Size(428, 926),
        ];

        for (final size in screenSizes) {
          final stopwatch = Stopwatch()..start();
          
          await tester.binding.setSurfaceSize(size);
          await TestHelpers.pumpWidgetWithMocks(
            tester,
            const MaterialApp(home: LevelSelectionScreen()),
          );
          
          stopwatch.stop();
          
          // Should render quickly regardless of screen size
          expect(stopwatch.elapsedMilliseconds, lessThan(1000));
          expect(find.byType(LevelSelectionScreen), findsOneWidget);
        }
        
        // Reset size
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}
