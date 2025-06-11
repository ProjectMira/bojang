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
} 