import 'package:bojang/models/lesson_style.dart';
import 'package:bojang/models/quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

QuizQuestion word(String tibetan, {bool audio = true}) => QuizQuestion(
  tibetanText: tibetan,
  options: const ['apple', 'pear'],
  correctAnswerIndex: 0,
  type: QuizQuestion.multipleChoice,
  audioUrl: audio ? 'https://example.com/$tibetan.mp3' : null,
);

QuizQuestion picture(String gloss) => QuizQuestion(
  tibetanText: 'Select the Tibetan word for this picture',
  options: const ['ཀུ་ཤུ།', 'ལི།'],
  correctAnswerIndex: 0,
  type: QuizQuestion.pictureChoice,
  imageUrl: 'https://example.com/$gloss.jpg',
  englishGloss: gloss,
  audioUrl: 'https://example.com/$gloss.mp3',
);

void main() {
  group('LessonStyle.fromId', () {
    test('reads every saved style back', () {
      for (final style in LessonStyle.values) {
        expect(LessonStyle.fromId(style.name), style);
      }
    });

    test('falls back to mixed for a missing or unknown value', () {
      expect(LessonStyle.fromId(null), LessonStyle.mixed);
      expect(LessonStyle.fromId('pictionary'), LessonStyle.mixed);
    });
  });

  group('QuizQuestion conversions', () {
    test('a recorded word question becomes a listening question', () {
      final listening = word('ཀུ་ཤུ།').asListening()!;
      expect(listening.type, QuizQuestion.listening);
      expect(listening.tibetanText, 'ཀུ་ཤུ།');
      expect(listening.options, ['apple', 'pear']);
      expect(listening.correctAnswerIndex, 0);
      expect(listening.hasTibetanOptions, isFalse);
    });

    test('a word with no recording cannot be asked by ear', () {
      expect(word('ཀུ་ཤུ།', audio: false).asListening(), isNull);
    });

    test('a picture question becomes an English-prompt question', () {
      final reverse = picture('apple').asReverse()!;
      expect(reverse.type, QuizQuestion.reverseChoice);
      expect(reverse.imageUrl, isNull);
      expect(reverse.englishGloss, 'apple');
      expect(reverse.hasTibetanOptions, isTrue);
      expect(reverse.audioUrl, isNotNull);
    });

    test('conversions only apply to their own source type', () {
      expect(picture('apple').asListening(), isNull);
      expect(word('ཀུ་ཤུ།').asReverse(), isNull);
    });
  });

  group('LessonStyle.arrange', () {
    final session = [
      word('1'), picture('a'), word('2'), picture('b'), word('3'),
      picture('c'), word('4'), picture('d'), word('5'), picture('e'),
    ];

    test('mixed blends all four question kinds and keeps every question', () {
      final arranged = LessonStyle.mixed.arrange(session);
      expect(arranged, hasLength(session.length));
      final kinds = arranged.map((q) => q.type).toList();
      expect(kinds.where((k) => k == QuizQuestion.multipleChoice), hasLength(3));
      expect(kinds.where((k) => k == QuizQuestion.listening), hasLength(2));
      expect(kinds.where((k) => k == QuizQuestion.pictureChoice), hasLength(4));
      expect(kinds.where((k) => k == QuizQuestion.reverseChoice), hasLength(1));
    });

    test('mixed leaves unrecorded words as written questions', () {
      final arranged = LessonStyle.mixed.arrange([
        word('1', audio: false),
        word('2', audio: false),
      ]);
      expect(
        arranged.map((q) => q.type),
        everyElement(QuizQuestion.multipleChoice),
      );
    });

    test('listening converts every recorded word', () {
      final arranged = LessonStyle.listening.arrange([
        word('1'),
        word('2', audio: false),
      ]);
      expect(arranged[0].type, QuizQuestion.listening);
      expect(arranged[1].type, QuizQuestion.multipleChoice);
    });

    test('words and pictures pass questions through untouched', () {
      expect(LessonStyle.words.arrange(session), same(session));
      expect(LessonStyle.pictures.arrange(session), same(session));
    });

    test('every style requests exercise types the backend generates', () {
      for (final style in LessonStyle.values) {
        expect(style.exerciseTypes, isNotEmpty);
        expect(
          style.exerciseTypes,
          everyElement(isIn(['multiple_choice', 'picture_choice'])),
        );
      }
    });
  });
}
