import 'package:bojang/models/lesson_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonNote.parse', () {
    test('sound hint then example word', () {
      final n = LessonNote.parse(
        'k as in "skin", no puff of air. ཀ་རག: whitewash',
      );
      expect(n.hint, 'k as in "skin", no puff of air');
      expect(n.exampleTibetan, 'ཀ་རག');
      expect(n.exampleMeaning, 'whitewash');
    });

    test('hint with a comma-separated meaning', () {
      final n = LessonNote.parse(
        'ch as in "pitch", no puff of air. ཅ་ལག: things, belongings',
      );
      expect(n.exampleTibetan, 'ཅ་ལག');
      expect(n.exampleMeaning, 'things, belongings');
    });

    test('a note that is only an example', () {
      final n = LessonNote.parse('མི: person');
      expect(n.hint, isEmpty);
      expect(n.exampleTibetan, 'མི');
      expect(n.exampleMeaning, 'person');
    });

    test('Tibetan at the start without a colon stays a hint', () {
      final n = LessonNote.parse('ཀ with gigu');
      expect(n.hint, 'ཀ with gigu');
      expect(n.hasExample, isFalse);
    });

    test('a vowel note with an example after it', () {
      final n = LessonNote.parse('ང with naro. ངོ: face');
      expect(n.hint, 'ང with naro');
      expect(n.exampleTibetan, 'ངོ');
    });

    test('plain English stays whole', () {
      const raw =
          'w as in "water". Rare on its own; often a small mark under other letters';
      final n = LessonNote.parse(raw);
      expect(n.hint, raw);
      expect(n.hasExample, isFalse);
      expect(LessonNote.parse('fish').hint, 'fish');
    });

    test('short meanings go on the card, sound hints do not', () {
      expect(LessonNote.parse('fish').isShortMeaning, isTrue);
      expect(LessonNote.parse('the Tibetan language').isShortMeaning, isTrue);
      expect(LessonNote.parse('ཀ with gigu').isShortMeaning, isFalse);
      expect(
        LessonNote.parse('gigu, the hook above: i as in "ski"').isShortMeaning,
        isFalse,
      );
      expect(
        LessonNote.parse('h as in "hat". ཧ་གོ: to understand').isShortMeaning,
        isFalse,
      );
    });

    test('empty', () {
      expect(LessonNote.parse('  ').isEmpty, isTrue);
    });
  });
}
