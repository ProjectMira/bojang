import 'package:bojang/models/lesson_queue.dart';
import 'package:bojang/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

QuizQuestion q(String type, {int correct = 2, String id = 'e'}) => QuizQuestion(
  tibetanText: 'ཀ',
  options: const ['a', 'b', 'c', 'd'],
  optionIds: const ['1', '2', '3', '4'],
  correctAnswerIndex: correct,
  type: type,
  exerciseId: id,
  audioUrl: 'https://x/ka.mp3',
);

void main() {
  test('warm-up keeps the right answer and one other, in order', () {
    final w = q(QuizQuestion.multipleChoice).asWarmUp()!;
    expect(w.options, ['c', 'd']);
    expect(w.optionIds, ['3', '4']);
    expect(w.options[w.correctAnswerIndex], 'c');
    final last = q(QuizQuestion.multipleChoice, correct: 3).asWarmUp()!;
    expect(last.options, ['a', 'd']);
    expect(last.options[last.correctAnswerIndex], 'd');
  });

  test('a lesson never opens by ear, and opens with two options', () {
    final list = LessonQueue.easyStart([
      q(QuizQuestion.listening, id: 'l'),
      q(QuizQuestion.multipleChoice, id: 'm'),
      q(QuizQuestion.pictureChoice, id: 'p'),
    ]);
    expect(list.map((e) => e.exerciseId), ['m', 'l', 'p']);
    expect(list.first.options.length, 2);
    expect(list[1].options.length, 4);
  });

  test('all-by-ear lessons keep their order', () {
    final list = LessonQueue.easyStart([
      q(QuizQuestion.listening, id: 'l1'),
      q(QuizQuestion.listening, id: 'l2'),
    ]);
    expect(list.map((e) => e.exerciseId), ['l1', 'l2']);
  });
}
