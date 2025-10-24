import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();
  
  final ApiService _apiService = ApiService();
  late String _cacheDirectory;
  
  // Cache keys
  static const String _categoriesCacheKey = 'cached_categories';
  static const String _levelsCacheKey = 'cached_levels';
  static const String _questionsCacheKey = 'cached_questions';
  static const String _gamesCacheKey = 'cached_games';
  static const String _achievementsCacheKey = 'cached_achievements';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _contentVersionKey = 'content_version';
  
  // Offline data keys
  static const String _offlineSessionsKey = 'offline_quiz_sessions';
  static const String _offlineScoresKey = 'offline_game_scores';
  static const String _offlineProgressKey = 'offline_progress_updates';
  
  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    _cacheDirectory = '${directory.path}/bojang_cache';
    
    // Create cache directory if it doesn't exist
    final cacheDir = Directory(_cacheDirectory);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    // Load initial content from assets if cache is empty
    await _loadInitialContentFromAssets();
  }
  
  // =====================================================
  // CONTENT CACHING METHODS
  // =====================================================
  
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      // Try to get from API first if online
      if (await _apiService.isOnline()) {
        final apiCategories = await _apiService.getCategories();
        if (apiCategories != null) {
          await _cacheData(_categoriesCacheKey, apiCategories);
          return apiCategories;
        }
      }
      
      // Fallback to cached data
      return await _getCachedData(_categoriesCacheKey) ?? [];
    } catch (e) {
      print('Error getting categories: $e');
      return await _getCachedData(_categoriesCacheKey) ?? [];
    }
  }
  
  Future<List<Map<String, dynamic>>> getLevels(String categoryId) async {
    final cacheKey = '${_levelsCacheKey}_$categoryId';
    
    try {
      if (await _apiService.isOnline()) {
        final apiLevels = await _apiService.getLevels(categoryId);
        if (apiLevels != null) {
          await _cacheData(cacheKey, apiLevels);
          return apiLevels;
        }
      }
      
      return await _getCachedData(cacheKey) ?? [];
    } catch (e) {
      print('Error getting levels for category $categoryId: $e');
      return await _getCachedData(cacheKey) ?? [];
    }
  }
  
  Future<List<Map<String, dynamic>>> getQuestions(String levelId) async {
    final cacheKey = '${_questionsCacheKey}_$levelId';
    
    try {
      if (await _apiService.isOnline()) {
        final apiQuestions = await _apiService.getQuestions(levelId);
        if (apiQuestions != null) {
          await _cacheData(cacheKey, apiQuestions);
          return apiQuestions;
        }
      }
      
      // Fallback to cached data or load from assets
      List<Map<String, dynamic>>? cachedQuestions = await _getCachedData(cacheKey);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        return cachedQuestions;
      }
      
      // Load from JSON assets as last resort
      return await _loadQuestionsFromAssets(levelId);
    } catch (e) {
      print('Error getting questions for level $levelId: $e');
      return await _getCachedData(cacheKey) ?? await _loadQuestionsFromAssets(levelId);
    }
  }
  
  Future<List<Map<String, dynamic>>> getGames(String levelId) async {
    final cacheKey = '${_gamesCacheKey}_$levelId';
    
    try {
      if (await _apiService.isOnline()) {
        final apiGames = await _apiService.getGames(levelId);
        if (apiGames != null) {
          await _cacheData(cacheKey, apiGames);
          return apiGames;
        }
      }
      
      return await _getCachedData(cacheKey) ?? [];
    } catch (e) {
      print('Error getting games for level $levelId: $e');
      return await _getCachedData(cacheKey) ?? [];
    }
  }
  
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      if (await _apiService.isOnline()) {
        final apiAchievements = await _apiService.getAchievements();
        if (apiAchievements != null) {
          await _cacheData(_achievementsCacheKey, apiAchievements);
          return apiAchievements;
        }
      }
      
      return await _getCachedData(_achievementsCacheKey) ?? [];
    } catch (e) {
      print('Error getting achievements: $e');
      return await _getCachedData(_achievementsCacheKey) ?? [];
    }
  }
  
  // =====================================================
  // OFFLINE DATA STORAGE
  // =====================================================
  
  Future<void> storeOfflineQuizSession(Map<String, dynamic> sessionData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> sessions = prefs.getStringList(_offlineSessionsKey) ?? [];
    
    // Add timestamp and unique ID for offline tracking
    sessionData['offline_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    sessionData['created_offline'] = true;
    sessionData['device_timestamp'] = DateTime.now().toIso8601String();
    
    sessions.add(jsonEncode(sessionData));
    await prefs.setStringList(_offlineSessionsKey, sessions);
  }
  
  Future<void> storeOfflineGameScore(Map<String, dynamic> scoreData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> scores = prefs.getStringList(_offlineScoresKey) ?? [];
    
    scoreData['offline_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    scoreData['created_offline'] = true;
    scoreData['device_timestamp'] = DateTime.now().toIso8601String();
    
    scores.add(jsonEncode(scoreData));
    await prefs.setStringList(_offlineScoresKey, scores);
  }
  
  Future<void> storeOfflineProgressUpdate(Map<String, dynamic> progressData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> updates = prefs.getStringList(_offlineProgressKey) ?? [];
    
    progressData['offline_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    progressData['created_offline'] = true;
    progressData['device_timestamp'] = DateTime.now().toIso8601String();
    
    updates.add(jsonEncode(progressData));
    await prefs.setStringList(_offlineProgressKey, updates);
  }
  
  // =====================================================
  // SYNC METHODS
  // =====================================================
  
  Future<bool> syncOfflineData() async {
    if (!await _apiService.isOnline() || !_apiService.isAuthenticated) {
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> allOfflineData = [];
      
      // Collect all offline data
      final sessions = prefs.getStringList(_offlineSessionsKey) ?? [];
      final scores = prefs.getStringList(_offlineScoresKey) ?? [];
      final progressUpdates = prefs.getStringList(_offlineProgressKey) ?? [];
      
      // Parse and add to sync data
      for (String sessionJson in sessions) {
        final sessionData = jsonDecode(sessionJson);
        sessionData['sync_type'] = 'quiz_session';
        allOfflineData.add(sessionData);
      }
      
      for (String scoreJson in scores) {
        final scoreData = jsonDecode(scoreJson);
        scoreData['sync_type'] = 'game_score';
        allOfflineData.add(scoreData);
      }
      
      for (String progressJson in progressUpdates) {
        final progressData = jsonDecode(progressJson);
        progressData['sync_type'] = 'progress_update';
        allOfflineData.add(progressData);
      }
      
      if (allOfflineData.isEmpty) {
        return true; // Nothing to sync
      }
      
      // Sync with API
      final success = await _apiService.syncOfflineData(allOfflineData);
      
      if (success) {
        // Clear offline data after successful sync
        await prefs.remove(_offlineSessionsKey);
        await prefs.remove(_offlineScoresKey);
        await prefs.remove(_offlineProgressKey);
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
        print('Successfully synced ${allOfflineData.length} offline records');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error syncing offline data: $e');
      return false;
    }
  }
  
  Future<void> checkForContentUpdates() async {
    if (!await _apiService.isOnline()) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_contentVersionKey) ?? 0;
      
      final versionData = await _apiService.getContentVersion();
      if (versionData != null) {
        final serverVersion = versionData['version'] as int;
        
        if (serverVersion > currentVersion) {
          print('New content version available: $serverVersion (current: $currentVersion)');
          await _downloadContentUpdates();
          await prefs.setInt(_contentVersionKey, serverVersion);
        }
      }
    } catch (e) {
      print('Error checking for content updates: $e');
    }
  }
  
  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================
  
  Future<void> _cacheData(String key, List<Map<String, dynamic>> data) async {
    try {
      final file = File('$_cacheDirectory/$key.json');
      await file.writeAsString(jsonEncode(data));
      
      // Also store in SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      print('Error caching data for key $key: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>?> _getCachedData(String key) async {
    try {
      // Try SharedPreferences first (faster)
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);
      
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        return decoded.cast<Map<String, dynamic>>();
      }
      
      // Try file cache as backup
      final file = File('$_cacheDirectory/$key.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        return decoded.cast<Map<String, dynamic>>();
      }
      
      return null;
    } catch (e) {
      print('Error getting cached data for key $key: $e');
      return null;
    }
  }
  
  Future<void> _loadInitialContentFromAssets() async {
    try {
      // Check if we already have cached content
      final categories = await _getCachedData(_categoriesCacheKey);
      if (categories != null && categories.isNotEmpty) {
        return; // Already have content
      }
      
      // Load levels.json to get category structure
      final levelsString = await rootBundle.loadString('assets/quiz_data/levels.json');
      final levelsData = jsonDecode(levelsString);
      
      // Create categories from levels data
      List<Map<String, dynamic>> initialCategories = [];
      for (var category in levelsData['categories']) {
        initialCategories.add({
          'id': category['name'].toLowerCase().replaceAll(' ', '_'),
          'name': category['name'],
          'tibetan_name': category['tibetan_name'] ?? '',
          'description': category['description'] ?? '',
          'sort_order': initialCategories.length + 1,
          'is_active': true,
        });
      }
      
      await _cacheData(_categoriesCacheKey, initialCategories);
      print('Loaded ${initialCategories.length} categories from assets');
      
    } catch (e) {
      print('Error loading initial content from assets: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> _loadQuestionsFromAssets(String levelId) async {
    try {
      // Map levelId to asset path (this is a simplified mapping)
      // In a real app, you'd have a more sophisticated mapping system
      String assetPath = 'assets/quiz_data/level-1/greetings.json'; // Default
      
      // Try to determine the correct asset path based on levelId
      // This is a temporary solution - in production, this mapping should come from the API
      if (levelId.contains('greeting')) {
        assetPath = 'assets/quiz_data/level-1/greetings.json';
      } else if (levelId.contains('number')) {
        assetPath = 'assets/quiz_data/level-1/numbers.json';
      } else if (levelId.contains('color')) {
        assetPath = 'assets/quiz_data/level-1/colors.json';
      }
      
      final questionsString = await rootBundle.loadString(assetPath);
      final questionsData = jsonDecode(questionsString);
      
      // Convert to API format
      List<Map<String, dynamic>> questions = [];
      for (var question in questionsData['questions']) {
        questions.add({
          'id': question['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'question_type': 'multiple_choice',
          'question_text': question['question'],
          'correct_answer': question['correct'],
          'options': question['options'],
          'explanation': question['explanation'] ?? '',
        });
      }
      
      return questions;
    } catch (e) {
      print('Error loading questions from assets for level $levelId: $e');
      return [];
    }
  }
  
  Future<void> _downloadContentUpdates() async {
    // This would download incremental content updates from the server
    // For now, we'll just refresh all cached content
    try {
      await clearCache();
      
      // Re-fetch all content
      await getCategories();
      await getAchievements();
      
      print('Content updates downloaded successfully');
    } catch (e) {
      print('Error downloading content updates: $e');
    }
  }
  
  // =====================================================
  // UTILITY METHODS
  // =====================================================
  
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove all cache keys
      await prefs.remove(_categoriesCacheKey);
      await prefs.remove(_levelsCacheKey);
      await prefs.remove(_questionsCacheKey);
      await prefs.remove(_gamesCacheKey);
      await prefs.remove(_achievementsCacheKey);
      
      // Clear cache directory
      final cacheDir = Directory(_cacheDirectory);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      
      print('Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  Future<int> getOfflineDataCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getStringList(_offlineSessionsKey) ?? [];
      final scores = prefs.getStringList(_offlineScoresKey) ?? [];
      final progressUpdates = prefs.getStringList(_offlineProgressKey) ?? [];
      
      return sessions.length + scores.length + progressUpdates.length;
    } catch (e) {
      print('Error getting offline data count: $e');
      return 0;
    }
  }
  
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      if (lastSyncString != null) {
        return DateTime.parse(lastSyncString);
      }
      return null;
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }
  
  Future<bool> hasOfflineData() async {
    final count = await getOfflineDataCount();
    return count > 0;
  }
}
