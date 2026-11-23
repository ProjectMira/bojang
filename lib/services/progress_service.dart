import 'dart:async';

import 'package:flutter/material.dart';
import 'analytics.dart';
import 'api_service.dart';
import 'offline_mode.dart';
import 'offline_queue.dart';
import '../utils/offline_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/streak_rules.dart';
import '../widgets/achievement_dialog.dart';

/// What to celebrate after the first practice of a day extended the streak.
class StreakCelebration {
  const StreakCelebration({
    required this.streak,
    required this.goal,
    this.freezeEarned = false,
    this.freezesUsed = 0,
    this.previousStreak,
    this.restored = false,
    this.earnBack,
  });

  final int streak;

  /// The learner's streak goal when this happened (0 if none set yet).
  final int goal;
  final bool freezeEarned;
  final int freezesUsed;

  /// The streak before this practice (defaults to one less).
  final int? previousStreak;

  /// Earn Back finished: the broken streak is back.
  final bool restored;

  /// An Earn Back still open after this practice (its progress to show).
  final EarnBack? earnBack;

  bool get isMilestone => StreakRules.isMilestone(streak);
  bool get goalReached => goal > 0 && streak == goal;

  FlameTier get tier => StreakRules.tierFor(streak);

  /// The flame grew a tier with this practice.
  bool get tierUp =>
      tier.index > StreakRules.tierFor(previousStreak ?? streak - 1).index;

  /// The tier the flame reaches if the learner comes back tomorrow.
  FlameTier? get tierTomorrow => StreakRules.tierTomorrow(streak);
}

class ProgressService extends ChangeNotifier {
  // Streak tracking
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastPlayDate;
  List<DateTime> _playDates = [];
  int _streakFreezes = 0;
  List<DateTime> _frozenDates = [];
  int _streakGoal = 0;
  StreakCelebration? _pendingCelebration;
  EarnBack? _earnBack;
  List<DateTime> _earnedBackDates = [];

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

  /// Streak freezes held (0-2): earned every 7 days, used on a missed day.
  int get streakFreezes => _streakFreezes;

  /// Days a streak freeze protected; the calendar shows them as ice.
  List<DateTime> get frozenDates => _frozenDates;

  /// The streak length the learner committed to (0 if none yet).
  int get streakGoal => _streakGoal;

  /// The Earn Back to show today, if a broken streak can still come back:
  /// the open window, or one owed to a break nothing has counted yet.
  EarnBack? earnBackOn(DateTime today) => StreakRules.earnBackStatus(
    streak: _currentStreak,
    lastActive: _lastPlayDate,
    freezes: _streakFreezes,
    stored: _earnBack,
    today: today,
  );

  EarnBack? get earnBack => earnBackOn(DateTime.now());

  /// Missed days an Earn Back repaired; the calendar shows them mended.
  List<DateTime> get earnedBackDates => _earnedBackDates;

  /// The celebration waiting to be shown, cleared once taken.
  StreakCelebration? takeStreakCelebration() {
    final c = _pendingCelebration;
    _pendingCelebration = null;
    return c;
  }

  Future<void> setStreakGoal(int days) async {
    _streakGoal = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_goal', days);
    Analytics.track('streak_goal_set', {
      'goal': days,
      'current_streak': _currentStreak,
    });
    notifyListeners();
  }
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

  /// [offlineQueue] replaces the legacy pending-day list with the
  /// persisted offline queue (plan item #23); by default the app's queue is
  /// used whenever offline mode is on. Tests that inject [recordActivity]
  /// alone keep the legacy path.
  ProgressService({
    bool Function()? isSignedIn,
    Future<Map<String, dynamic>?> Function(String localDate)? recordActivity,
    OfflineQueue? offlineQueue,
    bool Function()? offlineEnabled,
    Future<Map<String, dynamic>?> Function()? fetchStats,
  }) : _isSignedIn = isSignedIn ?? (() => ApiService().isAuthenticated),
       _recordActivity = recordActivity ?? ApiService().recordActivity,
       _fetchStats = fetchStats ?? ApiService().getUserProgress,
       _queueFactory =
           offlineQueue != null
               ? (() => offlineQueue)
               : recordActivity != null
               ? null
               : (() => OfflineMode.instance.queue),
       _offlineEnabled =
           offlineEnabled ??
           (offlineQueue != null
               ? () => true
               : () => OfflineMode.instance.enabled) {
    _loadProgressData();
  }

  // Server hooks; injectable so the activity sync can be unit-tested.
  final bool Function() _isSignedIn;
  final Future<Map<String, dynamic>?> Function(String localDate)
  _recordActivity;
  final Future<Map<String, dynamic>?> Function() _fetchStats;
  final OfflineQueue Function()? _queueFactory;
  final bool Function() _offlineEnabled;
  OfflineQueue? _queue;
  PendingProgress _pending = PendingProgress.none;

  /// Writes not yet on the server (XP and days shown optimistically).
  PendingProgress get pendingProgress => _pending;

  /// The offline queue when offline mode is on, else null (legacy path).
  OfflineQueue? get _activeQueue {
    final factory = _queueFactory;
    if (factory == null || !_offlineEnabled()) return null;
    final existing = _queue;
    if (existing != null) return existing;
    final queue = _queue = factory();
    queue.addListener(_onQueueDelivered);
    return queue;
  }

  void _onQueueDelivered(QueuedRequest item, SendResult result) {
    if (result.outcome != SendOutcome.delivered) {
      unawaited(_refreshPending());
      return;
    }
    final response = result.response;
    if (item.kind == QueuedKind.activity && response != null) {
      unawaited(_applyActivityResponse(response));
    } else if (item.kind == QueuedKind.lessonComplete && item.attempts > 0) {
      // A lesson played offline just reached the server: show its numbers.
      unawaited(_refreshFromServer());
    } else {
      unawaited(_refreshPending());
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final stats = await _fetchStats();
      if (stats != null) await updateFromServer(stats);
    } catch (e) {
      debugPrint('Stats refresh after replay failed: $e');
    }
  }

  Future<void> _refreshPending() async {
    final queue = _activeQueue;
    if (queue == null) {
      _pending = PendingProgress.none;
      return;
    }
    try {
      final before = _pending;
      _pending = PendingProgress.of([
        ...await queue.itemsOf(QueuedKind.lessonComplete),
        ...await queue.itemsOf(QueuedKind.activity),
      ]);
      if (before.lessons != _pending.lessons ||
          before.activities != _pending.activities) {
        notifyListeners();
      }
    } catch (_) {}
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
    _streakFreezes = prefs.getInt('streak_freezes') ?? 0;
    _frozenDates = _parseDays(prefs.getStringList('frozen_dates'));
    _streakGoal = prefs.getInt('streak_goal') ?? 0;
    _earnBack = _decodeEarnBack(prefs.getString('earn_back'));
    _earnedBackDates = _parseDays(prefs.getStringList('earned_back_dates'));

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

    _syncPersonProperties();
    notifyListeners();
  }

  Future<void> updateFromServer(Map<String, dynamic> data) async {
    // Queued lessons and days the server hasn't seen stay on screen.
    await _refreshPending();
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
      final serverXp = xpInfo?['total'] as int?;
      if (serverXp != null) _xp = _pending.mergeXp(server: serverXp);
      final serverStreak = streakInfo?['current'] as int?;
      if (serverStreak != null) _currentStreak = _mergedStreak(serverStreak);
      if (streakInfo != null) {
        _applyServerFreezes(streakInfo);
        _applyServerEarnBack(streakInfo);
      }
      _league = (leagueInfo?['current'] ?? _league).toString();
      _completedLevelsCount =
          levelsInfo?['count'] as int? ?? _completedLevelsCount;
    } else {
      final serverXp = data['xp'] as int?;
      if (serverXp != null) _xp = _pending.mergeXp(server: serverXp);
      final serverStreak = data['streak'] as int?;
      if (serverStreak != null) _currentStreak = _mergedStreak(serverStreak);
      _league = (data['league'] ?? _league).toString();
      _rank = data['rank'] as int?;
      _completedLevelsCount =
          data['completed_levels_count'] as int? ?? _completedLevelsCount;
    }

    _currentLevel = _levelFromXp(_xp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', _xp);
    await prefs.setInt('current_streak', _currentStreak);
    await _saveFreezes(prefs);
    await prefs.setString('league', _league);
    if (_rank != null) await prefs.setInt('rank', _rank!);
    await prefs.setInt('completed_levels_count', _completedLevelsCount);
    await prefs.setInt('current_level', _currentLevel);
    notifyListeners();
  }

  static List<DateTime> _parseDays(Iterable<dynamic>? values) {
    final days = <DateTime>{};
    for (final v in values ?? const []) {
      final parsed = DateTime.tryParse(v.toString());
      if (parsed != null) {
        days.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
    return days.toList()..sort();
  }

  /// Takes freezes from a server response (`streak_freezes`/`frozen_dates`
  /// on activity and lesson responses, `freezes`/`frozen_dates` in stats).
  void _applyServerFreezes(Map<String, dynamic> data) {
    final freezes = data['streak_freezes'] ?? data['freezes'];
    if (freezes is int) {
      _streakFreezes = freezes.clamp(0, StreakRules.maxFreezes);
    }
    final frozen = data['frozen_dates'];
    if (frozen is List) {
      // Keep days frozen on this device that the server hasn't seen yet.
      _frozenDates = _parseDays([
        ...frozen,
        ..._frozenDates.map(localDateString),
      ]);
    }
  }

  Future<void> _saveFreezes(SharedPreferences prefs) async {
    await prefs.setInt('streak_freezes', _streakFreezes);
    await prefs.setStringList(
      'frozen_dates',
      _frozenDates.map(localDateString).toList(),
    );
    final earnBack = _earnBack;
    if (earnBack == null) {
      await prefs.remove('earn_back');
    } else {
      await prefs.setString('earn_back', json.encode(earnBack.toJson()));
    }
    await prefs.setStringList(
      'earned_back_dates',
      _earnedBackDates.map(localDateString).toList(),
    );
  }

  static EarnBack? _decodeEarnBack(String? stored) {
    if (stored == null) return null;
    try {
      return EarnBack.fromJson(json.decode(stored));
    } catch (_) {
      return null;
    }
  }

  /// Takes Earn Back from a server response (`earn_back` and
  /// `earned_back_dates`, on activity and lesson responses and in stats).
  void _applyServerEarnBack(Map<String, dynamic> data) {
    if (data.containsKey('earn_back')) {
      final server = EarnBack.fromJson(data['earn_back']);
      final local = _earnBack;
      if (server != null &&
          local != null &&
          server.sameWindow(local) &&
          local.sessionsDone > server.sessionsDone) {
        // This device counted a session the server hasn't seen yet.
        _earnBack = local;
      } else {
        _earnBack =
            server == null || local == null || !server.sameWindow(local)
                ? server
                : server.copyWith(openedOn: local.openedOn);
      }
    }
    final repaired = data['earned_back_dates'];
    if (repaired is List) {
      _earnedBackDates = _parseDays([
        ...repaired,
        ..._earnedBackDates.map(localDateString),
      ]);
    }
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
    final previousLevel = _currentLevel;
    final previousStreak = _currentStreak;
    _xp += score * 10;
    _currentLevel = _levelFromXp(_xp);
    if (score > 0) {
      Analytics.track('xp_gained', {
        'amount': score * 10,
        'xp': _xp,
        'category': category,
      });
    }
    if (_currentLevel > previousLevel) {
      Analytics.track('level_up', {
        'level': _currentLevel,
        'previous_level': previousLevel,
      });
    }

    // Update category progress
    final categoryKey = category.toLowerCase().replaceAll(' ', '_');
    _categoryScores[categoryKey] = (_categoryScores[categoryKey] ?? 0) + score;
    _categoryProgress[categoryKey] = (score / totalQuestions).clamp(0.0, 1.0);

    // Update streak
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // Every finished session counts toward an open Earn Back, so the rule
    // runs each time; on a day already practiced it only moves Earn Back.
    final newDay = _lastPlayDate == null || !_isSameDay(_lastPlayDate!, today);
    final update = StreakRules.apply(
      streak: _currentStreak,
      lastActive: _lastPlayDate,
      freezes: _streakFreezes,
      today: today,
      earnBack: earnBackOn(today),
      session: true,
    );
    if (newDay) {
      _currentStreak = update.streak;
      _streakFreezes = update.freezes;
      if (update.frozenDays.isNotEmpty) {
        _frozenDates = _parseDays([
          ..._frozenDates.map(localDateString),
          ...update.frozenDays.map(localDateString),
        ]);
        Analytics.track('streak_freeze_used', {
          'days': update.frozenDays.length,
          'current_streak': _currentStreak,
          'freezes_left': _streakFreezes,
        });
      }
      if (update.freezeEarned) {
        Analytics.track('streak_freeze_earned', {
          'current_streak': _currentStreak,
          'freezes': _streakFreezes,
        });
      }

      _lastPlayDate = today;
      _playDates.add(todayKey);

      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }
      _pendingCelebration = StreakCelebration(
        streak: _currentStreak,
        goal: _streakGoal,
        freezeEarned: update.freezeEarned,
        freezesUsed: update.frozenDays.length,
        previousStreak: update.streakRestored ? previousStreak : null,
        restored: update.streakRestored,
        earnBack: update.earnBack,
      );
    }
    _applyEarnBack(update, today, newDay: newDay, previousStreak: previousStreak);

    if (_currentStreak != previousStreak) {
      Analytics.track(
        _currentStreak > previousStreak ? 'streak_extended' : 'streak_reset',
        {
          'current_streak': _currentStreak,
          'longest_streak': _longestStreak,
          'previous_streak': previousStreak,
        },
      );
    }

    // Check for new achievements and show them
    final newAchievements = _checkAchievements();
    for (final id in newAchievements) {
      Analytics.track('achievement_unlocked', {
        'achievement': id,
        'title': getAchievementTitle(id),
      });
    }
    _syncPersonProperties();

    // Save all data
    await _saveProgressData(prefs);
    notifyListeners();

    // Count the day on the server too (fire-and-forget; retried if it fails).
    _reportActivity(localDateString(today));

    // Show achievement dialogs if context is provided
    // Streak achievements are still unlocked, but the streak celebration
    // shows the moment, so they don't get a second pop-up.
    final dialogAchievements =
        newAchievements.where((id) => !id.startsWith('streak_')).toList();
    if (context != null && dialogAchievements.isNotEmpty) {
      for (final achievementId in dialogAchievements) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showAchievementDialog(context, achievementId);
        });
      }
    }
  }

  /// Keeps the Earn Back from [update]: its progress, and on a restore the
  /// streak, the repaired days and a celebration (a restore on a day already
  /// practiced queues one too, since it changes the streak).
  void _applyEarnBack(
    StreakUpdate update,
    DateTime today, {
    required bool newDay,
    required int previousStreak,
  }) {
    final before = _earnBack;
    _earnBack = update.earnBack;
    final after = update.earnBack;
    if (after != null &&
        after.sessionsDone == 1 &&
        (before == null || before.sessionsDone == 0)) {
      Analytics.track('earn_back_started', {
        'streak': after.streak,
        'days_left': after.daysLeft(today),
        'sessions_needed': after.sessionsNeeded,
      });
    } else if (after == null &&
        before != null &&
        !update.streakRestored &&
        !before.isOpenOn(today)) {
      Analytics.track('earn_back_expired', {
        'streak': before.streak,
        'sessions_done': before.sessionsDone,
      });
    }
    if (!update.streakRestored) return;

    _earnedBackDates = _parseDays([
      ..._earnedBackDates.map(localDateString),
      ...update.earnedBackDays.map(localDateString),
    ]);
    Analytics.track('earn_back_completed', {
      'streak': update.streak,
      'previous_streak': previousStreak,
      'repaired_days': update.earnedBackDays.length,
    });
    if (!newDay) {
      _currentStreak = update.streak;
      _streakFreezes = update.freezes;
      if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
      _pendingCelebration = StreakCelebration(
        streak: _currentStreak,
        goal: _streakGoal,
        freezeEarned: update.freezeEarned,
        previousStreak: previousStreak,
        restored: true,
      );
    }
  }

  void _syncPersonProperties() {
    Analytics.setPersonProperties({
      'xp': _xp,
      'level': _currentLevel,
      'current_streak': _currentStreak,
      'longest_streak': _longestStreak,
      'completed_levels': _completedLevelsCount,
      'accuracy': double.parse(_accuracy.toStringAsFixed(1)),
      'achievements_unlocked': _unlockedAchievements.length,
      'questions_answered': _totalQuizzesTaken,
      'league': _league,
    });
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
    await _saveFreezes(prefs);

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
    _streakFreezes = 0;
    _frozenDates = [];
    _streakGoal = 0;
    _pendingCelebration = null;
    _earnBack = null;
    _earnedBackDates = [];
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
    await prefs.remove('streak_freezes');
    await prefs.remove('frozen_dates');
    await prefs.remove('streak_goal');
    await prefs.remove('earn_back');
    await prefs.remove('earned_back_dates');
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
    // Unsent streak days belong to this account; never post them for the next.
    await prefs.remove(_pendingActivityKey);
    await _queue?.clear();
    _pending = PendingProgress.none;
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

  /// True when [currentDate] is the calendar day right after [lastDate].
  ///
  /// Compares calendar dates, not elapsed time: 23:00 then 08:00 the next
  /// morning is consecutive even though only 9 hours passed. The dates are
  /// rebuilt in UTC so a 23- or 25-hour daylight-saving day can't skew it.
  static bool isConsecutiveDay(DateTime lastDate, DateTime currentDate) {
    final last = DateTime.utc(lastDate.year, lastDate.month, lastDate.day);
    final current = DateTime.utc(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    return current.difference(last).inDays == 1;
  }

  /// The device's local calendar day as `YYYY-MM-DD` for the API.
  ///
  /// Built by hand rather than with a locale-aware formatter, so a Tibetan
  /// (or any non-Latin-digit) locale can never send digits the server rejects.
  static String localDateString(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
  }

  static const _pendingActivityKey = 'pending_activity_dates';

  // Report and flush calls run one at a time, so the pending list is read
  // and written in a fixed order even when a game and Home overlap.
  Future<void> _activityQueue = Future.value();

  Future<void> _enqueueActivity(Future<void> Function() job) {
    final next = _activityQueue.then((_) => job()).catchError((
      Object e,
      StackTrace st,
    ) {
      debugPrint('Activity sync error: $e');
    });
    _activityQueue = next;
    return next;
  }

  /// Reports a day of activity so the server streak counts it. Lessons,
  /// local-topic lessons, games and the speed quiz all come through
  /// [updateQuizResults], so this is the single hook. Days that can't be sent
  /// stay pending and go out (oldest first) on the next report or
  /// [flushPendingActivity].
  ///
  /// With offline mode on, each report is an item of the persisted offline
  /// queue instead: it carries a client UUID (a replay counts once) and, if
  /// sent late, `offline: true`, so the server credits the day it was
  /// played, up to 7 days back.
  Future<void> _reportActivity(String localDate) => _enqueueActivity(() async {
    final queue = _activeQueue;
    final prefs = await SharedPreferences.getInstance();
    if (queue != null) {
      await _moveLegacyPending(prefs, queue);
      await queue.submit(QueuedKind.activity, 'progress/activity', {
        'local_date': localDate,
      });
      await _refreshPending();
      return;
    }
    await _sendPending(prefs, [..._recentPending(prefs), localDate]);
  });

  /// Retries days that couldn't be sent before (offline, signed out).
  Future<void> flushPendingActivity() => _enqueueActivity(() async {
    final queue = _activeQueue;
    final prefs = await SharedPreferences.getInstance();
    if (queue != null) {
      await _moveLegacyPending(prefs, queue);
      await queue.flush(force: true);
      await _refreshPending();
      return;
    }
    await _sendPending(prefs, _recentPending(prefs));
  });

  /// Days left in the old pending list (from a build before the queue) go
  /// to the front of the queue, oldest first.
  Future<void> _moveLegacyPending(
    SharedPreferences prefs,
    OfflineQueue queue,
  ) async {
    final days = prefs.getStringList(_pendingActivityKey);
    if (days == null || days.isEmpty) return;
    for (final day in days.toList()..sort()) {
      await queue.enqueue(QueuedKind.activity, 'progress/activity', {
        'local_date': day,
        'offline': true,
      });
    }
    await prefs.remove(_pendingActivityKey);
  }

  /// Takes a delivered activity report's streak, freezes and Earn Back.
  Future<void> _applyActivityResponse(Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    await _refreshPending();
    final serverStreak = response['streak'];
    if (serverStreak is int) {
      _currentStreak = _mergedStreak(serverStreak);
      await prefs.setInt('current_streak', _currentStreak);
    }
    _applyServerFreezes(response);
    _applyServerEarnBack(response);
    await _saveFreezes(prefs);
    notifyListeners();
  }

  /// Stored pending days still worth sending: only today and yesterday. The
  /// server treats anything older as "today", which would be wrong.
  List<String> _recentPending(SharedPreferences prefs) {
    final now = DateTime.now();
    final keep = {
      localDateString(now),
      localDateString(DateTime(now.year, now.month, now.day - 1)),
    };
    return (prefs.getStringList(_pendingActivityKey) ?? const <String>[])
        .where(keep.contains)
        .toList();
  }

  /// Sends [dates] oldest first, stopping at the first failure, so the server
  /// sees day N before day N+1. Only acknowledged days leave the list. A day
  /// can appear once per session: the streak counts it once, and Earn Back
  /// counts every session.
  Future<void> _sendPending(
    SharedPreferences prefs,
    Iterable<String> dates,
  ) async {
    // YYYY-MM-DD sorts chronologically as text.
    final remaining = dates.toList()..sort();
    while (remaining.isNotEmpty && await _sendOne(prefs, remaining.first)) {
      remaining.removeAt(0);
    }
    if (remaining.isEmpty) {
      await prefs.remove(_pendingActivityKey);
    } else {
      await prefs.setStringList(_pendingActivityKey, remaining);
    }
  }

  Future<bool> _sendOne(SharedPreferences prefs, String localDate) async {
    if (!_isSignedIn()) return false;
    final response = await _recordActivity(localDate);
    if (response == null) return false;
    final serverStreak = response['streak'];
    if (serverStreak is int) {
      _currentStreak = _mergedStreak(serverStreak);
      await prefs.setInt('current_streak', _currentStreak);
    }
    _applyServerFreezes(response);
    _applyServerEarnBack(response);
    await _saveFreezes(prefs);
    notifyListeners();
    return true;
  }

  /// The server is the source of truth, except that a day already played
  /// on this device is never taken away while the server catches up.
  int _mergedStreak(int serverStreak) {
    final playedToday =
        _lastPlayDate != null && _isSameDay(_lastPlayDate!, DateTime.now());
    // Also while queued days are still on their way (offline queue).
    return _pending.mergeStreak(
      server: serverStreak,
      local: _currentStreak,
      playedToday: playedToday,
    );
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
