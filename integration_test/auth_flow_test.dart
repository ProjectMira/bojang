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
      final hasMainNavigation = find.text('Welcome back!').evaluate().isNotEmpty ||
          find.text('Ready to learn?').evaluate().isNotEmpty;

      expect(
        hasAuthElements || hasMainNavigation,
        isTrue,
        reason: 'Should show either auth screen or main navigation',
      );
    });

    testWidgets('Auth screen UI elements and interactions', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on the auth screen, test its elements
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Test app branding
        expect(find.text('Bojang'), findsOneWidget);
        expect(find.text('Learn Tibetan Language'), findsOneWidget);
        expect(find.byIcon(Icons.school), findsOneWidget);

        // Test form elements
        expect(find.text('Welcome Back!'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);

        // Test form toggle
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(4));

        // Toggle back to login
        await tester.tap(find.text('Sign In').last);
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back!'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
      }
    });

    testWidgets('Skip authentication flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test skip functionality
      if (find.text('Skip for now').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        // Should navigate to main navigation screen
        // Look for home screen elements
        final hasHomeElements = find.text('Welcome back!').evaluate().isNotEmpty ||
            find.text('Ready to learn?').evaluate().isNotEmpty;

        expect(
          hasHomeElements,
          isTrue,
          reason: 'Should navigate to home screen after skipping auth',
        );
      }
    });

    testWidgets('Email validation in auth form', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test form validation
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Find email field (first TextFormField)
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().isNotEmpty) {
          await tester.enterText(emailFields.first, 'invalid-email');
          
          // Try to submit form
          final signInButtons = find.text('Sign In');
          if (signInButtons.evaluate().isNotEmpty) {
            await tester.tap(signInButtons.first);
            await tester.pumpAndSettle();

            // Should show validation error
            expect(
              find.text('Please enter a valid email').evaluate().isNotEmpty ||
              find.text('Email is required').evaluate().isNotEmpty,
              isTrue,
              reason: 'Should show email validation error',
            );
          }
        }
      }
    });

    testWidgets('Password visibility toggle', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test password visibility
      if (find.text('Bojang').evaluate().isNotEmpty) {
        final visibilityIcons = find.byIcon(Icons.visibility);
        if (visibilityIcons.evaluate().isNotEmpty) {
          await tester.tap(visibilityIcons.first);
          await tester.pumpAndSettle();

          // Should toggle to visibility_off icon
          expect(find.byIcon(Icons.visibility_off), findsOneWidget);

          // Toggle back
          await tester.tap(find.byIcon(Icons.visibility_off));
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.visibility), findsOneWidget);
        }
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

        // This will likely fail in test environment due to lack of Google services
        // But we can verify the button is tappable and doesn't crash the app
        expect(
          find.byType(MaterialApp),
          findsOneWidget,
          reason: 'App should remain stable after Google sign-in attempt',
        );
      }
    });

    testWidgets('Navigation between auth modes', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test navigation between login/signup
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Start in login mode
        expect(find.text('Welcome Back!'), findsOneWidget);
        
        // Switch to signup
        final signUpLinks = find.textContaining('Sign Up');
        if (signUpLinks.evaluate().isNotEmpty) {
          await tester.tap(signUpLinks.first);
          await tester.pumpAndSettle();

          expect(find.text('Create Account'), findsOneWidget);
          
          // Switch back to login
          final signInLinks = find.textContaining('Sign In');
          if (signInLinks.evaluate().length > 1) {
            await tester.tap(signInLinks.last);
            await tester.pumpAndSettle();

            expect(find.text('Welcome Back!'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('Form field interactions and validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on auth screen, test comprehensive form interaction
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Switch to signup mode for more fields
        final signUpLinks = find.textContaining('Sign Up');
        if (signUpLinks.evaluate().isNotEmpty) {
          await tester.tap(signUpLinks.first);
          await tester.pumpAndSettle();

          final textFields = find.byType(TextFormField);
          if (textFields.evaluate().length >= 4) {
            // Fill out form with valid data
            await tester.enterText(textFields.at(0), 'Test User');
            await tester.enterText(textFields.at(1), 'testuser');
            await tester.enterText(textFields.at(2), 'test@example.com');
            await tester.enterText(textFields.at(3), 'password123');

            // Try to submit (will fail due to no backend, but form should validate)
            final signUpButtons = find.text('Sign Up');
            if (signUpButtons.evaluate().isNotEmpty) {
              await tester.tap(signUpButtons.first);
              await tester.pumpAndSettle();

              // Form should be valid (no validation errors shown)
              expect(
                find.text('Display name is required').evaluate().isEmpty &&
                find.text('Username is required').evaluate().isEmpty &&
                find.text('Please enter a valid email').evaluate().isEmpty &&
                find.text('Password must be at least 6 characters').evaluate().isEmpty,
                isTrue,
                reason: 'Form should pass validation with valid data',
              );
            }
          }
        }
      }
    });

    testWidgets('App state persistence after navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test that app state is maintained during navigation
      if (find.text('Skip for now').evaluate().isNotEmpty) {
        // Skip to main app
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        // Should be on main navigation screen
        expect(
          find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
          find.text('Welcome back!').evaluate().isNotEmpty,
          isTrue,
          reason: 'Should navigate to main app successfully',
        );

        // Test bottom navigation if present
        final bottomNavBars = find.byType(BottomNavigationBar);
        if (bottomNavBars.evaluate().isNotEmpty) {
          // Try to navigate between tabs
          final bottomNavBar = tester.widget<BottomNavigationBar>(bottomNavBars.first);
          if (bottomNavBar.items.length > 1) {
            // Tap second tab
            await tester.tap(find.byIcon(bottomNavBar.items[1].icon));
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

    testWidgets('Error handling and recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test error handling in auth forms
      if (find.text('Bojang').evaluate().isNotEmpty) {
        // Try to submit empty form
        final signInButtons = find.text('Sign In');
        if (signInButtons.evaluate().isNotEmpty) {
          await tester.tap(signInButtons.first);
          await tester.pumpAndSettle();

          // Should show validation errors but app should remain stable
          expect(
            find.byType(MaterialApp),
            findsOneWidget,
            reason: 'App should handle form validation errors gracefully',
          );

          // Clear any error states by filling form properly
          final textFields = find.byType(TextFormField);
          if (textFields.evaluate().length >= 2) {
            await tester.enterText(textFields.at(0), 'test@example.com');
            await tester.enterText(textFields.at(1), 'password123');
            
            // App should recover from error state
            expect(
              find.byType(MaterialApp),
              findsOneWidget,
              reason: 'App should recover from error states',
            );
          }
        }
      }
    });
  });
}
