class QuizQuestion {
  final String tibetanText;
  final List<String> options;
  final int correctAnswerIndex;
  final String? type;

  QuizQuestion({
    required this.tibetanText,
    required this.options,
    required this.correctAnswerIndex,
    this.type,
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
    final options =
        rawOptions.map((option) => option['text'].toString()).toList();
    final correctAnswerId = json['correct_answer_id']?.toString();
    var correctIndex = rawOptions.indexWhere((option) {
      return option['id']?.toString() == correctAnswerId ||
          option['is_correct'] == true;
    });
    if (correctIndex < 0) {
      correctIndex = options.indexOf(json['correct_answer']?.toString() ?? '');
    }
    if (correctIndex < 0) correctIndex = 0;

    return QuizQuestion(
      tibetanText:
          (json['tibetan_word'] ?? json['question'] ?? json['prompt'] ?? '')
              .toString(),
      options: options,
      correctAnswerIndex: correctIndex,
      type: json['type'] as String?,
    );
  }
}
