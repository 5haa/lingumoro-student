import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/quiz_practice_service.dart';
import '../../services/auth_service.dart';
import '../../services/level_service.dart';
import '../../services/points_notification_service.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

class QuizSessionScreen extends StatefulWidget {
  final int studentLevel;

  const QuizSessionScreen({
    super.key,
    required this.studentLevel,
  });

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  final _quizService = QuizPracticeService();
  final _authService = AuthService();
  final _levelService = LevelService();
  final _pointsNotificationService = PointsNotificationService();

  // Quiz state
  List<Map<String, dynamic>> _questions = [];
  List<String?> _studentAnswers = [];
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _isLoading = false;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  bool _showingResult = false;

  // Timer state
  Timer? _questionTimer;
  int _timeRemaining = 15;
  DateTime? _quizStartTime;

  // Results
  int _correctCount = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _generateQuizQuestions();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQuizQuestions() async {
    setState(() => _isLoading = true);

    try {
      final questions = await _quizService.generateQuizSession(
        level: widget.studentLevel,
        language: 'English',
      );

      if (questions != null && questions.isNotEmpty) {
        setState(() {
          _questions = questions;
          _studentAnswers = List.filled(questions.length, null);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).failedToGenerateQuiz),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _quizStartTime = DateTime.now();
      _currentQuestionIndex = 0;
      _selectedOptionIndex = null;
    });
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _timeRemaining = 15;
    _questionTimer?.cancel();
    
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    // Auto-submit with no answer
    _submitAnswer(null);
  }

  void _submitAnswer(String? answer) {
    _questionTimer?.cancel();
    
    setState(() {
      _studentAnswers[_currentQuestionIndex] = answer;
      _showingResult = true;
    });

    // Check if correct
    final correctAnswer = _questions[_currentQuestionIndex]['correct_answer'];
    final isCorrect = answer != null && answer == correctAnswer;

    if (isCorrect) {
      _correctCount++;
      _totalPoints += 5 + (widget.studentLevel ~/ 10);
    }

    // Wait 1.5 seconds to show result, then move to next
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _moveToNextQuestion();
      }
    });
  }

  void _moveToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _showingResult = false;
      });
      _startQuestionTimer();
    } else {
      // Quiz completed
      _completeQuiz();
    }
  }

  Future<void> _completeQuiz() async {
    _questionTimer?.cancel();
    
    final duration = DateTime.now().difference(_quizStartTime!).inSeconds;

    // Save quiz session
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      await _quizService.saveQuizSession(
        studentId: currentUser.id,
        level: widget.studentLevel,
        questions: _questions,
        studentAnswers: _studentAnswers,
        durationSeconds: duration,
      );
      
      // Show points notification if points were earned
      if (_totalPoints > 0 && mounted) {
        final l10n = AppLocalizations.of(context);
        _pointsNotificationService.showPointsEarnedNotification(
          context: context,
          pointsGained: _totalPoints,
          message: '${l10n.quizComplete} +$_totalPoints ${l10n.points} ${l10n.success.toLowerCase()}!',
        );
      }
    }

    setState(() {
      _quizCompleted = true;
      _showingResult = false;
    });
  }

  void _retryQuiz() {
    setState(() {
      _quizStarted = false;
      _quizCompleted = false;
      _currentQuestionIndex = 0;
      _selectedOptionIndex = null;
      _studentAnswers = List.filled(_questions.length, null);
      _correctCount = 0;
      _totalPoints = 0;
      _showingResult = false;
    });
    _generateQuizQuestions();
  }

  Color _getTimerColor() {
    if (_timeRemaining >= 11) return Colors.green;
    if (_timeRemaining >= 6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_quizStarted && !_quizCompleted) {
          final l10n = AppLocalizations.of(context);
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.exitQuiz),
              content: Text(l10n.exitQuizMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.exit, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          return shouldExit ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _quizCompleted
                  ? _buildResultsScreen()
                  : !_quizStarted
                      ? _buildStartScreen()
                      : _buildQuestionScreen(),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9966), Color(0xFFFF6B6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '✏️',
                        style: TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).quizPractice,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppLocalizations.of(context).level} ${widget.studentLevel} • ${_getDifficultyText()}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quiz info cards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: FontAwesomeIcons.clipboardQuestion,
                        label: AppLocalizations.of(context).totalQuestions,
                        value: '10',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: FontAwesomeIcons.clock,
                        label: AppLocalizations.of(context).timePerQuestion,
                        value: '15 sec',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: FontAwesomeIcons.star,
                        label: AppLocalizations.of(context).pointsAvailable,
                        value: '${(5 + (widget.studentLevel ~/ 10)) * 10}',
                        color: Colors.amber,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).quizInstructions,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Start button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _startQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.play, size: 18, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).startQuiz,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionScreen() {
    final question = _questions[_currentQuestionIndex];
    final correctAnswer = question['correct_answer'];

    return Column(
      children: [
        // Header with timer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CustomBackButton(
                onPressed: () async {
                  final l10n = AppLocalizations.of(context);
                  final shouldExit = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.exitQuiz),
                      content: Text(l10n.exitQuizMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.exit, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (shouldExit == true && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(width: 12),
              
              // Question counter
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context).questionNumber} ${_currentQuestionIndex + 1}/10',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              
              // Timer
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _timeRemaining / 15,
                      backgroundColor: AppColors.lightGrey,
                      valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor()),
                      strokeWidth: 5,
                    ),
                    Text(
                      '$_timeRemaining',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getTimerColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      if (question['topic'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9966), Color(0xFFFF6B6B)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            question['topic'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        question['question'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Options
                ...List.generate(
                  question['options'].length,
                  (index) => _buildOptionButton(index, question['options'][index], correctAnswer),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(int index, String option, String correctAnswer) {
    final isSelected = _selectedOptionIndex == index;
    final isCorrect = option == correctAnswer;
    final studentAnswer = _studentAnswers[_currentQuestionIndex];
    final isStudentAnswer = studentAnswer == option;

    Color? backgroundColor;
    Color? borderColor;
    IconData? icon;

    if (_showingResult) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
        icon = FontAwesomeIcons.circleCheck;
      } else if (isStudentAnswer) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        icon = FontAwesomeIcons.circleXmark;
      }
    } else if (isSelected) {
      backgroundColor = AppColors.primary.withOpacity(0.1);
      borderColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showingResult
              ? null
              : () {
                  setState(() {
                    _selectedOptionIndex = index;
                  });
                  _submitAnswer(option);
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor ?? AppColors.border,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor ?? AppColors.background,
                    border: Border.all(
                      color: borderColor ?? AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: borderColor ?? AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: isSelected || _showingResult ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (icon != null)
                  FaIcon(
                    icon,
                    color: borderColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final accuracy = (_correctCount / _questions.length * 100).toInt();
    final isPerfect = _correctCount == _questions.length;
    final isGood = accuracy >= 70;

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPerfect
                          ? [Color(0xFFFFD700), Color(0xFFFFB800)]
                          : isGood
                              ? [Color(0xFF11998E), Color(0xFF38EF7D)]
                              : [Color(0xFFFF9966), Color(0xFFFF6B6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isPerfect ? '🏆' : isGood ? '🎉' : '💪',
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).quizComplete,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '$_correctCount/10',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$accuracy% ${AppLocalizations.of(context).accuracy}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '+$_totalPoints ${AppLocalizations.of(context).points}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Review section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.rate_review,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).reviewAnswers,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_questions.length, (index) {
                        return _buildReviewItem(index);
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).back,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.redGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _retryQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).retryQuiz,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(int index) {
    final question = _questions[index];
    final studentAnswer = _studentAnswers[index];
    final correctAnswer = question['correct_answer'];
    final isCorrect = studentAnswer != null && studentAnswer == correctAnswer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(
                  isCorrect ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q${index + 1}: ${question['question']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isCorrect) ...[
                      Text(
                        studentAnswer != null 
                            ? '${AppLocalizations.of(context).yourAnswer} $studentAnswer'
                            : AppLocalizations.of(context).noAnswerTimeout,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context).correctAnswer} $correctAnswer',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else
                      Text(
                        AppLocalizations.of(context).correct,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCorrect && question['explanation'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question['explanation'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CustomBackButton(onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context).languageQuiz,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FaIcon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getDifficultyText() {
    final l10n = AppLocalizations.of(context);
    if (widget.studentLevel <= 10) return l10n.levelBeginner;
    if (widget.studentLevel <= 25) return l10n.levelElementary;
    if (widget.studentLevel <= 40) return l10n.levelPreIntermediate;
    if (widget.studentLevel <= 60) return l10n.levelIntermediate;
    if (widget.studentLevel <= 80) return l10n.levelUpperIntermediate;
    return l10n.levelAdvanced;
  }
}














