import 'dart:convert';

/// Model for a quiz question with multiple choice options
class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final int difficultyLevel;
  final int orderIndex;
  final int pointsReward;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed property to get correct answer text
  String get correctAnswer => options[correctOptionIndex];

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.difficultyLevel,
    required this.orderIndex,
    required this.pointsReward,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON (Supabase response)
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // Parse options - handle both string and list formats
    List<String> parsedOptions;
    if (json['options'] is String) {
      parsedOptions = List<String>.from(jsonDecode(json['options']));
    } else if (json['options'] is List) {
      parsedOptions = List<String>.from(json['options']);
    } else {
      parsedOptions = [];
    }

    return QuizQuestion(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      options: parsedOptions,
      correctOptionIndex: json['correct_option_index'] as int,
      explanation: json['explanation'] as String,
      difficultyLevel: json['difficulty_level'] as int,
      orderIndex: json['order_index'] as int,
      pointsReward: json['points_reward'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': jsonEncode(options),
      'correct_option_index': correctOptionIndex,
      'explanation': explanation,
      'difficulty_level': difficultyLevel,
      'order_index': orderIndex,
      'points_reward': pointsReward,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if a given answer index is correct
  bool isAnswerCorrect(int answerIndex) {
    return answerIndex == correctOptionIndex;
  }

  /// Copy with method for immutability
  QuizQuestion copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    int? difficultyLevel,
    int? orderIndex,
    int? pointsReward,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      orderIndex: orderIndex ?? this.orderIndex,
      pointsReward: pointsReward ?? this.pointsReward,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

