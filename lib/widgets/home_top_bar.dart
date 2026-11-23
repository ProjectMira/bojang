import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/learning_path.dart';
import '../screens/streak_calendar_screen.dart';
import '../screens/streak_view_screen.dart';
import '../services/analytics.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../utils/streak_rules.dart';
import 'app_text_style.dart';
import 'learning_path_view.dart';
import 'reading_voice_pickers.dart';
import 'streak_flame.dart';

/// Home's status bar (plan item #18): the streak flame (opens the calendar
/// sheet), today's goal ring, and the voice chip.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, this.daily});

  /// Today's sessions toward the daily goal; null before the path loads.
  final DailyProgress? daily;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();
    final streak = progress.currentStreak;
    final now = DateTime.now();
    final practicedToday = progress.playDates.any(
      (d) => d.year == now.year && d.month == now.month && d.day == now.day,
    );
    // Offline or signed out: count today as one session if practised.
    final goal =
        daily ?? DailyProgress(sessions: practicedToday ? 1 : 0, goal: 1);
    return Row(
      children: [
        _StreakChip(streak: streak, practicedToday: practicedToday),
        const SizedBox(width: AppSpacing.sm),
        _GoalChip(daily: goal),
        const Spacer(),
        const VoiceChip(source: 'home_top_bar'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.semantics,
    required this.onTap,
    required this.child,
  });

  final String semantics;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTokens.cardBorder(context)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, required this.practicedToday});

  final int streak;
  final bool practicedToday;

  @override
  Widget build(BuildContext context) {
    final tier = StreakRules.tierFor(streak);
    return _Chip(
      semantics:
          '$streak day streak${practicedToday ? ', practised today' : ''}. Open streak calendar',
      onTap: () => showStreakSheet(context, source: 'home_top_bar'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: streak == 0 || !practicedToday ? 0.55 : 1,
            child: StreakFlame(tier: tier, size: 26),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppTextStyles.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTokens.ink(context),
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.daily});

  final DailyProgress daily;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final color = dark ? AppColors.greenNight : AppColors.green;
    final label = '${daily.sessions.clamp(0, 99)}/${daily.goal}';
    return _Chip(
      semantics:
          'Daily goal: ${daily.sessions} of ${daily.goal} lessons today'
          '${daily.reached ? ', reached' : ''}',
      onTap: () {
        Analytics.track('daily_goal_tapped', {
          'sessions': daily.sessions,
          'goal': daily.goal,
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                daily.reached
                    ? 'Daily goal reached: ${daily.sessions} lessons today.'
                    : '${daily.sessions} of ${daily.goal} lessons today. '
                        'Finish ${daily.goal - daily.sessions} more for your daily goal.',
              ),
            ),
          );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SessionRing(
                  size: 26,
                  stroke: 4,
                  progress: daily.progress,
                  color: color,
                  track: AppTokens.tint(color, context, opacity: 0.22),
                ),
                if (daily.reached)
                  Icon(Icons.check_rounded, size: 14, color: color),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.ink(context),
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// The streak calendar as a sheet over Home, with the way to the full
/// streak screen at the top.
Future<void> showStreakSheet(BuildContext context, {required String source}) {
  Analytics.track('streak_sheet_opened', {'source': source});
  final height = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTokens.background(context),
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (sheetContext) {
      final progress = sheetContext.watch<ProgressService>();
      final tier = StreakRules.tierFor(progress.currentStreak);
      return SizedBox(
        height: height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  StreakFlame(tier: tier, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${progress.currentStreak} day streak',
                      style: AppTextStyles.title(sheetContext),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Analytics.track('streak_details_opened', {
                        'source': 'streak_sheet',
                      });
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        screenRoute('streak', (_) => const StreakViewScreen()),
                      );
                    },
                    child: const Text('Streak details'),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.hero),
                ),
                // The sheet has its own header row above.
                child: StreakCalendarScreen(showAppBar: false),
              ),
            ),
          ],
        ),
      );
    },
  );
}
