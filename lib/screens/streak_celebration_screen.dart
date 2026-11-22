import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/analytics.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../utils/streak_calendar.dart';
import '../utils/streak_rules.dart';
import '../widgets/app_text_style.dart';
import '../widgets/earn_back_card.dart';
import '../widgets/session_end_scaffold.dart';
import '../widgets/streak_day_bubble.dart';
import '../widgets/streak_flame.dart';

/// Shown after the first practice of each day, after Duolingo's streak
/// screen: the new streak count, the week, and — when it applies — a
/// milestone, a freeze earned or used, a streak goal to commit to, the
/// flame growing a tier (or a tease the day before), Earn Back progress,
/// and a restored streak (which can also come on a second lesson the same
/// day).
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
  /// streak. Completes when the learner closes it, with whether it showed.
  static Future<bool> maybeShow(BuildContext context) async {
    final celebration =
        Provider.of<ProgressService>(context, listen: false)
            .takeStreakCelebration();
    if (celebration == null || !context.mounted) return false;
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
    return true;
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
  bool _started = false;

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
    );
    _confetti = ConfettiController(duration: const Duration(milliseconds: 2000));
    Analytics.track('streak_celebration_shown', {
      'streak': c.streak,
      'milestone': c.isMilestone,
      'goal': c.goal,
      'goal_reached': c.goalReached,
      'freeze_earned': c.freezeEarned,
      'freezes_used': c.freezesUsed,
      'tier': c.tier.name,
      'tier_up': c.tierUp,
      'restored': c.restored,
      if (c.earnBack != null) 'earn_back_sessions': c.earnBack!.sessionsDone,
    });
    if (c.tierUp) {
      Analytics.track('streak_tier_reached', {
        'streak': c.streak,
        'tier': c.tier.name,
      });
    } else if (c.tierTomorrow != null && !c.restored) {
      Analytics.track('streak_tier_teased', {
        'streak': c.streak,
        'tier': c.tierTomorrow!.name,
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce Motion (system or Settings > Animations): the flame is simply
    // there, and no confetti falls. Reduced keeps the pop, not the confetti.
    final motion = Motion.of(context);
    if (!motion.animates) {
      _pop.value = 1;
      return;
    }
    _pop.forward();
    if ((c.isMilestone || c.goalReached || c.tierUp || c.restored) &&
        motion.allowsCelebration) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _confetti.dispose();
    super.dispose();
  }

  String get _headline {
    if (c.restored) return 'Streak restored!';
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

    // Same layout as every session-end screen: Continue stays in place.
    return SessionEndScaffold(
      primaryColor: StreakColors.fire,
      primaryLabel: offered != null ? 'Commit to my goal' : 'Continue',
      onPrimary:
          () => _close(action: offered != null ? 'commit' : 'continue'),
      secondaryLabel: offered != null ? 'Not now' : null,
      onSecondary: () => _close(action: 'not_now'),
      overlays: [
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
      body: Column(
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
                      c.restored
                          ? 'You earned it back. Your streak carries on as if it never broke.'
                          : c.tierUp
                          ? 'Your flame grew into a ${c.tier.label}.'
                          : 'One lesson a day keeps your streak going.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.poppins(fontSize: 15, color: subtle),
                    ),
                    const SizedBox(height: 20),
                    _week(isDark),
                    if (c.earnBack != null && !c.restored) ...[
                      const SizedBox(height: 16),
                      _earnBackNote(c.earnBack!, ink, subtle, isDark),
                    ],
                    if (!c.tierUp && !c.restored && c.tierTomorrow != null) ...[
                      const SizedBox(height: 16),
                      _tease(c.tierTomorrow!, ink, isDark),
                    ],
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
                  ],
      ),
    );
  }

  Widget _flame() {
    final scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
    final previous = StreakRules.tierFor(c.previousStreak ?? c.streak - 1);
    return ScaleTransition(
      scale: scale,
      child: StreakFlame(
        tier: c.tier,
        size: 112,
        from: c.tierUp ? previous : null,
      ),
    );
  }

  Widget _earnBackNote(EarnBack e, Color ink, Color subtle, bool isDark) {
    final today = widget.now ?? DateTime.now();
    final left = e.sessionsNeeded - e.sessionsDone;
    final byDay = DateFormat.EEEE().format(e.expires);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.orangeNightTint : AppColors.orangeTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StreakColors.fire.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.replay_rounded, color: StreakColors.fireDeep, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn back your ${e.streak}-day streak',
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${EarnBackCard.progressLine(e, today)}. '
                  '${left == 1 ? 'One more lesson' : '$left more lessons'} '
                  'by $byDay brings it back.',
                  style: AppTextStyles.poppins(fontSize: 13, color: subtle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The day before the flame grows: a dim preview of tomorrow's flame.
  Widget _tease(FlameTier next, Color ink, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreakFlame(tier: next, size: 34, dimmed: true),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Come back tomorrow and your flame grows into a ${next.label}.',
            style: AppTextStyles.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _week(bool isDark) {
    final progress = Provider.of<ProgressService>(context, listen: false);
    final today = widget.now ?? DateTime.now();
    final calendar = StreakCalendar(
      progress.playDates,
      frozenDates: progress.frozenDates,
      earnedBackDates: progress.earnedBackDates,
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
            : const [7, 14, 30, 50];
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
