import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../services/location_service.dart';
import '../services/notification_primer.dart';
import '../services/progress_service.dart';
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
  });

  /// The asks, in priority order. Add new ones here, not as extra
  /// pop-ups elsewhere, so a lesson never ends with more than one.
  ///
  /// 1. The notification primer, at a streak moment (started, extended or
  ///    saved by a freeze): at most 3 asks, 3+ days apart.
  /// 2. Location, once, from the first lesson on; it waits for a session
  ///    end the primer does not take.
  static final List<SessionEndAsk> asks = [
    (context, end) async {
      final streak = end.streak;
      if (streak == null) return false;
      return NotificationPrimer.instance.afterStreakCelebration(
        context,
        streak,
      );
    },
    (context, end) => LocationService.instance.maybePromptAfterLesson(context),
  ];

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen> {
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;
  late final CelebrationSize _size;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _size = SessionEndSequence.celebrationFor(
      lessonsCompleted: widget.lessonsCompleted,
      accuracy: widget.accuracy,
    );
    _confettiLeft = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    _confettiRight = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    // Peak-end: the big moment is the first lesson and each milestone.
    // Reduced motion (Settings > Animations) skips the confetti.
    if (_size == CelebrationSize.big && Motion.read(context).allowsCelebration) {
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
    });
  }

  /// Walks the rest of the session end, then returns to where the lesson
  /// was opened from.
  Future<void> _continue() async {
    if (_leaving) return;
    _leaving = true;
    _trackAction('continue');
    final shown = <String>[SessionEndStep.result.name];
    final streak = await StreakCelebrationScreen.showWaiting(context);
    if (streak != null) shown.add(SessionEndStep.streak.name);
    if (mounted && SessionEndSequence.showsGoal(widget.lessonsCompleted)) {
      await LessonGoalScreen.show(context, widget.lessonsCompleted);
      shown.add(SessionEndStep.goal.name);
    }
    final end = SessionEndInfo(
      streak: streak,
      lessonsCompleted: widget.lessonsCompleted,
    );
    for (final ask in LessonCompleteScreen.asks) {
      if (!mounted) break;
      if (await ask(context, end)) {
        shown.add(SessionEndStep.ask.name);
        break;
      }
    }
    Analytics.track('session_end_completed', {
      'steps': shown,
      'celebration': _size.name,
      'lessons_completed': widget.lessonsCompleted,
    });
    if (mounted) Navigator.of(context).pop();
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
    if (_size != CelebrationSize.big) return (title: line.title, body: line.body);
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
        primaryLabel: 'Continue',
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
          ],
        ),
      ),
    );
  }

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
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
