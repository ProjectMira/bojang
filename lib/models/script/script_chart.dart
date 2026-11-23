/// The "Reading Tibetan" chart: groups of rows of characters, each with its
/// reading, sound hint, example words, recordings and strength.
///
/// Parsed from `GET /learn/script/course`. When that cannot be reached a
/// bundled chart ([ScriptChart.fallback]) shows the same 30 consonants and
/// four vowels, without audio or strength.
library;

import '../../services/pronunciation_voices.dart';

/// How a cell is coloured, from its strength (0-1).
enum StrengthBand {
  unseen,
  weak,
  learning,
  strong,
  mastered;

  static StrengthBand of(double strength, {required bool seen}) {
    if (!seen) return StrengthBand.unseen;
    if (strength >= 0.85) return StrengthBand.mastered;
    if (strength >= 0.6) return StrengthBand.strong;
    if (strength >= 0.3) return StrengthBand.learning;
    return StrengthBand.weak;
  }

  String get label => switch (this) {
    StrengthBand.unseen => 'not started',
    StrengthBand.weak => 'needs practice',
    StrengthBand.learning => 'learning',
    StrengthBand.strong => 'strong',
    StrengthBand.mastered => 'mastered',
  };
}

class ScriptExample {
  const ScriptExample({
    required this.tibetan,
    required this.english,
    this.reading = '',
    this.wylie = '',
    this.audioUrl,
    this.audioUrls = const {},
  });

  final String tibetan;
  final String english;
  final String reading;
  final String wylie;
  final String? audioUrl;
  final Map<String, String> audioUrls;

  bool get hasAudio => audioUrl != null || audioUrls.isNotEmpty;

  String? audioFor(String voice) =>
      PronunciationVoices.pick(audioUrls, voice, fallbackUrl: audioUrl);

  factory ScriptExample.fromJson(Map<String, dynamic> json) => ScriptExample(
    tibetan: json['tibetan']?.toString() ?? '',
    english: json['english']?.toString() ?? '',
    reading: json['reading']?.toString() ?? '',
    wylie: json['wylie']?.toString() ?? '',
    audioUrl: _nonEmpty(json['audio_url']),
    audioUrls: voiceUrls(json['audio_urls']),
  );
}

class ScriptChar {
  const ScriptChar({
    required this.char,
    required this.reading,
    this.display,
    this.wylie = '',
    this.kind = 'consonant',
    this.tone = '',
    this.hint = '',
    this.lessonId = '',
    this.nearSounds = const [],
    this.examples = const [],
    this.audioUrl,
    this.audioUrls = const {},
    this.strength = 0,
    this.seen = false,
  });

  /// The letter, vowel sign or stack (strength is keyed by this).
  final String char;

  /// What to draw: the letter, or a vowel sign on ཨ.
  final String? display;
  final String reading;
  final String wylie;
  final String kind;
  final String tone;
  final String hint;
  final String lessonId;
  final List<String> nearSounds;
  final List<ScriptExample> examples;
  final String? audioUrl;
  final Map<String, String> audioUrls;
  final double strength;
  final bool seen;

  String get shown => display ?? char;
  bool get isConsonant => kind == 'consonant';
  bool get hasAudio => audioUrl != null || audioUrls.isNotEmpty;
  StrengthBand get band => StrengthBand.of(strength, seen: seen);

  String? audioFor(String voice) =>
      PronunciationVoices.pick(audioUrls, voice, fallbackUrl: audioUrl);

  ScriptChar withStrength(double value, {required bool seen}) => ScriptChar(
    char: char,
    reading: reading,
    display: display,
    wylie: wylie,
    kind: kind,
    tone: tone,
    hint: hint,
    lessonId: lessonId,
    nearSounds: nearSounds,
    examples: examples,
    audioUrl: audioUrl,
    audioUrls: audioUrls,
    strength: value,
    seen: seen,
  );

  factory ScriptChar.fromJson(Map<String, dynamic> json) => ScriptChar(
    char: json['char']?.toString() ?? '',
    display: _nonEmpty(json['display']),
    reading: json['reading']?.toString() ?? '',
    wylie: json['wylie']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'consonant',
    tone: json['tone']?.toString() ?? '',
    hint: json['hint']?.toString() ?? '',
    lessonId: json['lesson_id']?.toString() ?? '',
    nearSounds: [
      for (final c in json['near_sounds'] as List? ?? const []) c.toString(),
    ],
    examples: [
      for (final e in json['examples'] as List? ?? const [])
        if (e is Map<String, dynamic>) ScriptExample.fromJson(e),
    ],
    audioUrl: _nonEmpty(json['audio_url']),
    audioUrls: voiceUrls(json['audio_urls']),
    strength: (json['strength'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0,
    seen: json['seen'] == true,
  );
}

class ScriptGroup {
  const ScriptGroup({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.kind = 'consonant',
    this.columns = 4,
    required this.rows,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kind;
  final int columns;
  final List<List<ScriptChar>> rows;

  Iterable<ScriptChar> get chars => rows.expand((r) => r);

  factory ScriptGroup.fromJson(Map<String, dynamic> json) => ScriptGroup(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'consonant',
    columns: (json['columns'] as num?)?.toInt() ?? 4,
    rows: [
      for (final row in json['rows'] as List? ?? const [])
        [
          for (final c in row as List)
            if (c is Map<String, dynamic>) ScriptChar.fromJson(c),
        ],
    ],
  );
}

class ScriptChart {
  const ScriptChart({
    required this.groups,
    this.gatePassed = false,
    this.gateSkipped = false,
    this.offline = false,
  });

  final List<ScriptGroup> groups;
  final bool gatePassed;
  final bool gateSkipped;

  /// True for [fallback]: no audio, no strength.
  final bool offline;

  Iterable<ScriptChar> get chars => groups.expand((g) => g.chars);

  ScriptChar? find(String char) {
    for (final c in chars) {
      if (c.char == char) return c;
    }
    return null;
  }

  /// Items started and how many are strong (>= 0.6).
  int get seenCount => chars.where((c) => c.seen).length;
  int get strongCount => chars.where((c) => c.seen && c.strength >= 0.6).length;
  int get total => chars.length;

  /// The next items to learn, in chart order: below 0.6 strength. Mirrors
  /// the server's `next_to_learn`, for the "Learn" button's label.
  List<ScriptChar> nextToLearn({int count = 3, double threshold = 0.6}) =>
      chars.where((c) => !c.seen || c.strength < threshold).take(count).toList();

  factory ScriptChart.fromJson(Map<String, dynamic> json) {
    final gate = json['gate'] as Map? ?? const {};
    return ScriptChart(
      groups: [
        for (final g in json['groups'] as List? ?? const [])
          if (g is Map<String, dynamic>) ScriptGroup.fromJson(g),
      ],
      gatePassed: gate['gate_passed'] == true,
      gateSkipped: gate['gate_skipped'] == true,
    );
  }

  /// The 30 consonants in their rows of four, and the four vowels.
  static ScriptChart fallback() {
    const consonants = [
      ['ཀ', 'ka'], ['ཁ', 'kha'], ['ག', 'ga'], ['ང', 'nga'],
      ['ཅ', 'ca'], ['ཆ', 'cha'], ['ཇ', 'ja'], ['ཉ', 'nya'],
      ['ཏ', 'ta'], ['ཐ', 'tha'], ['ད', 'da'], ['ན', 'na'],
      ['པ', 'pa'], ['ཕ', 'pha'], ['བ', 'ba'], ['མ', 'ma'],
      ['ཙ', 'tsa'], ['ཚ', 'tsha'], ['ཛ', 'dza'], ['ཝ', 'wa'],
      ['ཞ', 'zha'], ['ཟ', 'za'], ['འ', "'a"], ['ཡ', 'ya'],
      ['ར', 'ra'], ['ལ', 'la'], ['ཤ', 'sha'], ['ས', 'sa'],
      ['ཧ', 'ha'], ['ཨ', 'a'],
    ];
    const vowels = [['ི', 'i'], ['ུ', 'u'], ['ེ', 'e'], ['ོ', 'o']];
    final letters = [
      for (final c in consonants) ScriptChar(char: c[0], reading: c[1]),
    ];
    return ScriptChart(
      offline: true,
      groups: [
        ScriptGroup(
          id: 'consonants',
          title: 'The 30 letters',
          rows: [
            for (var i = 0; i < letters.length; i += 4)
              letters.sublist(i, i + 4 > letters.length ? letters.length : i + 4),
          ],
        ),
        ScriptGroup(
          id: 'vowels',
          title: 'The 4 vowels',
          kind: 'vowel',
          rows: [
            [
              for (final v in vowels)
                ScriptChar(char: v[0], display: 'ཨ${v[0]}', reading: v[1], kind: 'vowel'),
            ],
          ],
        ),
      ],
    );
  }
}

Map<String, String> voiceUrls(Object? value) {
  if (value is! Map) return const {};
  final urls = <String, String>{};
  value.forEach((voice, url) {
    final text = _nonEmpty(url);
    if (voice is String && text != null) urls[voice] = text;
  });
  return urls;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
