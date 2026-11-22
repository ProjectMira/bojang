/// The screens after a lesson, always in this order:
///
/// 1. **result**: the score, and the lesson's celebration;
/// 2. **streak**: only after the first practice of the day;
/// 3. **goal**: lesson-goal progress, only when a lesson milestone is hit;
/// 4. **ask**: at most one request (location, notifications...), the
///    first that wants to show.
///
/// Every screen keeps its Continue button in the same place
/// (`SessionEndScaffold`). Following the peak-end rule, the biggest
/// celebration is kept for the first lesson ever and for milestones, not
/// every lesson.
enum SessionEndStep { result, streak, goal, ask }

/// How loudly the result screen celebrates.
enum CelebrationSize {
  /// First lesson ever, or a lesson milestone: confetti and the big yak.
  big,

  /// A passed lesson: a cheering yak, no confetti.
  normal,

  /// Below the pass mark: an encouraging yak.
  quiet,
}

class SessionEndSequence {
  SessionEndSequence._();

  /// Pass mark, in percent, as on the server.
  static const double passAccuracy = 70;

  /// Lessons-finished counts that are celebrated as milestones.
  static const lessonMilestones = [1, 5, 10, 25, 50, 100, 250, 500, 1000];

  static bool isLessonMilestone(int lessonsCompleted) =>
      lessonMilestones.contains(lessonsCompleted);

  /// The next lesson milestone above [lessonsCompleted], or null past the
  /// last one.
  static int? nextLessonMilestone(int lessonsCompleted) {
    for (final m in lessonMilestones) {
      if (m > lessonsCompleted) return m;
    }
    return null;
  }

  static CelebrationSize celebrationFor({
    required int lessonsCompleted,
    required double accuracy,
  }) {
    if (lessonsCompleted == 1 || isLessonMilestone(lessonsCompleted)) {
      return CelebrationSize.big;
    }
    return accuracy >= passAccuracy
        ? CelebrationSize.normal
        : CelebrationSize.quiet;
  }

  /// Whether the goal step shows: on a lesson milestone that has a next
  /// goal to aim for. The first lesson is celebrated on the result screen
  /// alone.
  static bool showsGoal(int lessonsCompleted) =>
      lessonsCompleted > 1 &&
      isLessonMilestone(lessonsCompleted) &&
      nextLessonMilestone(lessonsCompleted) != null;

  /// The steps after the result, in order. The ask is only a slot: each
  /// ask decides at run time whether it wants to show, and at most one does.
  static List<SessionEndStep> plan({
    required bool streakPending,
    required int lessonsCompleted,
  }) => [
    SessionEndStep.result,
    if (streakPending) SessionEndStep.streak,
    if (showsGoal(lessonsCompleted)) SessionEndStep.goal,
    SessionEndStep.ask,
  ];
}
