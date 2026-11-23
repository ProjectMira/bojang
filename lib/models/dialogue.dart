import 'romanisation.dart';

/// A short two-speaker listening dialogue (plan item #27), from
/// `GET /learn/dialogues/{id}`. Each line is spoken in its speaker's voice
/// (one Lhasa, one Kham), and 2 or 3 questions follow.
class Dialogue {
  final String id;
  final String title;
  final String titleBo;
  final String description;
  final String unitId;
  final String afterLevelId;
  final String status;
  final List<DialogueSpeaker> speakers;
  final List<DialogueLine> lines;
  final List<DialogueQuestion> questions;

  /// Present for a signed-in learner: complete it with `/progress/complete`
  /// so the server grades the answers. Null means grade on the device.
  final DialogueSession? session;

  const Dialogue({
    required this.id,
    required this.title,
    this.titleBo = '',
    this.description = '',
    this.unitId = '',
    this.afterLevelId = '',
    this.status = 'reviewed',
    required this.speakers,
    required this.lines,
    required this.questions,
    this.session,
  });

  factory Dialogue.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => [
      for (final item in json[key] as List<dynamic>? ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final session = json['session'];
    return Dialogue(
      id: _text(json['id']),
      title: _text(json['title']),
      titleBo: _text(json['title_bo']),
      description: _text(json['description']),
      unitId: _text(json['unit_id']),
      afterLevelId: _text(json['after_level_id']),
      status: _text(json['status'], fallback: 'reviewed'),
      speakers: list('speakers').map(DialogueSpeaker.fromJson).toList(),
      lines: list('lines').map(DialogueLine.fromJson).toList(),
      questions:
          list('questions')
              .map(DialogueQuestion.fromJson)
              .where((q) => q.options.isNotEmpty)
              .toList(),
      session:
          session is Map
              ? DialogueSession.fromJson(Map<String, dynamic>.from(session))
              : null,
    );
  }

  /// The speaker of [line], or a plain placeholder when the payload lacks it.
  DialogueSpeaker speakerOf(DialogueLine line) => speakers.firstWhere(
    (s) => s.id == line.speaker,
    orElse:
        () => DialogueSpeaker(
          id: line.speaker,
          name: line.speaker,
          voice: line.voice,
        ),
  );

  /// Whether [line]'s speaker is drawn on the leading side (the first
  /// speaker listed) or the trailing side.
  bool isLeading(DialogueLine line) =>
      speakers.isEmpty || speakers.first.id == line.speaker;

  /// Clip URLs to download before playing.
  Iterable<String> get audioUrls =>
      lines.map((l) => l.audioUrl).whereType<String>();

  bool get hasAudio =>
      lines.isNotEmpty && lines.every((l) => l.audioUrl != null);
}

class DialogueSpeaker {
  final String id;
  final String name;
  final String nameBo;
  final String voice;

  /// Avatar recipe: `circle` or `rounded_square`, and a colour key
  /// (`coral`, `teal`, ...) mapped to the app palette.
  final String shape;
  final String color;

  const DialogueSpeaker({
    required this.id,
    required this.name,
    this.nameBo = '',
    this.voice = '',
    this.shape = 'circle',
    this.color = '',
  });

  factory DialogueSpeaker.fromJson(Map<String, dynamic> json) =>
      DialogueSpeaker(
        id: _text(json['id']),
        name: _text(json['name']),
        nameBo: _text(json['name_bo']),
        voice: _text(json['voice']),
        shape: _text(json['shape'], fallback: 'circle'),
        color: _text(json['color']),
      );

  /// One letter for the avatar: the first Latin letter of the name.
  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

class DialogueLine {
  final String speaker;
  final String voice;
  final String tibetan;
  final String english;
  final Romanisation romanisation;

  /// voice -> MP3 URL. Usually one entry, the speaker's voice.
  final Map<String, String> audioUrls;

  const DialogueLine({
    required this.speaker,
    this.voice = '',
    required this.tibetan,
    this.english = '',
    this.romanisation = Romanisation.none,
    this.audioUrls = const {},
  });

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    final audio = json['audio_urls'];
    return DialogueLine(
      speaker: _text(json['speaker']),
      voice: _text(json['voice']),
      tibetan: _text(json['tibetan']),
      english: _text(json['english']),
      romanisation: Romanisation.fromJson(json),
      audioUrls: {
        if (audio is Map)
          for (final entry in audio.entries)
            if (entry.value is String && (entry.value as String).isNotEmpty)
              entry.key.toString(): entry.value as String,
      },
    );
  }

  /// The clip in the speaker's own voice, else any clip, else null.
  String? get audioUrl =>
      audioUrls[voice] ?? (audioUrls.isEmpty ? null : audioUrls.values.first);
}

class DialogueOption {
  final String id;
  final String text;

  const DialogueOption({required this.id, required this.text});

  factory DialogueOption.fromJson(Map<String, dynamic> json) =>
      DialogueOption(id: _text(json['id']), text: _text(json['text']));
}

class DialogueQuestion {
  final String id;
  final String prompt;
  final List<DialogueOption> options;
  final String correctOptionId;

  const DialogueQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionId,
  });

  factory DialogueQuestion.fromJson(Map<String, dynamic> json) =>
      DialogueQuestion(
        id: _text(json['id']),
        prompt: _text(json['prompt']),
        options: [
          for (final o in json['options'] as List<dynamic>? ?? const [])
            if (o is Map) DialogueOption.fromJson(Map<String, dynamic>.from(o)),
        ],
        correctOptionId: _text(json['correct_option_id']),
      );

  bool isCorrect(String optionId) => optionId == correctOptionId;

  DialogueOption? get correctOption {
    for (final o in options) {
      if (o.id == correctOptionId) return o;
    }
    return null;
  }
}

class DialogueSession {
  final String sessionId;
  final String levelId;
  final int totalQuestions;

  const DialogueSession({
    required this.sessionId,
    required this.levelId,
    required this.totalQuestions,
  });

  factory DialogueSession.fromJson(Map<String, dynamic> json) =>
      DialogueSession(
        sessionId: _text(json['session_id']),
        levelId: _text(json['level_id']),
        totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      );
}

/// One answer to a dialogue question, in the `/progress/complete` shape.
class DialogueAnswer {
  final String questionId;
  final String optionId;
  final bool correct;
  final int ms;

  const DialogueAnswer({
    required this.questionId,
    required this.optionId,
    required this.correct,
    required this.ms,
  });

  Map<String, Object> toJson() => {
    'exercise_id': questionId,
    'answer': optionId,
    'correct': correct,
    'ms': ms,
  };
}

/// The `/progress/complete` body for a server-graded dialogue.
Map<String, dynamic> dialogueCompletion({
  required DialogueSession session,
  required List<DialogueAnswer> answers,
  required String localDate,
  int timeTakenSeconds = 0,
}) {
  final correct = answers.where((a) => a.correct).length;
  return {
    'session_id': session.sessionId,
    'level_id': session.levelId,
    'correct_answers': correct,
    'total_questions': answers.length,
    'time_taken_seconds': timeTakenSeconds,
    'local_date': localDate,
    'answers': [for (final a in answers) a.toJson()],
  };
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
