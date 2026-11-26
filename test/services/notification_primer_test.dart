import 'package:bojang/services/notification_primer.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PrimerPolicy', () {
    final now = DateTime(2026, 11, 22, 20);

    test('asks at most 3 times in total', () {
      for (var asks = 0; asks < 3; asks++) {
        expect(
          PrimerPolicy.shouldAsk(asks: asks, lastAsk: null, now: now, canPrompt: true),
          isTrue,
        );
      }
      expect(PrimerPolicy.shouldAsk(asks: 3, lastAsk: null, now: now, canPrompt: true), isFalse);
      expect(PrimerPolicy.shouldAsk(asks: 7, lastAsk: null, now: now, canPrompt: true), isFalse);
    });

    test('asks are at least 3 days apart', () {
      bool at(Duration since) => PrimerPolicy.shouldAsk(
            asks: 1,
            lastAsk: now.subtract(since),
            now: now,
            canPrompt: true,
          );
      expect(at(const Duration(hours: 1)), isFalse);
      expect(at(const Duration(days: 2, hours: 23, minutes: 59)), isFalse);
      expect(at(const Duration(days: 3)), isTrue);
      expect(at(const Duration(days: 30)), isTrue);
    });

    test('never asks when the OS prompt cannot be shown', () {
      expect(PrimerPolicy.shouldAsk(asks: 0, lastAsk: null, now: now, canPrompt: false), isFalse);
    });

    test('which permission states can still prompt', () {
      const ios = TargetPlatform.iOS;
      const android = TargetPlatform.android;
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.notDetermined, ios), isTrue);
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.denied, ios), isFalse);
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.authorized, ios), isFalse);
      // Provisional (quiet) at launch: the primer still upgrades it to banners.
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.provisional, ios), isTrue);
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.denied, android), isTrue);
      expect(PrimerPolicy.canPromptFor(AuthorizationStatus.authorized, android), isFalse);
      expect(PrimerPolicy.canPromptFor(null, android), isFalse);
    });

    test('moments: streak started or extended, or a freeze used', () {
      expect(
        PrimerPolicy.momentFor(const StreakCelebration(streak: 1, goal: 0)),
        PrimerMoment.streak,
      );
      expect(
        PrimerPolicy.momentFor(const StreakCelebration(streak: 9, goal: 7, freezesUsed: 1)),
        PrimerMoment.freeze,
      );
      expect(PrimerPolicy.momentFor(const StreakCelebration(streak: 0, goal: 0)), isNull);
    });

    test('lesson end: the first finished lesson asks, with or without a streak', () {
      const started = StreakCelebration(streak: 1, goal: 0);
      expect(
        PrimerPolicy.momentForLessonEnd(lessonsCompleted: 1),
        PrimerMoment.firstLesson,
      );
      expect(
        PrimerPolicy.momentForLessonEnd(lessonsCompleted: 1, celebration: started),
        PrimerMoment.firstLesson,
      );
      // Later lessons fall back to the streak moments.
      expect(
        PrimerPolicy.momentForLessonEnd(lessonsCompleted: 2, celebration: started),
        PrimerMoment.streak,
      );
      expect(PrimerPolicy.momentForLessonEnd(lessonsCompleted: 2), isNull);
      // Unknown count (storage failed): not taken for a first lesson.
      expect(PrimerPolicy.momentForLessonEnd(lessonsCompleted: 0), isNull);
    });
  });

  group('NotificationPrimer', () {
    late DateTime clock;
    late List<PrimerMoment> shown;
    late List<String> requested;
    late bool? answer;
    late bool osAllows;
    late bool canPrompt;

    NotificationPrimer primer() => NotificationPrimer(
          canPrompt: () async => canPrompt,
          requestPermission: (source) async {
            requested.add(source);
            return osAllows;
          },
          present: (context, moment) async {
            shown.add(moment);
            return answer;
          },
          clock: () => clock,
        );

    setUp(() {
      clock = DateTime(2026, 11, 22, 20);
      shown = [];
      requested = [];
      answer = false;
      osAllows = true;
      canPrompt = true;
    });

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ));
      return captured;
    }

    testWidgets('"Maybe later" three times, 3+ days apart, then never again', (tester) async {
      final context = await pumpContext(tester);
      final p = primer();

      expect(await p.maybeAsk(context, PrimerMoment.streak), isTrue);
      // Same evening, next day, two days later: too soon.
      expect(await p.maybeAsk(context, PrimerMoment.streak), isFalse);
      clock = clock.add(const Duration(days: 1));
      expect(await p.maybeAsk(context, PrimerMoment.freeze), isFalse);
      clock = clock.add(const Duration(days: 2));
      expect(await p.maybeAsk(context, PrimerMoment.freeze), isTrue);
      clock = clock.add(const Duration(days: 3));
      expect(await p.maybeAsk(context, PrimerMoment.streak), isTrue);
      // Cap reached.
      clock = clock.add(const Duration(days: 30));
      expect(await p.maybeAsk(context, PrimerMoment.streak), isFalse);

      expect(shown, [PrimerMoment.streak, PrimerMoment.freeze, PrimerMoment.streak]);
      expect(requested, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationPrimer.asksKey), 3);
    });

    testWidgets('"Turn on" shows the OS prompt with the moment as source', (tester) async {
      final context = await pumpContext(tester);
      answer = true;
      expect(await primer().maybeAsk(context, PrimerMoment.freeze), isTrue);
      expect(requested, ['primer_freeze']);
    });

    testWidgets('refused at the OS prompt: no more asks', (tester) async {
      final context = await pumpContext(tester);
      answer = true;
      osAllows = false;
      final p = primer();
      expect(await p.maybeAsk(context, PrimerMoment.streak), isTrue);
      clock = clock.add(const Duration(days: 10));
      expect(await p.maybeAsk(context, PrimerMoment.streak), isFalse);
      expect(shown, hasLength(1));
    });

    testWidgets('allowed already or blocked: nothing shown, no ask used', (tester) async {
      final context = await pumpContext(tester);
      canPrompt = false;
      expect(await primer().maybeAsk(context, PrimerMoment.streak), isFalse);
      expect(shown, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationPrimer.asksKey), isNull);
    });

    testWidgets('the cap survives a restart (stored in preferences)', (tester) async {
      SharedPreferences.setMockInitialValues({
        NotificationPrimer.asksKey: 3,
        NotificationPrimer.lastAskKey: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      final context = await pumpContext(tester);
      expect(await primer().maybeAsk(context, PrimerMoment.streak), isFalse);
    });

    testWidgets('after a celebration without a streak, nothing', (tester) async {
      final context = await pumpContext(tester);
      expect(
        await primer().afterStreakCelebration(
          context,
          const StreakCelebration(streak: 0, goal: 0),
        ),
        isFalse,
      );
      expect(
        await primer().afterStreakCelebration(
          context,
          const StreakCelebration(streak: 1, goal: 0),
        ),
        isTrue,
      );
    });

    testWidgets('after the first lesson: asks once; an OS answer is kept', (tester) async {
      final context = await pumpContext(tester);
      expect(await primer().afterLesson(context, lessonsCompleted: 1), isTrue);
      expect(shown, [PrimerMoment.firstLesson]);
      expect(requested, isEmpty, reason: '"Not now": no OS prompt');

      // Learners who already answered the OS prompt are never asked again.
      shown.clear();
      canPrompt = false;
      clock = clock.add(const Duration(days: 10));
      expect(await primer().afterLesson(context, lessonsCompleted: 1), isFalse);
      expect(shown, isEmpty);
    });

    testWidgets('"Allow" after the first lesson shows the OS prompt', (tester) async {
      final context = await pumpContext(tester);
      answer = true;
      expect(await primer().afterLesson(context, lessonsCompleted: 1), isTrue);
      expect(requested, ['primer_firstLesson']);
    });

    testWidgets('the first-lesson pre-prompt offers "Allow" and "Not now"', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final context = await pumpContext(tester);
      final p = NotificationPrimer(
        canPrompt: () async => true,
        requestPermission: (source) async {
          requested.add(source);
          return true;
        },
        clock: () => clock,
      );
      final result = p.afterLesson(context, lessonsCompleted: 1);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Get a daily reminder to keep your streak?'), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await result, isTrue);
      expect(requested, ['primer_firstLesson']);
    });

    testWidgets('the pre-prompt offers "Allow" and "Not now"', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final context = await pumpContext(tester);
      final p = NotificationPrimer(
        canPrompt: () async => true,
        requestPermission: (source) async {
          requested.add(source);
          return true;
        },
        clock: () => clock,
      );
      final result = p.maybeAsk(context, PrimerMoment.streak);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Want a nudge from Norbu?'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await result, isTrue);
      expect(requested, isEmpty);
      expect(find.text('Want a nudge from Norbu?'), findsNothing);
    });
  });
}
