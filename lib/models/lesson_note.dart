/// A lesson item's one-line note split into its parts.
///
/// The Basics curriculum writes letter notes as a sound hint followed by an
/// example word: `k as in "skin", no puff of air. ཀ་རག: whitewash`. The
/// lesson screen shows the hint and the example separately, so it splits
/// the note here instead of changing the data.
class LessonNote {
  /// How the letter sounds, or the whole note when it has no example.
  final String hint;

  /// The example word in Tibetan (`ཀ་རག`), if the note has one.
  final String? exampleTibetan;

  /// What the example word means (`whitewash`).
  final String? exampleMeaning;

  const LessonNote({this.hint = '', this.exampleTibetan, this.exampleMeaning});

  bool get hasExample => exampleTibetan != null;
  bool get isEmpty => hint.isEmpty && !hasExample;

  /// A short English gloss ("fish", "the Tibetan language") rather than a
  /// sound description, so it is worth a line on the card itself.
  bool get isShortMeaning =>
      !hasExample &&
      hint.isNotEmpty &&
      hint.length <= 28 &&
      !hint.contains('as in') &&
      !hint.codeUnits.any(_isTibetan);

  static bool _isTibetan(int codeUnit) =>
      codeUnit >= 0x0F00 && codeUnit <= 0x0FFF;

  /// An example is the last sentence when it starts with Tibetan and reads
  /// `<tibetan>: <meaning>`. A sentence that starts with Tibetan but has no
  /// colon (`ཀ with gigu`) is a hint.
  static LessonNote parse(String note) {
    final text = note.trim();
    if (text.isEmpty) return const LessonNote();

    var start = 0;
    final sentence = text.lastIndexOf('. ');
    if (sentence >= 0) start = sentence + 2;
    final tail = text.substring(start);
    final colon = tail.indexOf(':');
    if (tail.isEmpty || !_isTibetan(tail.codeUnitAt(0)) || colon <= 0) {
      return LessonNote(hint: text);
    }
    final word = tail.substring(0, colon).trim();
    final meaning = tail.substring(colon + 1).trim();
    // The word itself must be Tibetan (syllables and tshegs), not a mix.
    if (word.isEmpty ||
        word.codeUnits.any((c) => !_isTibetan(c) && c != 0x20)) {
      return LessonNote(hint: text);
    }
    final hint = start == 0 ? '' : text.substring(0, start - 2).trim();
    return LessonNote(
      hint: hint,
      exampleTibetan: word,
      exampleMeaning: meaning.isEmpty ? null : meaning,
    );
  }
}
