import 'package:bojang/models/lesson_queue.dart';
import 'package:bojang/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

QuizQuestion q(String word, {String? label, String type = 'multiple_choice'}) =>
    QuizQuestion(
      tibetanText: word,
      options: ['right $word', 'wrong $word'],
      correctAnswerIndex: 0,
      type: type,
      exerciseId: 'ex-$word',
      optionIds: ['id-$word', 'id-x-$word'],
      label: label,
    );

/// Answers every remaining question, right unless its word is in [miss]
/// (on its first attempt) or in [missAgain] (on its retry). Returns the
/// words in the order they were asked.
List<String> play(
  LessonQueue lesson, {
  Set<String> miss = const {},
  Set<String> missAgain = const {},
}) {
  final asked = <String>[];
  while (true) {
    final item = lesson.current;
    final word = item.question.tibetanText;
    asked.add(item.role == LessonItemRole.retry ? '$word*' : word);
    final wrong =
        item.role == LessonItemRole.retry
            ? missAgain.contains(word)
            : miss.contains(word);
    lesson.answer(optionIndex: wrong ? 1 : 0, correct: !wrong, ms: 1000);
    if (lesson.isDone) return asked;
    lesson.advance();
  }
}

void main() {
  group('LessonQueue', () {
    test('a perfect lesson with no bonus is just the core', () {
      final lesson = LessonQueue([q('a'), q('b'), q('c')]);
      expect(play(lesson), ['a', 'b', 'c']);
      expect(lesson.correct, 3);
      expect(lesson.total, 3);
      expect(lesson.toFix, 0);
      expect(lesson.recycled, 0);
    });

    test('each wrong word comes back once, at the end', () {
      final lesson = LessonQueue([q('a'), q('b'), q('c'), q('d')]);
      expect(play(lesson, miss: {'a', 'c'}), ['a', 'b', 'c', 'd', 'a*', 'c*']);
      // The retry is stored but the first attempt is the score.
      expect(lesson.correct, 2);
      expect(lesson.total, 4);
      expect(lesson.recycled, 2);
      expect(lesson.fixed, 2);
    });

    test('a word missed again on its retry does not come back a third time', () {
      final lesson = LessonQueue([q('a'), q('b')]);
      expect(play(lesson, miss: {'a'}, missAgain: {'a'}), ['a', 'b', 'a*']);
      expect(lesson.fixed, 0);
      expect(lesson.retriesAnswered, 1);
    });

    test('the same word in two exercises comes back only once', () {
      final first = q('a');
      final second = QuizQuestion(
        tibetanText: 'a',
        options: const ['x', 'y'],
        correctAnswerIndex: 0,
        type: 'multiple_choice',
        exerciseId: 'ex-a-2',
      );
      final lesson = LessonQueue([first, second, q('b')]);
      expect(play(lesson, miss: {'a'}), ['a', 'a', 'b', 'a*']);
    });

    test('"to fix" counts missed words still to come', () {
      final lesson = LessonQueue([q('a'), q('b'), q('c')]);
      lesson.answer(optionIndex: 1, correct: false, ms: 10);
      expect(lesson.toFix, 1);
      lesson.advance();
      lesson.answer(optionIndex: 1, correct: false, ms: 10);
      expect(lesson.toFix, 2);
      expect(lesson.length, 5);
      lesson.advance();
      lesson.answer(optionIndex: 0, correct: true, ms: 10);
      lesson.advance(); // retries join the end of the queue
      expect(lesson.current.role, LessonItemRole.retry);
      expect(lesson.current.label, ExerciseLabel.mistake);
      expect(lesson.toFix, 2);
      lesson.answer(optionIndex: 0, correct: true, ms: 10);
      expect(lesson.toFix, 1);
      lesson.advance();
      lesson.answer(optionIndex: 0, correct: true, ms: 10);
      expect(lesson.toFix, 0);
      expect(lesson.isDone, isTrue);
    });

    test('high accuracy adds 2 bonus questions before the retries', () {
      final core = [for (final w in 'abcdefghij'.split('')) q(w)];
      final lesson = LessonQueue(core, bonus: [q('X'), q('Y'), q('Z')]);
      // 9 of 10 first time: 90% earns 2 bonus questions.
      final asked = play(lesson, miss: {'c'});
      expect(asked.sublist(10), ['X', 'Y', 'c*']);
      expect(lesson.bonusShown, 2);
      expect(lesson.bonusCorrect, 2);
      // Bonus questions answered right count; the score never passes 100%.
      expect(lesson.correct, 11);
      expect(lesson.total, 12);
    });

    test('80-89% earns one bonus question, below 80% none', () {
      final core = [for (final w in 'abcdefghij'.split('')) q(w)];
      final one = LessonQueue(core, bonus: [q('X'), q('Y')]);
      expect(play(one, miss: {'a', 'b'}).where((w) => w == 'X' || w == 'Y'), ['X']);

      final none = LessonQueue(core, bonus: [q('X'), q('Y')]);
      expect(play(none, miss: {'a', 'b', 'c'}), isNot(contains('X')));
      expect(none.bonusShown, 0);
    });

    test('a wrong bonus answer does not count against the score', () {
      final lesson = LessonQueue([q('a'), q('b')], bonus: [q('X')]);
      play(lesson, miss: {'X'});
      expect(lesson.correct, 2);
      expect(lesson.total, 2);
      expect(lesson.bonusShown, 1);
      expect(lesson.bonusCorrect, 0);
    });

    test('answers are logged per attempt for the server', () {
      final lesson = LessonQueue([q('a'), q('b')]);
      play(lesson, miss: {'a'});
      final sent = lesson.answers.map((a) => a.toJson()).toList();
      expect(sent, [
        {'exercise_id': 'ex-a', 'answer': 'id-x-a', 'correct': false, 'ms': 1000},
        {'exercise_id': 'ex-b', 'answer': 'id-b', 'correct': true, 'ms': 1000},
        {'exercise_id': 'ex-a', 'answer': 'id-a', 'correct': true, 'ms': 1000},
      ]);
      expect(lesson.answers.last.attempt, 2);
    });

    test('questions without server ids send the option text', () {
      final local = QuizQuestion(
        tibetanText: 'ཀ',
        options: const ['ka', 'ga'],
        correctAnswerIndex: 0,
      );
      final lesson = LessonQueue([local]);
      lesson.answer(optionIndex: 1, correct: false, ms: 5);
      expect(lesson.answers.single.answer, 'ga');
      expect(lesson.answers.single.exerciseId, isNull);
    });

    test('answering twice or advancing early does nothing', () {
      final lesson = LessonQueue([q('a'), q('b')]);
      expect(lesson.advance(), 0);
      expect(lesson.index, 0);
      lesson.answer(optionIndex: 0, correct: true, ms: 1);
      lesson.answer(optionIndex: 1, correct: false, ms: 1);
      expect(lesson.answers, hasLength(1));
      expect(lesson.correct, 1);
    });

    test('server labels show on first appearance', () {
      final lesson = LessonQueue([q('a', label: 'new'), q('b', label: 'weak'), q('c')]);
      expect(lesson.current.label, ExerciseLabel.newWord);
      lesson.answer(optionIndex: 0, correct: true, ms: 1);
      lesson.advance();
      expect(lesson.current.label, ExerciseLabel.weak);
      lesson.answer(optionIndex: 0, correct: true, ms: 1);
      lesson.advance();
      expect(lesson.current.label, isNull);
    });

    test('bonus questions are labelled hard and asked the harder way', () {
      final withAudio = QuizQuestion(
        tibetanText: 'ཡ',
        options: const ['yak', 'dog'],
        correctAnswerIndex: 0,
        type: QuizQuestion.multipleChoice,
        audioUrl: 'https://example.com/a.mp3',
      );
      expect(LessonQueue.harder(withAudio).type, QuizQuestion.listening);
      final picture = QuizQuestion(
        tibetanText: '',
        options: const ['གཡག', 'ཁྱི'],
        correctAnswerIndex: 0,
        type: QuizQuestion.pictureChoice,
        englishGloss: 'yak',
        imageUrl: 'https://example.com/yak.jpg',
      );
      final reversed = LessonQueue.harder(picture);
      expect(reversed.type, QuizQuestion.reverseChoice);
      expect(reversed.imageUrl, isNull);

      final lesson = LessonQueue([q('a')], bonus: [q('X')]);
      lesson.answer(optionIndex: 0, correct: true, ms: 1);
      lesson.advance();
      expect(lesson.current.role, LessonItemRole.bonus);
      expect(lesson.current.label, ExerciseLabel.hard);
    });

    test('script questions keep hiding the reading until answered', () {
      final script = QuizQuestion(
        tibetanText: 'ཀ',
        options: const ['ka', 'kha'],
        correctAnswerIndex: 0,
        type: QuizQuestion.multipleChoice,
        isScript: true,
        optionTibetan: const ['ཀ', 'ཁ'],
      );
      final lesson = LessonQueue([script]);
      lesson.answer(optionIndex: 1, correct: false, ms: 1);
      lesson.advance();
      final retry = lesson.current.question;
      expect(lesson.current.role, LessonItemRole.retry);
      expect(retry.showsRomanisation(answered: false), isFalse);
      expect(retry.showsRomanisation(answered: true), isTrue);
    });
  });
}
