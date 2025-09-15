import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/services/api_service.dart';
import 'dart:convert';

// Generate mocks
@GenerateMocks([http.Client])
import 'api_service_test.mocks.dart';

void main() {
  group('ApiService Tests', () {
    late ApiService apiService;
    late MockClient mockClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockClient();
      apiService = ApiService();
      await apiService.initialize();
    });

    group('Authentication Methods', () {
      test('should register user successfully', () async {
        final responseBody = {
          'token': 'auth-token-123',
          'user': {
            'id': 'user-123',
            'email': 'test@example.com',
            'username': 'testuser',
            'display_name': 'Test User',
            'created_at': '2023-01-01T00:00:00.000Z',
            'auth_provider': 'email',
          }
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(responseBody),
          201,
        ));

        final result = await apiService.register(
          email: 'test@example.com',
          username: 'testuser',
          password: 'password123',
          displayName: 'Test User',
        );

        expect(result, isNotNull);
        expect(result!['token'], equals('auth-token-123'));
        expect(result['user']['email'], equals('test@example.com'));
        expect(apiService.isAuthenticated, isTrue);
      });

      test('should handle registration failure', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Bad Request', 400));

        final result = await apiService.register(
          email: 'test@example.com',
          username: 'testuser',
          password: 'password123',
          displayName: 'Test User',
        );

        expect(result, isNull);
        expect(apiService.isAuthenticated, isFalse);
      });

      test('should login user successfully', () async {
        final responseBody = {
          'token': 'auth-token-123',
          'user': {
            'id': 'user-123',
            'email': 'test@example.com',
            'username': 'testuser',
            'display_name': 'Test User',
            'last_login': '2023-01-01T12:00:00.000Z',
            'auth_provider': 'email',
          }
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(responseBody),
          200,
        ));

        final result = await apiService.login(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, isNotNull);
        expect(result!['token'], equals('auth-token-123'));
        expect(result['user']['email'], equals('test@example.com'));
        expect(apiService.isAuthenticated, isTrue);
      });

      test('should handle login failure', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final result = await apiService.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        expect(result, isNull);
        expect(apiService.isAuthenticated, isFalse);
      });

      test('should authenticate with Google successfully', () async {
        final responseBody = {
          'token': 'google-auth-token-123',
          'user': {
            'id': 'user-123',
            'email': 'test@gmail.com',
            'username': 'testuser',
            'display_name': 'Test User',
            'profile_image_url': 'https://example.com/photo.jpg',
            'created_at': '2023-01-01T00:00:00.000Z',
            'google_id': 'google-id-123',
            'auth_provider': 'google',
          }
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(responseBody),
          200,
        ));

        final result = await apiService.googleAuth(
          googleId: 'google-id-123',
          email: 'test@gmail.com',
          displayName: 'Test User',
          profileImageUrl: 'https://example.com/photo.jpg',
          idToken: 'id-token',
          accessToken: 'access-token',
        );

        expect(result, isNotNull);
        expect(result!['token'], equals('google-auth-token-123'));
        expect(result['user']['google_id'], equals('google-id-123'));
        expect(result['user']['auth_provider'], equals('google'));
        expect(apiService.isAuthenticated, isTrue);
      });

      test('should handle Google auth failure', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final result = await apiService.googleAuth(
          googleId: 'google-id-123',
          email: 'test@gmail.com',
          displayName: 'Test User',
        );

        expect(result, isNull);
        expect(apiService.isAuthenticated, isFalse);
      });

      test('should logout successfully', () async {
        // First login
        final loginResponse = {
          'token': 'auth-token-123',
          'user': {'id': 'user-123', 'email': 'test@example.com'}
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(loginResponse),
          200,
        ));

        await apiService.login(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(apiService.isAuthenticated, isTrue);

        // Mock logout
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('OK', 200));

        await apiService.logout();

        expect(apiService.isAuthenticated, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(Exception('Network error'));

        final result = await apiService.login(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, isNull);
        expect(apiService.isAuthenticated, isFalse);
      });

      test('should handle invalid JSON responses', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Invalid JSON', 200));

        final result = await apiService.login(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, isNull);
      });
    });

    group('Headers and Authentication', () {
      test('should include auth token in headers when authenticated', () async {
        // First login to get token
        final loginResponse = {
          'token': 'auth-token-123',
          'user': {'id': 'user-123', 'email': 'test@example.com'}
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(loginResponse),
          200,
        ));

        await apiService.login(
          email: 'test@example.com',
          password: 'password123',
        );

        // Mock a subsequent request
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('{"profile": "data"}', 200));

        await apiService.getUserProfile();

        // Verify that Authorization header was included
        verify(mockClient.get(
          any,
          headers: argThat(
            contains('Authorization'),
            named: 'headers',
          ),
        )).called(1);
      });

      test('should not include auth token when not authenticated', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Unauthorized', 401));

        await apiService.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        expect(apiService.isAuthenticated, isFalse);
      });
    });

    group('Request Validation', () {
      test('should send correct data in registration request', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('{"token": "test"}', 201));

        await apiService.register(
          email: 'test@example.com',
          username: 'testuser',
          password: 'password123',
          displayName: 'Test User',
          deviceId: 'device-123',
        );

        verify(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: argThat(
            contains('"email":"test@example.com"'),
            named: 'body',
          ),
        )).called(1);

        verify(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: argThat(
            contains('"device_id":"device-123"'),
            named: 'body',
          ),
        )).called(1);
      });

      test('should send correct data in Google auth request', () async {
        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('{"token": "test"}', 200));

        await apiService.googleAuth(
          googleId: 'google-123',
          email: 'test@gmail.com',
          displayName: 'Test User',
          profileImageUrl: 'https://example.com/photo.jpg',
          idToken: 'id-token',
          accessToken: 'access-token',
        );

        verify(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: argThat(
            allOf([
              contains('"google_id":"google-123"'),
              contains('"email":"test@gmail.com"'),
              contains('"id_token":"id-token"'),
              contains('"access_token":"access-token"'),
            ]),
            named: 'body',
          ),
        )).called(1);
      });
    });
  });
}
