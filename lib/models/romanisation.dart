/// How Tibetan words are written in Latin letters next to the script.
///
/// * Phonetics: THL Simplified Phonetic Transcription, how the word sounds in
///   Lhasa Tibetan (བཀྲ་ཤིས་བདེ་ལེགས -> "trashi delek").
/// * Wylie: letter-by-letter transliteration used by dictionaries and Dharma
///   texts ("bkra shis bde legs").
enum TransliterationMode {
  phonetics,
  wylie,
  both,
  off;

  static const TransliterationMode defaultMode = TransliterationMode.phonetics;

  static TransliterationMode fromId(String? id) {
    for (final mode in values) {
      if (mode.name == id) return mode;
    }
    return defaultMode;
  }

  bool get showsPhonetics => this == phonetics || this == both;
  bool get showsWylie => this == wylie || this == both;

  String get title => switch (this) {
    TransliterationMode.phonetics => 'Phonetics',
    TransliterationMode.wylie => 'Wylie',
    TransliterationMode.both => 'Both',
    TransliterationMode.off => 'Off',
  };

  String get subtitle => switch (this) {
    TransliterationMode.phonetics => 'How it sounds: trashi delek',
    TransliterationMode.wylie => 'Letter by letter: bkra shis bde legs',
    TransliterationMode.both => 'Phonetics with Wylie underneath',
    TransliterationMode.off => 'Tibetan script only',
  };
}

/// A word's two romanisations. Either may be empty when the backend has none.
class Romanisation {
  final String phonetic;
  final String wylie;

  const Romanisation({this.phonetic = '', this.wylie = ''});

  static const Romanisation none = Romanisation();

  bool get isEmpty => phonetic.isEmpty && wylie.isEmpty;

  /// Reads `phonetic` and `wylie` from a backend payload (a word, an
  /// exercise, an option or a lesson item).
  factory Romanisation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    String text(Object? value) => value?.toString().trim() ?? '';
    return Romanisation(
      phonetic: text(json['phonetic']),
      wylie: text(json['wylie']),
    );
  }

  /// The lines to show for [mode], in display order.
  List<String> linesFor(TransliterationMode mode) => [
    if (mode.showsPhonetics && phonetic.isNotEmpty) phonetic,
    if (mode.showsWylie && wylie.isNotEmpty) wylie,
  ];

  @override
  bool operator ==(Object other) =>
      other is Romanisation && other.phonetic == phonetic && other.wylie == wylie;

  @override
  int get hashCode => Object.hash(phonetic, wylie);
}
