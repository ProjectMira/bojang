import '../services/offline_queue.dart';

/// What the server has not seen yet: the writes still in the offline queue.
/// Progress shows server values plus these, so a lesson finished offline
/// keeps its XP, streak and Earn Back on screen until the replay lands and
/// the server's answer replaces the guess.
class PendingProgress {
  const PendingProgress({
    this.xp = 0,
    this.lessons = 0,
    this.activityDays = const {},
    this.activities = 0,
  });

  static const PendingProgress none = PendingProgress();

  /// XP the app estimated for queued lesson completions.
  final int xp;
  final int lessons;

  /// Local days (YYYY-MM-DD) with a queued activity report.
  final Set<String> activityDays;

  /// Queued activity reports (each one Earn Back session).
  final int activities;

  bool get isEmpty => lessons == 0 && activities == 0;

  static PendingProgress of(Iterable<QueuedRequest> items) {
    var xp = 0, lessons = 0, activities = 0;
    final days = <String>{};
    for (final item in items) {
      switch (item.kind) {
        case QueuedKind.lessonComplete:
          lessons++;
          final earned = item.body['xp_earned'];
          if (earned is int && earned > 0) xp += earned;
        case QueuedKind.activity:
          activities++;
          final day = item.body['local_date'];
          if (day is String) days.add(day);
        case QueuedKind.kvPatch:
        case QueuedKind.notificationOpened:
          break;
      }
    }
    return PendingProgress(
      xp: xp,
      lessons: lessons,
      activityDays: days,
      activities: activities,
    );
  }

  /// Server XP plus the XP of lessons still queued.
  int mergeXp({required int server}) => server + xp;

  /// The streak to show: the server's, unless days it hasn't seen yet are
  /// queued (or today was played here) and the device's count is higher.
  int mergeStreak({
    required int server,
    required int local,
    required bool playedToday,
  }) {
    if ((activities > 0 || playedToday) && local > server) return local;
    return server;
  }
}
