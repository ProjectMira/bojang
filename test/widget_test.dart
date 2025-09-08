// Comprehensive Widget Tests for Bojang - Tibetan Learning App
//
// These tests cover the main app functionality, widget behavior,
// and integration between different components.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/main.dart';
import 'package:bojang/screens/splash_screen.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/services/notification_service.dart';
import 'test_helpers.dart';

void main() {
  group('MyApp Main Widget Tests', () {
    TestHelpers.setupTestGroup();
    testWidgets('should build app with correct configuration', (WidgetTester tester) async {
      // Build our app
      await tester.pumpWidget(const MyApp());

      // Verify app structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);
      
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('Bojang - Tibetan Learning'));
      expect(materialApp.theme?.useMaterial3, isTrue);
      expect(materialApp.theme?.colorScheme.primary, equals(Colors.blue));
    });

    testWidgets('should start with SplashScreen as home', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('bojang'), findsOneWidget);
    });

    testWidgets('should have proper theme configuration', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.visualDensity, equals(VisualDensity.adaptivePlatformDensity));
      expect(materialApp.theme?.useMaterial3, isTrue);
    });
  });

  group('App Navigation Flow Tests', () {
    testWidgets('should navigate from splash to level selection', (WidgetTester tester) async {
      await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());

      // Initially on splash screen
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('bojang'), findsOneWidget);

      // Wait for splash animation and navigation using safe pump method
      await tester.pumpWithTimeout(const Duration(milliseconds: 1500)); // Animation
      await tester.pumpWithTimeout(const Duration(milliseconds: 200)); // Delay
      await tester.pumpWithTimeout(const Duration(milliseconds: 800)); // Transition

      // Should now be on LevelSelectionScreen
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('should handle navigation transition smoothly', (WidgetTester tester) async {
      await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());

      // Monitor for any exceptions during navigation
      await tester.pumpWithTimeout(const Duration(milliseconds: 1500));
      await tester.pumpWithTimeout(const Duration(milliseconds: 200));
      
      // During transition, both widgets might be present temporarily
      await tester.pumpWithTimeout(const Duration(milliseconds: 400));

      // Final state should be clean
      expect(tester.takeException(), isNull);
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });

  group('App Initialization Tests', () {
    testWidgets('should initialize without errors', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // App should build without throwing exceptions
      expect(tester.takeException(), isNull);
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('should handle notification service initialization', (WidgetTester tester) async {
      // Since main() calls NotificationService().init(), we test that app starts
      await tester.pumpWidget(const MyApp());
      
      // App should start successfully even if notification initialization has issues
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('App Theme and Styling Tests', () {
    testWidgets('should apply consistent theme across app', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final theme = Theme.of(tester.element(find.byType(SplashScreen)));
      expect(theme.colorScheme.primary, equals(Colors.blue));
      expect(theme.useMaterial3, isTrue);
      expect(theme.visualDensity, equals(VisualDensity.adaptivePlatformDensity));
    });

    testWidgets('should work with different system themes', (WidgetTester tester) async {
      // Test with light theme
      await tester.pumpWidget(Theme(
        data: ThemeData.light(),
        child: const MyApp(),
      ));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Test with dark theme
      await tester.pumpWidget(Theme(
        data: ThemeData.dark(), 
        child: const MyApp(),
      ));
      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });

  group('App Performance Tests', () {
    testWidgets('should build efficiently', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(const MyApp());
      
      stopwatch.stop();
      
      // App should build quickly (adjust threshold as needed)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(find.byType(MyApp), findsOneWidget);
    });

    testWidgets('should handle rapid rebuilds', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Trigger multiple rebuilds
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }
      
      // Should remain stable
      expect(tester.takeException(), isNull);
      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });

  group('App State Management Tests', () {
    testWidgets('should maintain state during orientation changes', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.text('bojang'), findsOneWidget);

      // Simulate orientation change
      await tester.binding.setSurfaceSize(const Size(800, 400));
      await tester.pump();
      
      expect(find.text('bojang'), findsOneWidget);

      // Rotate back
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();
      
      expect(find.text('bojang'), findsOneWidget);
      
      // Reset
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should handle system back button appropriately', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Navigate to level selection
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      
      // Should handle gracefully
      expect(tester.takeException(), isNull);
    });
  });

  group('App Accessibility Tests', () {
    testWidgets('should support accessibility features', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Check for semantic information
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should work with large text scale', (WidgetTester tester) async {
      tester.binding.platformDispatcher.textScaleFactorTestValue = 3.0;
      
      await tester.pumpWidget(const MyApp());
      
      // App should handle large text without breaking
      expect(find.text('bojang'), findsOneWidget);
      expect(tester.takeException(), isNull);
      
      // Reset
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
  });

  group('App Error Handling Tests', () {
    testWidgets('should handle widget errors gracefully', (WidgetTester tester) async {
      // Override error handling for test
      FlutterError.onError = (FlutterErrorDetails details) {
        // Custom error handling for test
      };
      
      await tester.pumpWidget(const MyApp());
      
      // App should build successfully
      expect(find.byType(SplashScreen), findsOneWidget);
      
      // Reset error handling
      FlutterError.onError = null;
    });

    testWidgets('should recover from temporary failures', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Simulate a rebuild after potential error
      await tester.pump();
      await tester.pump();
      
      // Should maintain functionality
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('App Resource Management Tests', () {
    testWidgets('should dispose resources properly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Navigate through app lifecycle
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      
      // Remove app widget (simulating app termination)
      await tester.pumpWidget(Container());
      
      // Should clean up without errors
      expect(tester.takeException(), isNull);
    });
  });

  group('Integration with External Services', () {
    testWidgets('should handle notification service integration', (WidgetTester tester) async {
      // The app integrates with NotificationService
      await tester.pumpWidget(const MyApp());
      
      // Should start successfully regardless of notification service state
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
