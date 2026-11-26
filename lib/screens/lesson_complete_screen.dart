import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Feedback;
import '../services/analytics.dart';
import '../services/beginner.dart';
import '../services/feedback.dart';
import '../services/location_service.dart';
import '../services/notification_primer.dart';
import '../services/progress_service.dart';
import '../services/reading_help.dart';
import '../services/save_progress_prompt.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../utils/session_end_sequence.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/session_end_scaffold.dart';
import '../widgets/yak_mascot.dart';
import 'lesson_goal_screen.dart';
import 'quiz_screen.dart';
import 'streak_celebration_screen.dart';
import '../widgets/content_width.dart';

/// One request the session end may make. Returns whether it showed; the
/// session end makes at most one per lesson, the first that shows.
typedef SessionEndAsk =
    Future<bool> Function(BuildContext context, SessionEndInfo end);

/// What the earlier steps of this session end showed, for the asks.
class SessionEndInfo {
  const SessionEndInfo({this.streak, this.lessonsCompleted = 0});

  /// The streak celebration shown in this session end, if any.
  final StreakCelebration? streak;

  /// Lessons finished on this device, this one included (0 if unknown).
  final int lessonsCompleted;
}

/// The result screen after a lesson, and the first step of the session end
/// (see [SessionEndSequence]): result → streak (first practice of the day)
/// → goal progress → at most one ask. Continue walks through the steps.
class LessonCompleteScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int xpEarned;
  final double accuracy;
  final int streak;
  final String topicFilePath;
  final String? title;

  /// Missed words that came back at the end, and how many were then right.
  final int recycled;
  final int fixed;

  /// Lessons finished on this device, this one included (0 if unknown).
  /// Sets the size of the celebration.
  final int lessonsCompleted;

  const LessonCompleteScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.xpEarned,
    required this.accuracy,
    required this.streak,
    required this.topicFilePath,
    this.title,
    this.recycled = 0,
    this.fixed = 0,
    this.lessonsCompleted = 0,
    this.beginner,
  });

  /// Whether the learner gets the short session end (see [Beginner]);
  /// null works it out from [lessonsCompleted] and the learner's XP.
  final bool? beginner;

  /// The asks a beginner may get: only the notification primer (the OS
  /// permission and its timing belong to it). Saving progress, location and
  /// reading help wait until the learner is past [Beginner].
  static final List<SessionEndAsk> beginnerAsks = [asks.first];

  /// The asks, in priority order. Add new ones here, not as extra
  /// pop-ups elsewhere, so a lesson never ends with more than one.
  ///
  /// 1. The notification primer, at the first finished lesson or a streak
  ///    moment (started, extended or saved by a freeze): at most 3 asks,
  ///    3+ days apart, and never once the OS prompt has been answered.
  /// 2. "Save your progress", for a learner without a real account, from
  ///    the first lesson or a 3-day streak: at most 3 asks, 4+ days apart.
  /// 3. Location, once, from the first lesson on; it waits for a session
  ///    end the primer does not take.
  /// 4. "Turn off reading help?", once, after 20 right in a row with it on.
  static final List<SessionEndAsk> asks = [
    (context, end) => NotificationPrimer.instance.afterLesson(
      context,
      lessonsCompleted: end.lessonsCompleted,
      celebration: end.streak,
    ),
    (context, end) => SaveProgressPrompt.instance.maybeAsk(
      context,
      lessonsCompleted: end.lessonsCompleted,
      streak: end.streak?.streak ?? 0,
    ),
    (context, end) => LocationService.instance.maybePromptAfterLesson(context),
    (context, end) async {
      final help = ReadingHelp.instance;
      if (!help.suggestionDue) return false;
      final ThemeService theme;
      try {
        theme = Provider.of<ThemeService>(context, listen: false);
      } on ProviderNotFoundException {
        return false;
      }
      return help.maybeSuggest(
        context,
        currentMode: theme.transliterationMode,
        setMode: theme.setTransliterationMode,
      );
    },
  ];

  /// Runs [asks] (default: [LessonCompleteScreen.asks]) in order and stops
  /// at the first that shows, so one lesson end makes at most one ask.
  /// Returns the index of the ask shown, or null when none showed.
  static Future<int?> showFirstAsk(
    BuildContext context,
    SessionEndInfo end, {
    List<SessionEndAsk>? asks,
  }) async {
    final list = asks ?? LessonCompleteScreen.asks;
    for (var i = 0; i < list.length; i++) {
      if (!context.mounted) return null;
      if (await list[i](context, end)) return i;
    }
    return null;
  }

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen> {
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;
  late final CelebrationSize _size;
  late final bool _beginner;

  /// Beginners: the streak celebration, taken here and shown on this
  /// screen instead of on a screen of its own.
  StreakCelebration? _inlineStreak;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _size = SessionEndSequence.celebrationFor(
      lessonsCompleted: widget.lessonsCompleted,
      accuracy: widget.accuracy,
    );
    ProgressService? progress;
    try {
      progress = Provider.of<ProgressService>(context, listen: false);
    } on ProviderNotFoundException {
      progress = null;
    }
    _beginner =
        widget.beginner ??
        Beginner.check(
          lessonsCompleted: widget.lessonsCompleted,
          xp: progress?.xp ?? 0,
        );
    if (_beginner && progress != null) {
      final c = progress.takeStreakCelebration();
      // An Earn Back that brought a streak back keeps its own screen.
      if (c != null && c.restored) {
        progress.restoreStreakCelebration(c);
      } else {
        _inlineStreak = c;
      }
    }
    Feedback.play(FeedbackEvent.lessonComplete, context: context);
    _confettiLeft = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    _confettiRight = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    // Peak-end: the big moment is the first lesson and each milestone.
    // Reduced motion (Settings > Animations) skips the confetti.
    if (_size == CelebrationSize.big &&
        Motion.read(context).allowsCelebration) {
      _confettiLeft.play();
      _confettiRight.play();
    }
    Analytics.track('lesson_result_shown', {
      'topic': widget.title,
      'celebration': _size.name,
      'lessons_completed': widget.lessonsCompleted,
      'accuracy': widget.accuracy.round(),
      'recycled': widget.recycled,
      'fixed': widget.fixed,
      'beginner': _beginner,
      'streak_inline': _inlineStreak != null,
    });
  }

  @override
  void dispose() {
    _confettiLeft.dispose();
    _confettiRight.dispose();
    super.dispose();
  }

  void _trackAction(String action) {
    Analytics.track('lesson_complete_action', {
      'action': action,
      'topic': widget.title,
      'topic_path': widget.topicFilePath,
      'score': widget.score,
      'total': widget.totalQuestions,
      'beginner': _beginner,
    });
  }

  /// Walks the rest of the session end, then returns to where the lesson
  /// was opened from.
  Future<void> _continue() async {
    if (_leaving) return;
    _leaving = true;
    _trackAction('continue');
    final shown = <String>[SessionEndStep.result.name];
    var streak = _inlineStreak;
    if (streak == null) {
      streak = await StreakCelebrationScreen.showWaiting(context);
      if (streak != null) shown.add(SessionEndStep.streak.name);
    }
    if (!mounted) return;
    if (SessionEndSequence.showsGoal(widget.lessonsCompleted)) {
      await LessonGoalScreen.show(context, widget.lessonsCompleted);
      shown.add(SessionEndStep.goal.name);
    }
    final end = SessionEndInfo(
      streak: streak,
      lessonsCompleted: widget.lessonsCompleted,
    );
    if (mounted &&
        await LessonCompleteScreen.showFirstAsk(
              context,
              end,
              asks: _beginner ? LessonCompleteScreen.beginnerAsks : null,
            ) !=
            null) {
      shown.add(SessionEndStep.ask.name);
    }
    Analytics.track('session_end_completed', {
      'steps': shown,
      'celebration': _size.name,
      'lessons_completed': widget.lessonsCompleted,
      'beginner': _beginner,
      'streak_inline': _inlineStreak != null,
      'next_lesson': _beginner,
    });
    if (!mounted) return;
    Navigator.of(context).pop();
    // Beginners go straight on to the next lesson on the path (Home opens
    // it), instead of landing on Home and finding it themselves.
    if (_beginner) Beginner.nextLessonRequests.value++;
  }

  void _practiceAgain() {
    if (_leaving) return;
    _trackAction('practice_again');
    Navigator.of(context).pushReplacement(
      screenRoute(
        'quiz',
        (context) => QuizScreen(
          topicFilePath: widget.topicFilePath,
          title: widget.title,
          source: 'lesson_complete_retry',
        ),
      ),
    );
  }

  ({String title, String? body}) _headline(YakLine line) {
    if (_size != CelebrationSize.big) {
      return (title: line.title, body: line.body);
    }
    if (widget.lessonsCompleted == 1) {
      return (
        title: 'Your first lesson!',
        body: 'Every journey to Lhasa starts with one step.',
      );
    }
    return (title: '${widget.lessonsCompleted} lessons!', body: line.body);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTokens.isDark(context);
    final big = _size == CelebrationSize.big;
    final resultColor =
        _size == CelebrationSize.quiet ? AppColors.primary : AppColors.gold;
    final line = YakLines.lessonComplete(accuracy: widget.accuracy);
    final headline = _headline(line);
    final tablet = Breakpoints.isTablet(context);
    final yakSize = big ? (tablet ? 260.0 : 230.0) : (tablet ? 190.0 : 160.0);
    const confettiColors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.green,
      AppColors.purple,
    ];

    return PopScope(
      // Leaving by the back gesture still walks the session end, so the
      // streak and the ask are never lost or shown out of order.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continue();
      },
      child: SessionEndScaffold(
        primaryLabel: _beginner ? 'Next lesson' : 'Continue',
        onPrimary: _continue,
        secondaryLabel: 'Practice again',
        onSecondary: _practiceAgain,
        overlays: [
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiLeft,
              blastDirection: math.pi / 3,
              emissionFrequency: 0.06,
              numberOfParticles: 10,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.3,
              shouldLoop: false,
              colors: confettiColors,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiRight,
              blastDirection: math.pi - math.pi / 3,
              emissionFrequency: 0.06,
              numberOfParticles: 10,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.3,
              shouldLoop: false,
              colors: confettiColors,
            ),
          ),
        ],
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: yakSize + 50,
                  height: yakSize + 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        resultColor.withOpacity(
                          (isDark ? 0.16 : 0.08) * (big ? 1.5 : 1),
                        ),
                        resultColor.withOpacity(0),
                      ],
                    ),
                  ),
                ),
                // The yak is the celebration: it jumps for a pass and
                // cheers the learner on otherwise.
                YakMascot(
                  mood: line.mood,
                  size: yakSize,
                  semanticLabel:
                      _size == CelebrationSize.quiet
                          ? '${YakLines.name} the yak is cheering you on'
                          : '${YakLines.name} the yak is cheering',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                headline.title,
                style: AppTextStyles.display(context),
                textAlign: TextAlign.center,
              ),
            ),
            if (headline.body != null) ...[
              const SizedBox(height: 4),
              Text(
                headline.body!,
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.ink(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'You scored ${widget.score} of ${widget.totalQuestions} '
              '(${widget.accuracy.toStringAsFixed(0)}%)',
              style: AppTextStyles.poppins(
                fontSize: 14,
                color: AppTokens.inkSoft(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.recycled > 0) ...[
              const SizedBox(height: 4),
              Text(
                widget.fixed == widget.recycled
                    ? 'You fixed every mistake.'
                    : 'You fixed ${widget.fixed} of ${widget.recycled} mistakes.',
                style: AppTextStyles.poppins(
                  fontSize: 14,
                  color: AppTokens.inkSoft(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildStatChip(
                  context,
                  '⚡',
                  '+${widget.xpEarned} XP',
                  AppColors.gold,
                ),
                _buildStatChip(
                  context,
                  '🎯',
                  '${widget.accuracy.toStringAsFixed(0)}%',
                  AppColors.primary,
                ),
                _buildStatChip(
                  context,
                  '🔥',
                  '${widget.streak} streak',
                  AppColors.orange,
                ),
              ],
            ),
            if (_inlineStreak != null) ...[
              const SizedBox(height: 16),
              Text(
                _inlineStreakLine(_inlineStreak!),
                key: const ValueKey('inline_streak'),
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textOnTint(AppColors.orange, context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _inlineStreakLine(StreakCelebration c) =>
      c.streak <= 1
          ? 'Your streak has started! Come back tomorrow to grow it.'
          : '${c.streak} days in a row. Keep it going tomorrow!';

  Widget _buildStatChip(
    BuildContext context,
    String emoji,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.tint(color, context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              // Not the accent itself: gold on its tint is about 1.7:1.
              color: AppTokens.textOnTint(color, context),
            ),
          ),
        ],
      ),
    );
  }
}
