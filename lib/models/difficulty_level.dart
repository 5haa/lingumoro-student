/// Difficulty levels for practice activities (quizzes, videos, readings)
/// Each level must be completed before the next unlocks
enum DifficultyLevel {
  level1(1, 'Beginner'),
  level2(2, 'Elementary'),
  level3(3, 'Intermediate'),
  level4(4, 'Advanced');

  final int value;
  final String label;

  const DifficultyLevel(this.value, this.label);

  /// Get DifficultyLevel from integer value
  static DifficultyLevel fromValue(int value) {
    switch (value) {
      case 1:
        return DifficultyLevel.level1;
      case 2:
        return DifficultyLevel.level2;
      case 3:
        return DifficultyLevel.level3;
      case 4:
        return DifficultyLevel.level4;
      default:
        return DifficultyLevel.level1;
    }
  }

  /// Get all difficulty levels as a list
  static List<DifficultyLevel> get all => DifficultyLevel.values;

  /// Check if this is the last level
  bool get isLastLevel => this == DifficultyLevel.level4;

  /// Get the next difficulty level (returns null if already at max level)
  DifficultyLevel? get nextLevel {
    if (isLastLevel) return null;
    return DifficultyLevel.fromValue(value + 1);
  }
}

