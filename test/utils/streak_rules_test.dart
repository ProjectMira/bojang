import 'package:bojang/utils/streak_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 21, 15);
  DateTime ago(int days) => DateTime(2026, 11, 21 - days, 9);

  StreakUpdate apply(int streak, DateTime? last, {int freezes = 0}) =>
      StreakRules.apply(
        streak: streak,
        lastActive: last,
        freezes: freezes,
        today: today,
      );

  test('yesterday extends without spending a freeze', () {
    final u = apply(4, ago(1), freezes: 1);
    expect([u.streak, u.extended, u.freezes], [5, true, 1]);
    expect(u.frozenDays, isEmpty);
  });

  test('a freeze covers one missed day', () {
    final u = apply(4, ago(2), freezes: 1);
    expect([u.streak, u.freezes], [5, 0]);
    expect(u.frozenDays, [DateTime(2026, 11, 20)]);
  });

  test('two missed days need two freezes', () {
    final u = apply(10, ago(3), freezes: 2);
    expect([u.streak, u.freezes], [11, 0]);
    expect(u.frozenDays, [DateTime(2026, 11, 19), DateTime(2026, 11, 20)]);
  });

  test('too many missed days restarts and keeps the freezes', () {
    final u = apply(10, ago(4), freezes: 2);
    expect([u.streak, u.freezes], [1, 2]);
    expect(u.frozenDays, isEmpty);
  });

  test('a freeze is earned every 7th day, at most 2 held', () {
    expect(apply(6, ago(1)).freezeEarned, isTrue);
    expect(apply(6, ago(1)).freezes, 1);
    expect(apply(13, ago(1), freezes: 1).freezes, 2);
    final full = apply(20, ago(1), freezes: 2);
    expect([full.streak, full.freezes, full.freezeEarned], [21, 2, false]);
  });

  test('same day changes nothing', () {
    final u = apply(5, DateTime(2026, 11, 21, 7), freezes: 1);
    expect([u.streak, u.extended, u.freezes], [5, false, 1]);
  });

  test('first ever practice starts at 1', () {
    final u = apply(0, null);
    expect([u.streak, u.extended], [1, true]);
  });

  test('a lapsed streak of 0 is not revived by freezes', () {
    final u = apply(0, ago(2), freezes: 2);
    expect([u.streak, u.freezes], [1, 2]);
  });

  test('next goal steps up through the list', () {
    expect(StreakRules.nextGoal(7), 14);
    expect(StreakRules.nextGoal(30), 50);
    expect(StreakRules.nextGoal(365), isNull);
  });

  group('Earn Back', () {
    DateTime d(int offset) => DateTime(2026, 11, 21 + offset);

    StreakUpdate session(
      int streak,
      DateTime? last, {
      int freezes = 0,
      EarnBack? window,
      DateTime? on,
      bool counts = true,
    }) => StreakRules.apply(
      streak: streak,
      lastActive: last,
      freezes: freezes,
      today: on ?? today,
      earnBack: window,
      session: counts,
    );

    EarnBack open({int sessions = 1, int streak = 10, int brokeAfter = -2}) =>
        EarnBack(
          streak: streak,
          brokeAfter: d(brokeAfter),
          expires: d(brokeAfter + 4),
          openedOn: d(0),
          sessionsDone: sessions,
        );

    test('a break opens a 3-day window with this session counted', () {
      final u = session(10, ago(2));
      expect([u.streak, u.earnBackStarted, u.earnBackChanged], [1, true, true]);
      final e = u.earnBack!;
      expect([e.streak, e.sessionsDone, e.daysLeft(today)], [10, 1, 3]);
      expect(e.expires, d(2));
      expect(e.brokeAfter, d(-2));
    });

    test('the last day of the window still opens it; after, nothing', () {
      expect(session(10, ago(4)).earnBack!.daysLeft(today), 1);
      expect(session(10, ago(5)).earnBack, isNull);
    });

    test('a 1-day streak is a restart, not an Earn Back', () {
      expect(session(1, ago(2)).earnBack, isNull);
    });

    test('a second session the same day restores as if it never broke', () {
      final u = session(1, DateTime(2026, 11, 21, 8), window: open());
      expect([u.streak, u.extended, u.streakRestored], [11, false, true]);
      expect(u.earnBack, isNull);
      expect(u.earnedBackDays, [d(-1)]);
    });

    test('a second session the next day keeps the day since', () {
      final u = session(1, DateTime(2026, 11, 21, 8), window: open(), on: d(1));
      expect([u.streak, u.streakRestored], [12, true]);
    });

    test('one session is progress, not a restore', () {
      final u = session(1, DateTime(2026, 11, 21, 8), window: open(sessions: 0));
      expect([u.streak, u.streakRestored, u.earnBack!.sessionsDone], [1, false, 1]);
    });

    test('a call that is not a session counts nothing', () {
      final w = open();
      final u = session(1, DateTime(2026, 11, 21, 8), window: w, counts: false);
      expect([u.earnBack, u.earnBackChanged], [w, false]);
    });

    test('an offered window gets its first day when counted', () {
      final offered = StreakRules.offeredWindow(
        streak: 10,
        lastActive: ago(3),
        freezes: 0,
        today: d(-1),
      )!;
      expect([offered.sessionsDone, offered.openedOn], [0, null]);
      final u = session(0, ago(3), window: offered, on: d(-1));
      expect(u.earnBack!.openedOn, d(-1));
    });

    test('an expired window is dropped and never restores', () {
      final w = EarnBack(
        streak: 10,
        brokeAfter: d(-5),
        expires: d(-1),
        openedOn: d(-3),
        sessionsDone: 1,
      );
      final u = session(1, d(-3), window: w);
      expect([u.streak, u.streakRestored, u.earnBack, u.earnBackChanged], [
        1,
        false,
        null,
        true,
      ]);
    });

    test('freezes cover first, so there is no Earn Back', () {
      final u = session(10, ago(2), freezes: 1);
      expect([u.streak, u.freezes, u.earnBack], [11, 0, null]);
    });

    test('too few freezes: they are kept and the window opens after them', () {
      final u = session(10, ago(4), freezes: 2);
      expect([u.streak, u.freezes], [1, 2]);
      expect(u.earnBack!.expires, d(2));
      // Two freezes push a 5-day gap back inside the window.
      expect(session(10, ago(6)).earnBack, isNull);
      expect(session(10, ago(6), freezes: 2).earnBackStarted, isTrue);
    });

    test('a restore onto a 7th day earns a freeze, at most 2', () {
      final u = session(1, DateTime(2026, 11, 21, 8), window: open(streak: 13));
      expect([u.streak, u.freezes, u.freezeEarned], [14, 1, true]);
      final full = session(
        1,
        DateTime(2026, 11, 21, 8),
        freezes: 2,
        window: open(streak: 13),
      );
      expect([full.freezes, full.freezeEarned], [2, false]);
    });

    test('status: an unseen break is offered with nothing done', () {
      final e =
          StreakRules.earnBackStatus(
            streak: 10,
            lastActive: ago(2),
            freezes: 0,
            stored: null,
            today: today,
          )!;
      expect([e.sessionsDone, e.daysLeft(today), e.streak], [0, 3, 10]);
      expect(
        StreakRules.earnBackStatus(
          streak: 10,
          lastActive: ago(1),
          freezes: 0,
          stored: null,
          today: today,
        ),
        isNull,
      );
    });

    test('reads the API shape and the device copy', () {
      final api = EarnBack.fromJson({
        'active': true,
        'sessions_done': 1,
        'sessions_needed': 2,
        'expires_at': '2026-11-23',
        'days_left': 3,
        'streak': 10,
        'broke_after': '2026-11-19',
      })!;
      expect([api.streak, api.sessionsDone, api.expires, api.brokeAfter], [
        10,
        1,
        d(2),
        d(-2),
      ]);
      final copy = EarnBack.fromJson(open().toJson())!;
      expect([copy.openedOn, copy.sessionsDone], [d(0), 1]);
      expect(EarnBack.fromJson({'active': false}), isNull);
      expect(EarnBack.fromJson({'active': true, 'streak': 'x'}), isNull);
    });
  });

  group('flame tiers', () {
    test('grow at 7, 14, 30 and 50 days', () {
      expect(StreakRules.tierFor(1), FlameTier.spark);
      expect(StreakRules.tierFor(6), FlameTier.spark);
      expect(StreakRules.tierFor(7), FlameTier.flame);
      expect(StreakRules.tierFor(14), FlameTier.blaze);
      expect(StreakRules.tierFor(30), FlameTier.bonfire);
      expect(StreakRules.tierFor(49), FlameTier.bonfire);
      expect(StreakRules.tierFor(50), FlameTier.golden);
      expect(StreakRules.tierFor(400), FlameTier.golden);
    });

    test('tease the day before a tier only', () {
      expect(StreakRules.tierTomorrow(6), FlameTier.flame);
      expect(StreakRules.tierTomorrow(13), FlameTier.blaze);
      expect(StreakRules.tierTomorrow(29), FlameTier.bonfire);
      expect(StreakRules.tierTomorrow(49), FlameTier.golden);
      expect(StreakRules.tierTomorrow(7), isNull);
      expect(StreakRules.tierTomorrow(0), isNull);
    });

    test('next tier counts up, then stops', () {
      expect(StreakRules.nextTierAt(0), 7);
      expect(StreakRules.nextTierAt(30), 50);
      expect(StreakRules.nextTierAt(50), isNull);
    });

    test('50 is a goal a learner can pick', () {
      expect(StreakRules.goals, contains(50));
    });
  });
}
