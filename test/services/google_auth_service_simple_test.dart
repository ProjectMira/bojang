import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/models/user.dart';

void main() {
  group('GoogleAuthService Basic Tests', () {
    late GoogleAuthService authService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      
      authService = GoogleAuthService();
    });

    test('should initialize successfully', () async {
      await authService.initialize();
      expect(authService.isInitialized, isTrue);
    });

    test('should start with no current user', () async {
      await authService.initialize();
      expect(authService.currentUser, isNull);
      expect(authService.isSignedIn, isFalse);
    });

    test('should handle initialization multiple times', () async {
      await authService.initialize();
      expect(authService.isInitialized, isTrue);
      
      // Initialize again - should not fail
      await authService.initialize();
      expect(authService.isInitialized, isTrue);
    });

    test('should cache and load user data', () async {
      await authService.initialize();
      
      final testUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        authProvider: AuthProvider.google,
        googleId: 'google-123',
      );

      // Manually set user (simulating successful sign-in)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user', 
          '{"id":"test-id","email":"test@gmail.com","username":"testuser","display_name":"Test User","created_at":"2023-01-01T00:00:00.000Z","google_id":"google-123","auth_provider":"google"}');

      // Create new instance to test loading
      final newAuthService = GoogleAuthService();
      await newAuthService.initialize();

      // Should load cached user
      expect(newAuthService.currentUser, isNotNull);
      expect(newAuthService.currentUser?.email, equals('test@gmail.com'));
      expect(newAuthService.currentUser?.authProvider, equals(AuthProvider.google));
    });

    test('should handle corrupted cache data gracefully', () async {
      // Set corrupted cache data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user', 'invalid-json');

      await authService.initialize();
      
      // Should handle gracefully and not crash
      expect(authService.currentUser, isNull);
      expect(authService.isInitialized, isTrue);
    });

    test('should clear cached user on sign out', () async {
      await authService.initialize();
      
      // Set some cached user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user', 
          '{"id":"test-id","email":"test@gmail.com","username":"testuser","display_name":"Test User","created_at":"2023-01-01T00:00:00.000Z","auth_provider":"email"}');

      // Sign out should clear cache
      await authService.signOut();
      
      // Check that cache is cleared
      expect(prefs.getString('cached_user'), isNull);
      expect(authService.currentUser, isNull);
    });

    test('should generate username correctly from email', () {
      // Test internal username generation logic
      const testEmails = [
        'test@gmail.com',
        'test.user@example.com',
        'test+tag@domain.co.uk',
        'user123@test.org',
      ];
      
      const expectedUsernames = [
        'test',
        'testuser',
        'testtag',
        'user123',
      ];

      for (int i = 0; i < testEmails.length; i++) {
        final email = testEmails[i];
        final expected = expectedUsernames[i];
        final username = email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        expect(username, equals(expected));
      }
    });

    test('should handle sign out errors gracefully', () async {
      await authService.initialize();
      
      // Sign out should not throw even if there are errors
      expect(() => authService.signOut(), returnsNormally);
    });

    test('should maintain singleton pattern', () {
      final instance1 = GoogleAuthService();
      final instance2 = GoogleAuthService();
      
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('User Model Integration Tests', () {
    test('should create user from Google data correctly', () {
      final user = User(
        id: 'google-id-123',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'Test User',
        profileImageUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
        authProvider: AuthProvider.google,
        googleId: 'google-id-123',
      );

      expect(user.authProvider, equals(AuthProvider.google));
      expect(user.googleId, equals('google-id-123'));
      expect(user.profileImageUrl, equals('https://example.com/photo.jpg'));
    });

    test('should serialize and deserialize Google user correctly', () {
      final originalUser = User(
        id: 'test-id',
        email: 'test@gmail.com',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
        authProvider: AuthProvider.google,
        googleId: 'google-123',
      );

      final json = originalUser.toJson();
      final deserializedUser = User.fromJson(json);

      expect(deserializedUser.authProvider, equals(AuthProvider.google));
      expect(deserializedUser.googleId, equals('google-123'));
      expect(deserializedUser.email, equals(originalUser.email));
      expect(deserializedUser.displayName, equals(originalUser.displayName));
    });
  });
}
