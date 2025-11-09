import 'package:supabase_flutter/supabase_flutter.dart';

class LevelService {
  final _supabase = Supabase.instance.client;

  // Constants
  static const int maxLevel = 100;
  static const int minLevel = 1;
  static const int pointsPerLevel = 100; // Points required per level

  /// Calculate level based on points (1-100)
  int calculateLevel(int points) {
    final level = (points ~/ pointsPerLevel) + 1;
    return level.clamp(minLevel, maxLevel);
  }

  /// Get next level info
  Map<String, dynamic> getNextLevelInfo(int currentPoints) {
    final currentLevel = calculateLevel(currentPoints);
    
    if (currentLevel >= maxLevel) {
      // Already at max level
      return {
        'nextLevel': null,
        'pointsToNext': 0,
        'progressPercent': 100.0,
        'isMaxLevel': true,
        'currentLevel': currentLevel,
      };
    }

    final nextLevel = currentLevel + 1;
    final pointsForCurrentLevel = (currentLevel - 1) * pointsPerLevel;
    final pointsForNextLevel = currentLevel * pointsPerLevel;
    final pointsToNext = pointsForNextLevel - currentPoints;
    final progressPercent = ((currentPoints - pointsForCurrentLevel) / 
        pointsPerLevel * 100).clamp(0.0, 100.0);

    return {
      'nextLevel': nextLevel,
      'pointsToNext': pointsToNext,
      'progressPercent': progressPercent,
      'isMaxLevel': false,
      'currentLevel': currentLevel,
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
      final currentLevel = (student['level'] as int?) ?? 1;
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
      final level = (student['level'] as int?) ?? 1;
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

