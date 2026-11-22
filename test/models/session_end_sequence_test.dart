import 'package:bojang/utils/session_end_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionEndSequence', () {
    test('the order is always result, streak, goal, ask', () {
      expect(
        SessionEndSequence.plan(streakPending: true, lessonsCompleted: 10),
        [
          SessionEndStep.result,
          SessionEndStep.streak,
          SessionEndStep.goal,
          SessionEndStep.ask,
        ],
      );
    });

    test('the streak step is only for the first practice of the day', () {
      expect(
        SessionEndSequence.plan(streakPending: false, lessonsCompleted: 7),
        [SessionEndStep.result, SessionEndStep.ask],
      );
    });

    test('the goal step shows on lesson milestones with a next goal', () {
      expect(SessionEndSequence.showsGoal(1), isFalse); // the result covers it
      expect(SessionEndSequence.showsGoal(5), isTrue);
      expect(SessionEndSequence.showsGoal(6), isFalse);
      expect(SessionEndSequence.showsGoal(1000), isFalse); // no next goal
      expect(SessionEndSequence.nextLessonMilestone(10), 25);
      expect(SessionEndSequence.nextLessonMilestone(1000), isNull);
    });

    test('the big celebration is for the first lesson and milestones', () {
      CelebrationSize size(int lessons, double accuracy) =>
          SessionEndSequence.celebrationFor(
            lessonsCompleted: lessons,
            accuracy: accuracy,
          );
      expect(size(1, 40), CelebrationSize.big);
      expect(size(25, 90), CelebrationSize.big);
      expect(size(26, 100), CelebrationSize.normal);
      expect(size(26, 70), CelebrationSize.normal);
      expect(size(26, 69), CelebrationSize.quiet);
      expect(size(0, 100), CelebrationSize.normal); // count unknown
    });
  });
}
