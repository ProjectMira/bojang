import 'package:shared_preferences/shared_preferences.dart';

/// Counts finished lessons on this device, for the session-end celebration
/// (first lesson ever, lesson milestones).
class LessonMilestones {
  LessonMilestones._();
  static final LessonMilestones instance = LessonMilestones._();

  static const _key = 'lessons_completed';

  /// Records one finished lesson and returns the new total. Call it before
  /// the lesson's questions are added to ProgressService's totals.
  ///
  /// Installs from before this counter existed start from an estimate (ten
  /// questions a lesson), so a returning learner's next lesson is never
  /// mistaken for their first.
  Future<int> recordLessonFinished() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var count = prefs.getInt(_key);
      if (count == null) {
        final questions = prefs.getInt('total_quizzes') ?? 0;
        count = questions > 0 ? (questions / 10).ceil() : 0;
      }
      count += 1;
      await prefs.setInt(_key, count);
      return count;
    } catch (_) {
      // Storage unavailable: treat it as an ordinary lesson.
      return 0;
    }
  }
}
