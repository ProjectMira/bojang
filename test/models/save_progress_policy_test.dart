import 'package:bojang/services/save_progress_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 23, 18);

  group('SaveProgressPolicy (plan #19)', () {
    test('moments: first lesson, 3-day streak, later lessons', () {
      expect(
        SaveProgressPolicy.momentFor(lessonsCompleted: 1, streak: 1),
        SaveProgressMoment.firstLesson,
      );
      expect(
        SaveProgressPolicy.momentFor(lessonsCompleted: 0, streak: 3),
        SaveProgressMoment.streak,
      );
      expect(
        SaveProgressPolicy.momentFor(lessonsCompleted: 4, streak: 2),
        SaveProgressMoment.later,
      );
      expect(
        SaveProgressPolicy.momentFor(lessonsCompleted: 0, streak: 2),
        isNull,
      );
    });

    bool ask({
      int asks = 0,
      DateTime? last,
      bool needs = true,
      bool offer = true,
    }) => SaveProgressPolicy.shouldAsk(
      needsAccount: needs,
      canOffer: offer,
      asks: asks,
      lastAsk: last,
      now: now,
    );

    test('at most 3 asks', () {
      expect(ask(asks: 2), isTrue);
      expect(ask(asks: 3), isFalse);
    });

    test('at least 4 days apart', () {
      expect(
        ask(asks: 1, last: now.subtract(const Duration(days: 3))),
        isFalse,
      );
      expect(ask(asks: 1, last: now.subtract(const Duration(days: 4))), isTrue);
    });

    test('only for learners without a real account, with a way to save', () {
      expect(ask(needs: false), isFalse);
      expect(ask(offer: false), isFalse);
    });
  });

  group('SaveProgressPrompt', () {
    late DateTime clock;
    late int shown;
    late bool answer;
    late int opened;

    SaveProgressPrompt prompt({bool enabled = true, bool saved = false}) =>
        SaveProgressPrompt(
          needsAccount: () => true,
          canOffer: () => true,
          enabled: () => enabled,
          clock: () => clock,
          present: (_, __) async {
            shown++;
            return answer;
          },
          openAccount: (_) async {
            opened++;
            return saved;
          },
        );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      clock = now;
      shown = 0;
      opened = 0;
      answer = false;
    });

    testWidgets('caps at 3 asks, 4+ days apart, never blocking', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final p = prompt();
      Future<bool> run() => p.maybeAsk(context, lessonsCompleted: 2, streak: 1);

      expect(await run(), isTrue);
      expect(await run(), isFalse, reason: 'same day');
      clock = clock.add(const Duration(days: 4));
      expect(await run(), isTrue);
      clock = clock.add(const Duration(days: 4));
      expect(await run(), isTrue);
      clock = clock.add(const Duration(days: 30));
      expect(await run(), isFalse, reason: 'cap of 3');
      expect(shown, 3);
      expect(opened, 0);
    });

    testWidgets('saving stops the asks for good', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      answer = true;
      final p = prompt(saved: true);
      expect(await p.maybeAsk(context, lessonsCompleted: 1, streak: 1), isTrue);
      expect(opened, 1);
      clock = clock.add(const Duration(days: 10));
      expect(
        await p.maybeAsk(context, lessonsCompleted: 3, streak: 1),
        isFalse,
      );
    });

    testWidgets('the account_linking kill switch hides it', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      expect(
        await prompt(
          enabled: false,
        ).maybeAsk(context, lessonsCompleted: 1, streak: 1),
        isFalse,
      );
      expect(shown, 0);
    });
  });
}
