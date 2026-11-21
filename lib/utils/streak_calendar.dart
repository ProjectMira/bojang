/// How a calendar day looks on the streak screens.
enum StreakDayState {
  /// The learner practiced that day: shown with a flame.
  practiced,

  /// A past day after the learner started, with no practice: shown frozen.
  frozen,

  /// Today, not practiced yet: still open, so not frozen.
  open,

  /// A day that hasn't happened yet.
  future,

  /// A day before the learner's first practice: nothing to show.
  beforeStart,
}

/// Turns the device's practice history into calendar states, independent of
/// any widget so it can be unit-tested. Days are local calendar days.
class StreakCalendar {
  StreakCalendar(Iterable<DateTime> playDates, {DateTime? now})
    : practicedDays = {for (final d in playDates) dayKey(d)},
      today = dayKey(now ?? DateTime.now());

  final Set<DateTime> practicedDays;
  final DateTime today;

  static DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The first day the learner practiced, or null if never.
  DateTime? get firstDay =>
      practicedDays.isEmpty
          ? null
          : practicedDays.reduce((a, b) => a.isBefore(b) ? a : b);

  bool isPracticed(DateTime day) => practicedDays.contains(dayKey(day));

  StreakDayState stateOf(DateTime day) {
    final d = dayKey(day);
    if (practicedDays.contains(d)) return StreakDayState.practiced;
    if (d.isAfter(today)) return StreakDayState.future;
    if (d == today) return StreakDayState.open;
    final first = firstDay;
    if (first == null || d.isBefore(first)) return StreakDayState.beforeStart;
    return StreakDayState.frozen;
  }

  /// The earliest month worth showing: the month of the first practice, or
  /// this month for a learner who hasn't practiced yet.
  DateTime get firstMonth {
    final first = firstDay ?? today;
    final start = first.isAfter(today) ? today : first;
    return DateTime(start.year, start.month);
  }

  DateTime get currentMonth => DateTime(today.year, today.month);

  static int daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// The month laid out Monday-first, in whole weeks: null pads the days
  /// before the 1st and after the last day.
  static List<DateTime?> monthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1; // Monday = 1
    final count = daysInMonth(month);
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= count; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  int countIn(DateTime month, StreakDayState state) {
    var n = 0;
    for (var d = 1; d <= daysInMonth(month); d++) {
      if (stateOf(DateTime(month.year, month.month, d)) == state) n++;
    }
    return n;
  }
}
