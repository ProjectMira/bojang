import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'BOJANG_API_BASE_URL',
    defaultValue: 'https://bojang-backend-lbziapssxq-uc.a.run.app',
  );

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
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
    // The production API uses Firebase authentication plus /auth/sync.
    // Email/password registration is intentionally not exposed by the backend.
    return null;
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    // The production API uses Firebase authentication plus /auth/sync.
    // Email/password login is intentionally not exposed by the backend.
    return null;
  }

  Future<Map<String, dynamic>?> googleAuth({
    required String googleId,
    required String email,
    required String displayName,
    String? profileImageUrl,
    String? idToken,
    String? accessToken,
  }) async {
    return _providerAuth(
      providerUserId: googleId,
      email: email,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      token: idToken ?? accessToken,
      authProvider: 'google',
    );
  }

  Future<Map<String, dynamic>?> appleAuth({
    required String uid,
    required String email,
    required String displayName,
    String? profileImageUrl,
    String? idToken,
  }) async {
    return _providerAuth(
      providerUserId: uid,
      email: email,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      token: idToken,
      authProvider: 'apple',
    );
  }

  Future<Map<String, dynamic>?> _providerAuth({
    required String providerUserId,
    required String email,
    required String displayName,
    String? profileImageUrl,
    String? token,
    required String authProvider,
  }) async {
    if (token == null || token.isEmpty) return null;

    try {
      _authToken = token;
      await _storeAuthToken(token);

      final profile = await syncUser(
        email: email,
        nativeLang: 'en',
        targetLang: 'bo',
      );
      if (profile == null) return null;

      final uid = (profile['uid'] ?? providerUserId).toString();
      final user = {
        'id': uid,
        'uid': uid,
        'email': email,
        'username': email.split('@').first,
        'display_name': profile['display_name'] ?? displayName,
        'profile_image_url': profileImageUrl,
        'created_at': DateTime.now().toIso8601String(),
        if (authProvider == 'google') 'google_id': providerUserId,
        'auth_provider': authProvider,
        'xp': profile['xp'] ?? 0,
        'streak': profile['streak'] ?? 0,
        'league': profile['league'] ?? 'Bronze',
      };
      return {'token': token, 'user': user, 'profile': profile};
    } catch (e) {
      print('$authProvider auth sync error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // =====================================================
  // USER METHODS
  // =====================================================

  Future<Map<String, dynamic>?> getUserProfile() async {
    return _get('auth/me');
  }

  Future<Map<String, dynamic>?> getUserProgress() async {
    return _get('progress/stats');
  }

  Future<Map<String, dynamic>?> syncUser({
    required String email,
    String nativeLang = 'en',
    String targetLang = 'bo',
  }) async {
    return _post('auth/sync', {
      'email': email,
      'native_lang': nativeLang,
      'target_lang': targetLang,
    });
  }

  Future<Map<String, dynamic>?> updateUserProfile({
    String? displayName,
    String? nativeLang,
    String? targetLang,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (nativeLang != null) 'native_lang': nativeLang,
      if (targetLang != null) 'target_lang': targetLang,
    };
    return _patch('auth/me', body);
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    return _get('auth/me/stats');
  }

  Future<Map<String, dynamic>?> exportUserData() async {
    return _get('auth/me/data-export');
  }

  Future<bool> deleteAccount() async {
    final response = await _delete('auth/me');
    return response != null;
  }

  // =====================================================
  // CONTENT METHODS
  // =====================================================

  Future<List<Map<String, dynamic>>?> getCategories() async {
    return getCategoriesByType();
  }

  Future<List<Map<String, dynamic>>?> getCategoriesByType({
    String? type,
  }) async {
    try {
      final data = await _get(
        'content/categories',
        queryParameters: {if (type != null) 'type': type},
      );
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(data['categories'] ?? []);
    } catch (e) {
      print('Get categories error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getLevels(String categoryId) async {
    return getLearningLevels();
  }

  Future<List<Map<String, dynamic>>?> getLearningLevels() async {
    try {
      final data = await _getList('learn/levels');
      return data;
    } catch (e) {
      print('Get levels error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getQuestions(String levelId) async {
    try {
      final session = await getLearningSession(levelId: levelId);
      if (session == null) return null;
      return List<Map<String, dynamic>>.from(session['exercises'] ?? []);
    } catch (e) {
      print('Get questions error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLearningSession({
    required String levelId,
    int numQuestions = 10,
    List<String>? exerciseTypes,
  }) async {
    return _get(
      'learn/session/$levelId',
      queryParameters: {
        'num_questions': numQuestions.toString(),
        if (exerciseTypes != null && exerciseTypes.isNotEmpty)
          'exercise_types': exerciseTypes.join(','),
      },
    );
  }

  Future<List<Map<String, dynamic>>?> getGames(String levelId) async {
    return null;
  }

  /// Fetch Tibetan-English word pairs for the memory match game.
  /// Returns a list of cards: {id, tibetan, english, phonetic}.
  Future<List<Map<String, dynamic>>?> getMemoryMatchCards({
    required String levelId,
  }) async {
    try {
      final session = await getLearningSession(
        levelId: levelId,
        numQuestions: 5,
        exerciseTypes: const ['memory_match'],
      );
      if (session == null) return null;
      final exercises = List<Map<String, dynamic>>.from(
        session['exercises'] as List<dynamic>? ?? [],
      );
      for (final exercise in exercises) {
        final type = exercise['type'] ?? exercise['exercise_type'];
        if (type != 'memory_match') continue;
        final cards = List<Map<String, dynamic>>.from(
          exercise['cards'] as List<dynamic>? ?? [],
        );
        if (cards.isNotEmpty) return cards;
      }
      return null;
    } catch (e) {
      print('Get memory match cards error: $e');
      return null;
    }
  }

  // =====================================================
  // PROGRESS METHODS
  // =====================================================

  Future<bool> submitQuizSession(Map<String, dynamic> sessionData) async {
    return submitProgressCompletion(sessionData);
  }

  Future<bool> submitProgressCompletion(Map<String, dynamic> submission) async {
    try {
      final response = await _post('progress/complete', submission);
      return response != null && response['success'] == true;
    } catch (e) {
      print('Submit progress error: $e');
      return false;
    }
  }

  Future<bool> submitGameScore(Map<String, dynamic> scoreData) async {
    try {
      return false;
    } catch (e) {
      print('Submit game score error: $e');
      return false;
    }
  }

  Future<bool> updateStreak(Map<String, dynamic> streakData) async {
    try {
      return false;
    } catch (e) {
      print('Update streak error: $e');
      return false;
    }
  }

  // =====================================================
  // ACHIEVEMENTS METHODS
  // =====================================================

  Future<List<Map<String, dynamic>>?> getAchievements() async {
    return null;
  }

  Future<List<Map<String, dynamic>>?> getUserAchievements() async {
    return null;
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
      final league =
          ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'].contains(type)
              ? type
              : null;
      final data = await _get(
        'progress/leaderboard',
        queryParameters: {if (league != null) 'league': league},
      );
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(data['entries'] ?? []);
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
      var allSynced = true;
      for (final item in syncData) {
        if (item.containsKey('session_id') && item.containsKey('level_id')) {
          allSynced = await submitProgressCompletion(item) && allSynced;
        }
      }
      return allSynced;
    } catch (e) {
      print('Sync offline data error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getContentVersion() async {
    final config = await getAppConfig();
    if (config == null) return null;
    final latest =
        (config['latest_ios_version'] ??
                config['latest_android_version'] ??
                '1.0.0')
            .toString();
    final versionNumber = latest
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .fold<int>(0, (value, part) => value * 100 + part);
    return {'version': versionNumber, 'config': config};
  }

  Future<Map<String, dynamic>?> getAppConfig() async {
    return _get('subscriptions/config');
  }

  // =====================================================
  // UTILITY METHODS
  // =====================================================

  Future<void> _storeAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  bool get isAuthenticated => _authToken != null;

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _storeAuthToken(token);
  }

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
  Future<Map<String, dynamic>?> _get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _client.get(
        _uri(endpoint, queryParameters),
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

  Future<List<Map<String, dynamic>>?> _getList(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _client.get(
        _uri(endpoint, queryParameters),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('GET $endpoint error: $e');
      return null;
    }
  }

  // Generic POST request with error handling
  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.post(
        _uri(endpoint),
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

  Future<Map<String, dynamic>?> _patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.patch(
        _uri(endpoint),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('PATCH $endpoint error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _delete(String endpoint) async {
    try {
      final response = await _client.delete(_uri(endpoint), headers: _headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('DELETE $endpoint error: $e');
      return null;
    }
  }

  Uri _uri(String endpoint, [Map<String, String>? queryParameters]) {
    final cleanBase =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$cleanBase/$cleanEndpoint').replace(
      queryParameters:
          queryParameters?.isEmpty == true ? null : queryParameters,
    );
  }
}
