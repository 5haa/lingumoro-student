import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/models/quiz.dart';
import 'package:student/models/quiz_question.dart';
import 'package:student/models/quiz_attempt.dart';
import 'package:student/models/difficulty_level.dart';

class QuizLevelProgressSummary {
  final int total;
  final int completed;

  const QuizLevelProgressSummary({required this.total, required this.completed});

  double get percentage => total <= 0 ? 0.0 : (completed / total * 100.0);
}

class QuizGlobalProgress {
  final Map<int, QuizLevelProgressSummary> progressByLevel;
  final Map<int, bool> unlockedByLevel;
  final Set<String> completedQuizIds;
  final Map<String, double> bestScoreByQuizId;

  const QuizGlobalProgress({
    required this.progressByLevel,
    required this.unlockedByLevel,
    required this.completedQuizIds,
    required this.bestScoreByQuizId,
  });
}

class QuizPracticeService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  final _dailyLimitService = DailyLimitService();

  Future<Map<String, int>> _getActiveQuestionCountsForQuizIds(
      List<String> quizIds) async {
    if (quizIds.isEmpty) return {};

    final response = await _supabase
        .from('quiz_questions')
        .select('quiz_id')
        .inFilter('quiz_id', quizIds)
        .eq('is_active', true);

    final counts = <String, int>{};
    for (final row in (response as List)) {
      final quizId = row['quiz_id'] as String?;
      if (quizId == null) continue;
      counts[quizId] = (counts[quizId] ?? 0) + 1;
    }
    return counts;
  }

  Future<({Set<String> completedQuizIds, Map<String, double> bestScoreByQuizId})>
      _getAttemptSummaryForQuizIds(String studentId, List<String> quizIds) async {
    if (quizIds.isEmpty) {
      return (completedQuizIds: <String>{}, bestScoreByQuizId: <String, double>{});
    }

    final response = await _supabase
        .from('student_quiz_attempts')
        .select('quiz_id, score_percentage')
        .eq('student_id', studentId)
        .inFilter('quiz_id', quizIds);

    final completed = <String>{};
    final bestScore = <String, double>{};
    for (final row in (response as List)) {
      final quizId = row['quiz_id'] as String?;
      if (quizId == null) continue;

      completed.add(quizId);
      final score = (row['score_percentage'] as num?)?.toDouble();
      if (score == null) continue;
      final current = bestScore[quizId];
      if (current == null || score > current) {
        bestScore[quizId] = score;
      }
    }

    return (completedQuizIds: completed, bestScoreByQuizId: bestScore);
  }

  /// Fetch progress/unlock status in a batched way (2 queries total).
  ///
  /// Completion rule: any completed attempt counts as completion.
  Future<QuizGlobalProgress> getQuizGlobalProgress(String studentId) async {
    // 1) Fetch all active quizzes once
    final quizzesResponse = await _supabase
        .from('quizzes')
        .select('id, difficulty_level, order_index')
        .eq('is_active', true)
        .order('difficulty_level', ascending: true)
        .order('order_index', ascending: true);

    final quizzes = (quizzesResponse as List)
        .map((q) => {
              'id': q['id'] as String,
              'difficulty_level': q['difficulty_level'] as int,
              'order_index': q['order_index'] as int,
            })
        .toList();

    final quizIds = quizzes.map((q) => q['id'] as String).toList();

    // 2) Fetch all attempts for those quizzes once
    final attemptSummary = await _getAttemptSummaryForQuizIds(studentId, quizIds);

    // Compute progress by level
    final progressByLevel = <int, QuizLevelProgressSummary>{};
    for (int level = 1; level <= 4; level++) {
      final levelQuizzes =
          quizzes.where((q) => (q['difficulty_level'] as int) == level).toList();
      final total = levelQuizzes.length;
      int completed = 0;
      for (final q in levelQuizzes) {
        final id = q['id'] as String;
        if (attemptSummary.completedQuizIds.contains(id)) completed++;
      }
      progressByLevel[level] =
          QuizLevelProgressSummary(total: total, completed: completed);
    }

    // Compute unlocks by level
    // All levels are now unlocked by default - students can access
    // the first quiz of any level immediately
    final unlockedByLevel = <int, bool>{
      1: true,
      2: true,
      3: true,
      4: true,
    };

    return QuizGlobalProgress(
      progressByLevel: progressByLevel,
      unlockedByLevel: unlockedByLevel,
      completedQuizIds: attemptSummary.completedQuizIds,
      bestScoreByQuizId: attemptSummary.bestScoreByQuizId,
    );
  }

  /// Get all quizzes for a specific difficulty level
  Future<List<Quiz>> getQuizzesByDifficulty(int difficultyLevel) async {
    try {
      final response = await _supabase
          .from('quizzes')
          .select('*')
          .eq('difficulty_level', difficultyLevel)
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final quizzes = (response as List)
          .map((json) => Quiz.fromJson(json))
          .toList();

      return quizzes;
    } catch (e) {
      print('Error fetching quizzes: $e');
      return [];
    }
  }

  /// Get all questions for a specific quiz
  Future<List<QuizQuestion>> getQuizQuestions(String quizId) async {
    try {
      final response = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('quiz_id', quizId)
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

  /// Get student's progress for a specific quiz (best attempt)
  Future<QuizAttempt?> getQuizBestAttempt(String studentId, String quizId) async {
    try {
      final response = await _supabase
          .from('student_quiz_attempts')
          .select('*')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .order('score_percentage', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Fetch answers for this attempt
      final answersResponse = await _supabase
          .from('quiz_attempt_answers')
          .select('''
            *,
            quiz_questions:quiz_question_id (
              question_text,
              options,
              correct_option_index,
              explanation
            )
          ''')
          .eq('attempt_id', response['id']);

      final answers = (answersResponse as List).map((a) {
        final questionData = a['quiz_questions'];
        return QuizAttemptAnswer(
          id: a['id'],
          attemptId: a['attempt_id'],
          quizQuestionId: a['quiz_question_id'],
          studentAnswerIndex: a['student_answer_index'],
          isCorrect: a['is_correct'],
          pointsEarned: a['points_earned'],
          createdAt: DateTime.parse(a['created_at']),
          questionText: questionData['question_text'],
          options: List<String>.from(questionData['options'] is String 
              ? [] 
              : questionData['options']),
          correctOptionIndex: questionData['correct_option_index'],
          explanation: questionData['explanation'],
        );
      }).toList();

      response['answers'] = answers;
      return QuizAttempt.fromJson(response);
    } catch (e) {
      print('Error fetching quiz best attempt: $e');
      return null;
    }
  }

  /// Get student's most recent attempt for a quiz
  Future<QuizAttempt?> getQuizLatestAttempt(String studentId, String quizId) async {
    try {
      final response = await _supabase
          .from('student_quiz_attempts')
          .select('*')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Fetch answers for this attempt
      final answersResponse = await _supabase
          .from('quiz_attempt_answers')
          .select('''
            *,
            quiz_questions:quiz_question_id (
              question_text,
              options,
              correct_option_index,
              explanation
            )
          ''')
          .eq('attempt_id', response['id']);

      final answers = (answersResponse as List).map((a) {
        final questionData = a['quiz_questions'];
        return QuizAttemptAnswer(
          id: a['id'],
          attemptId: a['attempt_id'],
          quizQuestionId: a['quiz_question_id'],
          studentAnswerIndex: a['student_answer_index'],
          isCorrect: a['is_correct'],
          pointsEarned: a['points_earned'],
          createdAt: DateTime.parse(a['created_at']),
          questionText: questionData['question_text'],
          options: List<String>.from(questionData['options'] is String 
              ? [] 
              : questionData['options']),
          correctOptionIndex: questionData['correct_option_index'],
          explanation: questionData['explanation'],
        );
      }).toList();

      response['answers'] = answers;
      return QuizAttempt.fromJson(response);
    } catch (e) {
      print('Error fetching quiz latest attempt: $e');
      return null;
    }
  }

  /// Check if student has completed a quiz at least once
  Future<bool> hasCompletedQuiz(String studentId, String quizId) async {
    try {
      final response = await _supabase
          .from('student_quiz_attempts')
          .select('id')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking quiz completion: $e');
      return false;
    }
  }

  /// Check if a difficulty level is unlocked for a student
  /// Level 1 is always unlocked
  /// Higher levels require ALL quizzes in previous level to be completed
  Future<bool> isDifficultyLevelUnlocked(String studentId, int difficultyLevel) async {
    try {
      // Level 1 is always unlocked
      if (difficultyLevel == 1) return true;

      final global = await getQuizGlobalProgress(studentId);
      return global.unlockedByLevel[difficultyLevel] == true;
    } catch (e) {
      print('Error checking difficulty level unlock: $e');
      return false;
    }
  }

  /// Get next unlocked quiz for a student in a difficulty level
  Future<Quiz?> getNextUnlockedQuiz(String studentId, int difficultyLevel) async {
    try {
      // Get all quizzes for this level
      final quizzes = await getQuizzesByDifficulty(difficultyLevel);
      
      if (quizzes.isEmpty) return null;

      // Sequential unlocking: find first incomplete quiz
      for (var quiz in quizzes) {
        final hasCompleted = await hasCompletedQuiz(studentId, quiz.id);
        if (!hasCompleted) {
          return quiz;
        }
      }

      // All quizzes completed, return first quiz (for retakes)
      return quizzes.first;
    } catch (e) {
      print('Error getting next unlocked quiz: $e');
      return null;
    }
  }

  /// Get quizzes with progress information for a difficulty level
  Future<List<Quiz>> getQuizzesWithProgress(
      String studentId, int difficultyLevel) async {
    try {
      // Fetch quizzes for level (1 query)
      final quizzes = await getQuizzesByDifficulty(difficultyLevel);
      if (quizzes.isEmpty) return [];

      final global = await getQuizGlobalProgress(studentId);
      final isLevelUnlocked = global.unlockedByLevel[difficultyLevel] == true;

      // Batch question counts and attempts for these quizzes (2 queries)
      final quizIds = quizzes.map((q) => q.id).toList();
      final questionCounts = await _getActiveQuestionCountsForQuizIds(quizIds);

      for (int i = 0; i < quizzes.length; i++) {
        final quiz = quizzes[i];

        quiz.totalQuestions = questionCounts[quiz.id] ?? 0;

        final isCompleted = global.completedQuizIds.contains(quiz.id);
        quiz.isCompleted = isCompleted;
        quiz.bestScore = global.bestScoreByQuizId[quiz.id];

        if (!isLevelUnlocked) {
          quiz.isLocked = true;
        } else if (i == 0) {
          quiz.isLocked = false;
        } else {
          final previousQuiz = quizzes[i - 1];
          final previousCompleted = global.completedQuizIds.contains(previousQuiz.id);
          quiz.isLocked = !previousCompleted;
        }
      }

      return quizzes;
    } catch (e) {
      print('Error fetching quizzes with progress: $e');
      return [];
    }
  }

  /// Same as [getQuizzesWithProgress] but reuses a pre-fetched [QuizGlobalProgress]
  /// to avoid re-querying attempts/unlocks.
  Future<List<Quiz>> getQuizzesWithProgressUsingGlobal(
    String studentId,
    int difficultyLevel,
    QuizGlobalProgress global,
  ) async {
    try {
      final quizzes = await getQuizzesByDifficulty(difficultyLevel);
      if (quizzes.isEmpty) return [];

      final isLevelUnlocked = global.unlockedByLevel[difficultyLevel] == true;
      final quizIds = quizzes.map((q) => q.id).toList();
      final questionCounts = await _getActiveQuestionCountsForQuizIds(quizIds);

      for (int i = 0; i < quizzes.length; i++) {
        final quiz = quizzes[i];

        quiz.totalQuestions = questionCounts[quiz.id] ?? 0;
        quiz.isCompleted = global.completedQuizIds.contains(quiz.id);
        quiz.bestScore = global.bestScoreByQuizId[quiz.id];

        if (!isLevelUnlocked) {
          quiz.isLocked = true;
        } else if (i == 0) {
          quiz.isLocked = false;
        } else {
          final previousQuiz = quizzes[i - 1];
          quiz.isLocked = !global.completedQuizIds.contains(previousQuiz.id);
        }
      }

      return quizzes;
    } catch (e) {
      print('Error fetching quizzes with progress (using global): $e');
      return [];
    }
  }

  /// Get set of question IDs that student has ever answered correctly
  Future<Set<String>> _getPreviouslyCorrectQuestionIds(
      String studentId, String quizId) async {
    try {
      // Get all previous attempts for this quiz
      final previousAttempts = await _supabase
          .from('student_quiz_attempts')
          .select('id')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId);

      if (previousAttempts.isEmpty) {
        return {};
      }

      // Get attempt IDs
      final attemptIds = (previousAttempts as List)
          .map((a) => a['id'] as String)
          .toList();

      // Get all previously correct answers
      final correctAnswers = await _supabase
          .from('quiz_attempt_answers')
          .select('quiz_question_id')
          .inFilter('attempt_id', attemptIds)
          .eq('is_correct', true);

      // Return set of question IDs
      return (correctAnswers as List)
          .map((a) => a['quiz_question_id'] as String)
          .toSet();
    } catch (e) {
      print('Error getting previously correct questions: $e');
      return {};
    }
  }

  /// Submit a complete quiz attempt
  Future<String?> submitQuizAttempt({
    required String studentId,
    required String quizId,
    required List<QuizAttemptAnswer> answers,
    required int durationSeconds,
  }) async {
    try {
      // If this quiz was ever attempted before, do NOT award points again.
      final existingAttempt = await _supabase
          .from('student_quiz_attempts')
          .select('id')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .limit(1)
          .maybeSingle();

      final isFirstAttemptForQuiz = existingAttempt == null;

      final correctCount = answers.where((a) => a.isCorrect).length;
      int actualPointsToAward = 0;
      
      // Create a map to track actual points for each answer
      final Map<String, int> actualPointsPerAnswer = {};

      if (isFirstAttemptForQuiz) {
        // Award points for correct answers only on first attempt.
        for (var answer in answers) {
          if (answer.isCorrect) {
            actualPointsPerAnswer[answer.quizQuestionId] = answer.pointsEarned;
            actualPointsToAward += answer.pointsEarned;
          } else {
            actualPointsPerAnswer[answer.quizQuestionId] = 0;
          }
        }
        print('🆕 First attempt for quiz: awarding $actualPointsToAward points');
      } else {
        // Retake: always 0 points.
        for (var answer in answers) {
          actualPointsPerAnswer[answer.quizQuestionId] = 0;
        }
        actualPointsToAward = 0;
        print('🔁 Retake for quiz: awarding 0 points');
      }

      final scorePercentage = (correctCount / answers.length * 100).toDouble();

      print('💰 Total points to award: $actualPointsToAward');

      // Insert quiz attempt
      final attemptResponse = await _supabase
          .from('student_quiz_attempts')
          .insert({
            'student_id': studentId,
            'quiz_id': quizId,
            'score_percentage': scorePercentage,
            'total_questions': answers.length,
            'correct_answers': correctCount,
            'total_points_earned': actualPointsToAward,
            'completed_at': DateTime.now().toIso8601String(),
            'duration_seconds': durationSeconds,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final attemptId = attemptResponse['id'] as String;

      // Insert all answers (with adjusted points_earned values from the map)
      final answerInserts = answers.map((answer) => {
        'attempt_id': attemptId,
        'quiz_question_id': answer.quizQuestionId,
        'student_answer_index': answer.studentAnswerIndex,
        'is_correct': answer.isCorrect,
        'points_earned': actualPointsPerAnswer[answer.quizQuestionId] ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await _supabase
          .from('quiz_attempt_answers')
          .insert(answerInserts);

      // Award points to student (only new points)
      if (actualPointsToAward > 0) {
        await _levelService.awardPoints(studentId, actualPointsToAward);
        print('🎉 Awarded $actualPointsToAward points to student');
      } else {
        print('ℹ️ No new points awarded (all questions previously correct)');
      }

      // Record daily limit with attempt ID
      await _dailyLimitService.recordPracticeCompletion(
          studentId, DailyLimitService.practiceTypeQuiz, attemptId: attemptId);

      return attemptId;
    } catch (e) {
      print('Error submitting quiz attempt: $e');
      rethrow;
    }
  }

  /// Check if student can attempt a quiz today (daily limit)
  Future<bool> canAttemptQuizToday(String studentId) async {
    try {
      return await _dailyLimitService.checkDailyLimit(
          studentId, DailyLimitService.practiceTypeQuiz);
    } catch (e) {
      print('Error checking daily limit: $e');
      return false;
    }
  }

  /// Get quiz statistics for a student
  Future<Map<String, dynamic>> getQuizStatistics(String studentId) async {
    try {
      final response = await _supabase
          .from('student_quiz_attempts')
          .select('score_percentage, total_questions, correct_answers')
          .eq('student_id', studentId);

      final attempts = response as List;
      
      if (attempts.isEmpty) {
        return {
          'total_attempts': 0,
          'average_score': 0.0,
          'best_score': 0.0,
          'total_questions_answered': 0,
          'total_correct_answers': 0,
        };
      }

      final totalAttempts = attempts.length;
      final averageScore = attempts.fold<double>(
        0.0,
        (sum, a) => sum + (a['score_percentage'] as num).toDouble()
      ) / totalAttempts;
      
      final bestScore = attempts.fold<double>(
        0.0,
        (max, a) {
          final score = (a['score_percentage'] as num).toDouble();
          return score > max ? score : max;
        }
      );

      final totalQuestions = attempts.fold<int>(
        0,
        (sum, a) => sum + (a['total_questions'] as int)
      );

      final totalCorrect = attempts.fold<int>(
        0,
        (sum, a) => sum + (a['correct_answers'] as int)
      );

      return {
        'total_attempts': totalAttempts,
        'average_score': averageScore,
        'best_score': bestScore,
        'total_questions_answered': totalQuestions,
        'total_correct_answers': totalCorrect,
        'accuracy': totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0.0,
      };
    } catch (e) {
      print('Error getting quiz statistics: $e');
      return {
        'total_attempts': 0,
        'average_score': 0.0,
        'best_score': 0.0,
        'total_questions_answered': 0,
        'total_correct_answers': 0,
        'accuracy': 0.0,
      };
    }
  }

  /// Get all attempts for a specific quiz (for history)
  Future<List<QuizAttempt>> getQuizAttemptHistory(
      String studentId, String quizId) async {
    try {
      final response = await _supabase
          .from('student_quiz_attempts')
          .select('*')
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .order('completed_at', ascending: false);

      return (response as List)
          .map((json) => QuizAttempt.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching quiz attempt history: $e');
      return [];
    }
  }

  /// Legacy method - kept for backward compatibility
  /// Returns quizzes instead of individual questions
  @Deprecated('Use getQuizzesByDifficulty instead')
  Future<List<QuizQuestion>> getQuizQuestionsByDifficulty(
      int difficultyLevel) async {
    // This method is deprecated but kept for compatibility
    // It will return questions from all quizzes in the difficulty level
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
}
