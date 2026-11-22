import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/analytics.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/yak_mascot.dart';
import '../utils/streak_calendar.dart';
import '../utils/streak_rules.dart';
import '../widgets/earn_back_card.dart';
import '../widgets/streak_day_bubble.dart';
import '../widgets/streak_flame.dart';
import 'level_selection_screen.dart';
import 'streak_calendar_screen.dart';
import '../widgets/content_width.dart';

class StreakViewScreen extends StatelessWidget {
  const StreakViewScreen({super.key});

  static const List<int> _milestones = [3, 7, 14, 30, 50, 100];

  bool _practicedOn(ProgressService progress, DateTime day) {
    return progress.playDates.any(
      (date) =>
          date.year == day.year &&
          date.month == day.month &&
          date.day == day.day,
    );
  }

  int _nextMilestone(int streak) {
    for (final milestone in _milestones) {
      if (streak < milestone) return milestone;
    }
    return ((streak ~/ 100) + 1) * 100;
  }

  void _openCalendar(BuildContext context, String source) {
    Analytics.track('streak_calendar_opened', {'source': source});
    Navigator.push(
      context,
      screenRoute('streak_calendar', (context) => const StreakCalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Consumer<ProgressService>(
      builder: (context, progress, child) {
        final practicedToday = _practicedOn(progress, DateTime.now());

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Your Streak',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: ContentWidth(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStreakHero(progress, practicedToday),
                const SizedBox(height: 16),
                if (progress.earnBack != null) ...[
                  _buildEarnBack(context, progress.earnBack!),
                  const SizedBox(height: 16),
                ],
                _buildWeekRow(context, progress, isDark, titleColor),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Longest Streak',
                        '${progress.longestStreak}',
                        'days',
                        Icons.emoji_events,
                        Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Practice',
                        '${progress.playDates.length}',
                        'days',
                        Icons.calendar_month,
                        Colors.green,
                        onTap: () => _openCalendar(context, 'total_practice'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMilestoneCard(context, progress, isDark, titleColor),
                const SizedBox(height: 16),
                _buildFreezeCard(context, progress, isDark, titleColor),
                const SizedBox(height: 16),
                _buildMotivationCard(context, progress, practicedToday, isDark),
                const SizedBox(height: 24),
                _buildPracticeButton(context, practicedToday),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    practicedToday
                        ? 'Come back tomorrow to keep the flame alive!'
                        : 'One short lesson keeps your streak alive.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: subtitleColor,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ),
              ],
            ),
          ),),
        );
      },
    );
  }

  Widget _buildStreakHero(ProgressService progress, bool practicedToday) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [StreakColors.fire, StreakColors.fireDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // The yak wears the streak: asleep at zero, urging you on while
          // today is still open, proud once it is done.
          Container(
            width: 148,
            height: 148,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: YakMascot(
              mood: YakLines.streakMood(
                streak: progress.currentStreak,
                practicedToday: practicedToday,
              ),
              size: 128,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreakFlame(
                tier: StreakRules.tierFor(progress.currentStreak),
                size: 52,
              ),
              const SizedBox(width: 6),
              Text(
                '${progress.currentStreak}',
                style: GoogleFonts.poppins(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            ],
          ),
          Text(
            progress.currentStreak == 1 ? 'Day Streak' : 'Days Streak',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white70,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              practicedToday
                  ? '✓ Practiced today'
                  : 'Practice today to keep it going',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnBack(BuildContext context, EarnBack earnBack) {
    final now = DateTime.now();
    return EarnBackCard(
      earnBack: earnBack,
      today: now,
      onStart: () {
        Analytics.track('earn_back_card_tapped', {
          'source': 'streak',
          'streak': earnBack.streak,
          'sessions_done': earnBack.sessionsDone,
          'days_left': earnBack.daysLeft(now),
        });
        Navigator.push(
          context,
          screenRoute(
            'level_selection',
            (context) => const LevelSelectionScreen(),
          ),
        );
      },
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    ProgressService progress,
    bool isDark,
    Color titleColor,
  ) {
    final today = DateTime.now();
    final calendar = StreakCalendar(
      progress.playDates,
      frozenDates: progress.frozenDates,
      earnedBackDates: progress.earnedBackDates,
      now: today,
    );
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'This Week',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const Spacer(),
              Text(
                'See calendar',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: StreakColors.fire,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: StreakColors.fire,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              // Monday-first week containing today.
              final day = today.subtract(
                Duration(days: today.weekday - 1 - index),
              );
              final state = calendar.stateOf(day);
              final isToday = StreakCalendar.dayKey(day) == calendar.today;

              return Column(
                children: [
                  Text(
                    dayLetters[index],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.w500,
                      color:
                          isToday
                              ? Colors.orange
                              : isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                  const SizedBox(height: 6),
                  StreakDayBubble(state: state, size: 36, isToday: isToday),
                ],
              );
            }),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      hint: 'Opens the streak calendar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCalendar(context, 'this_week'),
          child: card,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String unit,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2C3E50),
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          Text(
            '$title ($unit)',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      hint: 'Opens the streak calendar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    ProgressService progress,
    bool isDark,
    Color titleColor,
  ) {
    final streak = progress.currentStreak;
    // A goal the learner committed to comes first; then the next milestone.
    final goal = progress.streakGoal;
    final hasGoal = goal > streak;
    final milestone = hasGoal ? goal : _nextMilestone(streak);
    final fraction = (streak / milestone).clamp(0.0, 1.0);
    final nextTierAt = StreakRules.nextTierAt(streak);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                hasGoal ? 'Your Goal' : 'Next Milestone',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const Spacer(),
              Text(
                '$streak / $milestone days',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor:
                  isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            streak == 0
                ? 'Complete a lesson today to start your streak.'
                : hasGoal
                ? 'You committed to $goal days. ${goal - streak} to go!'
                : 'Keep practicing daily to reach $milestone days!',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          if (nextTierAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                StreakFlame(
                  tier: StreakRules.tierFor(nextTierAt),
                  size: 26,
                  dimmed: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextTierAt - streak == 1
                        ? 'Tomorrow your flame grows into a '
                            '${StreakRules.tierFor(nextTierAt).label}.'
                        : 'Your flame grows into a '
                            '${StreakRules.tierFor(nextTierAt).label} at $nextTierAt days.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreezeCard(
    BuildContext context,
    ProgressService progress,
    bool isDark,
    Color titleColor,
  ) {
    final held = progress.streakFreezes;
    final streak = progress.currentStreak;
    final toNext =
        StreakRules.freezeEveryDays - (streak % StreakRules.freezeEveryDays);
    final full = held >= StreakRules.maxFreezes;

    return Semantics(
      label:
          'Streak freezes: $held of ${StreakRules.maxFreezes}. '
          'Earned every ${StreakRules.freezeEveryDays} days of streak, '
          'used automatically if you miss a day.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? StreakColors.iceFillDark : StreakColors.iceFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StreakColors.iceBorder),
        ),
        child: Row(
          children: [
            for (var i = 0; i < StreakRules.maxFreezes; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Opacity(
                  opacity: i < held ? 1 : 0.3,
                  child: const StreakDayBubble(
                    state: StreakDayState.frozen,
                    size: 34,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Streak freezes: $held/${StreakRules.maxFreezes}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    full
                        ? 'Fully stocked. A freeze is used automatically if you miss a day.'
                        : 'Earn one every ${StreakRules.freezeEveryDays} days of streak '
                            '($toNext to go). Used automatically if you miss a day.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationCard(
    BuildContext context,
    ProgressService progress,
    bool practicedToday,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.goldNightTint : AppColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: isDark ? 0.3 : 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? AppColors.goldNight : AppColors.goldLip,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _motivationalMessage(progress.currentStreak, practicedToday),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                // Amber text on the amber tint was about 2.6:1.
                color: AppTokens.textOnTint(AppColors.gold, context),
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeButton(BuildContext context, bool practicedToday) {
    return ElevatedButton.icon(
      onPressed: () {
        Analytics.track('streak_practice_tapped', {
          'practiced_today': practicedToday,
        });
        Navigator.push(
          context,
          screenRoute(
            'level_selection',
            (context) => const LevelSelectionScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            practicedToday ? Colors.green : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(practicedToday ? Icons.add_circle : Icons.play_arrow_rounded),
      label: Text(
        practicedToday ? 'Practice More' : 'Practice Now',
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      ),
    );
  }

  String _motivationalMessage(int streak, bool practicedToday) {
    if (streak == 0) {
      return 'Every expert was once a beginner. One short lesson today starts your journey!';
    }
    if (streak < 3) {
      return practicedToday
          ? 'Great start! Two more days and you\'ll hit your first milestone.'
          : 'Don\'t lose your momentum — a quick lesson keeps your streak alive.';
    }
    if (streak < 7) {
      return 'You\'re building a real habit. A week-long streak is within reach!';
    }
    if (streak < 14) {
      return 'A full week of Tibetan — ལེགས་སོ། You\'re on fire!';
    }
    if (streak < 30) {
      return 'Two weeks strong! Your dedication is turning into real knowledge.';
    }
    return 'Incredible commitment! You\'re an inspiration to every learner.';
  }
}
