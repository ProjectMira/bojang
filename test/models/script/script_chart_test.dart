import 'package:bojang/models/quiz_question.dart';
import 'package:bojang/models/script/script_chart.dart';
import 'package:bojang/models/script/stack_builder.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _char(String c, String r, {double s = 0, bool seen = false}) => {
  'char': c,
  'display': c,
  'reading': r,
  'kind': 'consonant',
  'strength': s,
  'seen': seen,
  'audio_url': 'https://a/$c.mp3',
  'audio_urls': {'lhasa_female': 'https://a/$c.mp3'},
  'examples': [
    {'tibetan': 'ཀ་བ', 'english': 'pillar', 'reading': 'kawa', 'audio_url': 'https://a/kawa.mp3'},
    {'tibetan': 'ཀུ་ཤུ', 'english': 'apple', 'reading': 'kushu'},
  ],
};

void main() {
  test('strength bands', () {
    expect(StrengthBand.of(0.9, seen: false), StrengthBand.unseen);
    expect(StrengthBand.of(0.1, seen: true), StrengthBand.weak);
    expect(StrengthBand.of(0.4, seen: true), StrengthBand.learning);
    expect(StrengthBand.of(0.7, seen: true), StrengthBand.strong);
    expect(StrengthBand.of(0.9, seen: true), StrengthBand.mastered);
  });

  test('parses the course payload', () {
    final chart = ScriptChart.fromJson({
      'groups': [
        {
          'id': 'consonants',
          'title': 'The 30 letters',
          'columns': 4,
          'rows': [
            [_char('ཀ', 'ka', s: 0.9, seen: true), _char('ཁ', 'kha', s: 0.2, seen: true), _char('ག', 'ga'), _char('ང', 'nga')],
          ],
        },
      ],
      'gate': {'gate_passed': true, 'gate_skipped': false},
    });
    expect(chart.gatePassed, isTrue);
    expect(chart.total, 4);
    expect(chart.seenCount, 2);
    expect(chart.strongCount, 1);
    expect(chart.nextToLearn().map((c) => c.char), ['ཁ', 'ག', 'ང']);
    final ka = chart.find('ཀ')!;
    expect(ka.band, StrengthBand.mastered);
    expect(ka.audioFor('kham_male'), 'https://a/ཀ.mp3');
    expect(ka.examples.first.hasAudio, isTrue);
    expect(ka.examples.last.hasAudio, isFalse); // shown without a speaker
  });

  test('fallback chart: 30 letters in rows of four, and four vowels', () {
    final chart = ScriptChart.fallback();
    final rows = chart.groups.first.rows;
    expect(rows.map((r) => r.length), [4, 4, 4, 4, 4, 4, 4, 2]);
    expect(rows.first.map((c) => c.char).join(), 'ཀཁགང');
    expect(chart.groups[1].chars.map((c) => c.shown), ['ཨི', 'ཨུ', 'ཨེ', 'ཨོ']);
    expect(chart.offline, isTrue);
  });

  group('script exercises in QuizQuestion', () {
    test('every script type is renderable', () {
      for (final t in QuizQuestion.scriptTypes) {
        expect(QuizQuestion.renderableTypes, contains(t));
      }
    });

    test('find_root', () {
      final q = QuizQuestion.fromAnyExercise({
        'type': 'find_root',
        'exercise_id': 'e1',
        'char': 'ག',
        'syllable': 'བསྒྲུབས',
        'reading': 'drup',
        'tiles': [
          {'id': '0:བ', 'char': 'བ', 'role': 'prefix'},
          {'id': '1:ས', 'char': 'ས', 'role': 'superscript'},
          {'id': '2:ག', 'char': 'ག', 'role': 'root'},
          {'id': '3:ར', 'char': 'ར', 'role': 'subscript'},
        ],
        'correct_answer_id': '2:ག',
        'correct_answer': 'ག',
      });
      expect(q.correctAnswerIndex, 2);
      expect(q.answerIdFor(2), '2:ག');
      expect(q.holdsAudio, isTrue);
      expect(q.wordTibetan, 'བསྒྲུབས');
    });

    test('build_stack', () {
      final q = QuizQuestion.fromAnyExercise({
        'type': 'build_stack',
        'exercise_id': 'e2',
        'char': 'སྟ',
        'mode': 'shown',
        'target': 'སྟག',
        'tail': 'ག',
        'reading': 'tak',
        'slots': [
          {'slot': 'root', 'label': 'Root', 'tiles': [{'id': 'root:ཏ', 'char': 'ཏ', 'label': 'ཏ'}]},
        ],
        'correct_tile_ids': ['prefix:', 'superscript:ས', 'root:ཏ', 'subscript:', 'vowel:'],
        'correct_answer': 'སྟག',
      });
      expect(q.answersWithoutOptions, isTrue);
      final want = q.script!.correctChoices;
      expect(StackBuilder.fromChoices(want, tail: q.script!.tail), 'སྟག');
    });

    test('near_sound pick_heard plays its clip, options are letters', () {
      final q = QuizQuestion.fromAnyExercise({
        'type': 'near_sound',
        'exercise_id': 'e3',
        'char': 'ཁ',
        'mode': 'pick_heard',
        'group': ['ཀ', 'ཁ', 'ག'],
        'clips': [{'char': 'ཁ', 'audio_url': 'https://a/kha.mp3'}],
        'options': [
          {'id': 'a', 'text': 'ཀ', 'is_correct': false},
          {'id': 'b', 'text': 'ཁ', 'is_correct': true},
          {'id': 'c', 'text': 'ག', 'is_correct': false},
        ],
        'correct_answer_id': 'b',
        'correct_answer': 'ཁ',
      });
      expect(q.correctAnswerIndex, 1);
      expect(q.audioUrl, 'https://a/kha.mp3');
      expect(q.hasTibetanOptions, isTrue);
    });

    test('read_syllable holds its audio and reading', () {
      final q = QuizQuestion.fromAnyExercise({
        'type': 'read_syllable',
        'exercise_id': 'e4',
        'char': 'ཁྱ',
        'syllable': 'ཁྱི',
        'audio_url': 'https://a/khyi.mp3',
        'options': [
          {'id': 'r0', 'text': 'khyi', 'is_correct': true},
          {'id': 'r1', 'text': 'chi', 'is_correct': false},
        ],
        'correct_answer_id': 'r0',
        'correct_answer': 'khyi',
      });
      expect(q.holdsAudio, isTrue);
      expect(q.showsRomanisation(answered: false), isFalse);
      expect(q.romanisation.phonetic, 'khyi');
    });

    test('a bad script payload is rejected', () {
      expect(
        () => QuizQuestion.fromScriptExercise({'type': 'find_root', 'tiles': []}),
        throwsFormatException,
      );
    });
  });
}
