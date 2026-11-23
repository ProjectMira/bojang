import 'package:bojang/utils/widget_snapshot.dart';
import 'package:bojang/utils/word_of_the_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetDayPart', () {
    test('four parts of the day', () {
      DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);
      expect(WidgetDayPart.at(at(0)), WidgetDayPart.day);
      expect(WidgetDayPart.at(at(15, 59)), WidgetDayPart.day);
      expect(WidgetDayPart.at(at(16)), WidgetDayPart.evening);
      expect(WidgetDayPart.at(at(19, 59)), WidgetDayPart.evening);
      expect(WidgetDayPart.at(at(20)), WidgetDayPart.late);
      expect(WidgetDayPart.at(at(22)), WidgetDayPart.lastCall);
      expect(WidgetDayPart.at(at(23, 59)), WidgetDayPart.lastCall);
    });
  });

  group('WidgetSnapshot', () {
    final now = DateTime(2026, 11, 23, 21, 15);

    test('active streak, not yet done', () {
      final s = WidgetSnapshot.build(
        now: now,
        streak: 6,
        lastPlayDate: DateTime(2026, 11, 22, 9),
      );
      expect(s.state, WidgetStreakState.active);
      expect(s.todayDone, isFalse);
      expect(s.dayPart, WidgetDayPart.late);
      final data = s.toWidgetData();
      expect(data['streak'], 6);
      expect(data['streak_state'], 'active');
      expect(data['last_done_date'], '2026-11-22');
      expect(data['today'], '2026-11-23');
      expect(data['line_last_call'], 'Last call for day 7');
      for (final part in WidgetDayPart.values) {
        expect(data['line_${part.key}'], isA<String>());
      }
      expect(data['line_done'], isA<String>());
      expect(data['word_tibetan'], isNotEmpty);
    });

    test('done today', () {
      final s = WidgetSnapshot.build(
        now: now,
        streak: 7,
        lastPlayDate: DateTime(2026, 11, 23, 8),
      );
      expect(s.todayDone, isTrue);
      expect(s.toWidgetData()['today_done'], isTrue);
    });

    test('a freeze covered yesterday', () {
      final s = WidgetSnapshot.build(
        now: now,
        streak: 10,
        lastPlayDate: DateTime(2026, 11, 21),
        frozenDates: [DateTime(2026, 11, 22)],
      );
      expect(s.state, WidgetStreakState.frozen);
    });

    test('earn back window open', () {
      final s = WidgetSnapshot.build(now: now, streak: 0, earnBackStreak: 12);
      expect(s.state, WidgetStreakState.earnBack);
      expect(s.toWidgetData()['line_day'], 'Win back your 12 days');
      expect(s.toWidgetData()['earn_back_streak'], 12);
    });

    test('no streak', () {
      final s = WidgetSnapshot.build(now: now, streak: 0);
      expect(s.state, WidgetStreakState.none);
      expect(s.lastDoneDate, '');
    });
  });

  group('WordOfTheDay', () {
    test('same word all day, next word tomorrow, cycles', () {
      final a = WordOfTheDay.forDay(DateTime(2026, 11, 23, 1));
      final b = WordOfTheDay.forDay(DateTime(2026, 11, 23, 23));
      final c = WordOfTheDay.forDay(DateTime(2026, 11, 24, 1));
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
      final later = WordOfTheDay.forDay(
        DateTime(2026, 11, 23).add(Duration(days: WordOfTheDay.words.length)),
      );
      expect(identical(a, later), isTrue);
    });

    test('every word is complete', () {
      for (final w in WordOfTheDay.words) {
        expect(w.tibetan, isNotEmpty);
        expect(w.phonetic, isNotEmpty);
        expect(w.english, isNotEmpty);
      }
    });
  });
}
