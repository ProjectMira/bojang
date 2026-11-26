/// A spoken dialect of Tibetan. Voices are grouped by dialect so a missing
/// recording falls back to another voice of the same dialect first.
enum TibetanDialect {
  /// Ü-Tsang / Central Tibetan as spoken in Lhasa (the standard).
  lhasa('Lhasa', 'Central Tibetan, the standard taught in most courses'),

  /// Kham, spoken in eastern Tibet.
  kham('Kham', 'Eastern Tibet'),

  /// Amdo, spoken in north-eastern Tibet.
  amdo('Amdo', 'North-eastern Tibet');

  final String label;
  final String region;
  const TibetanDialect(this.label, this.region);
}

/// One TTS voice the backend publishes recordings for. Its [id] is the key in
/// a word's `audio_urls`.
class PronunciationVoice {
  final String id;
  final TibetanDialect dialect;
  final String speaker; // "female", "male"

  const PronunciationVoice(this.id, this.dialect, this.speaker);

  /// "Lhasa · female", as shown in Settings.
  String get label => '${dialect.label} · $speaker';

  /// "Lhasa ♀", for the small voice chip next to a speaker button.
  String get shortLabel =>
      '${dialect.label} ${speaker == 'female' ? '\u2640' : '\u2642'}';
}

/// TTS voices the backend publishes per word (`audio_urls` keys).
///
/// To add a dialect or voice: publish its recordings under a new `audio_urls`
/// key (audio-work/publish_audio.sh VOICE) and add one line to [all]. Words
/// that lack the new voice keep playing through [pick]'s fallback.
class PronunciationVoices {
  PronunciationVoices._();

  static const String defaultVoice = 'lhasa_female';

  /// Every voice, in display order.
  static const List<PronunciationVoice> all = [
    PronunciationVoice('lhasa_female', TibetanDialect.lhasa, 'female'),
    PronunciationVoice('kham_male', TibetanDialect.kham, 'male'),
    PronunciationVoice('amdo_male', TibetanDialect.amdo, 'male'),
  ];

  /// Voice id -> label shown in Settings, in display order.
  static final Map<String, String> labels = {
    for (final voice in all) voice.id: voice.label,
  };

  static PronunciationVoice? byId(String? id) {
    for (final voice in all) {
      if (voice.id == id) return voice;
    }
    return null;
  }

  /// Which voice will actually speak a word that has recordings [urls], when
  /// the learner prefers [preferred]: that voice, else another voice of the
  /// same dialect, else the default voice, else any recording. Null when the
  /// word has no per-voice recordings at all.
  static String? resolve(Map<String, String> urls, String preferred) {
    if (urls.isEmpty) return null;
    if (urls.containsKey(preferred)) return preferred;
    final dialect = byId(preferred)?.dialect;
    for (final voice in all) {
      if (voice.dialect == dialect && urls.containsKey(voice.id)) {
        return voice.id;
      }
    }
    if (urls.containsKey(defaultVoice)) return defaultVoice;
    return urls.keys.first;
  }

  /// The recording to play: see [resolve]; [fallbackUrl] (the word's single
  /// default-voice `audio_url`) when it has no per-voice recordings.
  static String? pick(
    Map<String, String> urls,
    String preferred, {
    String? fallbackUrl,
  }) {
    final voice = resolve(urls, preferred);
    return voice == null ? fallbackUrl : urls[voice];
  }
}
