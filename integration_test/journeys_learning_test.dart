// Learning journeys: onboarding, Home, lesson intro, quiz, lesson complete
// and Practice review. Run through ci/scripts/e2e.sh (see TESTING.md).

import 'package:bojang/screens/lesson_complete_screen.dart';
import 'package:bojang/screens/lesson_intro_screen.dart';
import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';
import 'support/quiz_helpers.dart';

const _notifications = 'dexterous.com/flutter/local_notifications';
const _messaging = 'plugins.flutter.io/firebase_messaging';

/// Messaging#requestPermission calls that would show the iOS dialog.
List<MethodCall> fullPushRequests() => [
  for (final c in channelCalls[_messaging] ?? const <MethodCall>[])
    if (c.method == 'Messaging#requestPermission' && !isProvisionalRequest(c))
      c,
];

/// Goes through onboarding from the hello step.
Future<void> onboard(
  WidgetTester tester, {
  required String knowledge,
  String voice = 'voice_lhasa_female',
  bool shots = false,
}) async {
  await waitFor(
    tester,
    find.byKey(const ValueKey('onboarding_start')),
    timeout: 30,
    reason: 'onboarding hello',
  );
  if (shots) await shot('onboarding-1-hello');
  await tapIt(tester, find.byKey(const ValueKey('onboarding_start')));
  await waitFor(tester, find.text('Why are you learning Tibetan?'));
  if (shots) await shot('onboarding-2-motivation');
  await tapIt(tester, find.byKey(const ValueKey('motivation_heritage')));
  await waitFor(tester, find.text('How much Tibetan do you know?'));
  if (shots) await shot('onboarding-3-knowledge');
  await tapIt(tester, find.byKey(ValueKey('knowledge_$knowledge')));
  await waitFor(tester, find.text('Which Tibetan do you want to hear?'));
  if (shots) await shot('onboarding-4-voice');
  await tapIt(tester, find.byKey(ValueKey(voice)));
  await waitFor(tester, find.text('How much a day?'));
  if (shots) await shot('onboarding-5-goal');
  await tapIt(tester, find.byKey(const ValueKey('goal_1')));
}

/// Dismisses whatever comes between a finished lesson and Home: the
/// reminder primer, streak celebration, goal screen, location prompt.
/// Returns what it saw.
Future<Set<String>> passInterstitials(
  WidgetTester tester, {
  bool allowPrimer = true,
}) async {
  final seen = <String>{};
  for (var i = 0; i < 8; i++) {
    final idx = await waitForAny(tester, [
      find.byKey(const ValueKey('notification_primer_allow')).hitTestable(),
      find.text('Where are you learning from?'),
      find.text('Commit to my goal').hitTestable(),
      find.byType(MainNavigationScreen).hitTestable(),
      find.text('Continue').hitTestable(),
    ], timeout: 6);
    switch (idx) {
      case 0:
        seen.add('primer');
        await shot('primer');
        await tapIt(
          tester,
          find.byKey(
            ValueKey(
              allowPrimer
                  ? 'notification_primer_allow'
                  : 'notification_primer_not_now',
            ),
          ),
          settle: 1.5,
        );
      case 1:
        seen.add('location');
        await tapIt(tester, find.text('Not now').last, settle: 1);
      case 2:
        seen.add('streak');
        await tapIt(tester, find.text('Commit to my goal'), settle: 1);
      case 3:
        return seen;
      case 4:
        // Streak celebration / goal screen (not the quiz banner: no quiz here).
        if (onQuiz) return seen;
        seen.add('continue');
        await tapIt(tester, find.text('Continue').hitTestable(), settle: 1);
      default:
        return seen;
    }
  }
  return seen;
}

/// Leaves the screen on top of Home: a lesson via Leave lesson > Quit,
/// anything else with its back button.
Future<void> leaveScreen(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    if (find.byType(MainNavigationScreen).hitTestable().evaluate().isNotEmpty) {
      return;
    }
    if (onQuiz && find.byTooltip('Leave lesson').evaluate().isNotEmpty) {
      await tapIt(tester, find.byTooltip('Leave lesson'));
      final d = await waitForAny(tester, [find.text('Quit')], timeout: 3);
      if (d == 0) await tapText(tester, 'Quit', settle: 1.5);
    } else {
      await tester.pageBack();
      await wait(tester, 1.5);
    }
  }
}

void main() {
  initBinding();

  testWidgets('fresh install onboarding: no notification prompt, Amdo voice', (
    tester,
  ) async {
    await launchApp(tester);
    await onboard(
      tester,
      knowledge: 'none',
      voice: 'voice_amdo_male',
      shots: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pronunciation_voice'), 'amdo_male');
    // Onboarding ends in the first lesson's intro.
    await waitForAny(tester, [
      find.byType(LessonIntroScreen),
      find.byType(QuizScreen),
    ], timeout: 20);
    await wait(tester, 2);
    expect(
      calledMethod(_notifications, 'requestPermissions'),
      isFalse,
      reason: 'local notification permission asked during onboarding',
    );
    expect(
      fullPushRequests(),
      isEmpty,
      reason: 'push permission dialog requested during onboarding',
    );
    expect(prefs.getString('onboarding_status'), 'done');
  });

  testWidgets('Home opens straight on the path; a path step opens', (
    tester,
  ) async {
    await launchApp(tester);
    await waitFor(
      tester,
      find.byKey(const ValueKey('onboarding_skip')),
      timeout: 30,
    );
    await tapIt(
      tester,
      find.byKey(const ValueKey('onboarding_skip')),
      settle: 1,
    );
    await waitFor(tester, find.byType(MainNavigationScreen), timeout: 15);
    // The path itself, not a loading or intermediate screen.
    await waitFor(
      tester,
      find.byKey(const ValueKey('path_start_button')),
      timeout: 20,
      reason: 'path start button on Home',
    );
    expect(find.text('Browse all topics'), findsWidgets);
    await shot('home-path');
    final routesBefore =
        find.byType(MainNavigationScreen).hitTestable().evaluate().length;
    expect(routesBefore, 1);
    await tapIt(
      tester,
      find.byKey(const ValueKey('path_start_button')),
      settle: 2,
    );
    expect(
      find.byType(MainNavigationScreen).hitTestable(),
      findsNothing,
      reason: 'tapping the active path step should push a screen',
    );
    await shot('home-path-step-opened');
  });

  testWidgets(
    'lesson intro auto-plays, then quiz: warm-up, Continue, auto-advance, Keep going?',
    (tester) async {
      await launchApp(tester);
      await onboard(tester, knowledge: 'none');
      await waitFor(
        tester,
        find.byType(LessonIntroScreen),
        timeout: 20,
        reason: 'lesson intro',
      );
      final hearAll = find.byKey(const Key('lesson-intro-hear-all'));
      await waitFor(tester, hearAll, timeout: 15);
      // The letter tour starts by itself (on the first frame after loading).
      await waitFor(
        tester,
        find.descendant(of: hearAll, matching: find.text('Stop')),
        timeout: 4,
        reason: 'letters should auto-play on open',
      );
      await shot('lesson-intro-autoplay');
      await waitFor(
        tester,
        find.descendant(of: hearAll, matching: find.text('Hear all')),
        timeout: 30,
        reason: 'tour ends',
      );
      await tapIt(tester, hearAll);
      expect(
        find.descendant(of: hearAll, matching: find.text('Stop')),
        findsOneWidget,
      );
      await tapIt(tester, hearAll);
      expect(
        find.descendant(of: hearAll, matching: find.text('Hear all')),
        findsOneWidget,
      );

      await tapIt(tester, find.text('Start practice').last, settle: 1);
      await waitFor(tester, find.byType(QuizScreen), timeout: 10);
      final first = await waitForQuestion(tester);
      await shot('quiz-first-question');
      expect(
        first.options.length,
        2,
        reason: 'first question is a two-choice warm-up',
      );

      // Wrong answer: stays until Continue.
      var outcome = await answerAndObserve(tester, right: false);
      expect(
        outcome,
        AnswerOutcome.needsContinue,
        reason: 'wrong answer must wait for Continue',
      );
      await shot('quiz-wrong-continue');
      await tapContinue(tester);

      // A right answer moves on by itself (skip trace questions, which have no options).
      var sawAutoAdvance = false;
      for (var i = 0; i < 8 && !sawAutoAdvance; i++) {
        final q = await waitForQuestion(tester);
        if (q.options.isEmpty) {
          await answer(tester, right: true);
          await waitFor(tester, continueButton.hitTestable(), timeout: 10);
          await wait(tester, 0.5);
          if (continueEnabled(tester)) await tapContinue(tester);
          continue;
        }
        outcome = await answerAndObserve(tester, right: true);
        if (outcome == AnswerOutcome.autoAdvanced) sawAutoAdvance = true;
        if (outcome == AnswerOutcome.needsContinue) await tapContinue(tester);
      }
      expect(
        sawAutoAdvance,
        isTrue,
        reason: 'a right answer should auto-advance',
      );

      // Back asks first.
      await tapIt(tester, find.byTooltip('Leave lesson'));
      await waitFor(tester, find.text('Keep going?'));
      await shot('quiz-keep-going');
      await tapText(tester, 'Keep learning');
      expect(find.text('Keep going?'), findsNothing);
      expect(find.byType(QuizScreen), findsOneWidget);
      await tapIt(tester, find.byTooltip('Leave lesson'));
      await waitFor(tester, find.text('Keep going?'));
      await tapText(tester, 'Quit', settle: 1.5);
      await waitGone(tester, find.byType(QuizScreen));
    },
  );

  testWidgets(
    'finish a lesson: beginner result, reminder primer, next lesson, then Practice',
    (tester) async {
      await launchApp(tester);
      await onboard(tester, knowledge: 'speak_some');
      // vocab-action has no intro: straight into the quiz (or via the intro).
      final idx = await waitForAny(tester, [
        find.byType(QuizScreen),
        find.byType(LessonIntroScreen),
      ], timeout: 20);
      if (idx == 1)
        await tapIt(tester, find.text('Start practice').last, settle: 1);
      await waitFor(tester, find.byType(QuizScreen));

      // First answer wrong, so the word comes back in Practice.
      final outcome = await answerAndObserve(tester, right: false);
      expect(outcome, AnswerOutcome.needsContinue);
      await tapContinue(tester);
      await finishLesson(tester);

      await waitFor(tester, find.text('Your first lesson!'), timeout: 10);
      await wait(tester, 1.5);
      await shot('lesson-complete-beginner');
      expect(
        find.text('Next lesson'),
        findsOneWidget,
        reason: 'beginner primary button',
      );
      expect(find.text('Continue'), findsNothing);
      // Reported, not asserted: 'Practice again' is also shown.
      debugPrint(
        'REPORT:- Lesson complete (beginner): "Practice again" shown: '
        '${find.text('Practice again').evaluate().isNotEmpty}',
      );

      await tapText(tester, 'Next lesson', settle: 1.5);
      final seen = await passInterstitials(tester);
      expect(
        seen,
        contains('primer'),
        reason: 'reminder primer after the first lesson',
      );
      expect(
        fullPushRequests(),
        isNotEmpty,
        reason: '"Allow" asks iOS for permission',
      );
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // A beginner's Next lesson opens the next path step from Home.
      final home = find.byType(MainNavigationScreen).hitTestable();
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (home.evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await wait(tester, 1.5);
      await shot('beginner-next-lesson');
      expect(
        home,
        findsNothing,
        reason: 'next lesson should open from Home by itself',
      );

      // Leave it and review the missed word in Practice.
      await leaveScreen(tester);
      await waitFor(
        tester,
        find.byType(MainNavigationScreen).hitTestable(),
        timeout: 10,
      );
      await tapText(tester, 'Practice', settle: 1);
      final practice = await waitForAny(tester, [
        find.byKey(const ValueKey('review_start_button')),
        find.text('Nothing to review yet'),
        find.text('All caught up'),
        find.text('Can’t reach Bojang'),
        find.text('Review needs an account'),
      ], timeout: 20);
      await shot('practice');
      expect(
        practice,
        0,
        reason: 'the word missed in the lesson should be up for review',
      );
      await tapIt(
        tester,
        find.byKey(const ValueKey('review_start_button')),
        settle: 1,
      );
      await waitFor(tester, find.byType(QuizScreen), timeout: 10);
      final q = await waitForQuestion(tester);
      expect(q.options, isNotEmpty);
      await shot('review-question');
      final o = await answerAndObserve(tester, right: true);
      if (o == AnswerOutcome.needsContinue) await tapContinue(tester);
      if (onQuiz) {
        await tapIt(tester, find.byTooltip('Leave lesson'));
        final d = await waitForAny(tester, [find.text('Quit')], timeout: 3);
        if (d == 0) await tapText(tester, 'Quit', settle: 1.5);
        await waitGone(tester, find.byType(QuizScreen));
      }
    },
  );
}
