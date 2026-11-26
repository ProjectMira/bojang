// Answering lesson questions in the end-to-end suite.
//
// QuizScreen.debugCurrentQuestion says which option is right, so a test can
// choose a right or a wrong answer. Script exercises without options
// (tracing) are handled by drawing on the pad until it gives up.

import 'package:bojang/models/quiz_question.dart';
import 'package:bojang/screens/lesson_complete_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:bojang/widgets/script/trace_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

final continueButton = find.byKey(const Key('answer-continue'));

QuizQuestion? get currentQuestion => QuizScreen.debugCurrentQuestion;

bool continueEnabled(WidgetTester tester) {
  if (continueButton.evaluate().isEmpty) return false;
  final button = tester.widget<FilledButton>(continueButton);
  return button.onPressed != null;
}

bool get onQuiz => find.byType(QuizScreen).evaluate().isNotEmpty;
bool get onLessonComplete =>
    find.byType(LessonCompleteScreen).evaluate().isNotEmpty;

/// Waits until a question with options (or a trace pad) is on screen.
Future<QuizQuestion> waitForQuestion(
  WidgetTester tester, {
  double timeout = 20,
}) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (timeout * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    final q = currentQuestion;
    if (q != null &&
        (find
                .byKey(const ValueKey('quiz-option-0'))
                .hitTestable()
                .evaluate()
                .isNotEmpty ||
            find.byType(TracePad).evaluate().isNotEmpty)) {
      return q;
    }
  }
  await shot('timeout-question');
  fail('No question on screen after ${timeout}s');
}

/// What happened after answering.
enum AnswerOutcome { autoAdvanced, needsContinue, finished }

/// Answers the question on screen. [right] picks the right option, otherwise
/// a wrong one. Does not tap Continue.
Future<void> answer(WidgetTester tester, {required bool right}) async {
  await waitForQuestion(tester);
  // Decide from what is on screen, not from debugCurrentQuestion alone: just
  // after Continue it can still be the previous question for a frame or two.
  final shown = await waitForAny(tester, [
    find.byType(TracePad),
    find.byKey(const ValueKey('quiz-option-0')).hitTestable(),
  ], timeout: 15);
  if (shown == 0) {
    await _trace(tester);
    return;
  }
  await wait(tester, 0.3);
  final q = currentQuestion!;
  final n = q.options.length;
  final index = right ? q.correctAnswerIndex : (q.correctAnswerIndex + 1) % n;
  await tapIt(tester, find.byKey(ValueKey('quiz-option-$index')), settle: 0.2);
}

/// Draws on the trace pad until it finishes (it shows a stroke after three
/// misses), pressing Check for freehand writing.
Future<void> _trace(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (continueEnabled(tester) || find.byType(TracePad).evaluate().isEmpty)
      return;
    final pad = find.byType(TracePad);
    final box = tester.getRect(
      find.descendant(of: pad, matching: find.byType(GestureDetector)).first,
    );
    await tester.dragFrom(
      box.center - Offset(box.width / 4, 0),
      Offset(box.width / 2, box.height / 4),
    );
    await wait(tester, 0.4);
    final check =
        find.descendant(of: pad, matching: find.text('Check')).hitTestable();
    if (check.evaluate().isNotEmpty) {
      await tester.tap(check.first, warnIfMissed: false);
      await wait(tester, 0.6);
    }
  }
}

/// Answers and waits to see whether the quiz moved on by itself.
Future<AnswerOutcome> answerAndObserve(
  WidgetTester tester, {
  required bool right,
}) async {
  final before = currentQuestion;
  await answer(tester, right: right);
  final end = DateTime.now().add(const Duration(milliseconds: 4000));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (onLessonComplete || !onQuiz) return AnswerOutcome.finished;
    if (!identical(currentQuestion, before) && !continueEnabled(tester)) {
      return AnswerOutcome.autoAdvanced;
    }
  }
  if (continueEnabled(tester)) return AnswerOutcome.needsContinue;
  return AnswerOutcome.finished;
}

Future<void> tapContinue(WidgetTester tester) async {
  await tester.tap(continueButton, warnIfMissed: false);
  await wait(tester, 0.8);
}

/// Answers every remaining question right (Continue where needed) until the
/// lesson-complete screen shows.
Future<void> finishLesson(WidgetTester tester, {int maxQuestions = 40}) async {
  for (var i = 0; i < maxQuestions; i++) {
    if (onLessonComplete) return;
    if (!onQuiz) break;
    // Completion can take a moment after the last answer.
    final idx = await waitForAny(tester, [
      find.byType(LessonCompleteScreen),
      find.byKey(const ValueKey('quiz-option-0')).hitTestable(),
      find.byType(TracePad),
    ], timeout: 20);
    if (idx == 0) return;
    if (idx < 0) break;
    final outcome = await answerAndObserve(tester, right: true);
    if (outcome == AnswerOutcome.needsContinue) await tapContinue(tester);
  }
  await waitFor(
    tester,
    find.byType(LessonCompleteScreen),
    timeout: 20,
    reason: 'lesson complete',
  );
}
