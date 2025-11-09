import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/ai_speech_service.dart';
import 'package:student/services/level_service.dart';

class GrammarPracticeService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  
  // Use AI server URL from AiSpeechService
  String get _serverUrl => AiSpeechService.serverUrl;

  /// Generate a single grammar question
  Future<Map<String, dynamic>?> generateQuestion({
    required int level,
    String language = 'English',
  }) async {
    try {
      print('Generating grammar question for level $level...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/api/grammar/question'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Grammar question response: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Failed to generate question';
        print('Error generating question: $errorMessage');
        return null;
      }

      final data = jsonDecode(response.body);
      
      if (data['success'] == true && data['question'] != null) {
        return data['question'];
      }
      
      return null;
    } catch (e) {
      print('Error generating grammar question: $e');
      return null;
    }
  }

  /// Generate multiple grammar questions
  Future<List<Map<String, dynamic>>?> generateQuestions({
    required int level,
    int count = 5,
    String language = 'English',
  }) async {
    try {
      print('Generating $count grammar questions for level $level...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/api/grammar/questions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'count': count,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 60));

      print('Grammar questions response: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Failed to generate questions';
        print('Error generating questions: $errorMessage');
        return null;
      }

      final data = jsonDecode(response.body);
      
      if (data['success'] == true && data['questions'] != null) {
        return List<Map<String, dynamic>>.from(data['questions']);
      }
      
      return null;
    } catch (e) {
      print('Error generating grammar questions: $e');
      return null;
    }
  }

  /// Save a grammar practice result
  Future<bool> saveResult({
    required String studentId,
    required int level,
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String studentAnswer,
    required bool isCorrect,
  }) async {
    try {
      // Calculate points awarded
      int pointsAwarded = 0;
      if (isCorrect) {
        // Award more points for higher levels
        pointsAwarded = 5 + (level ~/ 10); // 5-15 points depending on level
      }

      await _supabase.from('grammar_practice_results').insert({
        'student_id': studentId,
        'level': level,
        'question': question,
        'options': jsonEncode(options),
        'correct_answer': correctAnswer,
        'student_answer': studentAnswer,
        'is_correct': isCorrect,
        'points_awarded': pointsAwarded,
      });

      // Award points to student if correct
      if (isCorrect && pointsAwarded > 0) {
        await _levelService.awardPoints(studentId, pointsAwarded);
      }

      return true;
    } catch (e) {
      print('Error saving grammar result: $e');
      return false;
    }
  }

  /// Get student's grammar practice statistics
  Future<Map<String, dynamic>> getStatistics(String studentId) async {
    try {
      final results = await _supabase
          .from('grammar_practice_results')
          .select()
          .eq('student_id', studentId)
          .order('completed_at', ascending: false);

      final resultList = List<Map<String, dynamic>>.from(results);
      
      if (resultList.isEmpty) {
        return {
          'total_questions': 0,
          'correct_answers': 0,
          'incorrect_answers': 0,
          'accuracy': 0.0,
          'total_points_earned': 0,
          'recent_results': [],
        };
      }

      final totalQuestions = resultList.length;
      final correctAnswers = resultList.where((r) => r['is_correct'] == true).length;
      final incorrectAnswers = totalQuestions - correctAnswers;
      final accuracy = (correctAnswers / totalQuestions * 100).toStringAsFixed(1);
      final totalPointsEarned = resultList.fold<int>(
        0,
        (sum, r) => sum + ((r['points_awarded'] as int?) ?? 0),
      );

      return {
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'incorrect_answers': incorrectAnswers,
        'accuracy': double.parse(accuracy),
        'total_points_earned': totalPointsEarned,
        'recent_results': resultList.take(10).toList(),
      };
    } catch (e) {
      print('Error getting grammar statistics: $e');
      return {
        'total_questions': 0,
        'correct_answers': 0,
        'incorrect_answers': 0,
        'accuracy': 0.0,
        'total_points_earned': 0,
        'recent_results': [],
      };
    }
  }

  /// Get student's performance by level
  Future<Map<int, Map<String, dynamic>>> getPerformanceByLevel(String studentId) async {
    try {
      final results = await _supabase
          .from('grammar_practice_results')
          .select()
          .eq('student_id', studentId);

      final resultList = List<Map<String, dynamic>>.from(results);
      
      final performanceByLevel = <int, Map<String, dynamic>>{};
      
      for (final result in resultList) {
        final level = result['level'] as int;
        
        if (!performanceByLevel.containsKey(level)) {
          performanceByLevel[level] = {
            'total': 0,
            'correct': 0,
            'accuracy': 0.0,
          };
        }
        
        performanceByLevel[level]!['total'] = 
            (performanceByLevel[level]!['total'] as int) + 1;
        
        if (result['is_correct'] == true) {
          performanceByLevel[level]!['correct'] = 
              (performanceByLevel[level]!['correct'] as int) + 1;
        }
      }
      
      // Calculate accuracy for each level
      performanceByLevel.forEach((level, data) {
        final total = data['total'] as int;
        final correct = data['correct'] as int;
        data['accuracy'] = total > 0 ? (correct / total * 100) : 0.0;
      });
      
      return performanceByLevel;
    } catch (e) {
      print('Error getting performance by level: $e');
      return {};
    }
  }
}


