import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/widgets/google_sign_in_button.dart';

void main() {
  group('GoogleSignInButton Widget Tests', () {
    testWidgets('should display default text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('should display custom text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              text: 'Sign in with Google',
            ),
          ),
        ),
      );

      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('should show loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.text('Signing in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should call onPressed when tapped', (WidgetTester tester) async {
      bool wasTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pumpAndSettle();

      expect(wasTapped, isTrue);
    });

    testWidgets('should not call onPressed when loading', (WidgetTester tester) async {
      bool wasTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              isLoading: true,
              onPressed: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pumpAndSettle();

      expect(wasTapped, isFalse);
    });

    testWidgets('should not call onPressed when disabled', (WidgetTester tester) async {
      bool wasTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: null, // Disabled
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pumpAndSettle();

      expect(wasTapped, isFalse);
    });

    testWidgets('should have correct dimensions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.minWidth, equals(double.infinity));
      expect(container.constraints?.minHeight, equals(56.0));
    });

    testWidgets('should display Google logo', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      // Should find the custom painted Google logo
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('should have proper styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('should be accessible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      // Should be able to find the button for accessibility
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('should handle theme changes', (WidgetTester tester) async {
      // Test with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);

      // Test with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('GoogleLogoPainter Tests', () {
    testWidgets('should paint Google logo', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(),
          ),
        ),
      );

      // Verify that CustomPaint widget exists (contains the logo painter)
      expect(find.byType(CustomPaint), findsOneWidget);
      
      // Get the painter and verify it's the correct type
      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      expect(customPaint.painter, isA<GoogleLogoPainter>());
    });
  });
}
