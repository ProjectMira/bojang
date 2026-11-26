import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_settings.dart';

/// The one place that decides whether a learner is a beginner, for flows
/// that ask fewer taps of them: the short session end (streak inline, one
/// Continue straight into the next lesson, no optional asks) and no
/// name + picture ask yet.
///
/// A beginner has finished at most [maxLessons] lessons (this one included)
/// and has under [maxXp] XP. Both come from Remote Config
/// (`beginner_max_lessons`, `beginner_max_xp`); a lesson earns about 80 XP,
/// so the defaults (3 lessons, 300 XP) agree. Most learners stop within
/// their first two lessons (analytics report, 27 Nov 2026).
class Beginner {
  Beginner._();

  /// Overrides the thresholds in tests.
  @visibleForTesting
  static int? debugMaxLessons;
  @visibleForTesting
  static int? debugMaxXp;

  static int get maxLessons =>
      debugMaxLessons ?? RemoteSettings.getInt('beginner_max_lessons');
  static int get maxXp =>
      debugMaxXp ?? RemoteSettings.getInt('beginner_max_xp');

  /// [lessonsCompleted] counts lessons finished on this device (0 when
  /// unknown, then XP alone decides).
  static bool check({required int lessonsCompleted, required int xp}) {
    final lessons = maxLessons;
    if (lessons <= 0) return false;
    if (lessonsCompleted > lessons) return false;
    return xp < maxXp;
  }

  /// [check] from what is stored on this device, for screens that do not
  /// already know the counts.
  static Future<bool> now() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return check(
        lessonsCompleted: prefs.getInt('lessons_completed') ?? 0,
        xp: prefs.getInt('xp') ?? 0,
      );
    } catch (_) {
      return false;
    }
  }

  /// Asks the screen that shows the learning path (Home) to open the next
  /// lesson once the session end has closed. Bumped by the short session
  /// end; Home listens.
  static final ValueNotifier<int> nextLessonRequests = ValueNotifier(0);
}
