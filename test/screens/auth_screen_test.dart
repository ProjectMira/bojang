import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/screens/auth_screen.dart';
import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:bojang/models/user.dart';

// Generate mocks
@GenerateMocks([GoogleAuthService])
import 'auth_screen_test.mocks.dart';

/// Records route replacements without letting the destination route build,
/// so tests can confirm navigation was triggered without dragging in
/// MainNavigationScreen's Provider dependencies.
class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastReplacedWith;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    lastReplacedWith = newRoute;
  }
}

void main() {
  group('AuthScreen Widget Tests', () {
    late MockGoogleAuthService mockGoogleAuthService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGoogleAuthService = MockGoogleAuthService();

      // Set up default mock behaviors
      when(mockGoogleAuthService.initialize()).thenAnswer((_) async => {});
      when(mockGoogleAuthService.isInitialized).thenReturn(true);
    });

    Widget createTestWidget({List<NavigatorObserver> observers = const []}) {
      return MaterialApp(
        navigatorObservers: observers,
        home: AuthScreen(authService: mockGoogleAuthService),
      );
    }

    testWidgets('should display app wordmark and tagline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bojang'), findsOneWidget);
      expect(find.text('Practice Tibetan every day'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsNothing);
    });

    testWidgets('should only offer Google sign-in, no email form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Email sign-in coming soon'), findsNothing);
      expect(find.byIcon(Icons.mail_outline), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('should display continue without account button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Continue without account'), findsOneWidget);
    });

    testWidgets('should navigate to main screen when skip button tapped', (
      WidgetTester tester,
    ) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(createTestWidget(observers: [observer]));
      await tester.pumpAndSettle();

      // Tapping runs the synchronous onPressed handler (and thus
      // Navigator.pushReplacement) without needing a further pump, so the
      // destination route is never actually built here.
      await tester.tap(find.text('Continue without account'));

      expect(observer.lastReplacedWith?.settings.name, '/main');
    });

    testWidgets('should call Google sign-in when button is tapped', (
      WidgetTester tester,
    ) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      when(
        mockGoogleAuthService.signInWithGoogle(),
      ).thenAnswer((_) async => testUser);
      when(mockGoogleAuthService.currentUser).thenReturn(testUser);

      // The success path awaits a 500ms delay before navigating to
      // MainNavigationScreen, whose tabs pull ProgressService, ThemeService,
      // and GoogleAuthService from Provider. That timer must fire before the
      // test ends (flutter_test fails on pending timers), so the full
      // provider tree the destination screen needs is supplied here.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => ProgressService()),
            Provider<GoogleAuthService>.value(value: mockGoogleAuthService),
          ],
          child: MaterialApp(
            home: AuthScreen(authService: mockGoogleAuthService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      verify(mockGoogleAuthService.signInWithGoogle()).called(1);
      expect(find.text('Welcome Test User!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('should handle Google sign-in cancellation', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithGoogle(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cancelled or failed'), findsOneWidget);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('should handle Google sign-in error without crashing', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithGoogle(),
      ).thenThrow(Exception('sign_in_failed: developer error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('configuration issue'), findsOneWidget);

      // Loading state cleared, button back to its normal (usable) label.
      expect(find.text('Signing in...'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets(
      'should show loading state and ignore a second tap while pending',
      (WidgetTester tester) async {
        final completer = Completer<User?>();
        when(
          mockGoogleAuthService.signInWithGoogle(),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        expect(find.text('Signing in...'), findsOneWidget);

        // Tapping again while pending must not trigger a second call: the
        // button's onTap is null while isLoading is true.
        await tester.tap(find.text('Signing in...'), warnIfMissed: false);
        await tester.pump();

        completer.complete(null);
        await tester.pumpAndSettle();

        verify(mockGoogleAuthService.signInWithGoogle()).called(1);
      },
    );
  });
}
