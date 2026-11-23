import 'package:bojang/screens/memory_match_game.dart';
import 'package:bojang/services/pronunciation_voices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final voices = PronunciationVoices.labels.keys.toList();
  final chosen = voices.first;
  final other = voices.length > 1 ? voices[1] : voices.first;

  MemoryCard tibetan({Map<String, String> urls = const {}, String? url}) =>
      MemoryCard(
        id: 0,
        text: 'ཉི་མ།',
        subtitle: '',
        type: CardType.tibetan,
        pairId: 0,
        audioUrls: urls,
        audioUrl: url,
      );

  test('a Tibetan card plays the clip in the chosen voice', () {
    final card = tibetan(
      urls: {chosen: 'https://x/$chosen.mp3', other: 'https://x/$other.mp3'},
      url: 'https://x/default.mp3',
    );
    expect(card.revealClip(voice: chosen), 'https://x/$chosen.mp3');
  });

  test('falls back to the default recording without a per-voice one', () {
    final card = tibetan(url: 'https://x/default.mp3');
    expect(card.revealClip(voice: chosen), 'https://x/default.mp3');
  });

  test('sound effects off keeps the card silent', () {
    final card = tibetan(url: 'https://x/default.mp3');
    expect(card.revealClip(voice: chosen, soundOn: false), isNull);
  });

  test('photo and English cards never speak', () {
    for (final type in [CardType.photo, CardType.english]) {
      final card = MemoryCard(
        id: 1,
        text: 'sun',
        subtitle: '',
        type: type,
        pairId: 0,
        audioUrl: 'https://x/default.mp3',
      );
      expect(card.revealClip(voice: chosen), isNull);
    }
  });

  test('a card with no recording is silent', () {
    expect(tibetan().revealClip(voice: chosen), isNull);
  });
}
