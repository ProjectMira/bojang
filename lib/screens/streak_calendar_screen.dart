import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/analytics.dart';
import '../services/progress_service.dart';
import '../utils/streak_calendar.dart';
import '../widgets/content_width.dart';
import '../widgets/streak_day_bubble.dart';

/// A month calendar of the learner's practice, after Duolingo's streak
/// calendar: practiced days show a flame and runs of them are joined by a
/// band. Days a streak freeze protected show as ice. Other missed days stay
/// plain (just the number): research on streaks finds a highlighted break
/// discourages learners more than no record at all.
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key, this.now});

  /// Overrides "today" in tests.
  final DateTime? now;

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  TextStyle _poppins(double size, FontWeight weight, Color color) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']);

  void _go(int delta, StreakCalendar calendar) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(calendar.firstMonth) ||
        next.isAfter(calendar.currentMonth)) {
      return;
    }
    Analytics.track('streak_calendar_month_changed', {
      'direction': delta > 0 ? 'next' : 'previous',
    });
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    final subtleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Consumer<ProgressService>(
      builder: (context, progress, _) {
        final calendar = StreakCalendar(
          progress.playDates,
          frozenDates: progress.frozenDates,
          now: widget.now,
        );
        final canGoBack = _month.isAfter(calendar.firstMonth);
        final canGoForward = _month.isBefore(calendar.currentMonth);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Streak Calendar',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: ContentWidth(
            maxWidth: ContentWidth.reading,
            child: GestureDetector(
              // Swipe between months, like flipping a calendar.
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v.abs() < 200) return;
                _go(v < 0 ? 1 : -1, calendar);
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(context, calendar, isDark, titleColor, subtleColor),
                    const SizedBox(height: 16),
                    _card(
                      context,
                      child: Column(
                        children: [
                          _monthHeader(
                            calendar,
                            canGoBack,
                            canGoForward,
                            titleColor,
                          ),
                          const SizedBox(height: 12),
                          _weekdayHeader(subtleColor),
                          const SizedBox(height: 6),
                          _grid(calendar),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _legend(context, subtleColor),
                    const SizedBox(height: 12),
                    Text(
                      'Practice history is kept on this device.',
                      textAlign: TextAlign.center,
                      style: _poppins(12, FontWeight.w400, subtleColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
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
      child: child,
    );
  }

  Widget _summary(
    BuildContext context,
    StreakCalendar calendar,
    bool isDark,
    Color titleColor,
    Color subtleColor,
  ) {
    final practiced = calendar.countIn(_month, StreakDayState.practiced);
    final total = calendar.totalPracticedDays;

    Widget tile(Widget icon, int value, String label, Color tint) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: tint.withOpacity(isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value', style: _poppins(22, FontWeight.bold, titleColor)),
                    Text(
                      label,
                      style: _poppins(12, FontWeight.w500, subtleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(
          const Text('🔥', style: TextStyle(fontSize: 26)),
          practiced,
          practiced == 1 ? 'Day this month' : 'Days this month',
          StreakColors.fire,
        ),
        const SizedBox(width: 12),
        tile(
          const Icon(
            Icons.emoji_events_rounded,
            size: 26,
            color: StreakColors.fireDeep,
          ),
          total,
          total == 1 ? 'Day in total' : 'Days in total',
          StreakColors.fireDeep,
        ),
      ],
    );
  }

  Widget _monthHeader(
    StreakCalendar calendar,
    bool canGoBack,
    bool canGoForward,
    Color titleColor,
  ) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: canGoBack ? () => _go(-1, calendar) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM().format(_month),
            textAlign: TextAlign.center,
            style: _poppins(18, FontWeight.w600, titleColor),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: canGoForward ? () => _go(1, calendar) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _weekdayHeader(Color color) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final l in letters)
          Expanded(
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: _poppins(12, FontWeight.w600, color),
            ),
          ),
      ],
    );
  }

  Widget _grid(StreakCalendar calendar) {
    final cells = StreakCalendar.monthGrid(_month);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final bubble = (cellWidth * 0.78).clamp(28.0, 56.0);
        return Column(
          children: [
            for (var row = 0; row < cells.length ~/ 7; row++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    _cell(
                      calendar,
                      cells,
                      row * 7 + col,
                      col,
                      cellWidth,
                      bubble,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _cell(
    StreakCalendar calendar,
    List<DateTime?> cells,
    int index,
    int col,
    double width,
    double bubble,
  ) {
    final day = cells[index];
    final height = bubble + 22;
    if (day == null) return SizedBox(width: width, height: height);

    final state = calendar.stateOf(day);
    final isToday = StreakCalendar.dayKey(day) == calendar.today;
    final practiced = state == StreakDayState.practiced;

    // Join runs of practiced days within a week row with a band.
    bool practicedAt(int i) =>
        i >= 0 &&
        i < cells.length &&
        cells[i] != null &&
        calendar.isPracticed(cells[i]!);
    final joinLeft = practiced && col > 0 && practicedAt(index - 1);
    final joinRight = practiced && col < 6 && practicedAt(index + 1);
    // Full-height and solid, so a run of days reads as one pill.
    const bandColor = StreakColors.fire;
    final bandHeight = bubble;

    return Semantics(
      label: '${DateFormat.MMMMd().format(day)}, ${_describe(state)}',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(
              // Full cell width, so the band can reach the neighbour.
              width: width,
              height: bubble + 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (joinLeft)
                    Positioned(
                      left: 0,
                      right: width / 2,
                      height: bandHeight,
                      child: ColoredBox(color: bandColor),
                    ),
                  if (joinRight)
                    Positioned(
                      left: width / 2,
                      right: 0,
                      height: bandHeight,
                      child: ColoredBox(color: bandColor),
                    ),
                  StreakDayBubble(
                    state: state,
                    size: bubble,
                    isToday: isToday,
                    label: '${day.day}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // A flame or ice hides the number, so it goes underneath.
            if (practiced || state == StreakDayState.frozen)
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: practiced ? StreakColors.fireDeep : StreakColors.ice,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _describe(StreakDayState state) {
    switch (state) {
      case StreakDayState.practiced:
        return 'practiced';
      case StreakDayState.frozen:
        return 'protected by a streak freeze';
      case StreakDayState.missed:
        return 'not practiced';
      case StreakDayState.open:
        return 'today, not practiced yet';
      case StreakDayState.future:
        return 'upcoming';
      case StreakDayState.beforeStart:
        return 'before you started';
    }
  }

  Widget _legend(BuildContext context, Color textColor) {
    Widget item(StreakDayState state, String text, {bool today = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreakDayBubble(state: state, size: 24, isToday: today),
          const SizedBox(width: 6),
          Text(text, style: _poppins(12, FontWeight.w500, textColor)),
        ],
      );
    }

    return _card(
      context,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: [
          item(StreakDayState.practiced, 'Practiced'),
          item(StreakDayState.frozen, 'Streak freeze'),
          item(StreakDayState.open, 'Today', today: true),
        ],
      ),
    );
  }
}
