import 'dart:convert';

/// Model for a quiz containing multiple questions
class Quiz {
  final String id;
  final String title;
  final String? description;
  final int difficultyLevel;
  final int orderIndex;
  final int estimatedDurationMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed/dynamic fields (not from database)
  int? totalQuestions;
  bool? isCompleted;
  double? bestScore;
  bool? isLocked;

  Quiz({
    required this.id,
    required this.title,
    this.description,
    required this.difficultyLevel,
    required this.orderIndex,
    required this.estimatedDurationMinutes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.totalQuestions,
    this.isCompleted,
    this.bestScore,
    this.isLocked,
  });

  /// Create from JSON (Supabase response)
  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      difficultyLevel: json['difficulty_level'] as int,
      orderIndex: json['order_index'] as int,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      totalQuestions: json['total_questions'] as int?,
      isCompleted: json['is_completed'] as bool?,
      bestScore: json['best_score'] != null
          ? (json['best_score'] as num).toDouble()
          : null,
      isLocked: json['is_locked'] as bool?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty_level': difficultyLevel,
      'order_index': orderIndex,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (totalQuestions != null) 'total_questions': totalQuestions,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (bestScore != null) 'best_score': bestScore,
      if (isLocked != null) 'is_locked': isLocked,
    };
  }

  /// Get difficulty level name
  String get difficultyName {
    switch (difficultyLevel) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Elementary';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      default:
        return 'Unknown';
    }
  }

  /// Get difficulty level color
  String get difficultyColor {
    switch (difficultyLevel) {
      case 1:
        return '#10b981'; // green
      case 2:
        return '#3b82f6'; // blue
      case 3:
        return '#f59e0b'; // orange
      case 4:
        return '#ef4444'; // red
      default:
        return '#6b7280'; // gray
    }
  }

  /// Copy with method for immutability
  Quiz copyWith({
    String? id,
    String? title,
    String? description,
    int? difficultyLevel,
    int? orderIndex,
    int? estimatedDurationMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalQuestions,
    bool? isCompleted,
    double? bestScore,
    bool? isLocked,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      orderIndex: orderIndex ?? this.orderIndex,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      isCompleted: isCompleted ?? this.isCompleted,
      bestScore: bestScore ?? this.bestScore,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

