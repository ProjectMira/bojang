/// Wire models for the weekly leaderboard (`/v1/leaderboard`, plan #24) and
/// family streaks (`/v1/family`, plan #26). Entries carry a display name
/// and numbers only; the server never sends an email or another learner's
/// uid.
library;

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

class WeeklyEntry {
  const WeeklyEntry({
    required this.rank,
    required this.displayName,
    required this.xp,
    this.isMe = false,
  });

  final int rank;
  final String displayName;
  final int xp;
  final bool isMe;

  factory WeeklyEntry.fromJson(Map<String, dynamic> json) => WeeklyEntry(
    rank: _int(json['rank']),
    displayName: (json['display_name'] ?? '').toString(),
    xp: _int(json['xp']),
    isMe: _bool(json['is_me']),
  );
}

class WeeklyMe {
  const WeeklyMe({
    this.rank,
    this.xp = 0,
    this.visible = true,
    this.inTop = false,
    this.displayName = '',
  });

  /// Null with no XP this week, or when the learner is hidden.
  final int? rank;
  final int xp;
  final bool visible;
  final bool inTop;
  final String displayName;

  factory WeeklyMe.fromJson(Map<String, dynamic> json) => WeeklyMe(
    rank: _intOrNull(json['rank']),
    xp: _int(json['xp']),
    visible: _bool(json['visible'], true),
    inTop: _bool(json['in_top']),
    displayName: (json['display_name'] ?? '').toString(),
  );
}

class WeeklyBoard {
  const WeeklyBoard({
    required this.weekStart,
    required this.weekEnd,
    required this.entries,
    required this.me,
    this.totalLearners = 0,
  });

  /// Monday 00:00 UTC; the board resets at [weekEnd] (the next Monday).
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyEntry> entries;
  final WeeklyMe me;
  final int totalLearners;

  /// The learner's own row below the top 50 (null when they are in it, have
  /// no XP yet, or are hidden).
  WeeklyEntry? get ownRowBelow {
    final rank = me.rank;
    if (rank == null || me.inTop) return null;
    return WeeklyEntry(
      rank: rank,
      displayName: me.displayName,
      xp: me.xp,
      isMe: true,
    );
  }

  /// Time left until the reset, never negative.
  Duration timeLeft(DateTime now) {
    final left = weekEnd.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  static WeeklyBoard? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final start = _date(json['week_start']);
    final end = _date(json['week_end']);
    if (start == null || end == null) return null;
    final raw = json['entries'];
    final me = json['me'];
    return WeeklyBoard(
      weekStart: start,
      weekEnd: end,
      entries: [
        if (raw is List)
          for (final e in raw)
            if (e is Map) WeeklyEntry.fromJson(Map<String, dynamic>.from(e)),
      ],
      me:
          me is Map
              ? WeeklyMe.fromJson(Map<String, dynamic>.from(me))
              : const WeeklyMe(),
      totalLearners: _int(json['total_learners']),
    );
  }
}

/// How the learner finished a past week.
class WeeklyResult {
  const WeeklyResult({
    required this.weekStart,
    this.rank,
    this.xp = 0,
    this.totalLearners = 0,
  });

  final DateTime weekStart;
  final int? rank;
  final int xp;
  final int totalLearners;

  /// The key remembered once the result has been shown.
  String get weekKey => weekStart.toUtc().toIso8601String().substring(0, 10);

  /// Shown once per week, only when the learner placed.
  bool shouldShow(String? lastShownWeek) =>
      rank != null && xp > 0 && lastShownWeek != weekKey;

  static WeeklyResult? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final start = _date(json['week_start']);
    if (start == null) return null;
    return WeeklyResult(
      weekStart: start,
      rank: _intOrNull(json['rank']),
      xp: _int(json['xp']),
      totalLearners: _int(json['total_learners']),
    );
  }
}

/// Short reset label in the learner's own clock, e.g. "Resets in 2d 5h".
String weeklyResetLabel(Duration left) {
  if (left.inDays >= 1) {
    return 'Resets in ${left.inDays}d ${left.inHours % 24}h';
  }
  if (left.inHours >= 1) {
    return 'Resets in ${left.inHours}h ${left.inMinutes % 60}m';
  }
  return 'Resets in ${left.inMinutes.clamp(1, 59)}m';
}

class FamilyMember {
  const FamilyMember({
    required this.linkId,
    required this.displayName,
    this.streak = 0,
    this.sharedStreak = 0,
    this.practisedToday = false,
    this.youPractisedToday = false,
    this.canNudge = false,
    this.nudgedToday = false,
  });

  final String linkId;
  final String displayName;
  final int streak;
  final int sharedStreak;
  final bool practisedToday;
  final bool youPractisedToday;
  final bool canNudge;
  final bool nudgedToday;

  bool get bothDoneToday => practisedToday && youPractisedToday;

  FamilyMember copyWith({bool? canNudge, bool? nudgedToday}) => FamilyMember(
    linkId: linkId,
    displayName: displayName,
    streak: streak,
    sharedStreak: sharedStreak,
    practisedToday: practisedToday,
    youPractisedToday: youPractisedToday,
    canNudge: canNudge ?? this.canNudge,
    nudgedToday: nudgedToday ?? this.nudgedToday,
  );

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    linkId: (json['link_id'] ?? '').toString(),
    displayName: (json['display_name'] ?? '').toString(),
    streak: _int(json['streak']),
    sharedStreak: _int(json['shared_streak']),
    practisedToday: _bool(json['practised_today']),
    youPractisedToday: _bool(json['you_practised_today']),
    canNudge: _bool(json['can_nudge']),
    nudgedToday: _bool(json['nudged_today']),
  );
}

class FamilyState {
  const FamilyState({this.members = const [], this.maxMembers = 5});

  final List<FamilyMember> members;
  final int maxMembers;

  bool get isFull => members.length >= maxMembers;

  static FamilyState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final raw = json['members'];
    return FamilyState(
      members: [
        if (raw is List)
          for (final m in raw)
            if (m is Map) FamilyMember.fromJson(Map<String, dynamic>.from(m)),
      ],
      maxMembers: json['max_members'] is num ? _int(json['max_members']) : 5,
    );
  }
}

class FamilyInvite {
  const FamilyInvite({required this.code, this.expiresAt});

  /// As shown and shared, e.g. "K7QH-M2XP".
  final String code;
  final DateTime? expiresAt;

  static FamilyInvite? fromJson(Map<String, dynamic>? json) {
    final code = json?['code'];
    if (code is! String || code.isEmpty) return null;
    return FamilyInvite(code: code, expiresAt: _date(json!['expires_at']));
  }
}

/// What a typed invite code becomes before it is sent: letters and digits
/// only, upper case. Null when it cannot be a code (8 characters).
String? normalizeInviteCode(String raw) {
  final code = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return code.length == 8 ? code : null;
}

/// Why accepting a code failed, from the server's error.
enum InviteError { invalid, ownCode, alreadyLinked, full, theirFull, offline }

InviteError inviteErrorFrom(int? status, Object? detail) {
  if (status == null) return InviteError.offline;
  final error = detail is Map ? detail['error'] : null;
  return switch (error) {
    'own_code' => InviteError.ownCode,
    'already_linked' => InviteError.alreadyLinked,
    'family_full' => InviteError.full,
    'their_family_full' => InviteError.theirFull,
    _ => InviteError.invalid,
  };
}

String inviteErrorMessage(InviteError error) => switch (error) {
  InviteError.invalid =>
    'That code did not work. Codes last 7 days and work once.',
  InviteError.ownCode => 'That is your own code. Share it with family instead.',
  InviteError.alreadyLinked => 'You are already linked with them.',
  InviteError.full => 'Your family is full (5 people).',
  InviteError.theirFull => 'Their family is full (5 people).',
  InviteError.offline => 'No connection. Try again in a moment.',
};
