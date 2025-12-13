import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/models/quiz_question.dart';
import 'package:student/models/difficulty_level.dart';

class QuizPracticeService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  final _dailyLimitService = DailyLimitService();

  /// Get all quiz questions for a specific difficulty level
  Future<List<QuizQuestion>> getQuizQuestionsByDifficulty(
      int difficultyLevel) async {
    try {
      final response = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('difficulty_level', difficultyLevel)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final questions = (response as List)
          .map((json) => QuizQuestion.fromJson(json))
          .toList();

      return questions;
    } catch (e) {
      print('Error fetching quiz questions: $e');
      return [];
    }
  }

  /// Get the next uncompleted quiz question for a student in a difficulty level
  Future<QuizQuestion?> getNextUncompletedQuiz(
      String studentId, int difficultyLevel) async {
    try {
      // Get all questions for this difficulty level
      final allQuestions = await getQuizQuestionsByDifficulty(difficultyLevel);

      if (allQuestions.isEmpty) return null;

      // Get student's progress for these questions
      final questionIds = allQuestions.map((q) => q.id).toList();

      final progressResponse = await _supabase
          .from('student_quiz_progress')
          .select('quiz_question_id, completed')
          .eq('student_id', studentId)
          .inFilter('quiz_question_id', questionIds);

      final completedIds = <String>{};
      for (var progress in (progressResponse as List)) {
        if (progress['completed'] == true) {
          completedIds.add(progress['quiz_question_id'] as String);
        }
      }

      // Find first uncompleted question in order
      for (var question in allQuestions) {
        if (!completedIds.contains(question.id)) {
          return question;
        }
      }

      // All questions completed
      return null;
    } catch (e) {
      print('Error getting next uncompleted quiz: $e');
      return null;
    }
  }

  /// Check if student can attempt a quiz today (daily limit not reached)
  Future<bool> canAttemptQuiz(String studentId) async {
    return await _dailyLimitService.checkDailyLimit(
        studentId, DailyLimitService.practiceTypeQuiz);
  }

  /// Check if a specific quiz question is completed by the student
  Future<bool> isQuizCompleted(String studentId, String quizQuestionId) async {
    try {
      final response = await _supabase
          .from('student_quiz_progress')
          .select('completed')
          .eq('student_id', studentId)
          .eq('quiz_question_id', quizQuestionId)
          .maybeSingle();

      if (response == null) return false;
      return response['completed'] == true;
    } catch (e) {
      print('Error checking quiz completion: $e');
      return false;
    }
  }

  /// Submit a quiz answer and record progress
  /// Returns map with: {isCorrect, pointsAwarded, explanation}
  Future<Map<String, dynamic>> submitQuizAnswer({
    required String studentId,
    required QuizQuestion question,
    required int studentAnswerIndex,
  }) async {
    try {
      final isCorrect = question.isAnswerCorrect(studentAnswerIndex);
      final pointsAwarded = isCorrect ? question.pointsReward : 0;

      // Check if progress record exists
      final existing = await _supabase
          .from('student_quiz_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('quiz_question_id', question.id)
          .maybeSingle();

      final now = DateTime.now().toIso8601String();

      if (existing != null) {
        // Update existing progress
        await _supabase
            .from('student_quiz_progress')
            .update({
              'completed': true,
              'student_answer_index': studentAnswerIndex,
              'is_correct': isCorrect,
              'completed_at': now,
              'updated_at': now,
            })
            .eq('student_id', studentId)
            .eq('quiz_question_id', question.id);
      } else {
        // Create new progress record
        await _supabase.from('student_quiz_progress').insert({
          'student_id': studentId,
          'quiz_question_id': question.id,
          'completed': true,
          'student_answer_index': studentAnswerIndex,
          'is_correct': isCorrect,
          'completed_at': now,
          'created_at': now,
          'updated_at': now,
        });
      }

      // Award points if correct
      if (isCorrect && pointsAwarded > 0) {
        await _levelService.awardPoints(studentId, pointsAwarded);
      }

      // Record daily limit (first quiz completed today)
      await _dailyLimitService.recordPracticeCompletion(
          studentId, DailyLimitService.practiceTypeQuiz);

      return {
        'isCorrect': isCorrect,
        'pointsAwarded': pointsAwarded,
        'explanation': question.explanation,
        'correctAnswer': question.correctAnswer,
      };
    } catch (e) {
      print('Error submitting quiz answer: $e');
      rethrow;
    }
  }

  /// Get quiz progress statistics for a difficulty level
  Future<Map<String, dynamic>> getQuizProgress(
      String studentId, int difficultyLevel) async {
    try {
      // Get all questions for this level
      final allQuestions = await getQuizQuestionsByDifficulty(difficultyLevel);
      final totalQuestions = allQuestions.length;

      if (totalQuestions == 0) {
        return {
          'total': 0,
          'completed': 0,
          'percentage': 0.0,
          'canUnlockNext': false,
        };
      }

      // Get completion progress
      final questionIds = allQuestions.map((q) => q.id).toList();

      final progressResponse = await _supabase
          .from('student_quiz_progress')
          .select('completed')
          .eq('student_id', studentId)
          .eq('completed', true)
          .inFilter('quiz_question_id', questionIds);

      final completedCount = (progressResponse as List).length;
      final percentage = (completedCount / totalQuestions * 100).toDouble();
      final canUnlockNext = completedCount == totalQuestions;

      return {
        'total': totalQuestions,
        'completed': completedCount,
        'percentage': percentage,
        'canUnlockNext': canUnlockNext,
      };
    } catch (e) {
      print('Error getting quiz progress: $e');
      return {
        'total': 0,
        'completed': 0,
        'percentage': 0.0,
        'canUnlockNext': false,
      };
    }
  }

  /// Check if student can unlock the next difficulty level
  /// (All quizzes in current level must be completed)
  Future<bool> canUnlockNextLevel(String studentId, int currentLevel) async {
    if (currentLevel >= 4) return false; // Already at max level

    final progress = await getQuizProgress(studentId, currentLevel);
    return progress['canUnlockNext'] == true;
  }

  /// Check if previous quiz in sequence is completed (for sequential unlocking)
  Future<bool> isPreviousQuizCompleted(
      String studentId, QuizQuestion currentQuiz) async {
    try {
      // If this is the first quiz in the level (order_index = 0), it's always unlocked
      if (currentQuiz.orderIndex == 0) return true;

      // Get all questions for this level
      final allQuestions =
          await getQuizQuestionsByDifficulty(currentQuiz.difficultyLevel);

      // Find previous quiz (orderIndex - 1)
      final previousQuiz = allQuestions.firstWhere(
        (q) => q.orderIndex == currentQuiz.orderIndex - 1,
        orElse: () => currentQuiz, // If not found, allow current
      );

      if (previousQuiz.id == currentQuiz.id) {
        // No previous quiz found, allow current
        return true;
      }

      // Check if previous quiz is completed
      return await isQuizCompleted(studentId, previousQuiz.id);
    } catch (e) {
      print('Error checking previous quiz completion: $e');
      return false;
    }
  }

  /// Get student's overall quiz statistics (historical data from old AI quiz system)
  Future<Map<String, dynamic>> getStatistics(String studentId) async {
    try {
      // Get legacy quiz sessions from old AI system
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
            (sum, s) =>
                sum + ((s['score_percentage'] as num?)?.toDouble() ?? 0.0),
          ) /
          totalSessions;

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

  /// Get highest unlocked difficulty level for student
  Future<int> getHighestUnlockedLevel(String studentId) async {
    // Start from level 1
    int unlockedLevel = 1;

    // Check each level sequentially
    for (int level = 1; level <= 4; level++) {
      if (level == 1) {
        // Level 1 is always unlocked
        unlockedLevel = 1;
        continue;
      }

      // Check if previous level is completed
      final canUnlock = await canUnlockNextLevel(studentId, level - 1);
      if (canUnlock) {
        unlockedLevel = level;
      } else {
        break; // Can't unlock this level, stop checking
      }
    }

    return unlockedLevel;
  }

  /// Check if a specific quiz question is completed by the student
  Future<bool> isQuestionCompleted(String studentId, String questionId) async {
    try {
      final response = await _supabase
          .from('student_quiz_progress')
          .select('completed')
          .eq('student_id', studentId)
          .eq('quiz_question_id', questionId)
          .maybeSingle();

      if (response == null) return false;

      return response['completed'] == true;
    } catch (e) {
      print('Error checking question completion: $e');
      return false;
    }
  }
}
