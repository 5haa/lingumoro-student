import 'package:supabase_flutter/supabase_flutter.dart';

class LevelService {
  final _supabase = Supabase.instance.client;

  // Define level thresholds (points required to reach each level)
  static const Map<String, int> levelThresholds = {
    'Beginner': 0,
    'Elementary': 100,
    'Intermediate': 300,
    'Advanced': 600,
    'Proficient': 1000,
  };

  // Get level names in order
  static const List<String> levelOrder = [
    'Beginner',
    'Elementary',
    'Intermediate',
    'Advanced',
    'Proficient',
  ];

  /// Calculate level based on points
  String calculateLevel(int points) {
    if (points >= levelThresholds['Proficient']!) return 'Proficient';
    if (points >= levelThresholds['Advanced']!) return 'Advanced';
    if (points >= levelThresholds['Intermediate']!) return 'Intermediate';
    if (points >= levelThresholds['Elementary']!) return 'Elementary';
    return 'Beginner';
  }

  /// Get next level info
  Map<String, dynamic> getNextLevelInfo(int currentPoints) {
    final currentLevel = calculateLevel(currentPoints);
    final currentIndex = levelOrder.indexOf(currentLevel);
    
    if (currentIndex == levelOrder.length - 1) {
      // Already at max level
      return {
        'nextLevel': null,
        'pointsToNext': 0,
        'progressPercent': 100.0,
        'isMaxLevel': true,
      };
    }

    final nextLevel = levelOrder[currentIndex + 1];
    final pointsToNext = levelThresholds[nextLevel]! - currentPoints;
    final currentLevelThreshold = levelThresholds[currentLevel]!;
    final nextLevelThreshold = levelThresholds[nextLevel]!;
    final progressPercent = ((currentPoints - currentLevelThreshold) / 
        (nextLevelThreshold - currentLevelThreshold) * 100).clamp(0.0, 100.0);

    return {
      'nextLevel': nextLevel,
      'pointsToNext': pointsToNext,
      'progressPercent': progressPercent,
      'isMaxLevel': false,
    };
  }

  /// Award points to student and update level if needed
  Future<Map<String, dynamic>> awardPoints(String studentId, int points) async {
    try {
      // Get current student data
      final student = await _supabase
          .from('students')
          .select('points, level')
          .eq('id', studentId)
          .single();

      final currentPoints = (student['points'] as int?) ?? 0;
      final currentLevel = student['level'] as String? ?? 'Beginner';
      final newPoints = currentPoints + points;
      final newLevel = calculateLevel(newPoints);
      
      final leveledUp = currentLevel != newLevel;

      // Update student points and level
      await _supabase
          .from('students')
          .update({
            'points': newPoints,
            'level': newLevel,
          })
          .eq('id', studentId);

      return {
        'success': true,
        'newPoints': newPoints,
        'newLevel': newLevel,
        'leveledUp': leveledUp,
        'previousLevel': currentLevel,
        'pointsAwarded': points,
      };
    } catch (e) {
      print('Error awarding points: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get student's current level progress
  Future<Map<String, dynamic>> getStudentProgress(String studentId) async {
    try {
      final student = await _supabase
          .from('students')
          .select('points, level')
          .eq('id', studentId)
          .single();

      final points = (student['points'] as int?) ?? 0;
      final level = student['level'] as String? ?? 'Beginner';
      final nextLevelInfo = getNextLevelInfo(points);

      return {
        'points': points,
        'level': level,
        ...nextLevelInfo,
      };
    } catch (e) {
      print('Error getting student progress: $e');
      rethrow;
    }
  }

  /// Get leaderboard (top students by points)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('students')
          .select('id, full_name, avatar_url, points, level')
          .order('points', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Get student's rank
  Future<int> getStudentRank(String studentId) async {
    try {
      final student = await _supabase
          .from('students')
          .select('points')
          .eq('id', studentId)
          .single();

      final studentPoints = (student['points'] as int?) ?? 0;

      // Count students with more points
      final response = await _supabase
          .from('students')
          .select('id')
          .gt('points', studentPoints);

      return (response as List).length + 1;
    } catch (e) {
      print('Error getting student rank: $e');
      return 0;
    }
  }
}

