import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/achievement_dialog.dart';

class ProgressService extends ChangeNotifier {
  // Streak tracking
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastPlayDate;
  List<DateTime> _playDates = [];

  // Progress tracking
  Map<String, double> _categoryProgress = {};
  Map<String, int> _categoryScores = {};
  List<String> _unlockedAchievements = [];

  // User stats
  int _totalQuizzesTaken = 0;
  int _totalCorrectAnswers = 0;
  int _currentLevel = 1;
  double _accuracy = 0.0;
  int _xp = 0;
  String _league = 'Bronze';
  int? _rank;
  int _completedLevelsCount = 0;

  // Getters
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  DateTime? get lastPlayDate => _lastPlayDate;
  List<DateTime> get playDates => _playDates;
  Map<String, double> get categoryProgress => _categoryProgress;
  Map<String, int> get categoryScores => _categoryScores;
  List<String> get unlockedAchievements => _unlockedAchievements;
  int get totalQuizzesTaken => _totalQuizzesTaken;
  int get totalCorrectAnswers => _totalCorrectAnswers;
  int get currentLevel => _currentLevel;
  double get accuracy => _accuracy;
  int get xp => _xp;
  String get league => _league;
  int? get rank => _rank;
  int get completedLevelsCount => _completedLevelsCount;

  ProgressService() {
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load streak data
    _currentStreak = prefs.getInt('current_streak') ?? 0;
    _longestStreak = prefs.getInt('longest_streak') ?? 0;
    final lastPlayString = prefs.getString('last_play_date');
    if (lastPlayString != null) {
      _lastPlayDate = DateTime.parse(lastPlayString);
    }

    // Load play dates
    final playDateStrings = prefs.getStringList('play_dates') ?? [];
    _playDates = playDateStrings.map((date) => DateTime.parse(date)).toList();

    // Load progress data
    final categoryProgressString = prefs.getString('category_progress') ?? '{}';
    _categoryProgress = Map<String, double>.from(
      json.decode(categoryProgressString),
    );

    final categoryScoresString = prefs.getString('category_scores') ?? '{}';
    _categoryScores = Map<String, int>.from(json.decode(categoryScoresString));

    _unlockedAchievements = prefs.getStringList('unlocked_achievements') ?? [];

    // Load user stats
    _totalQuizzesTaken = prefs.getInt('total_quizzes') ?? 0;
    _totalCorrectAnswers = prefs.getInt('total_correct') ?? 0;
    _currentLevel = prefs.getInt('current_level') ?? 1;
    _xp = prefs.getInt('xp') ?? 0;
    _league = prefs.getString('league') ?? 'Bronze';
    _rank = prefs.getInt('rank');
    _completedLevelsCount = prefs.getInt('completed_levels_count') ?? 0;

    if (_totalQuizzesTaken > 0) {
      _accuracy = (_totalCorrectAnswers / _totalQuizzesTaken) * 100;
    }

    notifyListeners();
  }

  Future<void> updateFromServer(Map<String, dynamic> data) async {
    final stats =
        data['xp'] is Map<String, dynamic> ||
                data['streak'] is Map<String, dynamic> ||
                data['league'] is Map<String, dynamic>
            ? data
            : null;

    if (stats != null) {
      final xpInfo = stats['xp'] as Map<String, dynamic>?;
      final streakInfo = stats['streak'] as Map<String, dynamic>?;
      final leagueInfo = stats['league'] as Map<String, dynamic>?;
      final levelsInfo = stats['levels'] as Map<String, dynamic>?;
      _xp = xpInfo?['total'] as int? ?? _xp;
      _currentStreak = streakInfo?['current'] as int? ?? _currentStreak;
      _league = (leagueInfo?['current'] ?? _league).toString();
      _completedLevelsCount =
          levelsInfo?['count'] as int? ?? _completedLevelsCount;
    } else {
      _xp = data['xp'] as int? ?? _xp;
      _currentStreak = data['streak'] as int? ?? _currentStreak;
      _league = (data['league'] ?? _league).toString();
      _rank = data['rank'] as int?;
      _completedLevelsCount =
          data['completed_levels_count'] as int? ?? _completedLevelsCount;
    }

    _currentLevel = _levelFromXp(_xp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', _xp);
    await prefs.setInt('current_streak', _currentStreak);
    await prefs.setString('league', _league);
    if (_rank != null) await prefs.setInt('rank', _rank!);
    await prefs.setInt('completed_levels_count', _completedLevelsCount);
    await prefs.setInt('current_level', _currentLevel);
    notifyListeners();
  }

  Future<void> updateQuizResults(
    String category,
    int score,
    int totalQuestions, {
    BuildContext? context,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Update totals
    _totalQuizzesTaken += totalQuestions;
    _totalCorrectAnswers += score;
    _accuracy = (_totalCorrectAnswers / _totalQuizzesTaken) * 100;
    _xp += score * 10;
    _currentLevel = _levelFromXp(_xp);

    // Update category progress
    final categoryKey = category.toLowerCase().replaceAll(' ', '_');
    _categoryScores[categoryKey] = (_categoryScores[categoryKey] ?? 0) + score;
    _categoryProgress[categoryKey] = (score / totalQuestions).clamp(0.0, 1.0);

    // Update streak
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    if (_lastPlayDate == null || !_isSameDay(_lastPlayDate!, today)) {
      if (_lastPlayDate != null && _isConsecutiveDay(_lastPlayDate!, today)) {
        _currentStreak++;
      } else if (_lastPlayDate == null || !_isSameDay(_lastPlayDate!, today)) {
        _currentStreak = 1;
      }

      _lastPlayDate = today;
      _playDates.add(todayKey);

      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }
    }

    // Check for new achievements and show them
    final newAchievements = _checkAchievements();

    // Save all data
    await _saveProgressData(prefs);
    notifyListeners();

    // Show achievement dialogs if context is provided
    if (context != null && newAchievements.isNotEmpty) {
      for (final achievementId in newAchievements) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showAchievementDialog(context, achievementId);
        });
      }
    }
  }

  List<String> _checkAchievements() {
    List<String> newAchievements = [];

    // First quiz achievement
    if (_totalQuizzesTaken >= 1 &&
        !_unlockedAchievements.contains('first_quiz')) {
      _unlockedAchievements.add('first_quiz');
      newAchievements.add('first_quiz');
    }

    // Streak achievements
    if (_currentStreak >= 3 && !_unlockedAchievements.contains('streak_3')) {
      _unlockedAchievements.add('streak_3');
      newAchievements.add('streak_3');
    }
    if (_currentStreak >= 7 && !_unlockedAchievements.contains('streak_7')) {
      _unlockedAchievements.add('streak_7');
      newAchievements.add('streak_7');
    }
    if (_currentStreak >= 30 && !_unlockedAchievements.contains('streak_30')) {
      _unlockedAchievements.add('streak_30');
      newAchievements.add('streak_30');
    }

    // Accuracy achievements
    if (_accuracy >= 80 &&
        _totalQuizzesTaken >= 10 &&
        !_unlockedAchievements.contains('accuracy_80')) {
      _unlockedAchievements.add('accuracy_80');
      newAchievements.add('accuracy_80');
    }

    // Quiz count achievements
    if (_totalQuizzesTaken >= 50 &&
        !_unlockedAchievements.contains('quiz_50')) {
      _unlockedAchievements.add('quiz_50');
      newAchievements.add('quiz_50');
    }

    return newAchievements;
  }

  Future<void> _saveProgressData(SharedPreferences prefs) async {
    await prefs.setInt('current_streak', _currentStreak);
    await prefs.setInt('longest_streak', _longestStreak);
    if (_lastPlayDate != null) {
      await prefs.setString('last_play_date', _lastPlayDate!.toIso8601String());
    }

    final playDateStrings =
        _playDates.map((date) => date.toIso8601String()).toList();
    await prefs.setStringList('play_dates', playDateStrings);

    await prefs.setString('category_progress', json.encode(_categoryProgress));
    await prefs.setString('category_scores', json.encode(_categoryScores));
    await prefs.setStringList('unlocked_achievements', _unlockedAchievements);

    await prefs.setInt('total_quizzes', _totalQuizzesTaken);
    await prefs.setInt('total_correct', _totalCorrectAnswers);
    await prefs.setInt('current_level', _currentLevel);
    await prefs.setInt('xp', _xp);
    await prefs.setString('league', _league);
    if (_rank != null) await prefs.setInt('rank', _rank!);
    await prefs.setInt('completed_levels_count', _completedLevelsCount);
  }

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = 0;
    _longestStreak = 0;
    _lastPlayDate = null;
    _playDates = [];
    _categoryProgress = {};
    _categoryScores = {};
    _unlockedAchievements = [];
    _totalQuizzesTaken = 0;
    _totalCorrectAnswers = 0;
    _currentLevel = 1;
    _accuracy = 0.0;
    _xp = 0;
    _league = 'Bronze';
    _rank = null;
    _completedLevelsCount = 0;

    await prefs.remove('current_streak');
    await prefs.remove('longest_streak');
    await prefs.remove('last_play_date');
    await prefs.remove('play_dates');
    await prefs.remove('category_progress');
    await prefs.remove('category_scores');
    await prefs.remove('unlocked_achievements');
    await prefs.remove('total_quizzes');
    await prefs.remove('total_correct');
    await prefs.remove('current_level');
    await prefs.remove('xp');
    await prefs.remove('league');
    await prefs.remove('rank');
    await prefs.remove('completed_levels_count');
    notifyListeners();
  }

  int _levelFromXp(int xp) {
    if (xp >= 10000) return 5;
    if (xp >= 5000) return 4;
    if (xp >= 2000) return 3;
    if (xp >= 500) return 2;
    return 1;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isConsecutiveDay(DateTime lastDate, DateTime currentDate) {
    final difference = currentDate.difference(lastDate).inDays;
    return difference == 1;
  }

  String getAchievementTitle(String achievementId) {
    switch (achievementId) {
      case 'first_quiz':
        return 'First Steps';
      case 'streak_3':
        return 'Getting Started';
      case 'streak_7':
        return 'Week Warrior';
      case 'streak_30':
        return 'Monthly Master';
      case 'accuracy_80':
        return 'Precision Pro';
      case 'quiz_50':
        return 'Quiz Champion';
      default:
        return 'Achievement';
    }
  }

  String getAchievementDescription(String achievementId) {
    switch (achievementId) {
      case 'first_quiz':
        return 'Complete your first quiz';
      case 'streak_3':
        return 'Maintain a 3-day learning streak';
      case 'streak_7':
        return 'Maintain a 7-day learning streak';
      case 'streak_30':
        return 'Maintain a 30-day learning streak';
      case 'accuracy_80':
        return 'Achieve 80% accuracy with 10+ quizzes';
      case 'quiz_50':
        return 'Complete 50 quizzes';
      default:
        return 'Special achievement unlocked';
    }
  }

  void _showAchievementDialog(BuildContext context, String achievementId) {
    final title = getAchievementTitle(achievementId);
    final description = getAchievementDescription(achievementId);

    IconData icon;
    Color color;

    switch (achievementId) {
      case 'first_quiz':
        icon = Icons.play_circle_fill;
        color = Colors.blue;
        break;
      case 'streak_3':
      case 'streak_7':
      case 'streak_30':
        icon = Icons.local_fire_department;
        color = Colors.orange;
        break;
      case 'accuracy_80':
        icon = Icons.track_changes;
        color = Colors.green;
        break;
      case 'quiz_50':
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      default:
        icon = Icons.star;
        color = Colors.purple;
    }

    showAchievementDialog(
      context: context,
      achievementId: achievementId,
      title: title,
      description: description,
      icon: icon,
      color: color,
    );
  }
}
