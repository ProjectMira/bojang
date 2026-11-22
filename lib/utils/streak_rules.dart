/// The streak rule the app applies on the device, mirroring the server's
/// `StreakCalculator.apply_activity` so the streak looks right before the
/// server answers (or while offline). The server stays the source of truth.
///
/// After Duolingo: one lesson or game a day extends the streak; a streak
/// freeze is earned every 7 days of streak (held up to 2) and is spent
/// automatically on a missed day. A frozen day keeps the streak alive but
/// doesn't add to it.
///
/// Earn Back: when a streak breaks with no freeze to cover it, a 3-day
/// window opens; finishing 2 sessions inside it restores the streak as if it
/// never broke. No currency.
class StreakRules {
  StreakRules._();

  static const maxFreezes = 2;
  static const freezeEveryDays = 7;

  static const earnBackWindowDays = 3;
  static const earnBackSessions = 2;

  /// A 1-day streak is a restart, not worth a window.
  static const earnBackMinStreak = 2;

  /// Streak lengths where the flame grows a tier (see [FlameTier]).
  static const tierThresholds = [7, 14, 30, 50];

  static FlameTier tierFor(int streak) {
    var tier = 0;
    for (final t in tierThresholds) {
      if (streak >= t) tier++;
    }
    return FlameTier.values[tier];
  }

  /// The tier a streak of [streak] days reaches tomorrow, if it grows then.
  static FlameTier? tierTomorrow(int streak) =>
      streak > 0 && tierThresholds.contains(streak + 1)
          ? tierFor(streak + 1)
          : null;

  /// The next streak length that grows the flame, or null past the last.
  static int? nextTierAt(int streak) {
    for (final t in tierThresholds) {
      if (t > streak) return t;
    }
    return null;
  }

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
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(
        b.year,
        b.month,
        b.day,
      ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// The streak after activity on [today]. [earnBack] is the open Earn
  /// Back window, if any: a break opens one (while still inside it), and
  /// [session] counts this activity as one finished session toward it.
  static StreakUpdate apply({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
    EarnBack? earnBack,
    bool session = false,
  }) {
    final base = _applyDays(
      streak: streak,
      lastActive: lastActive,
      freezes: freezes,
      today: today,
    );
    return _applyEarnBack(
      base,
      streak: streak,
      lastActive: lastActive,
      freezes: freezes,
      today: _day(today),
      window: earnBack,
      session: session,
    );
  }

  static StreakUpdate _applyDays({
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

  /// The Earn Back window a broken streak is owed on [today], if any. Held
  /// freezes cover the days after the last active day; the first day they
  /// can't cover is the day it broke, and the window is the
  /// [earnBackWindowDays] days after that.
  static EarnBack? offeredWindow({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
  }) {
    if (lastActive == null || streak < earnBackMinStreak) return null;
    final last = _day(lastActive);
    final held = freezes.clamp(0, maxFreezes);
    final brokeOn = DateTime(last.year, last.month, last.day + held + 1);
    final expires = DateTime(
      brokeOn.year,
      brokeOn.month,
      brokeOn.day + earnBackWindowDays,
    );
    final t = _day(today);
    if (!t.isAfter(brokeOn) || t.isAfter(expires)) return null;
    return EarnBack(streak: streak, brokeAfter: last, expires: expires);
  }

  /// The Earn Back to show on [today]: the stored window while it lasts,
  /// otherwise one owed to a break nothing has counted yet.
  static EarnBack? earnBackStatus({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required EarnBack? stored,
    required DateTime today,
  }) {
    if (stored != null && stored.isOpenOn(today)) return stored;
    return offeredWindow(
      streak: streak,
      lastActive: lastActive,
      freezes: freezes,
      today: today,
    );
  }

  static StreakUpdate _applyEarnBack(
    StreakUpdate base, {
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
    required EarnBack? window,
    required bool session,
  }) {
    var changed = false, started = false, restored = false;
    if (window != null && !window.isOpenOn(today)) {
      window = null; // expired
      changed = true;
    }
    if (window == null && base.extended) {
      final offered = offeredWindow(
        streak: streak,
        lastActive: lastActive,
        freezes: freezes,
        today: today,
      );
      if (offered != null) {
        window = offered.copyWith(openedOn: today);
        changed = started = true;
      }
    }

    var newStreak = base.streak;
    var held = base.freezes;
    var earned = base.freezeEarned;
    var repaired = const <DateTime>[];
    if (window != null && session) {
      window = window.copyWith(
        openedOn: window.openedOn ?? today,
        sessionsDone: window.sessionsDone + 1,
      );
      changed = true;
      if (window.sessionsDone >= earnBackSessions) {
        // Back as if it never broke: the old streak plus the days since,
        // with the missed gap repaired.
        final from = window.brokeAfter;
        final opened = window.openedOn ?? today;
        repaired = [
          for (var i = 1; i < daysBetween(from, opened); i++)
            DateTime(from.year, from.month, from.day + i),
        ];
        newStreak = window.streak + base.streak;
        if (!earned && newStreak % freezeEveryDays == 0 && held < maxFreezes) {
          held += 1;
          earned = true;
        }
        window = null;
        restored = true;
      }
    }

    return StreakUpdate(
      streak: newStreak,
      extended: base.extended,
      freezes: held,
      frozenDays: base.frozenDays,
      freezeEarned: earned,
      earnBack: window,
      earnBackChanged: changed,
      earnBackStarted: started,
      streakRestored: restored,
      earnedBackDays: repaired,
    );
  }

  static StreakUpdate _extend(
    int previous,
    int freezes,
    List<DateTime> frozen,
  ) {
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
    this.earnBack,
    this.earnBackChanged = false,
    this.earnBackStarted = false,
    this.streakRestored = false,
    this.earnedBackDays = const [],
  });

  final int streak;
  final bool extended;
  final int freezes;

  /// Missed days a freeze covered in this update, oldest first.
  final List<DateTime> frozenDays;
  final bool freezeEarned;

  /// The Earn Back window after this update (null: none), whether it
  /// changed, whether this update opened it, and whether it restored the
  /// streak, with the missed days the restore repaired.
  final EarnBack? earnBack;
  final bool earnBackChanged;
  final bool earnBackStarted;
  final bool streakRestored;
  final List<DateTime> earnedBackDays;
}

/// The flame's look grows with the streak: a tier at 7, 14, 30 and 50 days.
enum FlameTier { spark, flame, blaze, bonfire, golden }

extension FlameTierName on FlameTier {
  String get label => switch (this) {
    FlameTier.spark => 'Spark',
    FlameTier.flame => 'Flame',
    FlameTier.blaze => 'Blaze',
    FlameTier.bonfire => 'Bonfire',
    FlameTier.golden => 'Golden flame',
  };
}

/// An Earn Back window, mirroring the server's `earn_back` (see
/// `gamification.EarnBack`): finish [StreakRules.earnBackSessions] sessions
/// by [expires] (a local day, inclusive) and [streak] comes back.
class EarnBack {
  const EarnBack({
    required this.streak,
    required this.brokeAfter,
    required this.expires,
    this.openedOn,
    this.sessionsDone = 0,
  });

  /// The streak that broke, restored on success.
  final int streak;

  /// The last day practiced before the break; the gap starts the day after.
  final DateTime brokeAfter;
  final DateTime expires;

  /// The first counted day in the window (null: offered, nothing done yet).
  final DateTime? openedOn;
  final int sessionsDone;

  int get sessionsNeeded => StreakRules.earnBackSessions;

  bool isOpenOn(DateTime today) =>
      !StreakRules._day(today).isAfter(StreakRules._day(expires));

  /// Days left including [today].
  int daysLeft(DateTime today) => StreakRules.daysBetween(today, expires) + 1;

  EarnBack copyWith({DateTime? openedOn, int? sessionsDone}) => EarnBack(
    streak: streak,
    brokeAfter: brokeAfter,
    expires: expires,
    openedOn: openedOn ?? this.openedOn,
    sessionsDone: sessionsDone ?? this.sessionsDone,
  );

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _date(Object? v) {
    final parsed = v == null ? null : DateTime.tryParse(v.toString());
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// The server's status shape, plus `opened_on` for the device's copy.
  Map<String, dynamic> toJson() => {
    'active': true,
    'sessions_done': sessionsDone,
    'sessions_needed': sessionsNeeded,
    'expires_at': _iso(expires),
    'streak': streak,
    'broke_after': _iso(brokeAfter),
    if (openedOn != null) 'opened_on': _iso(openedOn!),
  };

  /// Reads the API's `earn_back` (or the device's copy). Null when it is
  /// inactive or malformed.
  static EarnBack? fromJson(Object? json) {
    if (json is! Map || json['active'] != true) return null;
    final expires = _date(json['expires_at']);
    final streak = json['streak'];
    if (expires == null || streak is! int || streak < 1) return null;
    final brokeAfter =
        _date(json['broke_after']) ??
        // Older servers: assume no freezes held at the break.
        DateTime(
          expires.year,
          expires.month,
          expires.day - StreakRules.earnBackWindowDays - 1,
        );
    final done = json['sessions_done'];
    return EarnBack(
      streak: streak,
      brokeAfter: brokeAfter,
      expires: expires,
      openedOn: _date(json['opened_on']),
      sessionsDone: done is int ? done : 0,
    );
  }

  /// The same window (one break), whatever its progress.
  bool sameWindow(EarnBack other) =>
      StreakRules._day(brokeAfter) == StreakRules._day(other.brokeAfter) &&
      StreakRules._day(expires) == StreakRules._day(other.expires);
}
