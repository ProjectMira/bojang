import '../services/pronunciation_voices.dart';
import 'romanisation.dart';

class QuizQuestion {
  final String tibetanText;
  final List<String> options;
  final int correctAnswerIndex;
  final String? type;

  /// Illustration prompt for picture_choice exercises; null otherwise.
  final String? imageUrl;

  /// English gloss of the pictured word — shown as the prompt when the
  /// image fails to load.
  final String? englishGloss;

  /// Pronunciation of the question's Tibetan word: the prompt for
  /// multiple_choice, the correct option for picture_choice. Null when the
  /// word has no recording.
  final String? audioUrl;

  /// The same pronunciation per TTS voice (e.g. lhasa_female, kham_male).
  final Map<String, String> audioUrls;

  /// Phonetics and Wylie of the question's Tibetan word.
  final Romanisation romanisation;

  /// True for Basics script questions (letters, syllables): the options are
  /// readings, so romanisation would give the answer away before answering.
  final bool isScript;

  /// Per option, in [options] order: the option's word in Tibetan and its
  /// romanisation. Empty when the payload did not include them.
  final List<String?> optionTibetan;
  final List<Romanisation> optionRomanisations;

  /// The server's id for this exercise, sent back with the answer so the
  /// server can grade it. Null for bundled offline lessons.
  final String? exerciseId;

  /// The server's id of each option, in [options] order; the chosen one is
  /// the answer sent to the server. Empty for bundled lessons.
  final List<String> optionIds;

  /// Why the exercise is here, as the server labelled it: `new`, `mistake`
  /// (answered wrong last time), `weak` or `hard`. Null for plain review.
  final String? label;

  /// Tibetan prompt, English options. The prompt is spoken when it appears.
  static const String multipleChoice = 'multiple_choice';

  /// Picture prompt, Tibetan options.
  static const String pictureChoice = 'picture_choice';

  /// Audio-only prompt, English options. Made on the device from a
  /// [multipleChoice] exercise; see [asListening].
  static const String listening = 'listening';

  /// English prompt, Tibetan options. Made on the device from a
  /// [pictureChoice] exercise; see [asReverse].
  static const String reverseChoice = 'reverse_choice';

  QuizQuestion({
    required this.tibetanText,
    required this.options,
    required this.correctAnswerIndex,
    this.type,
    this.imageUrl,
    this.englishGloss,
    this.audioUrl,
    this.audioUrls = const {},
    this.romanisation = Romanisation.none,
    this.isScript = false,
    this.optionTibetan = const [],
    this.optionRomanisations = const [],
    this.exerciseId,
    this.optionIds = const [],
    this.label,
  });

  /// The server id of option [index], or its text when the payload had no
  /// ids (the server accepts either).
  String answerIdFor(int index) {
    final id = index < optionIds.length ? optionIds[index] : '';
    return id.isNotEmpty ? id : options[index];
  }

  /// Server exercise types the quiz screen can render; sent as
  /// `supported_types` so the server builds only these.
  static const List<String> renderableTypes = [multipleChoice, pictureChoice];

  /// The same question with a different [label].
  QuizQuestion withLabel(String? newLabel) =>
      _copyWithType(type ?? multipleChoice, label: newLabel, keepType: true);

  /// The question's Tibetan word: the correct option when the options are
  /// Tibetan (picture payloads carry no `tibetan_word`), else the prompt.
  String get wordTibetan =>
      hasTibetanOptions &&
              correctAnswerIndex >= 0 &&
              correctAnswerIndex < options.length
          ? options[correctAnswerIndex]
          : tibetanText;

  /// Romanisation of option [index] when the options are Tibetan.
  Romanisation optionRomanisation(int index) =>
      hasTibetanOptions && index < optionRomanisations.length
          ? optionRomanisations[index]
          : Romanisation.none;

  /// Whether romanisation may show now: always for vocabulary, and for
  /// script questions only once answered.
  bool showsRomanisation({required bool answered}) => answered || !isScript;

  /// Recording in [voice], falling back to another voice of the same
  /// dialect, then the default voice (see [PronunciationVoices.pick]).
  String? audioFor(String voice) =>
      PronunciationVoices.pick(audioUrls, voice, fallbackUrl: audioUrl);

  /// The voice [audioFor] actually uses, or null for the plain default
  /// `audio_url` (or no recording).
  String? voiceFor(String voice) =>
      PronunciationVoices.resolve(audioUrls, voice);

  /// True when the options are Tibetan words, so the word's recording must
  /// wait until the learner has answered (earlier would give it away).
  bool get hasTibetanOptions => type == pictureChoice || type == reverseChoice;

  bool get _hasAudio => audioUrl != null || audioUrls.isNotEmpty;

  /// This question asked by ear: the Tibetan word is heard, not shown.
  /// Null unless this is a [multipleChoice] question with a recording.
  QuizQuestion? asListening() {
    if (type != multipleChoice || !_hasAudio) return null;
    return _copyWithType(listening);
  }

  /// A script question turned around: the reading is shown ("kha") and the
  /// learner picks the Tibetan letter or word. Null unless this is a script
  /// [multipleChoice] question whose options all carry their Tibetan.
  QuizQuestion? asReadingReverse() {
    if (type != multipleChoice || !isScript) return null;
    if (optionTibetan.length != options.length) return null;
    if (optionTibetan.any((t) => t == null || t.isEmpty)) return null;
    return QuizQuestion(
      tibetanText: tibetanText,
      options: [for (final t in optionTibetan) t!],
      correctAnswerIndex: correctAnswerIndex,
      type: reverseChoice,
      englishGloss: options[correctAnswerIndex],
      audioUrl: audioUrl,
      audioUrls: audioUrls,
      romanisation: romanisation,
      isScript: true,
      optionTibetan: optionTibetan,
      optionRomanisations: optionRomanisations,
      exerciseId: exerciseId,
      optionIds: optionIds,
      label: label,
    );
  }

  /// This question asked from English: "how do you say X?" with the same
  /// Tibetan options and no picture. Null unless this is a [pictureChoice]
  /// question that knows its English meaning.
  QuizQuestion? asReverse() {
    final gloss = englishGloss?.trim() ?? '';
    if (type != pictureChoice || gloss.isEmpty) return null;
    return _copyWithType(reverseChoice, keepImage: false);
  }

  QuizQuestion _copyWithType(
    String newType, {
    bool keepImage = true,
    bool keepType = false,
    String? label,
  }) {
    return QuizQuestion(
      tibetanText: tibetanText,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      type: keepType ? type : newType,
      imageUrl: keepImage ? imageUrl : null,
      englishGloss: englishGloss,
      audioUrl: audioUrl,
      audioUrls: audioUrls,
      romanisation: romanisation,
      isScript: isScript,
      optionTibetan: optionTibetan,
      optionRomanisations: optionRomanisations,
      exerciseId: exerciseId,
      optionIds: optionIds,
      label: label ?? this.label,
    );
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      tibetanText: json['tibetanText'] as String,
      options: List<String>.from(json['options'] as List<dynamic>),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      type: json['type'] as String?,
    );
  }

  factory QuizQuestion.fromApiExercise(Map<String, dynamic> json) {
    final rawOptions = List<Map<String, dynamic>>.from(
      json['options'] as List<dynamic>? ?? [],
    );
    final validOptions =
        rawOptions.where((option) {
          final text = option['text']?.toString().trim() ?? '';
          return text.isNotEmpty;
        }).toList();
    if (validOptions.isEmpty) {
      throw const FormatException('Multiple choice exercise has no options.');
    }

    final correctAnswerId = json['correct_answer_id']?.toString();
    var correctIndex = validOptions.indexWhere((option) {
      return option['id']?.toString() == correctAnswerId ||
          option['is_correct'] == true;
    });
    if (correctIndex < 0) {
      final correctAnswer = json['correct_answer']?.toString().trim() ?? '';
      correctIndex = validOptions.indexWhere((option) {
        return option['text']?.toString().trim() == correctAnswer;
      });
    }
    if (correctIndex < 0 || correctIndex >= validOptions.length) {
      throw const FormatException(
        'Multiple choice exercise has no valid answer.',
      );
    }

    final tibetanText =
        (json['tibetan_word'] ?? json['question'] ?? json['prompt'] ?? '')
            .toString()
            .trim();
    if (tibetanText.isEmpty) {
      throw const FormatException(
        'Multiple choice exercise has no question text.',
      );
    }

    final type = (json['type'] ?? json['exercise_type'])?.toString();
    // Only picture_choice renders an image prompt. Plain multiple_choice
    // payloads also carry image_url, but words mode must stay text-only.
    final isPicture = type == 'picture_choice';

    return QuizQuestion(
      tibetanText: tibetanText,
      options:
          validOptions
              .map((option) => option['text'].toString().trim())
              .toList(),
      correctAnswerIndex: correctIndex,
      type: type,
      imageUrl: isPicture ? json['image_url']?.toString() : null,
      englishGloss: isPicture ? json['english_word']?.toString() : null,
      audioUrl: _nonEmpty(json['audio_url']),
      audioUrls: _voiceUrls(json['audio_urls']),
      romanisation: Romanisation.fromJson(json),
      isScript: json['skill']?.toString() == 'script',
      optionTibetan: [
        for (final option in validOptions) _nonEmpty(option['tibetan']),
      ],
      optionRomanisations: [
        for (final option in validOptions) Romanisation.fromJson(option),
      ],
      exerciseId: _nonEmpty(json['exercise_id']),
      optionIds: [
        for (final option in validOptions) option['id']?.toString() ?? '',
      ],
      label: _nonEmpty(json['label']),
    );
  }

  static Map<String, String> _voiceUrls(Object? value) {
    if (value is! Map) return const {};
    final urls = <String, String>{};
    value.forEach((voice, url) {
      final text = _nonEmpty(url);
      if (voice is String && text != null) urls[voice] = text;
    });
    return urls;
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
