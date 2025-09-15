class QuizSession {
  final String id;
  final String userId;
  final String levelId;
  final int totalQuestions;
  final int correctAnswers;
  final int score;
  final int xpEarned;
  final int? timeTokenSeconds;
  final double accuracy;
  final DateTime completedAt;
  final bool isSynced;
  final String? offlineSessionId;
  final DateTime? deviceTimestamp;

  QuizSession({
    required this.id,
    required this.userId,
    required this.levelId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.xpEarned,
    this.timeTokenSeconds,
    required this.accuracy,
    required this.completedAt,
    this.isSynced = false,
    this.offlineSessionId,
    this.deviceTimestamp,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      levelId: json['level_id'] as String,
      totalQuestions: json['total_questions'] as int,
      correctAnswers: json['correct_answers'] as int,
      score: json['score'] as int,
      xpEarned: json['xp_earned'] as int,
      timeTokenSeconds: json['time_taken_seconds'] as int?,
      accuracy: (json['accuracy'] as num).toDouble(),
      completedAt: DateTime.parse(json['completed_at'] as String),
      isSynced: json['is_synced'] as bool? ?? false,
      offlineSessionId: json['offline_session_id'] as String?,
      deviceTimestamp: json['device_timestamp'] != null 
          ? DateTime.parse(json['device_timestamp'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'level_id': levelId,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'score': score,
      'xp_earned': xpEarned,
      'time_taken_seconds': timeTokenSeconds,
      'accuracy': accuracy,
      'completed_at': completedAt.toIso8601String(),
      'is_synced': isSynced,
      'offline_session_id': offlineSessionId,
      'device_timestamp': deviceTimestamp?.toIso8601String(),
    };
  }

  QuizSession copyWith({
    String? id,
    String? userId,
    String? levelId,
    int? totalQuestions,
    int? correctAnswers,
    int? score,
    int? xpEarned,
    int? timeTokenSeconds,
    double? accuracy,
    DateTime? completedAt,
    bool? isSynced,
    String? offlineSessionId,
    DateTime? deviceTimestamp,
  }) {
    return QuizSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      levelId: levelId ?? this.levelId,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      score: score ?? this.score,
      xpEarned: xpEarned ?? this.xpEarned,
      timeTokenSeconds: timeTokenSeconds ?? this.timeTokenSeconds,
      accuracy: accuracy ?? this.accuracy,
      completedAt: completedAt ?? this.completedAt,
      isSynced: isSynced ?? this.isSynced,
      offlineSessionId: offlineSessionId ?? this.offlineSessionId,
      deviceTimestamp: deviceTimestamp ?? this.deviceTimestamp,
    );
  }
}

class QuizResult {
  final String id;
  final String sessionId;
  final String questionId;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int? timeTokenSeconds;
  final DateTime createdAt;

  QuizResult({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.timeTokenSeconds,
    required this.createdAt,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      questionId: json['question_id'] as String,
      userAnswer: json['user_answer'] as String,
      correctAnswer: json['correct_answer'] as String,
      isCorrect: json['is_correct'] as bool,
      timeTokenSeconds: json['time_taken_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'question_id': questionId,
      'user_answer': userAnswer,
      'correct_answer': correctAnswer,
      'is_correct': isCorrect,
      'time_taken_seconds': timeTokenSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
