import 'package:bojang/models/game_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameWord.fromCard', () {
    test('parses a backend memory_match card', () {
      final word = GameWord.fromCard({
        'id': '81f0',
        'tibetan': 'སྤྲེལ་ཁམ།',
        'english': 'kiwi',
        'phonetic': 'trel kham',
        'image_url': 'https://example.com/81f0.jpg',
        'audio_url': 'https://example.com/81f0.mp3',
        'audio_urls': {
          'kham_male': 'https://example.com/kham/81f0.mp3',
          'lhasa_female': 'https://example.com/81f0.mp3',
        },
      })!;

      expect(word.id, '81f0');
      expect(word.english, 'kiwi');
      expect(word.hasImage, isTrue);
      expect(word.hasAudio, isTrue);
      expect(word.audioFor('kham_male'), 'https://example.com/kham/81f0.mp3');
      expect(word.audioFor('unknown_voice'), 'https://example.com/81f0.mp3');
    });

    test('treats empty media fields as missing', () {
      final word = GameWord.fromCard({
        'id': 'a',
        'tibetan': 'ཨམ།',
        'english': 'mango',
        'phonetic': '',
        'image_url': '',
        'audio_url': null,
      })!;
      expect(word.hasImage, isFalse);
      expect(word.hasAudio, isFalse);
      expect(word.audioFor('lhasa_female'), isNull);
      expect(word.phonetic, '');
    });

    test('rejects a card with no Tibetan or no meaning', () {
      expect(GameWord.fromCard({'tibetan': '', 'english': 'x'}), isNull);
      expect(GameWord.fromCard({'tibetan': 'ཀ', 'english': '  '}), isNull);
    });
  });

  group('GameWord.syllables', () {
    GameWord w(String tibetan) =>
        GameWord(id: tibetan, tibetan: tibetan, english: 'x');

    test('splits on the tsheg and drops the closing shad', () {
      expect(w('ཆུ་ག་གོན།').syllables, ['ཆུ', 'ག', 'གོན']);
      expect(w('སྤྲེལ་ཁམ།').syllables, ['སྤྲེལ', 'ཁམ']);
    });

    test('a one-syllable word is one syllable', () {
      expect(w('ཨམ།').syllables, ['ཨམ']);
      expect(w('ཁ').syllables, ['ཁ']);
    });

    test('ignores a trailing tsheg', () {
      expect(w('ཁ་ལག་').syllables, ['ཁ', 'ལག']);
    });
  });

  test('distinct drops repeats and words sharing a spelling or meaning', () {
    const words = [
      GameWord(id: '1', tibetan: 'ཀ', english: 'Entirely'),
      GameWord(id: '1', tibetan: 'ཀ', english: 'Entirely'),
      GameWord(id: '2', tibetan: 'ཁ', english: 'entirely'),
      GameWord(id: '3', tibetan: 'ཀ', english: 'other'),
      GameWord(id: '4', tibetan: 'ག', english: 'third'),
    ];
    expect(GameWord.distinct(words).map((w) => w.id), ['1', '4']);
  });
}
