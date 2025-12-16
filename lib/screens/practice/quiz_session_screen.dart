import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/models/quiz.dart';
import 'package:student/models/quiz_question.dart';
import 'package:student/models/quiz_attempt.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/practice/quiz_results_screen.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

class QuizSessionScreen extends StatefulWidget {
  final Quiz quiz;
  final String studentId;

  const QuizSessionScreen({
    super.key,
    required this.quiz,
    required this.studentId,
  });

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  final _quizService = QuizPracticeService();

  bool _isLoading = true;
  List<QuizQuestion> _questions = [];
  List<int?> _selectedAnswers = [];
  int _currentQuestionIndex = 0;
  DateTime? _quizStartTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _quizStartTime = DateTime.now();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    try {
      final questions = await _quizService.getQuizQuestions(widget.quiz.id);

      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This quiz has no questions yet.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _questions = questions;
        _selectedAnswers = List.filled(questions.length, null);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading questions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    // Check if all questions answered
    final unansweredCount = _selectedAnswers.where((a) => a == null).length;
    if (unansweredCount > 0) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unanswered Questions'),
          content: Text(
            'You have $unansweredCount unanswered question(s). Submit anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Calculate duration
      final duration = DateTime.now().difference(_quizStartTime!);
      final durationSeconds = duration.inSeconds;

      // Prepare answers
      final answers = <QuizAttemptAnswer>[];
      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final selectedAnswer = _selectedAnswers[i];
        final isCorrect = selectedAnswer != null &&
            question.isAnswerCorrect(selectedAnswer);

        answers.add(QuizAttemptAnswer(
          quizQuestionId: question.id,
          studentAnswerIndex: selectedAnswer,
          isCorrect: isCorrect,
          pointsEarned: isCorrect ? question.pointsReward : 0,
          questionText: question.questionText,
          options: question.options,
          correctOptionIndex: question.correctOptionIndex,
          explanation: question.explanation,
        ));
      }

      // Submit attempt
      final attemptId = await _quizService.submitQuizAttempt(
        studentId: widget.studentId,
        quizId: widget.quiz.id,
        answers: answers,
        durationSeconds: durationSeconds,
      );

      if (attemptId != null && mounted) {
        // Navigate to results screen
        final result = await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultsScreen(
              quiz: widget.quiz,
              attempt: QuizAttempt(
                id: attemptId,
                quizId: widget.quiz.id,
                studentId: widget.studentId,
                scorePercentage: (answers.where((a) => a.isCorrect).length /
                        answers.length *
                        100),
                totalQuestions: answers.length,
                correctAnswers: answers.where((a) => a.isCorrect).length,
                totalPointsEarned: answers.fold<int>(
                    0, (sum, a) => sum + a.pointsEarned),
                completedAt: DateTime.now(),
                durationSeconds: durationSeconds,
                answers: answers,
              ),
            ),
          ),
        );

        // Return to quiz list
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quiz: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final answeredCount = _selectedAnswers.where((a) => a != null).length;

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Quiz?'),
            content: const Text(
              'Your progress will be lost if you exit now.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProgressBar(progress, answeredCount),
              
              Expanded(
                child: _isSubmitting
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                            SizedBox(height: 16),
                            Text('Submitting your answers...'),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildQuestionCard(currentQuestion, selectedAnswer),
                      ),
              ),
              
              _buildNavigationBar(answeredCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CustomBackButton(),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    widget.quiz.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, int answeredCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Answered: $answeredCount/${_questions.length}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question, int? selectedAnswer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Question ${_currentQuestionIndex + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            question.options.length,
            (index) => _buildOptionButton(index, question.options[index],
                selectedAnswer == index),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, String option, bool isSelected) {
    final label = String.fromCharCode(65 + index); // A, B, C, D

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(int answeredCount) {
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedAnswers[_currentQuestionIndex] == null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Select an answer before continuing',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousQuestion,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: _currentQuestionIndex > 0 ? 2 : 1,
                child: ElevatedButton(
                  onPressed: isLastQuestion ? _submitQuiz : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isLastQuestion ? 'Submit Quiz' : 'Next Question',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
