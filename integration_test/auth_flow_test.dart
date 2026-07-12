import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bojang/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    setUp(() async {
      // Clear any stored authentication data before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    testWidgets('Complete app startup and auth screen display', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show splash screen first, then auth screen
      // Note: This test might show main navigation if user is already signed in
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'App should start successfully',
      );

      // Look for either auth screen elements or main navigation
      final hasAuthElements = find.text('Bojang').evaluate().isNotEmpty ||
          find.text('Continue with Google').evaluate().isNotEmpty;
      final hasMainNavigation = find.text('Welcome back').evaluate().isNotEmpty ||
          find.text('Ready for Tibetan?').evaluate().isNotEmpty;

      expect(
        hasAuthElements || hasMainNavigation,
        isTrue,
        reason: 'Should show either auth screen or main navigation',
      );
    });

    testWidgets('Auth screen UI elements', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on the auth screen, test its elements
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Test app branding
        expect(find.text('Bojang'), findsOneWidget);
        expect(find.text('Practice Tibetan every day'), findsOneWidget);
        expect(find.byIcon(Icons.school), findsNothing);

        // Only Google sign-in is offered, no email/password form
        expect(find.text('Save your progress'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue without account'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
      }
    });

    testWidgets('Continue without account flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test the skip functionality
      if (find.text('Continue without account').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continue without account'));
        await tester.pumpAndSettle();

        // Should navigate to main navigation screen
        final hasHomeElements = find.text('Welcome back').evaluate().isNotEmpty ||
            find.text('Ready for Tibetan?').evaluate().isNotEmpty;

        expect(
          hasHomeElements,
          isTrue,
          reason: 'Should navigate to home screen after skipping auth',
        );
      }
    });

    testWidgets('Google Sign-In button interaction', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test Google sign-in button
      if (find.text('Continue with Google').evaluate().isNotEmpty) {
        // Tap Google sign-in button
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        // This may fail in a test environment without real Google services,
        // but tapping it must not crash the app.
        expect(
          find.byType(MaterialApp),
          findsOneWidget,
          reason: 'App should remain stable after Google sign-in attempt',
        );
      }
    });

    testWidgets('App state persistence after navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test that app state is maintained during navigation
      if (find.text('Continue without account').evaluate().isNotEmpty) {
        // Skip to main app
        await tester.tap(find.text('Continue without account'));
        await tester.pumpAndSettle();

        // Should be on main navigation screen
        expect(
          find.text('Welcome back').evaluate().isNotEmpty,
          isTrue,
          reason: 'Should navigate to main app successfully',
        );

        // Test bottom navigation if present
        final bottomNavItems = find.text('Home');
        if (bottomNavItems.evaluate().isNotEmpty) {
          // Try to navigate to the Streak tab
          final streakTab = find.text('Streak');
          if (streakTab.evaluate().isNotEmpty) {
            await tester.tap(streakTab);
            await tester.pumpAndSettle();

            // App should remain stable
            expect(
              find.byType(MaterialApp),
              findsOneWidget,
              reason: 'App should handle navigation between tabs',
            );
          }
        }
      }
    });
  });
}
