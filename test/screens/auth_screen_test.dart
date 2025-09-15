import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:bojang/screens/auth_screen.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/models/user.dart';

// Generate mocks
@GenerateMocks([GoogleAuthService, ApiService])
import 'auth_screen_test.mocks.dart';

void main() {
  group('AuthScreen Widget Tests', () {
    late MockGoogleAuthService mockGoogleAuthService;
    late MockApiService mockApiService;

    setUp(() {
      mockGoogleAuthService = MockGoogleAuthService();
      mockApiService = MockApiService();
      
      // Set up default mock behaviors
      when(mockGoogleAuthService.initialize()).thenAnswer((_) async => {});
      when(mockGoogleAuthService.isInitialized).thenReturn(true);
      when(mockGoogleAuthService.currentUser).thenReturn(null);
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          Provider<GoogleAuthService>.value(value: mockGoogleAuthService),
          Provider<ApiService>.value(value: mockApiService),
        ],
        child: const MaterialApp(
          home: AuthScreen(),
        ),
      );
    }

    testWidgets('should display app logo and title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bojang'), findsOneWidget);
      expect(find.text('Learn Tibetan Language'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets('should display login form by default', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password
    });

    testWidgets('should toggle to signup form', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on "Sign Up" link
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // Display name, username, email, password
    });

    testWidgets('should display Google sign-in button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('should display skip button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('should validate email field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find email field and enter invalid email
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalid-email');

      // Try to submit form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('should validate required fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Try to submit form without filling fields
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('should validate password length in signup mode', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to signup mode
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Fill required fields with short password
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User'); // Display name
      await tester.enterText(find.byType(TextFormField).at(1), 'testuser'); // Username
      await tester.enterText(find.byType(TextFormField).at(2), 'test@example.com'); // Email
      await tester.enterText(find.byType(TextFormField).at(3), '123'); // Short password

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('should toggle password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find password visibility toggle button
      final visibilityButton = find.byIcon(Icons.visibility);
      expect(visibilityButton, findsOneWidget);

      // Tap to show password
      await tester.tap(visibilityButton);
      await tester.pumpAndSettle();

      // Should now show visibility_off icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('should call Google sign-in when button is tapped', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      when(mockGoogleAuthService.signInWithGoogle())
          .thenAnswer((_) async => testUser);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Google sign-in button
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      verify(mockGoogleAuthService.signInWithGoogle()).called(1);
    });

    testWidgets('should handle Google sign-in cancellation', (WidgetTester tester) async {
      when(mockGoogleAuthService.signInWithGoogle())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Google sign-in button
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Should show snackbar with cancellation message
      expect(find.text('Google sign-in was cancelled or failed'), findsOneWidget);
    });

    testWidgets('should call API service for email login', (WidgetTester tester) async {
      final mockResponse = {
        'token': 'auth-token',
        'user': {
          'id': 'user-id',
          'email': 'test@example.com',
          'username': 'testuser',
          'display_name': 'Test User',
          'created_at': '2023-01-01T00:00:00.000Z',
          'auth_provider': 'email',
        }
      };

      when(mockApiService.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockResponse);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Fill login form
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      // Submit form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      verify(mockApiService.login(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });

    testWidgets('should call API service for email registration', (WidgetTester tester) async {
      final mockResponse = {
        'token': 'auth-token',
        'user': {
          'id': 'user-id',
          'email': 'test@example.com',
          'username': 'testuser',
          'display_name': 'Test User',
          'created_at': '2023-01-01T00:00:00.000Z',
          'auth_provider': 'email',
        }
      };

      when(mockApiService.register(
        email: anyNamed('email'),
        username: anyNamed('username'),
        password: anyNamed('password'),
        displayName: anyNamed('displayName'),
      )).thenAnswer((_) async => mockResponse);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to signup mode
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Fill registration form
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(2), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');

      // Submit form
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      verify(mockApiService.register(
        email: 'test@example.com',
        username: 'testuser',
        password: 'password123',
        displayName: 'Test User',
      )).called(1);
    });

    testWidgets('should handle login failure', (WidgetTester tester) async {
      when(mockApiService.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Fill login form
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');

      // Submit form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Login failed'), findsOneWidget);
    });

    testWidgets('should show loading state during authentication', (WidgetTester tester) async {
      // Make the authentication call take some time
      when(mockApiService.login(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return {
          'token': 'auth-token',
          'user': {'id': 'user-id', 'email': 'test@example.com'}
        };
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Fill and submit form
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));

      // Should show loading indicator
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should navigate on skip button tap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap skip button
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // This test would need navigation observer to fully verify navigation
      // For now, we just verify the button exists and is tappable
      expect(find.text('Skip for now'), findsOneWidget);
    });
  });
}
