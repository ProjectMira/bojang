import 'package:bojang/models/lesson_content.dart';
import 'package:bojang/models/lesson_style.dart';
import 'package:bojang/models/level_models.dart';
import 'package:bojang/models/quiz_question.dart';
import 'package:bojang/models/romanisation.dart';
import 'package:bojang/services/pronunciation_voices.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _scriptExercise({String skill = 'script'}) => {
  'type': 'multiple_choice',
  'tibetan_word': 'ཁ',
  'phonetic': 'kha',
  'wylie': 'kha',
  'skill': skill,
  'correct_answer_id': 'b',
  'audio_urls': {'lhasa_female': 'https://x/kha.mp3'},
  'options': [
    {'id': 'a', 'text': 'ka', 'tibetan': 'ཀ', 'phonetic': 'ka', 'wylie': 'ka'},
    {'id': 'b', 'text': 'kha', 'tibetan': 'ཁ', 'phonetic': 'kha', 'wylie': 'kha'},
    {'id': 'c', 'text': 'ga', 'tibetan': 'ག', 'phonetic': 'ga', 'wylie': 'ga'},
    {'id': 'd', 'text': 'nga', 'tibetan': 'ང', 'phonetic': 'nga', 'wylie': 'nga'},
  ],
};

void main() {
  group('TransliterationMode', () {
    test('defaults to phonetics and reads saved values back', () {
      expect(TransliterationMode.fromId(null), TransliterationMode.phonetics);
      expect(TransliterationMode.fromId('nope'), TransliterationMode.phonetics);
      for (final mode in TransliterationMode.values) {
        expect(TransliterationMode.fromId(mode.name), mode);
      }
    });

    test('chooses which romanisation lines show', () {
      const r = Romanisation(phonetic: 'trashi delek', wylie: 'bkra shis bde legs');
      expect(r.linesFor(TransliterationMode.phonetics), ['trashi delek']);
      expect(r.linesFor(TransliterationMode.wylie), ['bkra shis bde legs']);
      expect(r.linesFor(TransliterationMode.both), ['trashi delek', 'bkra shis bde legs']);
      expect(r.linesFor(TransliterationMode.off), isEmpty);
      expect(const Romanisation(wylie: 'chos').linesFor(TransliterationMode.phonetics), isEmpty);
    });
  });

  group('PronunciationVoices', () {
    const both = {'lhasa_female': 'l.mp3', 'kham_male': 'k.mp3'};

    test('plays the chosen voice when the word has it', () {
      expect(PronunciationVoices.pick(both, 'kham_male'), 'k.mp3');
      expect(PronunciationVoices.resolve(both, 'kham_male'), 'kham_male');
    });

    test('falls back to the default voice, then any recording', () {
      expect(PronunciationVoices.pick({'lhasa_female': 'l.mp3'}, 'kham_male'), 'l.mp3');
      expect(PronunciationVoices.pick({'other': 'o.mp3'}, 'kham_male'), 'o.mp3');
      expect(PronunciationVoices.pick({}, 'kham_male', fallbackUrl: 'd.mp3'), 'd.mp3');
      expect(PronunciationVoices.resolve({}, 'kham_male'), isNull);
    });

    test('every voice has a dialect and a label', () {
      expect(PronunciationVoices.byId(PronunciationVoices.defaultVoice), isNotNull);
      for (final voice in PronunciationVoices.all) {
        expect(PronunciationVoices.labels[voice.id], voice.label);
        expect(voice.shortLabel, startsWith(voice.dialect.label));
      }
      expect(TibetanDialect.values.map((d) => d.label), contains('Amdo'));
    });
  });

  group('QuizQuestion romanisation and script', () {
    test('parses phonetics, Wylie, skill and each option\'s Tibetan', () {
      final q = QuizQuestion.fromApiExercise(_scriptExercise());
      expect(q.romanisation, const Romanisation(phonetic: 'kha', wylie: 'kha'));
      expect(q.isScript, isTrue);
      expect(q.optionTibetan, ['ཀ', 'ཁ', 'ག', 'ང']);
      expect(q.correctAnswerIndex, 1);
    });

    test('script romanisation waits for the answer; vocabulary shows at once', () {
      final script = QuizQuestion.fromApiExercise(_scriptExercise());
      expect(script.showsRomanisation(answered: false), isFalse);
      expect(script.showsRomanisation(answered: true), isTrue);
      final vocab = QuizQuestion.fromApiExercise(_scriptExercise(skill: 'vocabulary'));
      expect(vocab.showsRomanisation(answered: false), isTrue);
    });

    test('a script question turns into "which letter reads like this?"', () {
      final reverse = QuizQuestion.fromApiExercise(_scriptExercise()).asReadingReverse()!;
      expect(reverse.type, QuizQuestion.reverseChoice);
      expect(reverse.englishGloss, 'kha');
      expect(reverse.options, ['ཀ', 'ཁ', 'ག', 'ང']);
      expect(reverse.correctAnswerIndex, 1);
      expect(reverse.hasTibetanOptions, isTrue);
      expect(reverse.optionRomanisation(2).phonetic, 'ga');
      expect(reverse.wordTibetan, 'ཁ');
      expect(QuizQuestion.fromApiExercise(_scriptExercise()).wordTibetan, 'ཁ');
      expect(QuizQuestion.fromApiExercise(_scriptExercise(skill: 'vocabulary')).asReadingReverse(), isNull);
    });

    test('mixed style mixes reading, listening and plain script questions', () {
      final questions = List.generate(6, (_) => QuizQuestion.fromApiExercise(_scriptExercise()));
      final types = LessonStyle.mixed.arrange(questions).map((q) => q.type).toList();
      expect(types, contains(QuizQuestion.reverseChoice));
      expect(types, contains(QuizQuestion.listening));
      expect(types, contains(QuizQuestion.multipleChoice));
      expect(types.length, 6);
    });

    test('old payloads without romanisation still parse', () {
      final json = _scriptExercise()
        ..remove('phonetic')
        ..remove('wylie')
        ..remove('skill');
      final q = QuizQuestion.fromApiExercise(json);
      expect(q.romanisation.isEmpty, isTrue);
      expect(q.isScript, isFalse);
    });
  });

  group('Basics lessons', () {
    test('levels carry has_lesson and the unit title', () {
      final levels = Level.fromApiLevels([
        {'id': 'basics-letters-1', 'name': 'Letters 1', 'unit': 'tibetan-basics',
         'unit_title': 'Tibetan Basics', 'order': 1, 'word_count': 8, 'has_lesson': true},
        {'id': 'vocab-animals', 'name': 'Animals', 'unit': 'vocab-categories',
         'unit_title': 'Vocabulary Categories', 'order': 4, 'word_count': 44},
      ]);
      expect(levels.map((l) => l.title), ['Tibetan Basics', 'Vocabulary']);
      final letters = levels.first.sublevels.single;
      expect(letters.hasLesson, isTrue);
      expect(letters.levelId, 'basics-letters-1');
      expect(levels.last.sublevels.single.hasLesson, isFalse);
    });

    test('lesson content parses notes and items', () {
      final lesson = LessonContent.fromJson({
        'level_id': 'basics-letters-1',
        'title': 'Letters 1',
        'skill': 'script',
        'notes': ['Tibetan has 30 consonants.', ''],
        'items': [
          {'id': '1', 'tibetan': 'ཀ', 'english': 'ka', 'phonetic': 'ka', 'wylie': 'ka',
           'note': 'k as in skin', 'audio_urls': {'kham_male': 'k.mp3'}},
          {'id': '2', 'tibetan': '', 'english': 'broken'},
        ],
      });
      expect(lesson.isScript, isTrue);
      expect(lesson.notes, ['Tibetan has 30 consonants.']);
      expect(lesson.items.single.note, 'k as in skin');
      expect(lesson.items.single.audioFor('lhasa_female'), 'k.mp3');
    });
  });
}
