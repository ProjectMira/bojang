/// The streak rule the app applies on the device, mirroring the server's
/// `StreakCalculator.apply_activity` so the streak looks right before the
/// server answers (or while offline). The server stays the source of truth.
///
/// After Duolingo: one lesson or game a day extends the streak; a streak
/// freeze is earned every 7 days of streak (held up to 2) and is spent
/// automatically on a missed day. A frozen day keeps the streak alive but
/// doesn't add to it.
class StreakRules {
  StreakRules._();

  static const maxFreezes = 2;
  static const freezeEveryDays = 7;

  /// Streak lengths that get a bigger celebration.
  static const milestones = [3, 7, 14, 30, 50, 100, 150, 200, 365, 500, 1000];

  /// Goal lengths a learner can commit to, after Duolingo's onboarding.
  static const goals = [7, 14, 30, 50, 100, 365];

  static bool isMilestone(int streak) => milestones.contains(streak);

  /// The next goal after [reached], or null past the last one.
  static int? nextGoal(int reached) {
    for (final g in goals) {
      if (g > reached) return g;
    }
    return null;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days from [a] to [b], immune to daylight-saving shifts.
  static int daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static StreakUpdate apply({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
  }) {
    final held = freezes.clamp(0, maxFreezes);
    final todayKey = _day(today);
    if (lastActive != null && !_day(lastActive).isBefore(todayKey)) {
      if (streak < 1) return _extend(0, held, const []);
      return StreakUpdate(streak: streak, extended: false, freezes: held);
    }
    if (lastActive == null || streak < 1) return _extend(0, held, const []);

    final missed = daysBetween(lastActive, todayKey) - 1;
    if (missed == 0) return _extend(streak, held, const []);
    if (missed <= held) {
      final last = _day(lastActive);
      return _extend(streak, held - missed, [
        for (var i = 1; i <= missed; i++)
          DateTime(last.year, last.month, last.day + i),
      ]);
    }
    return _extend(0, held, const []);
  }

  static StreakUpdate _extend(int previous, int freezes, List<DateTime> frozen) {
    final streak = previous + 1;
    final earned = streak % freezeEveryDays == 0 && freezes < maxFreezes;
    return StreakUpdate(
      streak: streak,
      extended: true,
      freezes: earned ? freezes + 1 : freezes,
      frozenDays: frozen,
      freezeEarned: earned,
    );
  }
}

class StreakUpdate {
  const StreakUpdate({
    required this.streak,
    required this.extended,
    required this.freezes,
    this.frozenDays = const [],
    this.freezeEarned = false,
  });

  final int streak;
  final bool extended;
  final int freezes;

  /// Missed days a freeze covered in this update, oldest first.
  final List<DateTime> frozenDays;
  final bool freezeEarned;
}
