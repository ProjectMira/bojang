// Cross-Platform Compatibility Tests
//
// Tests that verify the app works correctly on both iOS and Android platforms
// with their respective screen sizes, behaviors, and platform-specific features

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/main.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import '../test_helpers.dart';

void main() {
  group('Cross-Platform Compatibility Tests', () {
    TestHelpers.setupTestGroup();

    group('iOS Platform Tests', () {
      final iOSScreenSizes = [
        // iPhone SE (1st gen) - 4" display
        {'name': 'iPhone SE 1st', 'size': const Size(320, 568), 'columns': 2},
        // iPhone SE (2nd/3rd gen) - 4.7" display  
        {'name': 'iPhone SE 2nd/3rd', 'size': const Size(375, 667), 'columns': 2},
        // iPhone 8 - 4.7" display
        {'name': 'iPhone 8', 'size': const Size(375, 667), 'columns': 2},
        // iPhone 8 Plus - 5.5" display
        {'name': 'iPhone 8 Plus', 'size': const Size(414, 736), 'columns': 3},
        // iPhone X/XS - 5.8" display
        {'name': 'iPhone X/XS', 'size': const Size(375, 812), 'columns': 2},
        // iPhone XR/11 - 6.1" display
        {'name': 'iPhone XR/11', 'size': const Size(414, 896), 'columns': 3},
        // iPhone 12/13/14 - 6.1" display
        {'name': 'iPhone 12/13/14', 'size': const Size(390, 844), 'columns': 2},
        // iPhone 12/13/14 Plus - 6.7" display
        {'name': 'iPhone Plus', 'size': const Size(428, 926), 'columns': 4},
        // iPhone 15/16 Pro Max - 6.9" display
        {'name': 'iPhone Pro Max', 'size': const Size(430, 932), 'columns': 4},
      ];

      for (final device in iOSScreenSizes) {
        testWidgets('should work on ${device['name']}', (WidgetTester tester) async {
          // Set screen size
          await tester.binding.setSurfaceSize(device['size'] as Size);
          
          // Test app startup
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          
          // Verify splash screen
          expect(find.text('bojang'), findsOneWidget);
          
          // Navigate to level selection
          await tester.pumpWithTimeout(const Duration(seconds: 3));
          
          // Verify level selection screen works
          expect(find.byType(LevelSelectionScreen), findsOneWidget);
          expect(find.text('Learn Tibetan'), findsOneWidget);
          expect(find.text('Beginner'), findsOneWidget);
          
          // Verify no overflow errors
          expect(tester.takeException(), isNull);
          
          // Reset screen size
          await tester.binding.setSurfaceSize(null);
        });
      }
    });

    group('Android Platform Tests', () {
      final androidScreenSizes = [
        // Small Android phones
        {'name': 'Android Small', 'size': const Size(320, 533), 'columns': 2},
        // Compact Android (Galaxy S series)
        {'name': 'Android Compact', 'size': const Size(360, 640), 'columns': 2},
        // Standard Android (Pixel)
        {'name': 'Android Standard', 'size': const Size(411, 731), 'columns': 3},
        // Large Android phones
        {'name': 'Android Large', 'size': const Size(428, 926), 'columns': 4},
        // Android tablets (7")
        {'name': 'Android Tablet 7"', 'size': const Size(600, 960), 'columns': 4},
        // Android tablets (10")
        {'name': 'Android Tablet 10"', 'size': const Size(800, 1280), 'columns': 4},
        // Foldable phones (unfolded)
        {'name': 'Android Foldable', 'size': const Size(673, 841), 'columns': 4},
      ];

      for (final device in androidScreenSizes) {
        testWidgets('should work on ${device['name']}', (WidgetTester tester) async {
          // Set screen size
          await tester.binding.setSurfaceSize(device['size'] as Size);
          
          // Test app startup
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          
          // Verify splash screen
          expect(find.text('bojang'), findsOneWidget);
          
          // Navigate to level selection
          await tester.pumpWithTimeout(const Duration(seconds: 3));
          
          // Verify level selection screen works
          expect(find.byType(LevelSelectionScreen), findsOneWidget);
          expect(find.text('Learn Tibetan'), findsOneWidget);
          expect(find.text('Beginner'), findsOneWidget);
          
          // Verify no overflow errors
          expect(tester.takeException(), isNull);
          
          // Reset screen size
          await tester.binding.setSurfaceSize(null);
        });
      }
    });

    group('Platform-Specific Behavior Tests', () {
      testWidgets('should handle platform-specific navigation', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Test navigation patterns work on both platforms
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        
        // Test back button behavior (Android) vs swipe gesture (iOS)
        // Both should be handled gracefully
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/platform',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('SystemNavigator.pop')
          ),
          (data) {},
        );
        
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle platform-specific notifications', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        // App should start successfully with notification service mocks
        // that handle both iOS and Android notification APIs
        expect(find.text('bojang'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle platform-specific audio', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Navigate to quiz to test audio functionality
        final alphabetButton = find.text('Alphabet');
        if (alphabetButton.evaluate().isNotEmpty) {
          await tester.tap(alphabetButton);
          await tester.pumpWithTimeout(const Duration(milliseconds: 500));
          
          // Audio should work on both platforms
          expect(find.byType(QuizScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    });

    group('Cross-Platform Theme Tests', () {
      testWidgets('should use Material theme on both platforms', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.theme?.useMaterial3, isTrue);
        expect(materialApp.theme?.colorScheme.primary, equals(Colors.blue));
      });

      testWidgets('should handle different text scales on both platforms', (WidgetTester tester) async {
        final textScales = [1.0, 1.5, 2.0, 3.0];
        
        for (final scale in textScales) {
          tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
          
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          
          expect(find.text('bojang'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        
        // Reset text scale
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      });
    });

    group('Cross-Platform Performance Tests', () {
      testWidgets('should perform well on both iOS and Android screen sizes', (WidgetTester tester) async {
        final crossPlatformSizes = [
          const Size(320, 568),   // Small (both platforms)
          const Size(375, 667),   // iPhone standard
          const Size(411, 731),   // Android standard  
          const Size(428, 926),   // Large (both platforms)
        ];

        for (final size in crossPlatformSizes) {
          final stopwatch = Stopwatch()..start();
          
          await tester.binding.setSurfaceSize(size);
          await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
          await tester.pumpWithTimeout(const Duration(seconds: 3));
          
          stopwatch.stop();
          
          // Should perform well regardless of platform or screen size
          expect(stopwatch.elapsedMilliseconds, lessThan(5000));
          expect(find.text('Beginner'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Cross-Platform Asset Loading Tests', () {
      testWidgets('should load assets consistently on both platforms', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Assets should load on both platforms
        expect(find.text('Beginner'), findsOneWidget);
        expect(find.text('Intermediate'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
        
        // No platform-specific asset loading issues
        expect(tester.takeException(), isNull);
      });
    });

    group('Cross-Platform Error Handling Tests', () {
      testWidgets('should handle errors gracefully on both platforms', (WidgetTester tester) async {
        // Test without setting up mocks to simulate error conditions
        await tester.pumpWidget(const MyApp());
        
        // App should handle missing assets gracefully on both platforms
        expect(find.text('bojang'), findsOneWidget);
        
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Should not crash on either platform
        expect(tester.takeException(), isNull);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
      });
    });

    group('Cross-Platform Input Handling Tests', () {
      testWidgets('should handle touch input on both platforms', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Test tap interactions work on both platforms
        final settingsButton = find.byIcon(Icons.settings);
        if (settingsButton.evaluate().isNotEmpty) {
          await tester.tap(settingsButton);
          await tester.pumpWithTimeout(const Duration(milliseconds: 500));
          
          // Navigation should work on both platforms
          expect(tester.takeException(), isNull);
        }
      });
    });

    group('Cross-Platform Accessibility Tests', () {
      testWidgets('should maintain accessibility on both platforms', (WidgetTester tester) async {
        await TestHelpers.pumpWidgetWithMocks(tester, const MyApp());
        await tester.pumpWithTimeout(const Duration(seconds: 3));
        
        // Both platforms should have semantic information
        expect(find.byType(Semantics), findsWidgets);
        
        // Test with high contrast (available on both platforms)
        await tester.binding.setSurfaceSize(const Size(411, 731)); // Android size
        await tester.pump();
        
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        await tester.binding.setSurfaceSize(const Size(375, 667)); // iOS size
        await tester.pump();
        
        expect(find.text('Learn Tibetan'), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}
