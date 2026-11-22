import 'package:bojang/screens/streak_celebration_screen.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/utils/streak_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProgressService> pump(
    WidgetTester tester,
    StreakCelebration celebration,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressService(
      isSignedIn: () => false,
      recordActivity: (_) async => null,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progress,
        child: MaterialApp(
          home: StreakCelebrationScreen(
            celebration: celebration,
            now: DateTime(2026, 11, 21, 15),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return progress;
  }

  testWidgets('first day offers a goal and saves the choice', (tester) async {
    final progress = await pump(
      tester,
      const StreakCelebration(streak: 1, goal: 0),
    );
    expect(find.text('Your streak has started!'), findsOneWidget);
    expect(find.text('Commit to a streak goal'), findsOneWidget);
    await tester.ensureVisible(find.text('14 days'));
    await tester.tap(find.text('14 days'));
    await tester.pump();
    await tester.ensureVisible(find.text('Commit to my goal'));
    await tester.tap(find.text('Commit to my goal'));
    await tester.pump(const Duration(seconds: 1));
    expect(progress.streakGoal, 14);
  });

  testWidgets('a freeze earned on a milestone is explained', (tester) async {
    await pump(
      tester,
      const StreakCelebration(streak: 7, goal: 30, freezeEarned: true),
    );
    expect(find.text('7-day milestone!'), findsOneWidget);
    expect(find.textContaining('You earned a streak freeze'), findsOneWidget);
    expect(find.text('Day 7 of your 30-day goal'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('reaching the goal offers the next one', (tester) async {
    await pump(tester, const StreakCelebration(streak: 7, goal: 7));
    expect(find.text('Goal reached!'), findsOneWidget);
    expect(find.text('Set your next goal'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);
  });

  testWidgets('a used freeze is explained', (tester) async {
    await pump(
      tester,
      const StreakCelebration(streak: 12, goal: 30, freezesUsed: 1),
    );
    expect(find.textContaining('covered the day you missed'), findsOneWidget);
  });

  testWidgets('the goal picker offers 50 days', (tester) async {
    await pump(tester, const StreakCelebration(streak: 1, goal: 0));
    expect(find.text('50 days'), findsOneWidget);
  });

  testWidgets('a restored streak is celebrated', (tester) async {
    await pump(
      tester,
      const StreakCelebration(
        streak: 13,
        goal: 30,
        previousStreak: 1,
        restored: true,
      ),
    );
    expect(find.text('Streak restored!'), findsOneWidget);
    expect(find.textContaining('as if it never broke'), findsOneWidget);
  });

  testWidgets('Earn Back progress is shown after the first lesson', (
    tester,
  ) async {
    await pump(
      tester,
      StreakCelebration(
        streak: 1,
        goal: 7,
        earnBack: EarnBack(
          streak: 12,
          brokeAfter: DateTime(2026, 11, 19),
          expires: DateTime(2026, 11, 23),
          openedOn: DateTime(2026, 11, 21),
          sessionsDone: 1,
        ),
      ),
    );
    expect(find.text('Earn back your 12-day streak'), findsOneWidget);
    expect(find.textContaining('3 days left, 1 of 2 lessons'), findsOneWidget);
  });

  testWidgets('the flame grows a tier at 14 days', (tester) async {
    await pump(tester, const StreakCelebration(streak: 14, goal: 30));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('14-day milestone!'), findsOneWidget);
    expect(find.text('Your flame grew into a Blaze.'), findsOneWidget);
    expect(find.bySemanticsLabel('Blaze streak flame'), findsWidgets);
  });

  testWidgets('the day before a tier teases tomorrow', (tester) async {
    await pump(tester, const StreakCelebration(streak: 29, goal: 30));
    expect(
      find.text('Come back tomorrow and your flame grows into a Bonfire.'),
      findsOneWidget,
    );
  });

  testWidgets('Reduce Motion shows the new flame without animating', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressService(
      isSignedIn: () => false,
      recordActivity: (_) async => null,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progress,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StreakCelebrationScreen(
              celebration: const StreakCelebration(streak: 7, goal: 7),
              now: DateTime(2026, 11, 21, 15),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Nothing is left animating: no pump-and-settle timeout.
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Flame streak flame'), findsOneWidget);
  });
}
