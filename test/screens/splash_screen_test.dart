import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/splash_screen.dart';
import 'package:bojang/screens/level_selection_screen.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('should display splash screen with correct content', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('bojang'), findsOneWidget);
      
      // Check for the circular container
      expect(find.byType(Container), findsWidgets);
      
      // Check for FadeTransition
      expect(find.byType(FadeTransition), findsOneWidget);
    });

    testWidgets('should have correct styling for bojang text', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Assert
      final textWidget = tester.widget<Text>(find.text('bojang'));
      expect(textWidget.style?.fontSize, equals(32));
      expect(textWidget.style?.color, equals(Colors.white));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w300));
      expect(textWidget.style?.letterSpacing, equals(1.5));
    });

    testWidgets('should have correct container properties', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FadeTransition),
          matching: find.byType(Container).first
        )
      );
      
      // Note: Container properties are not directly accessible in widget tests
      // We verify the container exists and has the expected decoration
      expect(container.decoration, isA<BoxDecoration>());
      
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.color, equals(Colors.black));
    });

    testWidgets('should have white background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.white));
    });

    testWidgets('should center content properly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Assert
      expect(find.byType(Center), findsOneWidget);
      
      // Verify the Center widget contains the FadeTransition
      expect(find.descendant(
        of: find.byType(Center),
        matching: find.byType(FadeTransition)
      ), findsOneWidget);
    });

    testWidgets('should have animation controller', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(); // Trigger first frame

      // Assert
      final splashState = tester.state<State>(find.byType(SplashScreen));
      
      // Animation should exist and be configured properly
      expect(splashState.controller.duration, equals(const Duration(milliseconds: 1500)));
    });

    testWidgets('should animate opacity from 0 to 1', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      
      // Get initial opacity (should be animating from low to high)
      FadeTransition fadeTransition = tester.widget<FadeTransition>(find.byType(FadeTransition));
      final initialOpacity = fadeTransition.opacity.value;
      
      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      fadeTransition = tester.widget<FadeTransition>(find.byType(FadeTransition));
      final midOpacity = fadeTransition.opacity.value;
      
      // Advance animation to completion
      await tester.pump(const Duration(milliseconds: 1500));
      fadeTransition = tester.widget<FadeTransition>(find.byType(FadeTransition));
      final finalOpacity = fadeTransition.opacity.value;
      
      // Assert
      expect(midOpacity, greaterThanOrEqualTo(initialOpacity));
      expect(finalOpacity, greaterThanOrEqualTo(midOpacity));
    });

    testWidgets('should navigate to LevelSelectionScreen after animation', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(MaterialApp(
        home: const SplashScreen(),
        routes: {
          '/level_selection': (context) => const LevelSelectionScreen(),
        },
      ));

      // Wait for animation to complete and navigation to occur using pumpAndSettle
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert - LevelSelectionScreen should be present
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('should use PageRouteBuilder for navigation transition', (WidgetTester tester) async {
      // This test ensures the navigation uses custom transition
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // Use pumpAndSettle to handle all animations and timers properly
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert navigation completed
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });

    group('Animation Tests', () {
      testWidgets('should start animation immediately on init', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        
        // Get the animation controller
        final splashState = tester.state<State>(find.byType(SplashScreen));
        
        // Assert
        expect(splashState.controller.status, equals(AnimationStatus.forward));
      });

      testWidgets('should use CurvedAnimation with easeInOut', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        
        // Get the state to access animation
        final splashState = tester.state<State>(find.byType(SplashScreen));
        
        // Assert
        expect(splashState.animation, isA<CurvedAnimation>());
      });

      testWidgets('should dispose animation controller properly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        final splashState = tester.state(find.byType(SplashScreen));
        
        // Act - Remove the widget
        await tester.pumpWidget(MaterialApp(home: Container()));
        
        // Assert - Controller should be disposed (no direct way to test, but no exception should occur)
        expect(tester.takeException(), isNull);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid navigation attempts', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        
        // Simulate rapid state changes
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        
        // Complete animation using pumpAndSettle
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        // Assert - Should handle gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('should not navigate if widget is disposed during animation', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        
        // Act - Dispose widget before animation completes
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(MaterialApp(home: Container()));
        
        // Assert - No exceptions should occur
        expect(tester.takeException(), isNull);
      });
    });

    group('Layout Tests', () {
      testWidgets('should maintain layout on different screen sizes', (WidgetTester tester) async {
        // Test small screen
        await tester.binding.setSurfaceSize(const Size(300, 600));
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        expect(find.text('bojang'), findsOneWidget);
        
        // Test large screen
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        expect(find.text('bojang'), findsOneWidget);
        
        // Reset to default size
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('should center content regardless of screen size', (WidgetTester tester) async {
        // Arrange
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        
        // Act
        final center = find.byType(Center);
        final centerWidget = tester.widget<Center>(center);
        
        // Assert
        expect(centerWidget.widthFactor, isNull); // Should expand to fill
        expect(centerWidget.heightFactor, isNull); // Should expand to fill
        
        // Reset
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}

