import 'package:bojang/utils/streak_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saturday 21 November 2026, mid-afternoon.
  final now = DateTime(2026, 11, 21, 15, 30);

  group('StreakCalendar.stateOf', () {
    final calendar = StreakCalendar([
      DateTime(2026, 11, 3, 9, 15), // times are ignored
      DateTime(2026, 11, 4),
      DateTime(2026, 11, 10, 23, 59),
    ], now: now);

    test('practiced days are practiced whatever the time of day', () {
      expect(calendar.stateOf(DateTime(2026, 11, 3)), StreakDayState.practiced);
      expect(
        calendar.stateOf(DateTime(2026, 11, 10, 1)),
        StreakDayState.practiced,
      );
    });

    test('missed past days after the first practice are frozen', () {
      expect(calendar.stateOf(DateTime(2026, 11, 5)), StreakDayState.frozen);
      expect(calendar.stateOf(DateTime(2026, 11, 20)), StreakDayState.frozen);
    });

    test('days before the first practice are not frozen', () {
      expect(
        calendar.stateOf(DateTime(2026, 11, 2)),
        StreakDayState.beforeStart,
      );
      expect(
        calendar.stateOf(DateTime(2026, 10, 30)),
        StreakDayState.beforeStart,
      );
    });

    test('today stays open until practiced, then shows a flame', () {
      expect(calendar.stateOf(now), StreakDayState.open);
      final practicedToday = StreakCalendar([
        DateTime(2026, 11, 21, 8),
      ], now: now);
      expect(practicedToday.stateOf(now), StreakDayState.practiced);
    });

    test('tomorrow is in the future', () {
      expect(calendar.stateOf(DateTime(2026, 11, 22)), StreakDayState.future);
    });

    test('a learner who never practiced has no frozen days', () {
      final empty = StreakCalendar(const [], now: now);
      expect(
        empty.stateOf(DateTime(2026, 11, 20)),
        StreakDayState.beforeStart,
      );
      expect(empty.firstMonth, DateTime(2026, 11));
    });

    test('duplicate play dates count once', () {
      final dup = StreakCalendar([
        DateTime(2026, 11, 3, 8),
        DateTime(2026, 11, 3, 20),
      ], now: now);
      expect(dup.countIn(DateTime(2026, 11), StreakDayState.practiced), 1);
    });
  });

  group('StreakCalendar month counts and range', () {
    final calendar = StreakCalendar([
      DateTime(2026, 10, 30),
      DateTime(2026, 11, 3),
      DateTime(2026, 11, 4),
    ], now: now);

    test('November: 2 practiced, 18 frozen up to yesterday', () {
      final nov = DateTime(2026, 11);
      expect(calendar.countIn(nov, StreakDayState.practiced), 2);
      // Nov 1-20 is 20 past days, minus the 2 practiced and nothing before
      // the start (the first practice was in October) = 18.
      expect(calendar.countIn(nov, StreakDayState.frozen), 18);
    });

    test('the first month is the month of the first practice', () {
      expect(calendar.firstMonth, DateTime(2026, 10));
      expect(calendar.currentMonth, DateTime(2026, 11));
    });
  });

  group('StreakCalendar.monthGrid', () {
    test('November 2026 starts on a Sunday, so six leading blanks', () {
      final grid = StreakCalendar.monthGrid(DateTime(2026, 11));
      expect(grid.length % 7, 0);
      expect(grid.take(6).every((d) => d == null), isTrue);
      expect(grid[6], DateTime(2026, 11, 1));
      expect(grid.whereType<DateTime>().length, 30);
      expect(grid.whereType<DateTime>().last, DateTime(2026, 11, 30));
    });

    test('a month starting on Monday has no leading blanks', () {
      final grid = StreakCalendar.monthGrid(DateTime(2027, 2));
      expect(grid.first, DateTime(2027, 2, 1));
      expect(grid.whereType<DateTime>().length, 28);
    });

    test('daysInMonth handles leap years', () {
      expect(StreakCalendar.daysInMonth(DateTime(2028, 2)), 29);
      expect(StreakCalendar.daysInMonth(DateTime(2026, 12)), 31);
    });
  });
}
