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
  });

  /// Recording in [voice], falling back to the default voice.
  String? audioFor(String voice) => audioUrls[voice] ?? audioUrl;

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

  /// This question asked from English: "how do you say X?" with the same
  /// Tibetan options and no picture. Null unless this is a [pictureChoice]
  /// question that knows its English meaning.
  QuizQuestion? asReverse() {
    final gloss = englishGloss?.trim() ?? '';
    if (type != pictureChoice || gloss.isEmpty) return null;
    return _copyWithType(reverseChoice, keepImage: false);
  }

  QuizQuestion _copyWithType(String newType, {bool keepImage = true}) {
    return QuizQuestion(
      tibetanText: tibetanText,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      type: newType,
      imageUrl: keepImage ? imageUrl : null,
      englishGloss: englishGloss,
      audioUrl: audioUrl,
      audioUrls: audioUrls,
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
