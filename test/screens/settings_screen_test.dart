import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/screens/settings_screen.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/api_service.dart';

@GenerateMocks([GoogleAuthService, ApiService])
import 'settings_screen_test.mocks.dart';

void main() {
  group('SettingsScreen Account Deletion', () {
    late MockGoogleAuthService mockAuthService;
    late MockApiService mockApiService;
    late ThemeService themeService;
    late ProgressService progressService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockAuthService = MockGoogleAuthService();
      mockApiService = MockApiService();
      themeService = ThemeService();
      progressService = ProgressService();
    });

    Widget createTestWidget({required bool isSignedIn}) {
      when(mockAuthService.isSignedIn).thenReturn(isSignedIn);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ChangeNotifierProvider<ProgressService>.value(value: progressService),
          Provider<GoogleAuthService>.value(value: mockAuthService),
          Provider<ApiService>.value(value: mockApiService),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );
    }

    testWidgets('hides the Account section for guests', (tester) async {
      await tester.pumpWidget(createTestWidget(isSignedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsNothing);
      expect(find.text('Delete Account'), findsNothing);
    });

    testWidgets('shows Delete Account for signed-in users', (tester) async {
      await tester.pumpWidget(createTestWidget(isSignedIn: true));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('cancelling the first dialog does nothing', (tester) async {
      await tester.pumpWidget(createTestWidget(isSignedIn: true));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Delete Account'));

      expect(find.text('Delete Account?'), findsOneWidget);
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsNothing);
      verifyNever(mockApiService.deleteAccount());
    });

    testWidgets('cancelling the second dialog does not call the API', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(isSignedIn: true));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Delete Account'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      verifyNever(mockApiService.deleteAccount());
    });

    testWidgets(
      'confirming deletion signs out, resets progress, and returns to AuthScreen',
      (tester) async {
        when(mockApiService.deleteAccount()).thenAnswer((_) async => true);
        when(mockAuthService.signOut()).thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget(isSignedIn: true));
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Delete Account'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete My Account'));
        await tester.pumpAndSettle();

        expect(find.text('Account Deleted'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        verify(mockApiService.deleteAccount()).called(1);
        verify(mockAuthService.signOut()).called(1);
        expect(progressService.xp, 0);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );

    testWidgets('shows an error and stays signed in when deletion fails', (
      tester,
    ) async {
      when(mockApiService.deleteAccount()).thenAnswer((_) async => false);

      await tester.pumpWidget(createTestWidget(isSignedIn: true));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Delete Account'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete My Account'));
      await tester.pumpAndSettle();

      expect(find.text('Something Went Wrong'), findsOneWidget);
      verifyNever(mockAuthService.signOut());
    });
  });
}
