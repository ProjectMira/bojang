import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../theme/app_tokens.dart';
import '../utils/session_end_sequence.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/session_end_scaffold.dart';
import '../widgets/yak_mascot.dart';

/// The goal step after a lesson: shown when a lessons-finished milestone is
/// reached, with the next goal to aim for.
class LessonGoalScreen extends StatelessWidget {
  const LessonGoalScreen({super.key, required this.lessonsCompleted});

  final int lessonsCompleted;

  /// Pushes the screen and completes when the learner continues.
  static Future<void> show(BuildContext context, int lessonsCompleted) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'lesson_goal'),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                LessonGoalScreen(lessonsCompleted: lessonsCompleted),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = SessionEndSequence.nextLessonMilestone(lessonsCompleted);
    final fraction = next == null ? 1.0 : lessonsCompleted / next;
    return SessionEndScaffold(
      primaryLabel: 'Continue',
      onPrimary: () {
        Analytics.track('lesson_goal_closed', {
          'lessons_completed': lessonsCompleted,
          'next_goal': next,
        });
        Navigator.of(context).pop();
      },
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          YakMascot(
            mood: YakMood.proud,
            size: Breakpoints.isTablet(context) ? 200 : 160,
            semanticLabel: 'The yak is proud of you',
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              '$lessonsCompleted lessons done!',
              style: AppTextStyles.display(context),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          if (next != null)
            Text(
              'Your next goal: $next lessons. '
              '${next - lessonsCompleted} to go.',
              style: AppTextStyles.body(context, color: AppTokens.inkSoft(context)),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),
          Semantics(
            label: '$lessonsCompleted of ${next ?? lessonsCompleted} lessons',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 12,
                color: AppColors.gold,
                backgroundColor: AppTokens.tint(AppColors.gold, context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$lessonsCompleted / ${next ?? lessonsCompleted}',
              style: AppTextStyles.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}
