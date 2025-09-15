import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/models/user.dart';

void main() {
  group('User Model Tests', () {
    late User testUser;
    late Map<String, dynamic> testUserJson;

    setUp(() {
      testUser = User(
        id: 'test-id-123',
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'Test User',
        profileImageUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
        lastLogin: DateTime.parse('2023-01-02T00:00:00Z'),
        isActive: true,
        timezone: 'UTC',
        preferredLanguage: 'en',
        deviceId: 'device-123',
        lastSync: DateTime.parse('2023-01-02T12:00:00Z'),
        googleId: 'google-id-123',
        authProvider: AuthProvider.google,
      );

      testUserJson = {
        'id': 'test-id-123',
        'email': 'test@example.com',
        'username': 'testuser',
        'display_name': 'Test User',
        'profile_image_url': 'https://example.com/avatar.jpg',
        'created_at': '2023-01-01T00:00:00.000Z',
        'last_login': '2023-01-02T00:00:00.000Z',
        'is_active': true,
        'timezone': 'UTC',
        'preferred_language': 'en',
        'device_id': 'device-123',
        'last_sync': '2023-01-02T12:00:00.000Z',
        'google_id': 'google-id-123',
        'auth_provider': 'google',
      };
    });

    test('should create User instance with all fields', () {
      expect(testUser.id, equals('test-id-123'));
      expect(testUser.email, equals('test@example.com'));
      expect(testUser.username, equals('testuser'));
      expect(testUser.displayName, equals('Test User'));
      expect(testUser.profileImageUrl, equals('https://example.com/avatar.jpg'));
      expect(testUser.isActive, isTrue);
      expect(testUser.timezone, equals('UTC'));
      expect(testUser.preferredLanguage, equals('en'));
      expect(testUser.deviceId, equals('device-123'));
      expect(testUser.googleId, equals('google-id-123'));
      expect(testUser.authProvider, equals(AuthProvider.google));
    });

    test('should create User with default values', () {
      final defaultUser = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      expect(defaultUser.isActive, isTrue);
      expect(defaultUser.timezone, equals('UTC'));
      expect(defaultUser.preferredLanguage, equals('en'));
      expect(defaultUser.authProvider, equals(AuthProvider.email));
      expect(defaultUser.profileImageUrl, isNull);
      expect(defaultUser.googleId, isNull);
    });

    test('should serialize to JSON correctly', () {
      final json = testUser.toJson();
      
      expect(json['id'], equals('test-id-123'));
      expect(json['email'], equals('test@example.com'));
      expect(json['username'], equals('testuser'));
      expect(json['display_name'], equals('Test User'));
      expect(json['profile_image_url'], equals('https://example.com/avatar.jpg'));
      expect(json['is_active'], isTrue);
      expect(json['timezone'], equals('UTC'));
      expect(json['preferred_language'], equals('en'));
      expect(json['device_id'], equals('device-123'));
      expect(json['google_id'], equals('google-id-123'));
      expect(json['auth_provider'], equals('google'));
    });

    test('should deserialize from JSON correctly', () {
      final user = User.fromJson(testUserJson);
      
      expect(user.id, equals('test-id-123'));
      expect(user.email, equals('test@example.com'));
      expect(user.username, equals('testuser'));
      expect(user.displayName, equals('Test User'));
      expect(user.profileImageUrl, equals('https://example.com/avatar.jpg'));
      expect(user.isActive, isTrue);
      expect(user.timezone, equals('UTC'));
      expect(user.preferredLanguage, equals('en'));
      expect(user.deviceId, equals('device-123'));
      expect(user.googleId, equals('google-id-123'));
      expect(user.authProvider, equals(AuthProvider.google));
    });

    test('should handle null values in JSON correctly', () {
      final jsonWithNulls = {
        'id': 'test-id',
        'email': 'test@example.com',
        'username': 'testuser',
        'display_name': 'Test User',
        'created_at': '2023-01-01T00:00:00.000Z',
        'profile_image_url': null,
        'last_login': null,
        'device_id': null,
        'last_sync': null,
        'google_id': null,
      };

      final user = User.fromJson(jsonWithNulls);
      
      expect(user.profileImageUrl, isNull);
      expect(user.lastLogin, isNull);
      expect(user.deviceId, isNull);
      expect(user.lastSync, isNull);
      expect(user.googleId, isNull);
      expect(user.authProvider, equals(AuthProvider.email)); // default
    });

    test('should create copy with updated fields', () {
      final updatedUser = testUser.copyWith(
        displayName: 'Updated Name',
        profileImageUrl: 'https://example.com/new-avatar.jpg',
        authProvider: AuthProvider.email,
      );

      expect(updatedUser.id, equals(testUser.id)); // unchanged
      expect(updatedUser.email, equals(testUser.email)); // unchanged
      expect(updatedUser.displayName, equals('Updated Name')); // changed
      expect(updatedUser.profileImageUrl, equals('https://example.com/new-avatar.jpg')); // changed
      expect(updatedUser.authProvider, equals(AuthProvider.email)); // changed
    });

    test('should handle AuthProvider enum correctly', () {
      expect(AuthProvider.values.length, equals(2));
      expect(AuthProvider.values.contains(AuthProvider.email), isTrue);
      expect(AuthProvider.values.contains(AuthProvider.google), isTrue);
    });

    test('should serialize and deserialize AuthProvider correctly', () {
      final emailUser = testUser.copyWith(authProvider: AuthProvider.email);
      final googleUser = testUser.copyWith(authProvider: AuthProvider.google);

      final emailJson = emailUser.toJson();
      final googleJson = googleUser.toJson();

      expect(emailJson['auth_provider'], equals('email'));
      expect(googleJson['auth_provider'], equals('google'));

      final deserializedEmailUser = User.fromJson(emailJson);
      final deserializedGoogleUser = User.fromJson(googleJson);

      expect(deserializedEmailUser.authProvider, equals(AuthProvider.email));
      expect(deserializedGoogleUser.authProvider, equals(AuthProvider.google));
    });
  });
}
