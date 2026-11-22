import 'package:bojang/screens/lesson_complete_screen.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The session end runs result → streak (first practice of the day) → goal
/// → at most one ask, with Continue in the same place on every screen.
void main() {
  Future<ProgressService> pumpResult(
    WidgetTester tester, {
    required int lessonsCompleted,
    required bool practisedToday,
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
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
}
