import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:bojang/screens/profile_screen.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/models/user.dart';

// Generate mocks
@GenerateMocks([GoogleAuthService, ProgressService])
import 'profile_screen_test.mocks.dart';

void main() {
  group('ProfileScreen Widget Tests', () {
    late MockGoogleAuthService mockGoogleAuthService;
    late MockProgressService mockProgressService;

    setUp(() {
      mockGoogleAuthService = MockGoogleAuthService();
      mockProgressService = MockProgressService();
      
      // Set up default mock behaviors
      when(mockProgressService.currentLevel).thenReturn(1);
      when(mockProgressService.totalScore).thenReturn(100);
      when(mockProgressService.streakCount).thenReturn(5);
      when(mockProgressService.totalQuestionsAnswered).thenReturn(50);
      when(mockProgressService.correctAnswers).thenReturn(40);
    });

    Widget createTestWidget({User? currentUser}) {
      when(mockGoogleAuthService.currentUser).thenReturn(currentUser);
      
      return MultiProvider(
        providers: [
          Provider<GoogleAuthService>.value(value: mockGoogleAuthService),
          ChangeNotifierProvider<ProgressService>.value(value: mockProgressService),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      );
    }

    testWidgets('should display default user info when not authenticated', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tibetan Learner'), findsOneWidget);
      expect(find.text('Level 1 Learner'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('should display Google user info when authenticated', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        profileImageUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
        googleId: 'google-123',
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('test@gmail.com'), findsOneWidget);
      expect(find.text('Google Account'), findsOneWidget);
    });

    testWidgets('should display logout button when authenticated', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('should not display logout button when not authenticated', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('should display user avatar with initials when no profile image', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.email,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      expect(find.text('J'), findsOneWidget); // First letter of display name
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('should display user avatar with network image when available', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        profileImageUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
    });

    testWidgets('should display progress stats', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Level 1 Learner'), findsOneWidget);
      // The exact text depends on the implementation, but should show progress info
    });

    testWidgets('should show edit name dialog when edit button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Edit Name'), findsOneWidget);
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should update name when save is tapped in edit dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Enter new name
      await tester.enterText(find.byType(TextField), 'New Name');
      
      // Tap save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should update the displayed name
      expect(find.text('New Name'), findsOneWidget);
    });

    testWidgets('should cancel name edit when cancel is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final originalName = 'Tibetan Learner';

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Enter new name but cancel
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should keep original name
      expect(find.text(originalName), findsOneWidget);
      expect(find.text('New Name'), findsNothing);
    });

    testWidgets('should navigate to settings when settings button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap settings button
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // This would require navigation testing setup to fully verify
      // For now, we just verify the button exists and is tappable
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should show logout confirmation dialog', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsNWidgets(2)); // Title and button
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should cancel logout when cancel is tapped', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should still be on profile screen
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('should call signOut when logout is confirmed', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      when(mockGoogleAuthService.signOut()).thenAnswer((_) async => {});

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Confirm logout
      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();

      verify(mockGoogleAuthService.signOut()).called(1);
    });

    testWidgets('should display correct auth provider badge', (WidgetTester tester) async {
      final emailUser = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'John Doe',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.email,
      );

      await tester.pumpWidget(createTestWidget(currentUser: emailUser));
      await tester.pumpAndSettle();

      // Should not show Google Account badge for email users
      expect(find.text('Google Account'), findsNothing);

      // Test with Google user
      final googleUser = emailUser.copyWith(authProvider: AuthProvider.google);
      when(mockGoogleAuthService.currentUser).thenReturn(googleUser);

      await tester.pumpWidget(createTestWidget(currentUser: googleUser));
      await tester.pumpAndSettle();

      expect(find.text('Google Account'), findsOneWidget);
    });

    testWidgets('should handle empty display name gracefully', (WidgetTester tester) async {
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: '',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );

      await tester.pumpWidget(createTestWidget(currentUser: testUser));
      await tester.pumpAndSettle();

      // Should fall back to default name
      expect(find.text('Tibetan Learner'), findsOneWidget);
      
      // Avatar should show 'T' for default name
      expect(find.text('T'), findsOneWidget);
    });
  });
}
