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

  QuizQuestion({
    required this.tibetanText,
    required this.options,
    required this.correctAnswerIndex,
    this.type,
    this.imageUrl,
    this.englishGloss,
  });

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
    );
  }
}
