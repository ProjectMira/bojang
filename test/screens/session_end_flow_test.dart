import 'package:bojang/screens/lesson_complete_screen.dart';
import 'package:bojang/services/beginner.dart';
import 'package:bojang/services/notification_primer.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The session end runs result → streak (first practice of the day) → goal
/// → at most one ask, with Continue in the same place on every screen.
void main() {
  final now = DateTime(2026, 11, 22, 19);
  late List<String> permissionRequests;

  /// The primer as the session end sees it, without Firebase: [canPrompt]
  /// stands in for the OS permission state.
  void installPrimer({required bool canPrompt}) {
    NotificationPrimer.instance = NotificationPrimer(
      canPrompt: () async => canPrompt,
      requestPermission: (source) async {
        permissionRequests.add(source);
        return true;
      },
      clock: () => now,
    );
  }

  setUp(() {
    permissionRequests = [];
    // Tests that don't care about notifications: permission already decided.
    installPrimer(canPrompt: false);
  });
  tearDown(() => NotificationPrimer.instance = NotificationPrimer());

  Future<ProgressService> pumpResult(
    WidgetTester tester, {
    required int lessonsCompleted,
    required bool practisedToday,
    bool dark = false,
    Map<String, Object> prefs = const {},
    // The standard session end unless a test is about beginners.
    bool? beginner = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final progress = ProgressService(
      isSignedIn: () => false,
      recordActivity: (_) async => null,
    );
    if (practisedToday) {
      // The first lesson of the day leaves a streak celebration waiting.
      await progress.updateQuizResults('basics', 4, 5);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progress,
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : null,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => LessonCompleteScreen(
                                    score: 4,
                                    totalQuestions: 5,
                                    xpEarned: 40,
                                    accuracy: 80,
                                    streak: 1,
                                    topicFilePath: 'api://level/basics_1',
                                    lessonsCompleted: lessonsCompleted,
                                    beginner: beginner,
                                  ),
                            ),
                          ),
                      child: const Text('open'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return progress;
  }

  Finder primary(String label) => find.widgetWithText(FilledButton, label);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('result, then streak, then one ask; Continue never moves', (
    tester,
  ) async {
    await pumpResult(tester, lessonsCompleted: 3, practisedToday: true);
    expect(find.text('You scored 4 of 5 (80%)'), findsOneWidget);
    final continueRect = tester.getRect(primary('Continue'));

    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(find.text('Your streak has started!'), findsOneWidget);
    expect(tester.getRect(primary('Commit to my goal')), continueRect);

    await tester.tap(find.text('Not now'));
    await settle(tester);
    // The one ask comes last.
    expect(find.text('Where are you learning from?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the first lesson asks for notifications, and only that', (
    tester,
  ) async {
    installPrimer(canPrompt: true);
    await pumpResult(tester, lessonsCompleted: 1, practisedToday: true);

    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(find.text('Your streak has started!'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settle(tester);

    // The primer takes the one ask slot, ahead of location.
    expect(
      find.text('Get a daily reminder to keep your streak?'),
      findsOneWidget,
    );
    expect(find.text('Where are you learning from?'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification_primer_not_now')));
    await settle(tester);

    expect(find.text('Where are you learning from?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(permissionRequests, isEmpty);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getInt(NotificationPrimer.asksKey), 1);
    // Location was not used up: it can still ask at a later session end.
    expect(saved.getBool('location_prompted'), isNot(true));
  });

  testWidgets('first lesson, OS prompt already answered: no primer', (
    tester,
  ) async {
    // canPrompt false: the learner allowed or refused in an older build.
    await pumpResult(tester, lessonsCompleted: 1, practisedToday: false);
    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(
      find.text('Get a daily reminder to keep your streak?'),
      findsNothing,
    );
    expect(permissionRequests, isEmpty);
  });

  testWidgets('"Allow" goes to the OS prompt, then nothing else', (
    tester,
  ) async {
    installPrimer(canPrompt: true);
    await pumpResult(tester, lessonsCompleted: 3, practisedToday: true);
    await tester.tap(primary('Continue'));
    await settle(tester);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(permissionRequests, ['primer_streak']);
    expect(find.text('Where are you learning from?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('primer asked 3 days ago or less: location takes the slot', (
    tester,
  ) async {
    installPrimer(canPrompt: true);
    await pumpResult(
      tester,
      lessonsCompleted: 3,
      practisedToday: true,
      prefs: {
        NotificationPrimer.asksKey: 1,
        NotificationPrimer.lastAskKey:
            now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      },
    );
    await tester.tap(primary('Continue'));
    await settle(tester);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('Want a nudge from Norbu?'), findsNothing);
    expect(find.text('Where are you learning from?'), findsOneWidget);
  });

  testWidgets('no streak moment, no primer: the next ask shows', (
    tester,
  ) async {
    installPrimer(canPrompt: true);
    await pumpResult(tester, lessonsCompleted: 7, practisedToday: false);
    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(find.text('Want a nudge from Norbu?'), findsNothing);
    expect(find.text('Where are you learning from?'), findsOneWidget);
  });

  testWidgets('a lesson milestone adds the goal step, no streak twice a day', (
    tester,
  ) async {
    await pumpResult(tester, lessonsCompleted: 5, practisedToday: false);
    expect(find.text('5 lessons!'), findsOneWidget); // the big celebration
    final continueRect = tester.getRect(primary('Continue'));

    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(find.text('5 lessons done!'), findsOneWidget);
    expect(find.textContaining('Your next goal: 10 lessons'), findsOneWidget);
    expect(tester.getRect(primary('Continue')), continueRect);

    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(find.text('Where are you learning from?'), findsOneWidget);
  });

  testWidgets('an ordinary lesson is a quieter celebration', (tester) async {
    await pumpResult(tester, lessonsCompleted: 7, practisedToday: false);
    expect(find.text('ལེགས་སོ། Excellent!'), findsOneWidget);
    expect(find.text('7 lessons!'), findsNothing);
    // "+40 XP" sits on a light gold chip: dark ink, not gold (1.7:1).
    final xp = tester.widget<Text>(find.text('+40 XP'));
    expect(xp.style?.color, AppColors.inkLight);
  });

  testWidgets('the layout holds on an iPad in dark mode', (tester) async {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpResult(
      tester,
      lessonsCompleted: 1,
      practisedToday: false,
      dark: true,
    );
    expect(find.text('Your first lesson!'), findsOneWidget);
    final rect = tester.getRect(primary('Continue'));
    expect(rect.width, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  group('one ask per lesson end', () {
    test('primer, save-progress, location and the wean-off sheet', () {
      expect(LessonCompleteScreen.asks, hasLength(4));
    });

    testWidgets('stops at the first ask that shows', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final called = <String>[];
      SessionEndAsk ask(String name, bool shows) => (_, _) async {
        called.add(name);
        return shows;
      };
      const end = SessionEndInfo(lessonsCompleted: 3);

      // Every ask is due: only the first one shows.
      final all = [
        ask('primer', true),
        ask('save_progress', true),
        ask('location', true),
        ask('wean_off', true),
      ];
      expect(
        await LessonCompleteScreen.showFirstAsk(context, end, asks: all),
        0,
      );
      expect(called, ['primer']);

      // The primer passes: the next one takes the slot, the rest wait.
      called.clear();
      final later = [
        ask('primer', false),
        ask('save_progress', false),
        ask('location', true),
        ask('wean_off', true),
      ];
      expect(
        await LessonCompleteScreen.showFirstAsk(context, end, asks: later),
        2,
      );
      expect(called, ['primer', 'save_progress', 'location']);

      // None due: nothing shows.
      called.clear();
      final none = [
        for (final n in ['a', 'b', 'c', 'd']) ask(n, false),
      ];
      expect(
        await LessonCompleteScreen.showFirstAsk(context, end, asks: none),
        isNull,
      );
      expect(called, hasLength(4));
    });
  });

  group('beginners: fewer taps', () {
    tearDown(() {
      Beginner.debugMaxLessons = null;
      Beginner.debugMaxXp = null;
    });

    test('a beginner has at most 3 lessons and under 300 XP', () {
      Beginner.debugMaxLessons = 3;
      Beginner.debugMaxXp = 300;
      expect(Beginner.check(lessonsCompleted: 1, xp: 40), isTrue);
      expect(Beginner.check(lessonsCompleted: 3, xp: 240), isTrue);
      expect(Beginner.check(lessonsCompleted: 4, xp: 240), isFalse);
      expect(Beginner.check(lessonsCompleted: 2, xp: 300), isFalse);
      // Count unknown: XP alone decides.
      expect(Beginner.check(lessonsCompleted: 0, xp: 0), isTrue);
      // Turned off from Remote Config.
      Beginner.debugMaxLessons = 0;
      expect(Beginner.check(lessonsCompleted: 1, xp: 0), isFalse);
    });

    testWidgets('streak on the result screen, one tap to the next lesson', (
      tester,
    ) async {
      Beginner.debugMaxLessons = 3;
      Beginner.debugMaxXp = 300;
      var requests = 0;
      void count() => requests++;
      Beginner.nextLessonRequests.addListener(count);
      addTearDown(() => Beginner.nextLessonRequests.removeListener(count));

      // Worked out from the lesson count and XP (40 XP after one lesson).
      await pumpResult(
        tester,
        lessonsCompleted: 2,
        practisedToday: true,
        beginner: null,
      );
      expect(find.byKey(const ValueKey('inline_streak')), findsOneWidget);
      await tester.tap(primary('Next lesson'));
      await settle(tester);
      // No streak screen, no location or save-progress ask: straight back.
      expect(find.text('Your streak has started!'), findsNothing);
      expect(find.text('Where are you learning from?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(requests, 1);
    });

    testWidgets('the notification primer still asks after the first lesson', (
      tester,
    ) async {
      installPrimer(canPrompt: true);
      await pumpResult(
        tester,
        lessonsCompleted: 1,
        practisedToday: true,
        beginner: true,
      );
      await tester.tap(primary('Next lesson'));
      await settle(tester);
      expect(
        find.text('Get a daily reminder to keep your streak?'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('notification_primer_not_now')),
      );
      await settle(tester);
      expect(find.text('open'), findsOneWidget);
    });

    test('beginners only get the primer ask', () {
      expect(LessonCompleteScreen.beginnerAsks, hasLength(1));
      expect(
        LessonCompleteScreen.beginnerAsks.first,
        same(LessonCompleteScreen.asks.first),
      );
    });
  });
}
