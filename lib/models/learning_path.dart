/// The learning path from `GET /learn/path` (plan item #5): units of nodes,
/// each with a state and a session ring (finished / total sessions).
library;

enum PathNodeState { locked, unlocked, active, passed }

PathNodeState _stateFrom(Object? raw) => switch (raw) {
  'unlocked' => PathNodeState.unlocked,
  'active' => PathNodeState.active,
  'passed' => PathNodeState.passed,
  _ => PathNodeState.locked,
};

/// Node types the server sends. Unknown types still render, as lessons.
class PathNodeType {
  PathNodeType._();
  static const lesson = 'lesson';
  static const practice = 'practice';
  static const unitReview = 'unit_review';
  static const alphabet = 'alphabet';
  static const alphabetGate = 'alphabet_gate';
  static const dialogue = 'dialogue';
}

class PathNode {
  const PathNode({
    required this.id,
    required this.type,
    required this.title,
    this.subtype = '',
    this.state = PathNodeState.locked,
    this.levelId,
    this.finishedSessions = 0,
    this.totalSessions = 1,
    this.sessionWords,
    this.route,
    this.hasLesson = false,
  });

  final String id;
  final String type;
  final String subtype;
  final String title;
  final PathNodeState state;
  final String? levelId;
  final int finishedSessions;
  final int totalSessions;
  final int? sessionWords;

  /// Named app route the node opens (`/script`, `/script/gate`, ...).
  final String? route;

  /// A Basics lesson: open its teaching cards before practice.
  final bool hasLesson;

  bool get isLocked => state == PathNodeState.locked;
  bool get isActive => state == PathNodeState.active;
  bool get isPassed => state == PathNodeState.passed;

  /// 0..1 for the session ring.
  double get progress =>
      totalSessions <= 0
          ? 0
          : (finishedSessions / totalSessions).clamp(0.0, 1.0).toDouble();

  /// Practice and unit review nodes run a review session.
  bool get isReview =>
      type == PathNodeType.practice || type == PathNodeType.unitReview;

  factory PathNode.fromJson(Map<String, dynamic> json) {
    int toInt(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final route = json['route'];
    return PathNode(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? PathNodeType.lesson).toString(),
      subtype: (json['subtype'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      state: _stateFrom(json['state']),
      levelId: json['level_id'] as String?,
      finishedSessions: toInt(json['finished_sessions'], 0),
      totalSessions: toInt(json['total_sessions'], 1),
      sessionWords:
          json['session_words'] is num
              ? (json['session_words'] as num).toInt()
              : null,
      route: route is String && route.isNotEmpty ? route : null,
      hasLesson: json['has_lesson'] == true,
    );
  }
}

class PathUnit {
  const PathUnit({
    required this.id,
    required this.index,
    required this.title,
    this.description = '',
    this.nodes = const [],
  });

  final String id;
  final int index;
  final String title;
  final String description;
  final List<PathNode> nodes;

  int get passedCount => nodes.where((n) => n.isPassed).length;
  bool get isLocked => nodes.every((n) => n.isLocked);

  factory PathUnit.fromJson(Map<String, dynamic> json, int fallbackIndex) {
    return PathUnit(
      id: (json['id'] ?? '').toString(),
      index:
          json['index'] is num ? (json['index'] as num).toInt() : fallbackIndex,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      nodes: [
        for (final n in (json['nodes'] as List? ?? const []))
          if (n is Map) PathNode.fromJson(Map<String, dynamic>.from(n)),
      ],
    );
  }
}

/// Today's progress toward the daily goal, in sessions.
class DailyProgress {
  const DailyProgress({required this.sessions, required this.goal});
  final int sessions;
  final int goal;

  double get progress =>
      goal <= 0 ? 0 : (sessions / goal).clamp(0.0, 1.0).toDouble();
  bool get reached => sessions >= goal;
}

class LearningPath {
  const LearningPath({
    required this.units,
    this.activeNodeId,
    this.gateSkipped = false,
    this.daily,
  });

  final List<PathUnit> units;
  final String? activeNodeId;
  final bool gateSkipped;
  final DailyProgress? daily;

  Iterable<PathNode> get nodes => units.expand((u) => u.nodes);

  PathNode? get activeNode {
    for (final n in nodes) {
      if (n.id == activeNodeId || (activeNodeId == null && n.isActive)) {
        return n;
      }
    }
    return null;
  }

  PathUnit? unitOf(PathNode node) {
    for (final u in units) {
      if (u.nodes.any((n) => n.id == node.id)) return u;
    }
    return null;
  }

  /// Why [node] is locked, in one sentence for the learner.
  String lockedReason(PathNode node) {
    final active = activeNode;
    if (!node.isLocked) return '';
    if (active == null) return 'Finish the steps before this one to unlock it.';
    final unit = unitOf(node);
    final activeUnit = unitOf(active);
    if (active.type == PathNodeType.alphabetGate) {
      return 'Take the reading check, or skip it if you already read '
          'Tibetan, to open ${unit == null ? 'this' : 'Unit ${unit.index}'}.';
    }
    if (unit != null && activeUnit != null && unit.id != activeUnit.id) {
      return 'Finish Unit ${activeUnit.index} (next up: "${active.title}") '
          'to open Unit ${unit.index}.';
    }
    return 'Finish "${active.title}" to unlock this step.';
  }

  factory LearningPath.fromJson(Map<String, dynamic> json) {
    final raw = json['units'] as List? ?? const [];
    final daily = json['daily'];
    return LearningPath(
      units: [
        for (var i = 0; i < raw.length; i++)
          if (raw[i] is Map)
            PathUnit.fromJson(Map<String, dynamic>.from(raw[i] as Map), i + 1),
      ],
      activeNodeId: json['active_node_id'] as String?,
      gateSkipped: json['gate_skipped'] == true,
      daily:
          daily is Map
              ? DailyProgress(
                sessions: (daily['sessions'] as num?)?.toInt() ?? 0,
                goal: (daily['goal'] as num?)?.toInt() ?? 1,
              )
              : null,
    );
  }
}

/// One word from `GET /learn/review`.
class ReviewWord {
  const ReviewWord({
    required this.lexemeId,
    required this.tibetan,
    required this.english,
    required this.label,
    this.phonetic = '',
    this.attempts = 0,
    this.correct = 0,
    this.audioUrls = const {},
    this.dueAt,
  });

  final String lexemeId;
  final String tibetan;
  final String english;
  final String phonetic;

  /// `mistake` (last answer wrong), `weak` (under 70% right) or `due`
  /// (scheduled for review, neither a mistake nor weak).
  final String label;
  final int attempts;
  final int correct;
  final Map<String, String> audioUrls;

  /// When spaced repetition schedules this word next (null from servers
  /// without it).
  final DateTime? dueAt;

  factory ReviewWord.fromJson(Map<String, dynamic> json) => ReviewWord(
    lexemeId: (json['lexeme_id'] ?? '').toString(),
    tibetan: (json['tibetan'] ?? '').toString(),
    english: (json['english'] ?? '').toString(),
    phonetic: (json['phonetic'] ?? '').toString(),
    label: (json['label'] ?? 'weak').toString(),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    audioUrls: {
      for (final e in ((json['audio_urls'] as Map?) ?? const {}).entries)
        e.key.toString(): e.value.toString(),
    },
    dueAt: _parseTime(json['due_at']),
  );
}

DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

List<ReviewWord> _words(Object? value) => [
  for (final w in (value is List ? value : const []))
    if (w is Map) ReviewWord.fromJson(Map<String, dynamic>.from(w)),
];

/// `GET /learn/review`: mistake / weak words (every server) plus the
/// spaced-repetition schedule (FSRS) from servers that have it. An older
/// server sends no FSRS fields: [fsrsEnabled] is then false and the screen
/// falls back to mistake / weak words.
class ReviewSummary {
  const ReviewSummary({
    required this.wordCount,
    this.mistakeCount = 0,
    this.weakCount = 0,
    this.words = const [],
    this.fsrsEnabled = false,
    this.dueCount = 0,
    this.nextDueAt,
    this.trackedCount = 0,
    this.sessionSize = 0,
    this.dueWords = const [],
  });

  /// Mistake + weak words.
  final int wordCount;
  final int mistakeCount;
  final int weakCount;
  final List<ReviewWord> words;

  /// False on older servers and when the `fsrs_review` kill switch is on.
  final bool fsrsEnabled;

  /// Words due for review now.
  final int dueCount;

  /// When the next word falls due (null when none is scheduled).
  final DateTime? nextDueAt;

  /// Words with a review schedule ("You're remembering N words").
  final int trackedCount;

  /// Words the next review session would ask (due first, then weak).
  final int sessionSize;

  /// Due words, most overdue first.
  final List<ReviewWord> dueWords;

  static const empty = ReviewSummary(wordCount: 0);

  /// Due words first, then mistake / weak words not already listed.
  List<ReviewWord> get allWords {
    final seen = <String>{};
    return [
      for (final w in [...dueWords, ...words])
        if (seen.add(w.lexemeId)) w,
    ];
  }

  /// This summary with the FSRS part dropped (the client-side kill switch).
  ReviewSummary withoutFsrs() => ReviewSummary(
    wordCount: wordCount,
    mistakeCount: mistakeCount,
    weakCount: weakCount,
    words: words,
  );

  factory ReviewSummary.fromJson(Map<String, dynamic> json) => ReviewSummary(
    wordCount: _int(json['word_count']),
    mistakeCount: _int(json['mistake_count']),
    weakCount: _int(json['weak_count']),
    words: _words(json['words']),
    fsrsEnabled: json['fsrs_enabled'] == true,
    dueCount: _int(json['due_count']),
    nextDueAt: _parseTime(json['next_due_at']),
    trackedCount: _int(json['tracked_count']),
    sessionSize: _int(json['session_size']),
    dueWords: _words(json['due_words']),
  );
}

/// "in 3 h", "in 20 min", "tomorrow", "in 4 days" for the next review
/// [due] seen from [now] (both compared in local time for "tomorrow").
String nextReviewPhrase(DateTime due, DateTime now) {
  final d = due.toLocal();
  final n = now.toLocal();
  final diff = d.difference(n);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
  final today = DateTime(n.year, n.month, n.day);
  final dueDay = DateTime(d.year, d.month, d.day);
  final days = dueDay.difference(today).inDays;
  if (days == 0) return 'in ${diff.inHours} h';
  if (days == 1) return diff.inHours < 12 ? 'in ${diff.inHours} h' : 'tomorrow';
  return 'in $days days';
}

/// QuizScreen topic path for a review session (optionally scoped to a
/// practice / unit review node).
const String kReviewTopicPath = 'api://review';

String reviewTopicPath([String? nodeId]) =>
    nodeId == null ? kReviewTopicPath : '$kReviewTopicPath/$nodeId';

/// The node id in a [reviewTopicPath], or null for the learner's own review.
String? reviewNodeIdOf(String topicPath) {
  if (!topicPath.startsWith(kReviewTopicPath)) return null;
  final rest = topicPath.substring(kReviewTopicPath.length);
  return rest.startsWith('/') && rest.length > 1 ? rest.substring(1) : null;
}
