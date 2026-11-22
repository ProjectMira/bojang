import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_tokens.dart';
import '../utils/streak_rules.dart';
import 'app_text_style.dart';
import 'streak_day_bubble.dart';

/// "Earn back your streak": shown on Home and the Streak screen while a
/// broken streak can still come back. Says the days left and the lessons
/// done, and starts a lesson when tapped.
class EarnBackCard extends StatelessWidget {
  const EarnBackCard({
    super.key,
    required this.earnBack,
    required this.today,
    this.onStart,
    this.compact = false,
  });

  final EarnBack earnBack;
  final DateTime today;
  final VoidCallback? onStart;

  /// Home's one-line version; the Streak screen explains the rule too.
  final bool compact;

  static String progressLine(EarnBack e, DateTime today) {
    final days = e.daysLeft(today);
    final dayText = days <= 1 ? 'Last day' : '$days days left';
    return '$dayText, ${e.sessionsDone} of ${e.sessionsNeeded} lessons';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF2C3E50);
    final subtle = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final left = earnBack.sessionsNeeded - earnBack.sessionsDone;
    final byDay = DateFormat.EEEE().format(earnBack.expires);
    final line = progressLine(earnBack, today);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StreakColors.fire.withValues(alpha: isDark ? 0.22 : 0.14),
            ),
            child: const Icon(
              Icons.replay_rounded,
              color: StreakColors.fireDeep,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn back your ${earnBack.streak}-day streak',
                  style: AppTextStyles.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: AppTextStyles.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: StreakColors.fireDeep,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    left == 1
                        ? 'One more lesson by $byDay and your streak comes back '
                            'as if it never broke.'
                        : 'Finish $left lessons by $byDay and your streak comes '
                            'back as if it never broke.',
                    style: AppTextStyles.poppins(fontSize: 13, color: subtle),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < earnBack.sessionsNeeded; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _pip(
                          done: i < earnBack.sessionsDone,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onStart != null)
            const Icon(Icons.chevron_right, color: StreakColors.fireDeep),
        ],
      ),
    );

    return Semantics(
      button: onStart != null,
      label:
          'Earn back your ${earnBack.streak}-day streak. $line. '
          'Finish $left more by $byDay.',
      excludeSemantics: true,
      child: Material(
        color: isDark ? AppColors.orangeNightTint : AppColors.orangeTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onStart,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: StreakColors.fire.withValues(alpha: 0.55),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _pip({required bool done, required bool isDark}) {
    return Container(
      width: 28,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color:
            done
                ? StreakColors.fire
                : (isDark
                    ? Colors.white24
                    : StreakColors.fire.withValues(alpha: 0.2)),
      ),
    );
  }
}
