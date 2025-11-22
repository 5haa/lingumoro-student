import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';

class QuizPracticeService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  
  // AI server URL configuration
  static const String _serverUrl = 'https://lingumoroai-production.up.railway.app';

  /// Generate a single quiz question
  Future<Map<String, dynamic>?> generateQuestion({
    required int level,
    String language = 'English',
  }) async {
    try {
      print('Generating quiz question for level $level...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/api/quiz/question'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Quiz question response: ${response.statusCode}');

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
      print('Error generating quiz question: $e');
      return null;
    }
  }

  /// Generate multiple quiz questions
  Future<List<Map<String, dynamic>>?> generateQuestions({
    required int level,
    int count = 5,
    String language = 'English',
  }) async {
    try {
      print('Generating $count quiz questions for level $level...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/api/quiz/questions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'count': count,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 60));

      print('Quiz questions response: ${response.statusCode}');

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
      print('Error generating quiz questions: $e');
      return null;
    }
  }

  /// Generate a new quiz session with 10 questions
  Future<List<Map<String, dynamic>>?> generateQuizSession({
    required int level,
    String language = 'English',
  }) async {
    return generateQuestions(level: level, count: 10, language: language);
  }

  /// Save a complete quiz session with all results
  Future<String?> saveQuizSession({
    required String studentId,
    required int level,
    required List<Map<String, dynamic>> questions,
    required List<String?> studentAnswers,
    required int durationSeconds,
  }) async {
    try {
      // Calculate results
      int correctCount = 0;
      int totalPoints = 0;

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final studentAnswer = studentAnswers[i];
        final correctAnswer = question['correct_answer'];
        final isCorrect = studentAnswer != null && studentAnswer == correctAnswer;

        if (isCorrect) {
          correctCount++;
          // Award more points for higher levels
          final pointsForQuestion = 5 + (level ~/ 10);
          totalPoints += pointsForQuestion;
        }
      }

      final scorePercentage = (correctCount / questions.length * 100).toStringAsFixed(2);

      // Create quiz session
      final sessionResponse = await _supabase
          .from('quiz_sessions')
          .insert({
            'student_id': studentId,
            'total_questions': questions.length,
            'correct_answers': correctCount,
            'score_percentage': double.parse(scorePercentage),
            'points_earned': totalPoints,
            'duration_seconds': durationSeconds,
          })
          .select()
          .single();

      final sessionId = sessionResponse['id'] as String;

      // Save individual question results
      final results = <Map<String, dynamic>>[];
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final studentAnswer = studentAnswers[i];
        final correctAnswer = question['correct_answer'];
        final isCorrect = studentAnswer != null && studentAnswer == correctAnswer;
        final pointsForQuestion = isCorrect ? (5 + (level ~/ 10)) : 0;

        results.add({
          'session_id': sessionId,
          'student_id': studentId,
          'level': level,
          'question': question['question'],
          'options': jsonEncode(question['options']),
          'correct_answer': correctAnswer,
          'student_answer': studentAnswer ?? '',
          'is_correct': isCorrect,
          'points_awarded': pointsForQuestion,
        });
      }

      await _supabase.from('quiz_practice_results').insert(results);

      // Award total points to student
      if (totalPoints > 0) {
        await _levelService.awardPoints(studentId, totalPoints);
      }

      return sessionId;
    } catch (e) {
      print('Error saving quiz session: $e');
      return null;
    }
  }

  /// Get quiz session history
  Future<List<Map<String, dynamic>>> getQuizSessionHistory(String studentId) async {
    try {
      final sessions = await _supabase
          .from('quiz_sessions')
          .select()
          .eq('student_id', studentId)
          .order('completed_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(sessions);
    } catch (e) {
      print('Error getting quiz session history: $e');
      return [];
    }
  }

  /// Get quiz session with all questions
  Future<Map<String, dynamic>?> getQuizSession(String sessionId) async {
    try {
      final session = await _supabase
          .from('quiz_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final results = await _supabase
          .from('quiz_practice_results')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return {
        ...session,
        'questions': List<Map<String, dynamic>>.from(results),
      };
    } catch (e) {
      print('Error getting quiz session: $e');
      return null;
    }
  }

  /// Save a quiz practice result
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

      await _supabase.from('quiz_practice_results').insert({
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
      print('Error saving quiz result: $e');
      return false;
    }
  }

  /// Get student's quiz practice statistics (based on sessions)
  Future<Map<String, dynamic>> getStatistics(String studentId) async {
    try {
      // Get all quiz sessions
      final sessions = await _supabase
          .from('quiz_sessions')
          .select()
          .eq('student_id', studentId)
          .order('completed_at', ascending: false);

      final sessionList = List<Map<String, dynamic>>.from(sessions);
      
      if (sessionList.isEmpty) {
        return {
          'total_sessions': 0,
          'total_questions': 0,
          'correct_answers': 0,
          'incorrect_answers': 0,
          'accuracy': 0.0,
          'total_points_earned': 0,
          'average_score': 0.0,
          'recent_sessions': [],
        };
      }

      final totalSessions = sessionList.length;
      final totalQuestions = sessionList.fold<int>(
        0,
        (sum, s) => sum + ((s['total_questions'] as int?) ?? 0),
      );
      final correctAnswers = sessionList.fold<int>(
        0,
        (sum, s) => sum + ((s['correct_answers'] as int?) ?? 0),
      );
      final incorrectAnswers = totalQuestions - correctAnswers;
      final accuracy = totalQuestions > 0 
          ? (correctAnswers / totalQuestions * 100).toStringAsFixed(1)
          : '0.0';
      final totalPointsEarned = sessionList.fold<int>(
        0,
        (sum, s) => sum + ((s['points_earned'] as int?) ?? 0),
      );
      final averageScore = sessionList.fold<double>(
        0.0,
        (sum, s) => sum + ((s['score_percentage'] as num?)?.toDouble() ?? 0.0),
      ) / totalSessions;

      return {
        'total_sessions': totalSessions,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'incorrect_answers': incorrectAnswers,
        'accuracy': double.parse(accuracy),
        'total_points_earned': totalPointsEarned,
        'average_score': averageScore,
        'recent_sessions': sessionList.take(10).toList(),
      };
    } catch (e) {
      print('Error getting quiz statistics: $e');
      return {
        'total_sessions': 0,
        'total_questions': 0,
        'correct_answers': 0,
        'incorrect_answers': 0,
        'accuracy': 0.0,
        'total_points_earned': 0,
        'average_score': 0.0,
        'recent_sessions': [],
      };
    }
  }

  /// Get student's performance by level
  Future<Map<int, Map<String, dynamic>>> getPerformanceByLevel(String studentId) async {
    try {
      final results = await _supabase
          .from('quiz_practice_results')
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



