import 'package:bojang/utils/yak_lines.dart';
import 'package:bojang/widgets/yak_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YakMascot', () {
    testWidgets('paints every mood, with and without a body', (tester) async {
      for (final showBody in [true, false]) {
        for (final mood in YakMood.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: YakMascot(mood: mood, size: 160, showBody: showBody),
              ),
            ),
          );
          // Sample several points of the idle loop: blink, jump, wave.
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 730));
          }
          expect(tester.takeException(), isNull, reason: '$mood body=$showBody');
        }
      }
    });

    testWidgets('a full-body yak is narrower than tall; head-only is square', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              YakMascot(key: Key('body'), size: 200),
              YakMascot(key: Key('head'), size: 80, showBody: false),
            ],
          ),
        ),
      );
      final body = tester.getSize(find.byKey(const Key('body')));
      final head = tester.getSize(find.byKey(const Key('head')));
      expect(body.height, 200);
      expect(body.width, lessThan(200));
      expect(head, const Size(80, 80));
    });

    testWidgets('changing mood tweens instead of throwing', (tester) async {
      Future<void> show(YakMood mood) => tester.pumpWidget(
        MaterialApp(home: Center(child: YakMascot(mood: mood))),
      );
      await show(YakMood.happy);
      await show(YakMood.cheering);
      await tester.pump(const Duration(milliseconds: 100));
      // Interrupt the transition halfway.
      await show(YakMood.sad);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds still when the system asks for reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(child: YakMascot(mood: YakMood.cheering)),
          ),
        ),
      );
      // Nothing is animating, so this returns instead of timing out.
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is decorative unless given a label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              YakMascot(animate: false),
              YakMascot(animate: false, semanticLabel: 'Norbu waving'),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Norbu waving'), findsOneWidget);
    });
  });

  group('YakLines', () {
    final noon = DateTime(2026, 11, 14, 12);

    test('greets a brand-new learner by name', () {
      final line = YakLines.home(
        now: noon,
        streak: 0,
        practicedToday: false,
        isNewLearner: true,
      );
      expect(line.mood, YakMood.waving);
      expect(line.body, contains(YakLines.name));
    });

    test('is proud once today is done and names the streak', () {
      final line = YakLines.home(
        now: DateTime(2026, 11, 2, 12),
        streak: 5,
        practicedToday: true,
        isNewLearner: false,
      );
      expect(line.mood, YakMood.proud);
    });

    test('nudges in the evening when a streak is at risk', () {
      final line = YakLines.home(
        now: DateTime(2026, 11, 14, 21),
        streak: 4,
        practicedToday: false,
        isNewLearner: false,
      );
      expect(line.mood, YakMood.encouraging);
      expect(line.body, contains('4-day'));
    });

    test('the same seed gives the same line', () {
      expect(
        YakLines.correct(seed: 3).title,
        YakLines.correct(seed: 3).title,
      );
    });

    test('calls out a run of right answers', () {
      expect(YakLines.correct(seed: 0, combo: 3).title, '3 in a row!');
      expect(YakLines.correct(seed: 0, combo: 10).title, '10 in a row!');
    });

    test('a miss is met with encouragement, never sadness', () {
      for (var seed = 0; seed < 6; seed++) {
        expect(YakLines.incorrect(seed: seed).mood, YakMood.encouraging);
      }
    });

    test('lesson results: cheer for a pass, encourage otherwise', () {
      expect(YakLines.lessonComplete(accuracy: 100).mood, YakMood.cheering);
      expect(YakLines.lessonComplete(accuracy: 70).mood, YakMood.cheering);
      expect(YakLines.lessonComplete(accuracy: 40).mood, YakMood.encouraging);
    });

    test('streak mood follows the streak', () {
      expect(
        YakLines.streakMood(streak: 0, practicedToday: false),
        YakMood.sleeping,
      );
      expect(
        YakLines.streakMood(streak: 3, practicedToday: false),
        YakMood.encouraging,
      );
      expect(
        YakLines.streakMood(streak: 3, practicedToday: true),
        YakMood.proud,
      );
      expect(
        YakLines.streakMood(streak: 7, practicedToday: true),
        YakMood.cheering,
      );
    });
  });
}
