import 'quiz_question.dart';

/// Why a question is in the lesson.
enum LessonItemRole {
  /// One of the lesson's own questions.
  core,

  /// A harder bonus question, added when the learner is doing well.
  bonus,

  /// A word the learner got wrong, asked once more at the end.
  retry,
}

/// The label shown above a question.
enum ExerciseLabel {
  newWord('new', 'New word'),
  mistake('mistake', 'Fix this mistake'),
  pastMistake('mistake', 'Past mistake'),
  weak('weak', 'Weak word'),
  hard('hard', 'Hard');

  const ExerciseLabel(this.id, this.text);

  /// The id the server uses.
  final String id;
  final String text;

  /// A server label, as shown on a question's first appearance.
  static ExerciseLabel? fromServer(String? id) => switch (id) {
    'new' => ExerciseLabel.newWord,
    'mistake' => ExerciseLabel.pastMistake,
    'weak' => ExerciseLabel.weak,
    'hard' => ExerciseLabel.hard,
    _ => null,
  };
}

class LessonItem {
  const LessonItem(this.question, this.role, {this.attempt = 1});

  final QuizQuestion question;
  final LessonItemRole role;

  /// 1 the first time a question is asked, 2 when it comes back.
  final int attempt;

  ExerciseLabel? get label => switch (role) {
    LessonItemRole.retry => ExerciseLabel.mistake,
    LessonItemRole.bonus => ExerciseLabel.hard,
    LessonItemRole.core => ExerciseLabel.fromServer(question.label),
  };
}

/// One attempt, as sent to `POST /progress/complete` in `answers`.
class LessonAnswer {
  const LessonAnswer({
    required this.exerciseId,
    required this.answer,
    required this.correct,
    required this.ms,
    required this.attempt,
    required this.role,
  });

  final String? exerciseId;
  final String answer;
  final bool correct;
  final int ms;
  final int attempt;
  final LessonItemRole role;

  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'answer': answer,
    'correct': correct,
    'ms': ms,
  };
}

/// The order of a lesson's questions and its score.
///
/// Duolingo's lesson shape, kept small: the lesson's own questions first;
/// if the learner gets at least [bonusThreshold] of them right first time,
/// 1 or 2 harder bonus questions; then every word answered wrong comes back
/// once at the end.
///
/// Scoring matches the server (`functions/grading.py`): each core question
/// counts once, on its first attempt; a bonus question counts only when
/// right; a word asked again changes nothing but [fixed].
class LessonQueue {
  LessonQueue(
    List<QuizQuestion> core, {
    List<QuizQuestion> bonus = const [],
    this.bonusThreshold = 0.8,
    this.maxBonus = 2,
  }) : _items = [for (final q in core) LessonItem(q, LessonItemRole.core)],
       _bonus = List.of(bonus),
       _coreCount = core.length;

  /// Share of the core answered right first time that earns bonus questions.
  final double bonusThreshold;
  final int maxBonus;

  final List<LessonItem> _items;
  final List<QuizQuestion> _bonus;
  final int _coreCount;
  final List<LessonItem> _pendingRetries = [];
  final Set<String> _missedWords = {};
  final List<LessonAnswer> _answers = [];
  int _index = 0;
  bool _bonusDecided = false;
  bool _answeredCurrent = false;

  int _coreAnswered = 0;
  int _coreCorrect = 0;
  int _bonusShown = 0;
  int _bonusCorrect = 0;
  int _retriesAnswered = 0;
  int _fixed = 0;

  /// The question on screen.
  LessonItem get current => _items[_index];

  /// Its position, from 0.
  int get index => _index;

  /// Questions in the lesson as known now. It grows when a word is missed
  /// or bonus questions are added.
  int get length => _items.length + _pendingRetries.length;

  /// Questions answered so far, retries included.
  int get answered => _answers.length;

  bool get isEmpty => _coreCount == 0;

  /// Whether the question on screen has been answered.
  bool get answeredCurrent => _answeredCurrent;

  /// True once every question, bonus and retry included, is answered.
  bool get isDone =>
      _answeredCurrent &&
      _index >= _items.length - 1 &&
      _pendingRetries.isEmpty &&
      !_bonusDue;

  /// The core is finished and has earned bonus questions not yet added.
  bool get _bonusDue =>
      !_bonusDecided &&
      _coreAnswered >= _coreCount &&
      bonusCountFor(coreAccuracy) > 0;

  /// Missed words still to come back (or on screen and not yet answered).
  int get toFix =>
      _pendingRetries.length +
      _items
          .skip(_answeredCurrent ? _index + 1 : _index)
          .where((i) => i.role == LessonItemRole.retry)
          .length;

  int get coreCount => _coreCount;
  int get bonusShown => _bonusShown;
  int get bonusCorrect => _bonusCorrect;
  int get recycled => _missedWords.length;
  int get retriesAnswered => _retriesAnswered;
  int get fixed => _fixed;

  /// Score as the server counts it.
  int get correct => _coreCorrect + _bonusCorrect;
  int get total => _coreAnswered + _bonusCorrect;

  /// 0-100, over what has been answered so far.
  double get accuracy => total == 0 ? 0 : correct / total * 100;

  /// First-try share of the core answered so far, 0-1.
  double get coreAccuracy =>
      _coreAnswered == 0 ? 0 : _coreCorrect / _coreAnswered;

  List<LessonAnswer> get answers => List.unmodifiable(_answers);

  /// Every question the lesson may ask, for prefetching audio.
  Iterable<QuizQuestion> get allQuestions => [
    for (final item in _items) item.question,
    ..._bonus,
  ];

  /// Records the answer to [current]. [optionIndex] is the option picked.
  void answer({
    required int optionIndex,
    required bool correct,
    required int ms,
  }) {
    if (_answeredCurrent) return;
    _answeredCurrent = true;
    final item = current;
    final q = item.question;
    _answers.add(
      LessonAnswer(
        exerciseId: q.exerciseId,
        answer: q.answerIdFor(optionIndex),
        correct: correct,
        ms: ms,
        attempt: item.attempt,
        role: item.role,
      ),
    );
    switch (item.role) {
      case LessonItemRole.core:
        _coreAnswered++;
        if (correct) _coreCorrect++;
      case LessonItemRole.bonus:
        if (correct) _bonusCorrect++;
      case LessonItemRole.retry:
        _retriesAnswered++;
        if (correct) _fixed++;
    }
    if (!correct && item.role != LessonItemRole.retry) {
      // Each missed word comes back once, however often it appears.
      if (_missedWords.add(_wordKey(q))) {
        _pendingRetries.add(
          LessonItem(q, LessonItemRole.retry, attempt: item.attempt + 1),
        );
      }
    }
  }

  /// Moves to the next question. Returns how many bonus questions were
  /// added by this move (0 almost always).
  int advance() {
    if (!_answeredCurrent) return 0;
    var added = 0;
    if (_index >= _items.length - 1) {
      if (!_bonusDecided && _coreAnswered >= _coreCount) {
        _bonusDecided = true;
        final count = bonusCountFor(coreAccuracy);
        for (final q in _bonus.take(count)) {
          _items.add(LessonItem(q, LessonItemRole.bonus));
          added++;
        }
        _bonusShown = added;
      }
      if (added == 0 && _pendingRetries.isNotEmpty) {
        _items.addAll(_pendingRetries);
        _pendingRetries.clear();
      }
    }
    if (_index < _items.length - 1) {
      _index++;
      _answeredCurrent = false;
    }
    return added;
  }

  /// How many bonus questions a first-try accuracy (0-1) earns.
  int bonusCountFor(double firstTry) {
    if (_bonus.isEmpty || firstTry < bonusThreshold) return 0;
    final count = firstTry >= 0.9 ? 2 : 1;
    return count.clamp(0, maxBonus).clamp(0, _bonus.length);
  }

  /// The word a question is about, so the same word asked by two exercises
  /// still comes back only once.
  static String _wordKey(QuizQuestion q) => q.wordTibetan;

  /// A bonus question asked the harder way: by ear when it has a recording,
  /// from English (no picture) for picture questions, or from the reading
  /// for script questions.
  static QuizQuestion harder(QuizQuestion q) =>
      q.asReadingReverse() ?? q.asListening() ?? q.asReverse() ?? q;
}
