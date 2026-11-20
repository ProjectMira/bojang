import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/services/progress_service.dart';

void main() {
  group('ProgressService.isConsecutiveDay', () {
    test('late evening then early next morning is consecutive', () {
      // Only 9 hours apart: the old elapsed-time check said 0 days and reset.
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 11, 19, 23, 0),
          DateTime(2026, 11, 20, 8, 0),
        ),
        isTrue,
      );
    });

    test('same day is not consecutive', () {
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 11, 20, 7, 0),
          DateTime(2026, 11, 20, 22, 0),
        ),
        isFalse,
      );
    });

    test('a skipped day is not consecutive', () {
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 11, 18, 8, 0),
          DateTime(2026, 11, 20, 8, 0),
        ),
        isFalse,
      );
    });

    test('works across month and year boundaries', () {
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 11, 30, 21, 0),
          DateTime(2026, 12, 1, 6, 0),
        ),
        isTrue,
      );
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 12, 31, 23, 59),
          DateTime(2027, 1, 1, 0, 1),
        ),
        isTrue,
      );
    });

    test('more than 24 hours but next calendar day is consecutive', () {
      expect(
        ProgressService.isConsecutiveDay(
          DateTime(2026, 11, 19, 6, 0),
          DateTime(2026, 11, 20, 22, 0),
        ),
        isTrue,
      );
    });
  });

  group('ProgressService.localDateString', () {
    test('zero-pads month and day with ASCII digits', () {
      expect(
        ProgressService.localDateString(DateTime(2026, 3, 7, 23, 30)),
        '2026-03-07',
      );
      expect(
        ProgressService.localDateString(DateTime(2026, 11, 20)),
        '2026-11-20',
      );
    });
  });

  group('activity sync', () {
    late List<String> sent;
    Map<String, dynamic>? Function(String date) reply = (_) => null;
    var signedIn = true;

    String day(int offset) {
      final now = DateTime.now();
      return ProgressService.localDateString(
        DateTime(now.year, now.month, now.day + offset),
      );
    }

    Future<ProgressService> build(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final service = ProgressService(
        isSignedIn: () => signedIn,
        recordActivity: (date) async {
          sent.add(date);
          return reply(date);
        },
      );
      await pumpEventQueue(); // let the constructor finish loading prefs
      return service;
    }

    Future<List<String>?> pending() async =>
        (await SharedPreferences.getInstance()).getStringList(
          'pending_activity_dates',
        );

    setUp(() {
      sent = [];
      signedIn = true;
      reply = (_) => {'streak': 3, 'streak_extended': true};
    });

    test('signed out: the day is kept pending, nothing sent', () async {
      signedIn = false;
      final service = await build({});
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(sent, isEmpty);
      expect(await pending(), [day(0)]);
    });

    test('server failure: the day is kept pending', () async {
      reply = (_) => null;
      final service = await build({});
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(sent, [day(0)]);
      expect(await pending(), [day(0)]);
    });

    test('success: pending cleared and server streak applied', () async {
      final service = await build({});
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(sent, [day(0)]);
      expect(await pending(), isNull);
      // Local first-play streak is 1; the server says 3 and wins.
      expect(service.currentStreak, 3);
    });

    test('an older unsent day goes out before today', () async {
      final service = await build({
        'pending_activity_dates': [day(-1)],
      });
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(sent, [day(-1), day(0)]);
      expect(await pending(), isNull);
    });

    test('first failure stops the send and keeps both days in order', () async {
      reply = (_) => null;
      final service = await build({
        'pending_activity_dates': [day(-1)],
      });
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(sent, [day(-1)]);
      expect(await pending(), [day(-1), day(0)]);
    });

    test('flush drops days older than yesterday without sending', () async {
      final service = await build({
        'pending_activity_dates': [day(-3), day(-2)],
      });
      await service.flushPendingActivity();
      expect(sent, isEmpty);
      expect(await pending(), isNull);
    });

    test('flush sends yesterday and today', () async {
      final service = await build({
        'pending_activity_dates': [day(0), day(-1)],
      });
      await service.flushPendingActivity();
      expect(sent, [day(-1), day(0)]);
      expect(await pending(), isNull);
    });

    test('merge keeps the higher local streak only if played today', () async {
      reply = (_) => {'streak': 1, 'streak_extended': false};
      final today = await build({
        'current_streak': 5,
        'last_play_date': DateTime.now().toIso8601String(),
        'pending_activity_dates': [day(0)],
      });
      await today.flushPendingActivity();
      expect(today.currentStreak, 5);

      final notToday = await build({
        'current_streak': 5,
        'last_play_date': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        'pending_activity_dates': [day(0)],
      });
      await notToday.flushPendingActivity();
      expect(notToday.currentStreak, 1);
    });
  });

  group('updateFromServer merge', () {
    Future<ProgressService> build({required bool playedToday}) async {
      SharedPreferences.setMockInitialValues({
        'current_streak': 5,
        'last_play_date': (playedToday
                ? DateTime.now()
                : DateTime.now().subtract(const Duration(days: 2)))
            .toIso8601String(),
      });
      final service = ProgressService(
        isSignedIn: () => false,
        recordActivity: (_) async => null,
      );
      await pumpEventQueue();
      return service;
    }

    final statsShape = {
      'xp': {'total': 100},
      'streak': {'current': 0, 'multiplier': 1.0},
      'league': {'current': 'Bronze'},
      'levels': {'completed': <String>[], 'count': 0},
    };
    final flatShape = {'xp': 100, 'streak': 0, 'league': 'Bronze'};

    for (final entry in {'stats': statsShape, 'flat': flatShape}.entries) {
      test('${entry.key} shape: played today keeps local streak', () async {
        final service = await build(playedToday: true);
        await service.updateFromServer(entry.value);
        expect(service.currentStreak, 5);
      });

      test('${entry.key} shape: not played today takes server 0', () async {
        final service = await build(playedToday: false);
        await service.updateFromServer(entry.value);
        expect(service.currentStreak, 0);
      });
    }
  });

  test('flush waits for an in-flight report before resolving', () async {
    SharedPreferences.setMockInitialValues({});
    final sent = <String>[];
    final service = ProgressService(
      isSignedIn: () => true,
      recordActivity: (date) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        sent.add(date);
        return {'streak': 1, 'streak_extended': true};
      },
    );
    await pumpEventQueue();
    await service.updateQuizResults('topic', 5, 5); // report starts, unawaited
    expect(sent, isEmpty);
    await service.flushPendingActivity(); // what the lesson awaits
    expect(sent, hasLength(1));
  });

  test('resetProgress clears unsent days', () async {
    SharedPreferences.setMockInitialValues({
      'pending_activity_dates': [
        ProgressService.localDateString(DateTime.now()),
      ],
    });
    final service = ProgressService(
      isSignedIn: () => false,
      recordActivity: (_) async => null,
    );
    await pumpEventQueue();
    await service.resetProgress();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pending_activity_dates'), isNull);
  });
}
