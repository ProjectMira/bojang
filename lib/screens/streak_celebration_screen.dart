import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/analytics.dart';
import '../services/notification_primer.dart';
import '../services/progress_service.dart';
import '../utils/streak_calendar.dart';
import '../utils/streak_rules.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/streak_day_bubble.dart';

/// Shown after the first practice of each day, after Duolingo's streak
/// screen: the new streak count, the week, and — when it applies — a
/// milestone, a freeze earned or used, and a streak goal to commit to.
///
/// Duolingo measured the streak animation and milestone celebrations at
/// +1.7% day-7 retention, and asking new learners to commit to a streak goal
/// as one of its retention wins.
class StreakCelebrationScreen extends StatefulWidget {
  const StreakCelebrationScreen({super.key, required this.celebration, this.now});

  final StreakCelebration celebration;

  /// Overrides "today" in tests.
  final DateTime? now;

  /// Shows the waiting celebration, if the last practice extended the
  /// streak. Completes when the learner closes it.
  static Future<void> maybeShow(BuildContext context) async {
    final celebration =
        Provider.of<ProgressService>(context, listen: false)
            .takeStreakCelebration();
    if (celebration == null || !context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'streak_celebration'),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                StreakCelebrationScreen(celebration: celebration),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
    if (context.mounted) await NotificationPrimer.instance.afterStreakCelebration(context, celebration);
  }

  @override
  State<StreakCelebrationScreen> createState() =>
      _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends State<StreakCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final ConfettiController _confetti;
  late int _goalChoice;
  bool _goalSaved = false;

  StreakCelebration get c => widget.celebration;

  /// No goal yet: offer one. Goal just reached: offer the next.
  int? get _offeredGoal {
    if (c.goal == 0) return 7;
    if (c.goalReached) return StreakRules.nextGoal(c.goal);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _goalChoice = _offeredGoal ?? 7;
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 2000));
    if (c.isMilestone || c.goalReached) _confetti.play();
    Analytics.track('streak_celebration_shown', {
      'streak': c.streak,
      'milestone': c.isMilestone,
      'goal': c.goal,
      'goal_reached': c.goalReached,
      'freeze_earned': c.freezeEarned,
      'freezes_used': c.freezesUsed,
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _confetti.dispose();
    super.dispose();
  }

  String get _headline {
    if (c.goalReached) return 'Goal reached!';
    if (c.isMilestone) return '${c.streak}-day milestone!';
    if (c.streak == 1) return 'Your streak has started!';
    return 'Streak extended!';
  }

  Future<void> _close({required String action}) async {
    final offered = _offeredGoal;
    if (action == 'commit' && offered != null && !_goalSaved) {
      _goalSaved = true;
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).setStreakGoal(_goalChoice);
    }
    Analytics.track('streak_celebration_closed', {
      'action': action,
      'streak': c.streak,
      if (action == 'commit') 'goal': _goalChoice,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF2C3E50);
    final subtle = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final offered = _offeredGoal;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            ContentWidth(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    _flame(),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      label: '${c.streak} day streak',
                      excludeSemantics: true,
                      child: Text(
                        '${c.streak}',
                        style: AppTextStyles.poppins(
                          fontSize: 72,
                          fontWeight: FontWeight.w800,
                          color: StreakColors.fireDeep,
                        ),
                      ),
                    ),
                    Text(
                      'day streak',
                      style: AppTextStyles.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: StreakColors.fire,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _headline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One lesson a day keeps your streak going.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.poppins(fontSize: 15, color: subtle),
                    ),
                    const SizedBox(height: 20),
                    _week(isDark),
                    if (c.freezesUsed > 0) ...[
                      const SizedBox(height: 16),
                      _note(
                        icon: Icons.ac_unit,
                        color: StreakColors.ice,
                        text:
                            c.freezesUsed == 1
                                ? 'A streak freeze covered the day you missed, so your streak is safe.'
                                : 'Streak freezes covered the ${c.freezesUsed} days you missed, so your streak is safe.',
                        isDark: isDark,
                      ),
                    ],
                    if (c.freezeEarned) ...[
                      const SizedBox(height: 16),
                      _note(
                        icon: Icons.ac_unit,
                        color: StreakColors.ice,
                        text:
                            'You earned a streak freeze! If you miss a day, it '
                            'keeps your streak alive automatically.',
                        isDark: isDark,
                      ),
                    ],
                    if (offered != null) ...[
                      const SizedBox(height: 20),
                      _goalPicker(offered, ink, subtle, isDark),
                    ] else if (c.goal > 0 && c.streak < c.goal) ...[
                      const SizedBox(height: 16),
                      _goalProgress(ink, subtle),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: StreakColors.fire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed:
                            () => _close(
                              action: offered != null ? 'commit' : 'continue',
                            ),
                        child: Text(
                          offered != null ? 'Commit to my goal' : 'Continue',
                          style: AppTextStyles.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (offered != null)
                      TextButton(
                        onPressed: () => _close(action: 'not_now'),
                        child: Text(
                          'Not now',
                          style: AppTextStyles.poppins(fontSize: 15, color: subtle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.08,
                numberOfParticles: 14,
                maxBlastForce: 20,
                minBlastForce: 8,
                gravity: 0.25,
                colors: const [
                  StreakColors.fire,
                  StreakColors.fireDeep,
                  Colors.amber,
                  StreakColors.ice,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flame() {
    final scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
    return ScaleTransition(
      scale: scale,
      child: const Text('🔥', style: TextStyle(fontSize: 96, height: 1.1)),
    );
  }

  Widget _week(bool isDark) {
    final progress = Provider.of<ProgressService>(context, listen: false);
    final today = widget.now ?? DateTime.now();
    final calendar = StreakCalendar(
      progress.playDates,
      frozenDates: progress.frozenDates,
      now: today,
    );
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = DateTime(
          today.year,
          today.month,
          today.day - (today.weekday - 1) + i,
        );
        final isToday = StreakCalendar.dayKey(day) == calendar.today;
        return Column(
          children: [
            Text(
              letters[i],
              style: AppTextStyles.poppins(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color:
                    isToday
                        ? StreakColors.fire
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 6),
            StreakDayBubble(
              state: calendar.stateOf(day),
              size: 38,
              isToday: isToday,
            ),
          ],
        );
      }),
    );
  }

  Widget _note({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? StreakColors.iceFillDark : StreakColors.iceFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StreakColors.iceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.poppins(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1B4F72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalPicker(int offered, Color ink, Color subtle, bool isDark) {
    final reached = c.goalReached;
    final options =
        reached
            ? [offered, if (StreakRules.nextGoal(offered) != null) StreakRules.nextGoal(offered)!]
            : const [7, 14, 30];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StreakColors.fire.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            reached ? 'Set your next goal' : 'Commit to a streak goal',
            style: AppTextStyles.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reached
                ? 'You did ${c.goal} days in a row. Keep the flame going.'
                : 'Learners who pick a goal are more likely to keep practicing.',
            textAlign: TextAlign.center,
            style: AppTextStyles.poppins(fontSize: 13, color: subtle),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final g in options)
                ChoiceChip(
                  label: Text('$g days'),
                  selected: _goalChoice == g,
                  selectedColor: StreakColors.fire.withOpacity(0.2),
                  onSelected: (_) => setState(() => _goalChoice = g),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalProgress(Color ink, Color subtle) {
    final fraction = (c.streak / c.goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Text(
          'Day ${c.streak} of your ${c.goal}-day goal',
          style: AppTextStyles.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            color: StreakColors.fire,
            backgroundColor: StreakColors.fire.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}
