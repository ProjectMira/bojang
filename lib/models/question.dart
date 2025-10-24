enum QuestionType { multipleChoice, fillBlank, pronunciation, matching }

class Question {
  final String id;
  final String levelId;
  final QuestionType questionType;
  final String questionText;
  final String? questionTextTibetan;
  final String? questionAudioUrl;
  final String correctAnswer;
  final String? explanation;
  final String? explanationTibetan;
  final int difficultyScore;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.levelId,
    required this.questionType,
    required this.questionText,
    this.questionTextTibetan,
    this.questionAudioUrl,
    required this.correctAnswer,
    this.explanation,
    this.explanationTibetan,
    this.difficultyScore = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.options = const [],
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      levelId: json['level_id'] as String,
      questionType: _parseQuestionType(json['question_type'] as String),
      questionText: json['question_text'] as String,
      questionTextTibetan: json['question_text_tibetan'] as String?,
      questionAudioUrl: json['question_audio_url'] as String?,
      correctAnswer: json['correct_answer'] as String,
      explanation: json['explanation'] as String?,
      explanationTibetan: json['explanation_tibetan'] as String?,
      difficultyScore: json['difficulty_score'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      options: (json['options'] as List<dynamic>?)
          ?.map((option) => QuestionOption.fromJson(option))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level_id': levelId,
      'question_type': _questionTypeToString(questionType),
      'question_text': questionText,
      'question_text_tibetan': questionTextTibetan,
      'question_audio_url': questionAudioUrl,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'explanation_tibetan': explanationTibetan,
      'difficulty_score': difficultyScore,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'options': options.map((option) => option.toJson()).toList(),
    };
  }

  static QuestionType _parseQuestionType(String type) {
    switch (type) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'fill_blank':
        return QuestionType.fillBlank;
      case 'pronunciation':
        return QuestionType.pronunciation;
      case 'matching':
        return QuestionType.matching;
      default:
        return QuestionType.multipleChoice;
    }
  }

  static String _questionTypeToString(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.fillBlank:
        return 'fill_blank';
      case QuestionType.pronunciation:
        return 'pronunciation';
      case QuestionType.matching:
        return 'matching';
    }
  }

  Question copyWith({
    String? id,
    String? levelId,
    QuestionType? questionType,
    String? questionText,
    String? questionTextTibetan,
    String? questionAudioUrl,
    String? correctAnswer,
    String? explanation,
    String? explanationTibetan,
    int? difficultyScore,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuestionOption>? options,
  }) {
    return Question(
      id: id ?? this.id,
      levelId: levelId ?? this.levelId,
      questionType: questionType ?? this.questionType,
      questionText: questionText ?? this.questionText,
      questionTextTibetan: questionTextTibetan ?? this.questionTextTibetan,
      questionAudioUrl: questionAudioUrl ?? this.questionAudioUrl,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      explanationTibetan: explanationTibetan ?? this.explanationTibetan,
      difficultyScore: difficultyScore ?? this.difficultyScore,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      options: options ?? this.options,
    );
  }
}

class QuestionOption {
  final String id;
  final String questionId;
  final String optionText;
  final String? optionTextTibetan;
  final String? optionAudioUrl;
  final bool isCorrect;
  final int sortOrder;

  QuestionOption({
    required this.id,
    required this.questionId,
    required this.optionText,
    this.optionTextTibetan,
    this.optionAudioUrl,
    required this.isCorrect,
    this.sortOrder = 0,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      optionText: json['option_text'] as String,
      optionTextTibetan: json['option_text_tibetan'] as String?,
      optionAudioUrl: json['option_audio_url'] as String?,
      isCorrect: json['is_correct'] as bool,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'option_text': optionText,
      'option_text_tibetan': optionTextTibetan,
      'option_audio_url': optionAudioUrl,
      'is_correct': isCorrect,
      'sort_order': sortOrder,
    };
  }
}
