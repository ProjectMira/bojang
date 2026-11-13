import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/screens/auth_screen.dart';
import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/services/app_config.dart';
import 'package:bojang/services/apple_sign_in.dart';
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
      // These cover the Google path on its own; the email form has its own
      // group below.
      AppConfig.debugEmailSignInEnabled = false;
      AppConfig.debugGoogleSignInEnabled = true;
    });

    tearDown(() {
      AppConfig.debugEmailSignInEnabled = null;
      AppConfig.debugGoogleSignInEnabled = null;
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

    testWidgets('without the email form, offers only Google sign-in', (
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

    testWidgets('cancelled Google sign-in shows no message at all', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithGoogle(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // A cancel is a user action, not an error: no snackbar, no dialog.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Google sign-in failure shows a friendly dialog', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithGoogle(),
      ).thenThrow(Exception('sign_in_failed: developer error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text("Google sign-in didn't complete"), findsOneWidget);
      expect(find.textContaining('continue without an account'), findsWidgets);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Loading state cleared, button back to its normal (usable) label.
      expect(find.byType(AlertDialog), findsNothing);
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

  // Sign in with Apple is compiled in only on iOS builds carrying the Firebase
  // configuration, so these tests force the button on through AppConfig's
  // test seam.
  group('AuthScreen Sign in with Apple', () {
    late MockGoogleAuthService mockGoogleAuthService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGoogleAuthService = MockGoogleAuthService();
      when(mockGoogleAuthService.initialize()).thenAnswer((_) async => {});
      when(mockGoogleAuthService.isInitialized).thenReturn(true);
      AppConfig.debugAppleSignInEnabled = true;
      AppConfig.debugGoogleSignInEnabled = true;
      AppConfig.debugEmailSignInEnabled = false;
    });

    tearDown(() {
      AppConfig.debugAppleSignInEnabled = null;
      AppConfig.debugGoogleSignInEnabled = null;
      AppConfig.debugEmailSignInEnabled = null;
      AppConfig.debugAppleSignInDiagnosticsEnabled = null;
    });

    Widget createTestWidget() =>
        MaterialApp(home: AuthScreen(authService: mockGoogleAuthService));

    testWidgets('offers Apple sign-in above Google on Apple platforms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Guideline 4.8 wants Sign in with Apple at least as prominent as the
      // other providers.
      final appleY = tester.getTopLeft(find.text('Continue with Apple')).dy;
      final googleY = tester.getTopLeft(find.text('Continue with Google')).dy;
      expect(appleY, lessThan(googleY));
    });

    testWidgets('successful Apple sign-in greets the user and navigates', (
      WidgetTester tester,
    ) async {
      // Apple sends no email when the user hides it, so the account can carry
      // only a uid and the name Apple gave on first authorization.
      final appleUser = User(
        id: 'apple-uid',
        email: '',
        username: 'apple-uid',
        displayName: 'Tenzin',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.apple,
      );
      when(
        mockGoogleAuthService.signInWithApple(),
      ).thenAnswer((_) async => appleUser);
      when(mockGoogleAuthService.currentUser).thenReturn(appleUser);

      // The success path navigates to MainNavigationScreen after 500ms, and
      // that screen resolves its services from Provider.
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

      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();

      verify(mockGoogleAuthService.signInWithApple()).called(1);
      expect(find.text('Welcome Tenzin!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('dismissing the Apple sheet shows no message at all', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithApple(),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('Apple sign-in failure shows a friendly, recoverable dialog', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithApple(),
      ).thenThrow(Exception('apple sign-in failed'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.text("Apple sign-in didn't complete"), findsOneWidget);
      expect(find.textContaining('continue without an account'), findsWidgets);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    // Apple's own refusal arrives as a plain cancel. Diagnostics builds turn
    // it into a visible error so a tester's screenshot carries the code.
    testWidgets('the failure dialog exposes Apple code and UTC timestamp', (
      WidgetTester tester,
    ) async {
      when(mockGoogleAuthService.signInWithApple()).thenThrow(
        AppleSignInFailure(
          code: 1001,
          domain: 'com.apple.AuthenticationServices.AuthorizationError',
          message: 'Apple could not complete the sign-up',
          underlying: const ['AKAuthenticationError -7003: unusable account'],
          occurredAt: DateTime.utc(2026, 8, 14, 12, 34, 56),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1001'), findsOneWidget);
      expect(find.textContaining('2026-08-14T12:34:56.000Z'), findsOneWidget);
      expect(
        find.textContaining('Apple could not complete the sign-up'),
        findsOneWidget,
      );
      // The nested error is the whole point of the native bridge: it must
      // survive all the way into the dialog a tester screenshots.
      expect(find.textContaining('AKAuthenticationError -7003'), findsOneWidget);
    });

    testWidgets('a pending Apple sign-in blocks the Google button', (
      WidgetTester tester,
    ) async {
      final completer = Completer<User?>();
      when(
        mockGoogleAuthService.signInWithApple(),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();

      expect(find.text('Signing in...'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'), warnIfMissed: false);
      await tester.pump();

      completer.complete(null);
      await tester.pumpAndSettle();

      verify(mockGoogleAuthService.signInWithApple()).called(1);
      verifyNever(mockGoogleAuthService.signInWithGoogle());
    });
  });

  group('AuthScreen layout', () {
    late MockGoogleAuthService mockGoogleAuthService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGoogleAuthService = MockGoogleAuthService();
      when(mockGoogleAuthService.initialize()).thenAnswer((_) async => {});
      when(mockGoogleAuthService.isInitialized).thenReturn(true);
      AppConfig.debugAppleSignInEnabled = true;
      AppConfig.debugGoogleSignInEnabled = true;
      AppConfig.debugEmailSignInEnabled = true;
    });

    tearDown(() {
      AppConfig.debugAppleSignInEnabled = null;
      AppConfig.debugGoogleSignInEnabled = null;
      AppConfig.debugEmailSignInEnabled = null;
    });

    Widget createTestWidget() =>
        MaterialApp(home: AuthScreen(authService: mockGoogleAuthService));

    // App Review rejected 2026-07-18 on an iPad Air 11-inch (M3), so pin the
    // sign-in screen's layout at that geometry.
    testWidgets('lays out without overflow on an iPad Air 11-inch', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1640, 2360);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue without account'), findsOneWidget);

      // Every control sits inside the 820x1180pt screen.
      for (final label in const [
        'Sign in',
        'Continue with Apple',
        'Continue with Google',
        'Continue without account',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0.0), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(1180.0), reason: label);
        expect(rect.left, greaterThanOrEqualTo(0.0), reason: label);
        expect(rect.right, lessThanOrEqualTo(820.0), reason: label);
      }
    });
  });

  group('AuthScreen email sign-in', () {
    late MockGoogleAuthService mockGoogleAuthService;

    final emailUser = User(
      id: 'uid-1',
      email: 'learner@example.com',
      username: 'learner',
      displayName: 'Learner One',
      createdAt: DateTime(2026, 11, 13),
      authProvider: AuthProvider.email,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGoogleAuthService = MockGoogleAuthService();
      when(mockGoogleAuthService.initialize()).thenAnswer((_) async => {});
      when(mockGoogleAuthService.isInitialized).thenReturn(true);
      // The shipping iOS configuration while Apple's Sign in with Apple
      // backend is broken: email accounts only, no Google or Apple.
      AppConfig.debugEmailSignInEnabled = true;
      AppConfig.debugGoogleSignInEnabled = false;
      AppConfig.debugAppleSignInEnabled = false;
    });

    tearDown(() {
      AppConfig.debugEmailSignInEnabled = null;
      AppConfig.debugGoogleSignInEnabled = null;
      AppConfig.debugAppleSignInEnabled = null;
    });

    // The success paths navigate to MainNavigationScreen, whose tabs pull
    // these services from Provider.
    Widget createTestWidget({List<NavigatorObserver> observers = const []}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => ProgressService()),
          Provider<GoogleAuthService>.value(value: mockGoogleAuthService),
        ],
        child: MaterialApp(
          navigatorObservers: observers,
          home: AuthScreen(authService: mockGoogleAuthService),
        ),
      );
    }

    // Success paths build MainNavigationScreen, which is laid out at the
    // default 800x600 test surface like the Google success test.
    Future<void> pumpDefault(WidgetTester tester, Widget widget) async {
      when(mockGoogleAuthService.currentUser).thenReturn(emailUser);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
    }

    Future<void> pumpTall(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('iOS configuration shows the email form and no social logins', (
      WidgetTester tester,
    ) async {
      await pumpTall(tester, createTestWidget());

      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.byKey(const Key('nameField')), findsNothing);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('or'), findsNothing);
      expect(find.text('Continue without account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid input is caught before calling Firebase', (
      WidgetTester tester,
    ) async {
      await pumpTall(tester, createTestWidget());

      await tester.enterText(find.byKey(const Key('emailField')), 'not-an-email');
      await tester.tap(find.byKey(const Key('emailSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      verifyNever(
        mockGoogleAuthService.signInWithEmail(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      );
    });

    testWidgets('signing in with email navigates to the main screen', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithEmail(
          email: 'learner@example.com',
          password: 'secret123',
        ),
      ).thenAnswer((_) async => emailUser);
      final observer = _RecordingNavigatorObserver();
      await pumpDefault(tester, createTestWidget(observers: [observer]));

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'learner@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
      await tapVisible(tester, find.byKey(const Key('emailSubmitButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Welcome Learner One!'), findsOneWidget);
      expect(observer.lastReplacedWith?.settings.name, '/main');
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('wrong password shows a clear inline error', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.signInWithEmail(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenThrow(
        firebase_auth.FirebaseAuthException(code: 'invalid-credential'),
      );
      await pumpTall(tester, createTestWidget());

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'learner@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'wrong');
      await tester.tap(find.byKey(const Key('emailSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byKey(const Key('emailSubmitButton')), findsOneWidget);
    });

    testWidgets('create-account mode asks for a name and creates the account', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.createAccountWithEmail(
          name: 'Learner One',
          email: 'learner@example.com',
          password: 'secret123',
        ),
      ).thenAnswer((_) async => emailUser);
      final observer = _RecordingNavigatorObserver();
      await pumpDefault(tester, createTestWidget(observers: [observer]));

      await tapVisible(tester, find.byKey(const Key('toggleAuthModeButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nameField')), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('passwordField')), '123');
      await tapVisible(tester, find.byKey(const Key('emailSubmitButton')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Use at least 6 characters'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('nameField')), 'Learner One');
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'learner@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
      await tapVisible(tester, find.byKey(const Key('emailSubmitButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        mockGoogleAuthService.createAccountWithEmail(
          name: 'Learner One',
          email: 'learner@example.com',
          password: 'secret123',
        ),
      ).called(1);
      expect(observer.lastReplacedWith?.settings.name, '/main');
      await tester.pumpAndSettle();
    });

    testWidgets('an existing email on sign-up says to sign in instead', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.createAccountWithEmail(
          name: anyNamed('name'),
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenThrow(
        firebase_auth.FirebaseAuthException(code: 'email-already-in-use'),
      );
      await pumpTall(tester, createTestWidget());

      await tester.tap(find.byKey(const Key('toggleAuthModeButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nameField')), 'Learner');
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'learner@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
      await tester.tap(find.byKey(const Key('emailSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('An account already exists for this email. Sign in instead.'),
        findsOneWidget,
      );
    });

    testWidgets('forgot password sends a reset email for the typed address', (
      WidgetTester tester,
    ) async {
      when(
        mockGoogleAuthService.sendPasswordResetEmail('learner@example.com'),
      ).thenAnswer((_) async {});
      await pumpTall(tester, createTestWidget());

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter your email above, then tap "Forgot password?"'),
        findsOneWidget,
      );
      verifyNever(mockGoogleAuthService.sendPasswordResetEmail(any));

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'learner@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      verify(
        mockGoogleAuthService.sendPasswordResetEmail('learner@example.com'),
      ).called(1);
      expect(
        find.textContaining('a reset link is on its way'),
        findsOneWidget,
      );
    });

    testWidgets('iOS configuration fits an iPad Air 11-inch and an iPhone SE', (
      WidgetTester tester,
    ) async {
      for (final (size, ratio, width, height) in const [
        (Size(1640, 2360), 2.0, 820.0, 1180.0),
        (Size(750, 1334), 2.0, 375.0, 667.0),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = ratio;
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byKey(const Key('emailSubmitButton')));
        expect(rect.left, greaterThanOrEqualTo(0.0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.top, lessThan(height));
      }
      tester.view.reset();
    });
  });
}
