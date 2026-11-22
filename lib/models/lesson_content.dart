import '../services/pronunciation_voices.dart';
import 'romanisation.dart';

/// One letter, word or phrase on a lesson's teaching cards
/// (`GET /learn/levels/{id}/lesson`).
class LessonItem {
  final String id;
  final String tibetan;

  /// The letter's reading ("kha") in script lessons; the English meaning in
  /// vocabulary lessons.
  final String english;
  final Romanisation romanisation;

  /// A letter's sound or a word's meaning, one line.
  final String note;
  final String? imageUrl;
  final String? audioUrl;
  final Map<String, String> audioUrls;

  const LessonItem({
    required this.id,
    required this.tibetan,
    required this.english,
    this.romanisation = Romanisation.none,
    this.note = '',
    this.imageUrl,
    this.audioUrl,
    this.audioUrls = const {},
  });

  bool get hasAudio => audioUrl != null || audioUrls.isNotEmpty;

  String? audioFor(String voice) =>
      PronunciationVoices.pick(audioUrls, voice, fallbackUrl: audioUrl);

  static LessonItem? fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final tibetan = text(json['tibetan']);
    if (tibetan == null) return null;
    final urls = <String, String>{};
    final raw = json['audio_urls'];
    if (raw is Map) {
      raw.forEach((voice, url) {
        final u = text(url);
        if (voice is String && u != null) urls[voice] = u;
      });
    }
    return LessonItem(
      id: text(json['id']) ?? tibetan,
      tibetan: tibetan,
      english: text(json['english']) ?? '',
      romanisation: Romanisation.fromJson(json),
      note: text(json['note']) ?? '',
      imageUrl: text(json['image_url']),
      audioUrl: text(json['audio_url']),
      audioUrls: urls,
    );
  }
}

/// What to learn before practising a level: teaching notes and items.
class LessonContent {
  final String levelId;
  final String title;
  final String description;
  final bool isScript;
  final List<String> notes;
  final List<LessonItem> items;

  const LessonContent({
    required this.levelId,
    required this.title,
    this.description = '',
    this.isScript = false,
    this.notes = const [],
    this.items = const [],
  });

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    return LessonContent(
      levelId: json['level_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isScript: json['skill']?.toString() == 'script',
      notes: [
        for (final note in (json['notes'] as List? ?? const []))
          if (note.toString().trim().isNotEmpty) note.toString().trim(),
      ],
      items:
          (json['items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(LessonItem.fromJson)
              .whereType<LessonItem>()
              .toList(),
    );
  }
}
