import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/quiz_session.dart';
import '../models/question.dart';
import '../models/category.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api'; // Change for production
  static const String apiVersion = 'v1';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  String? _authToken;
  
  // Headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };
  
  // Initialize service with stored auth token
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }
  
  // =====================================================
  // AUTHENTICATION METHODS
  // =====================================================
  
  Future<Map<String, dynamic>?> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
    String? deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'display_name': displayName,
          'device_id': deviceId,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        await _storeAuthToken(_authToken!);
        return data;
      }
      return null;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_id': deviceId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        await _storeAuthToken(_authToken!);
        return data;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> googleAuth({
    required String googleId,
    required String email,
    required String displayName,
    String? profileImageUrl,
    String? idToken,
    String? accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/auth/google'),
        headers: _headers,
        body: jsonEncode({
          'google_id': googleId,
          'email': email,
          'display_name': displayName,
          'profile_image_url': profileImageUrl,
          'id_token': idToken,
          'access_token': accessToken,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        await _storeAuthToken(_authToken!);
        return data;
      }
      return null;
    } catch (e) {
      print('Google auth error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/$apiVersion/auth/logout'),
        headers: _headers,
      );
    } finally {
      _authToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    }
  }
  
  // =====================================================
  // USER METHODS
  // =====================================================
  
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/user/profile'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get user profile error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> getUserProgress() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/user/progress'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get user progress error: $e');
      return null;
    }
  }
  
  // =====================================================
  // CONTENT METHODS
  // =====================================================
  
  Future<List<Map<String, dynamic>>?> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/content/categories'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['categories']);
      }
      return null;
    } catch (e) {
      print('Get categories error: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>?> getLevels(String categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/content/categories/$categoryId/levels'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['levels']);
      }
      return null;
    } catch (e) {
      print('Get levels error: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>?> getQuestions(String levelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/content/levels/$levelId/questions'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['questions']);
      }
      return null;
    } catch (e) {
      print('Get questions error: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>?> getGames(String levelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/content/levels/$levelId/games'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['games']);
      }
      return null;
    } catch (e) {
      print('Get games error: $e');
      return null;
    }
  }
  
  // =====================================================
  // PROGRESS METHODS
  // =====================================================
  
  Future<bool> submitQuizSession(Map<String, dynamic> sessionData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/progress/quiz-session'),
        headers: _headers,
        body: jsonEncode(sessionData),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Submit quiz session error: $e');
      return false;
    }
  }
  
  Future<bool> submitGameScore(Map<String, dynamic> scoreData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/progress/game-score'),
        headers: _headers,
        body: jsonEncode(scoreData),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Submit game score error: $e');
      return false;
    }
  }
  
  Future<bool> updateStreak(Map<String, dynamic> streakData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/progress/streak'),
        headers: _headers,
        body: jsonEncode(streakData),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Update streak error: $e');
      return false;
    }
  }
  
  // =====================================================
  // ACHIEVEMENTS METHODS
  // =====================================================
  
  Future<List<Map<String, dynamic>>?> getAchievements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/achievements'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['achievements']);
      }
      return null;
    } catch (e) {
      print('Get achievements error: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>?> getUserAchievements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/user/achievements'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['user_achievements']);
      }
      return null;
    } catch (e) {
      print('Get user achievements error: $e');
      return null;
    }
  }
  
  // =====================================================
  // LEADERBOARD METHODS
  // =====================================================
  
  Future<List<Map<String, dynamic>>?> getLeaderboard({
    required String type,
    String? period,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        'type': type,
        'limit': limit.toString(),
        if (period != null) 'period': period,
      };
      
      final uri = Uri.parse('$baseUrl/$apiVersion/leaderboard')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaderboard']);
      }
      return null;
    } catch (e) {
      print('Get leaderboard error: $e');
      return null;
    }
  }
  
  // =====================================================
  // SYNC METHODS
  // =====================================================
  
  Future<bool> syncOfflineData(List<Map<String, dynamic>> syncData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/sync/offline-data'),
        headers: _headers,
        body: jsonEncode({'sync_data': syncData}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Sync offline data error: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>?> getContentVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/content/version'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get content version error: $e');
      return null;
    }
  }
  
  // =====================================================
  // UTILITY METHODS
  // =====================================================
  
  Future<void> _storeAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  bool get isAuthenticated => _authToken != null;
  
  // Check if device is online
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  
  // Generic GET request with error handling
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/$endpoint'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('GET $endpoint error: $e');
      return null;
    }
  }
  
  // Generic POST request with error handling
  Future<Map<String, dynamic>?> _post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('POST $endpoint error: $e');
      return null;
    }
  }
}
