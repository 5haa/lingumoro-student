import 'dart:convert';

/// Model for a single question answer within a quiz attempt
class QuizAttemptAnswer {
  final String? id;
  final String? attemptId;
  final String quizQuestionId;
  final int? studentAnswerIndex;
  final bool isCorrect;
  final int pointsEarned;
  final DateTime? createdAt;

  // For client-side tracking before submission
  final String? questionText;
  final List<String>? options;
  final int? correctOptionIndex;
  final String? explanation;

  QuizAttemptAnswer({
    this.id,
    this.attemptId,
    required this.quizQuestionId,
    this.studentAnswerIndex,
    required this.isCorrect,
    required this.pointsEarned,
    this.createdAt,
    this.questionText,
    this.options,
    this.correctOptionIndex,
    this.explanation,
  });

  /// Create from JSON (Supabase response)
  factory QuizAttemptAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAttemptAnswer(
      id: json['id'] as String?,
      attemptId: json['attempt_id'] as String?,
      quizQuestionId: json['quiz_question_id'] as String,
      studentAnswerIndex: json['student_answer_index'] as int?,
      isCorrect: json['is_correct'] as bool,
      pointsEarned: json['points_earned'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      questionText: json['question_text'] as String?,
      options: json['options'] != null
          ? (json['options'] is String
              ? List<String>.from(jsonDecode(json['options']))
              : List<String>.from(json['options']))
          : null,
      correctOptionIndex: json['correct_option_index'] as int?,
      explanation: json['explanation'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (attemptId != null) 'attempt_id': attemptId,
      'quiz_question_id': quizQuestionId,
      'student_answer_index': studentAnswerIndex,
      'is_correct': isCorrect,
      'points_earned': pointsEarned,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (questionText != null) 'question_text': questionText,
      if (options != null) 'options': jsonEncode(options),
      if (correctOptionIndex != null) 'correct_option_index': correctOptionIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }

  /// Get student's answer text (if they answered)
  String? get studentAnswerText {
    if (studentAnswerIndex != null && options != null) {
      return options![studentAnswerIndex!];
    }
    return null;
  }

  /// Get correct answer text
  String? get correctAnswerText {
    if (correctOptionIndex != null && options != null) {
      return options![correctOptionIndex!];
    }
    return null;
  }
}

/// Model for a complete quiz attempt
class QuizAttempt {
  final String? id;
  final String? quizId;
  final String? studentId;
  final double scorePercentage;
  final int totalQuestions;
  final int correctAnswers;
  final int totalPointsEarned;
  final DateTime? completedAt;
  final int? durationSeconds;
  final DateTime? createdAt;
  final List<QuizAttemptAnswer> answers;

  QuizAttempt({
    this.id,
    this.quizId,
    this.studentId,
    required this.scorePercentage,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalPointsEarned,
    this.completedAt,
    this.durationSeconds,
    this.createdAt,
    required this.answers,
  });

  /// Create from JSON (Supabase response)
  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    List<QuizAttemptAnswer> answersList = [];
    if (json['answers'] != null) {
      answersList = (json['answers'] as List)
          .map((a) => QuizAttemptAnswer.fromJson(a))
          .toList();
    }

    return QuizAttempt(
      id: json['id'] as String?,
      quizId: json['quiz_id'] as String?,
      studentId: json['student_id'] as String?,
      scorePercentage: (json['score_percentage'] as num).toDouble(),
      totalQuestions: json['total_questions'] as int,
      correctAnswers: json['correct_answers'] as int,
      totalPointsEarned: json['total_points_earned'] as int,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      answers: answersList,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (quizId != null) 'quiz_id': quizId,
      if (studentId != null) 'student_id': studentId,
      'score_percentage': scorePercentage,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'total_points_earned': totalPointsEarned,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'answers': answers.map((a) => a.toJson()).toList(),
    };
  }

  /// Get incorrect answers count
  int get incorrectAnswers => totalQuestions - correctAnswers;

  /// Get formatted duration
  String get formattedDuration {
    if (durationSeconds == null) return 'N/A';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if this is a passing score (>= 60%)
  bool get isPassing => scorePercentage >= 60.0;

  /// Get grade letter based on score
  String get gradeLetter {
    if (scorePercentage >= 90) return 'A';
    if (scorePercentage >= 80) return 'B';
    if (scorePercentage >= 70) return 'C';
    if (scorePercentage >= 60) return 'D';
    return 'F';
  }

  /// Copy with method for immutability
  QuizAttempt copyWith({
    String? id,
    String? quizId,
    String? studentId,
    double? scorePercentage,
    int? totalQuestions,
    int? correctAnswers,
    int? totalPointsEarned,
    DateTime? completedAt,
    int? durationSeconds,
    DateTime? createdAt,
    List<QuizAttemptAnswer>? answers,
  }) {
    return QuizAttempt(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      studentId: studentId ?? this.studentId,
      scorePercentage: scorePercentage ?? this.scorePercentage,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      answers: answers ?? this.answers,
    );
  }
}

