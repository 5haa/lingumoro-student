import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';

class ReadingService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();

  /// Fetch all readings ordered by sequence
  Future<List<Map<String, dynamic>>> getAllReadings() async {
    try {
      final response = await _supabase
          .from('readings')
          .select('*')
          .order('order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching readings: $e');
      rethrow;
    }
  }

  /// Fetch questions for a specific reading
  Future<List<Map<String, dynamic>>> getQuestionsForReading(
      String readingId) async {
    try {
      final response = await _supabase
          .from('reading_questions')
          .select('*')
          .eq('reading_id', readingId);

      // Parse the options JSON string
      final questions = List<Map<String, dynamic>>.from(response);
      for (var question in questions) {
        if (question['options'] is String) {
          question['options'] = 
              List<String>.from(
                  (question['options'] as String)
                      .replaceAll('[', '')
                      .replaceAll(']', '')
                      .replaceAll('"', '')
                      .split(',')
                      .map((s) => s.trim())
              );
        }
      }

      return questions;
    } catch (e) {
      print('Error fetching reading questions: $e');
      rethrow;
    }
  }

  /// Get student's progress for all readings
  Future<Map<String, bool>> getStudentProgress(String studentId) async {
    try {
      final response = await _supabase
          .from('student_reading_progress')
          .select('reading_id, completed')
          .eq('student_id', studentId);

      final progressMap = <String, bool>{};
      for (var progress in response as List) {
        progressMap[progress['reading_id']] = progress['completed'] ?? false;
      }

      return progressMap;
    } catch (e) {
      print('Error fetching student progress: $e');
      return {};
    }
  }

  /// Check if a reading is unlocked for the student
  /// Returns true if:
  /// - It's the first reading (order = 0)
  /// - The previous reading has been completed
  Future<bool> isReadingUnlocked(
    String studentId,
    Map<String, dynamic> reading,
    List<Map<String, dynamic>> allReadings,
    Map<String, bool> progressMap,
  ) async {
    // First reading is always unlocked
    if (reading['order'] == 0) {
      return true;
    }

    // Find the previous reading
    final previousReadings = allReadings
        .where((r) => r['order'] < reading['order'])
        .toList()
      ..sort((a, b) => b['order'].compareTo(a['order']));

    if (previousReadings.isEmpty) {
      return true; // No previous reading, so unlocked
    }

    // Check if previous reading is completed
    final previousReading = previousReadings.first;
    final previousCompleted = progressMap[previousReading['id']] ?? false;

    return previousCompleted;
  }

  /// Submit answers and calculate score
  /// Returns a map with:
  /// - 'score': number of correct answers
  /// - 'total': total number of questions
  /// - 'correct': list of booleans indicating which answers were correct
  Future<Map<String, dynamic>> submitAnswers(
    String studentId,
    String readingId,
    List<int> studentAnswers,
    List<Map<String, dynamic>> questions,
    int points,
  ) async {
    try {
      // Calculate score
      int correctCount = 0;
      final correctList = <bool>[];

      for (int i = 0; i < questions.length; i++) {
        final isCorrect =
            studentAnswers[i] == questions[i]['correct_option_index'];
        if (isCorrect) {
          correctCount++;
        }
        correctList.add(isCorrect);
      }

      final totalQuestions = questions.length;
      final allCorrect = correctCount == totalQuestions;

      // If all correct, award points and mark as completed
      if (allCorrect) {
        // Award points to student
        await _levelService.awardPoints(studentId, points);

        // Mark reading as completed
        // First check if progress record exists
        final existingProgress = await _supabase
            .from('student_reading_progress')
            .select('id')
            .eq('student_id', studentId)
            .eq('reading_id', readingId)
            .maybeSingle();

        if (existingProgress == null) {
          // Create new progress record
          await _supabase.from('student_reading_progress').insert({
            'student_id': studentId,
            'reading_id': readingId,
            'completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          // Update existing progress record
          await _supabase
              .from('student_reading_progress')
              .update({
                'completed': true,
                'completed_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('student_id', studentId)
              .eq('reading_id', readingId);
        }
      }

      return {
        'score': correctCount,
        'total': totalQuestions,
        'correct': correctList,
        'allCorrect': allCorrect,
        'pointsAwarded': allCorrect ? points : 0,
      };
    } catch (e) {
      print('Error submitting answers: $e');
      rethrow;
    }
  }

  /// Get count of completed readings for a student
  Future<int> getCompletedCount(String studentId) async {
    try {
      final response = await _supabase
          .from('student_reading_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('completed', true);

      return (response as List).length;
    } catch (e) {
      print('Error getting completed count: $e');
      return 0;
    }
  }

  /// Get total number of readings
  Future<int> getTotalReadingsCount() async {
    try {
      final response = await _supabase.from('readings').select('id');

      return (response as List).length;
    } catch (e) {
      print('Error getting total readings count: $e');
      return 0;
    }
  }
}

