import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/progress_service.dart';
import 'level_selection_screen.dart';

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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStreakHero(progress, practicedToday),
                const SizedBox(height: 16),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMilestoneCard(context, progress, isDark, titleColor),
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
          ),
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
          colors: [Color(0xFFFF9600), Color(0xFFFF5722)],
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
          const Text('🔥', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(
            '${progress.currentStreak}',
            style: GoogleFonts.poppins(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.0,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
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

  Widget _buildWeekRow(
    BuildContext context,
    ProgressService progress,
    bool isDark,
    Color titleColor,
  ) {
    final today = DateTime.now();
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
          Text(
            'This Week',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              // Monday-first week containing today.
              final day = today.subtract(
                Duration(days: today.weekday - 1 - index),
              );
              final practiced = _practicedOn(progress, day);
              final isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final isFuture = day.isAfter(today);

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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          practiced
                              ? Colors.orange
                              : isDark
                              ? Colors.white10
                              : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border:
                          isToday
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                    ),
                    child: Center(
                      child:
                          practiced
                              ? const Text(
                                '🔥',
                                style: TextStyle(fontSize: 16),
                              )
                              : isFuture
                              ? null
                              : Icon(
                                Icons.remove,
                                size: 16,
                                color:
                                    isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                              ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        children: [
          Icon(icon, color: color, size: 28),
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
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    ProgressService progress,
    bool isDark,
    Color titleColor,
  ) {
    final streak = progress.currentStreak;
    final milestone = _nextMilestone(streak);
    final fraction = (streak / milestone).clamp(0.0, 1.0);

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
                'Next Milestone',
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
                : 'Keep practicing daily to reach $milestone days!',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
        ],
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
        color: isDark ? Colors.amber.withOpacity(0.12) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? Colors.amber.withOpacity(0.3) : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber.shade700, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _motivationalMessage(progress.currentStreak, practicedToday),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LevelSelectionScreen(),
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
