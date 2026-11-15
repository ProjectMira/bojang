/// One vocabulary word as the games use it: the Tibetan, its meaning, and
/// whatever picture and recordings the backend has for it.
class GameWord {
  final String id;
  final String tibetan;
  final String english;
  final String phonetic;
  final String? imageUrl;
  final String? audioUrl;

  /// The same pronunciation per TTS voice (e.g. lhasa_female, kham_male).
  final Map<String, String> audioUrls;

  const GameWord({
    required this.id,
    required this.tibetan,
    required this.english,
    this.phonetic = '',
    this.imageUrl,
    this.audioUrl,
    this.audioUrls = const {},
  });

  bool get hasImage => imageUrl != null;
  bool get hasAudio => audioUrl != null || audioUrls.isNotEmpty;

  /// Recording in [voice], falling back to the default voice.
  String? audioFor(String voice) => audioUrls[voice] ?? audioUrl;

  /// The word's syllables: Tibetan separates them with a tsheg (་) and ends
  /// a word with a shad (།). `ཆུ་ག་གོན།` is `[ཆུ, ག, གོན]`.
  List<String> get syllables =>
      tibetan
          .replaceAll('།', '')
          .split('་')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

  /// Parses a `memory_match` card from the backend. Null when the card has
  /// no Tibetan or no meaning, since no game can use it.
  static GameWord? fromCard(Map<String, dynamic> json) {
    final tibetan = _text(json['tibetan']);
    final english = _text(json['english']);
    if (tibetan == null || english == null) return null;

    final urls = <String, String>{};
    final rawUrls = json['audio_urls'];
    if (rawUrls is Map) {
      rawUrls.forEach((voice, url) {
        final text = _text(url);
        if (voice is String && text != null) urls[voice] = text;
      });
    }

    return GameWord(
      id: _text(json['id']) ?? tibetan,
      tibetan: tibetan,
      english: english,
      phonetic: _text(json['phonetic']) ?? '',
      imageUrl: _text(json['image_url']),
      audioUrl: _text(json['audio_url']),
      audioUrls: urls,
    );
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Drops words that would make a round ambiguous: a repeated word, or two
  /// words sharing a spelling or a meaning (either could be "the" answer).
  static List<GameWord> distinct(Iterable<GameWord> words) {
    final ids = <String>{};
    final spellings = <String>{};
    final meanings = <String>{};
    final result = <GameWord>[];
    for (final word in words) {
      final meaning = word.english.toLowerCase();
      if (ids.contains(word.id) ||
          spellings.contains(word.tibetan) ||
          meanings.contains(meaning)) {
        continue;
      }
      ids.add(word.id);
      spellings.add(word.tibetan);
      meanings.add(meaning);
      result.add(word);
    }
    return result;
  }
}
