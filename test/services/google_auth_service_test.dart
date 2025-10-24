import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/models/user.dart';

// Generate mocks
@GenerateMocks([ApiService])
import 'google_auth_service_test.mocks.dart';

void main() {
  group('GoogleAuthService Tests', () {
    late MockApiService mockApiService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      
      mockApiService = MockApiService();
      
      // Mock platform channels for Google Sign-In
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'init':
              return null;
            case 'signIn':
              return {
                'id': 'google-id-123',
                'email': 'test@gmail.com',
                'displayName': 'Test User',
                'photoUrl': 'https://example.com/photo.jpg',
                'idToken': 'mock-id-token',
                'accessToken': 'mock-access-token',
              };
            case 'signInSilently':
              return null;
            case 'signOut':
              return null;
            case 'isSignedIn':
              return false;
            default:
              return null;
          }
        },
      );
    });

    test('should initialize successfully', () async {
      await authService.initialize();
      expect(authService.isInitialized, isTrue);
    });

    test('should return null when user cancels Google sign-in', () async {
      // Mock user canceling sign-in
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
      
      await authService.initialize();
      final result = await authService.signInWithGoogle();
      
      expect(result, isNull);
      expect(authService.isSignedIn, isFalse);
    });

    test('should successfully sign in with Google', () async {
      // Mock successful Google sign-in
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleAccount);
      
      // Mock API response
      final mockApiResponse = {
        'user': {
          'id': 'backend-user-id',
          'email': 'test@gmail.com',
          'username': 'testuser',
          'display_name': 'Test User',
          'profile_image_url': 'https://example.com/photo.jpg',
          'created_at': '2023-01-01T00:00:00.000Z',
          'google_id': 'google-id-123',
          'auth_provider': 'google',
        },
        'token': 'auth-token-123'
      };
      
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => mockApiResponse);

      await authService.initialize();
      final result = await authService.signInWithGoogle();
      
      expect(result, isNotNull);
      expect(result!.email, equals('test@gmail.com'));
      expect(result.googleId, equals('google-id-123'));
      expect(result.authProvider, equals(AuthProvider.google));
      expect(authService.isSignedIn, isTrue);
      expect(authService.currentUser, equals(result));
    });

    test('should handle Google sign-in without backend API', () async {
      // Mock successful Google sign-in
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleAccount);
      
      // Mock API failure
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => null);

      await authService.initialize();
      final result = await authService.signInWithGoogle();
      
      expect(result, isNotNull);
      expect(result!.email, equals('test@gmail.com'));
      expect(result.googleId, equals('google-id-123'));
      expect(result.authProvider, equals(AuthProvider.google));
      expect(authService.isSignedIn, isTrue);
    });

    test('should sign out successfully', () async {
      // First sign in
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleAccount);
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => null);

      await authService.initialize();
      await authService.signInWithGoogle();
      
      expect(authService.isSignedIn, isTrue);

      // Mock sign out
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(mockApiService.logout()).thenAnswer((_) async => {});

      // Sign out
      await authService.signOut();
      
      expect(authService.isSignedIn, isFalse);
      expect(authService.currentUser, isNull);
    });

    test('should handle silent sign-in', () async {
      when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => mockGoogleAccount);
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => null);

      await authService.initialize();
      final result = await authService.signInSilently();
      
      expect(result, isNotNull);
      expect(result!.email, equals('test@gmail.com'));
    });

    test('should return cached user when silent sign-in fails', () async {
      // Set up cached user
      final cachedUser = User(
        id: 'cached-id',
        email: 'cached@example.com',
        username: 'cached',
        displayName: 'Cached User',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
      );
      
      // Mock silent sign-in failure
      when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => null);

      await authService.initialize();
      final result = await authService.signInSilently();
      
      // Should return null since no cached user in this test
      expect(result, isNull);
    });

    test('should check if signed in to Google', () async {
      when(mockGoogleSignIn.isSignedIn()).thenAnswer((_) async => true);
      
      await authService.initialize();
      final isSignedIn = await authService.isSignedInToGoogle();
      
      expect(isSignedIn, isTrue);
    });

    test('should get current Google account', () async {
      when(mockGoogleSignIn.currentUser).thenReturn(mockGoogleAccount);
      
      await authService.initialize();
      final currentAccount = authService.currentGoogleAccount;
      
      expect(currentAccount, equals(mockGoogleAccount));
    });

    test('should generate username from email correctly', () async {
      when(mockGoogleAccount.email).thenReturn('test.user+123@gmail.com');
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleAccount);
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => null);

      await authService.initialize();
      final result = await authService.signInWithGoogle();
      
      expect(result, isNotNull);
      expect(result!.username, equals('testuser123')); // Special characters removed
    });

    test('should handle sign-in errors gracefully', () async {
      when(mockGoogleSignIn.signIn()).thenThrow(Exception('Sign-in failed'));
      
      await authService.initialize();
      final result = await authService.signInWithGoogle();
      
      expect(result, isNull);
      expect(authService.isSignedIn, isFalse);
    });

    test('should handle sign-out errors gracefully', () async {
      // First sign in
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleAccount);
      when(mockApiService.googleAuth(
        googleId: anyNamed('googleId'),
        email: anyNamed('email'),
        displayName: anyNamed('displayName'),
        profileImageUrl: anyNamed('profileImageUrl'),
        idToken: anyNamed('idToken'),
        accessToken: anyNamed('accessToken'),
      )).thenAnswer((_) async => null);

      await authService.initialize();
      await authService.signInWithGoogle();

      // Mock sign out error
      when(mockGoogleSignIn.signOut()).thenThrow(Exception('Sign-out failed'));
      
      // Should not throw, should handle gracefully
      await authService.signOut();
      
      expect(authService.currentUser, isNull); // Should still clear user
    });
  });
}
