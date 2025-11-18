import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class QuizPracticeScreen extends StatefulWidget {
  const QuizPracticeScreen({super.key});

  @override
  State<QuizPracticeScreen> createState() => _QuizPracticeScreenState();
}

class _QuizPracticeScreenState extends State<QuizPracticeScreen> {
  final _quizService = QuizPracticeService();
  final _authService = AuthService();
  final _levelService = LevelService();
  final _proService = ProSubscriptionService();

  bool _isLoading = false;
  bool _isGenerating = false;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  int _studentLevel = 1;
  
  Map<String, dynamic>? _currentQuestion;
  int? _selectedOptionIndex;
  bool _answerSubmitted = false;
  bool _showExplanation = false;
  
  // Question cache for batch generation
  List<Map<String, dynamic>> _questionCache = [];
  int _currentQuestionIndex = 0;
  static const int _batchSize = 5; // Generate 5 questions at a time
  
  Map<String, dynamic> _statistics = {
    'total_questions': 0,
    'correct_answers': 0,
    'incorrect_answers': 0,
    'accuracy': 0.0,
    'total_points_earned': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current student ID
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to access quiz practice';
        });
        return;
      }

      _studentId = user.id;

      // Check PRO subscription
      final hasPro = await _proService.hasActivePro(_studentId!);
      if (!hasPro) {
        setState(() {
          _isLoading = false;
          _hasProSubscription = false;
          _errorMessage = 'PRO subscription required';
        });
        return;
      }

      setState(() {
        _hasProSubscription = true;
      });

      // Get student level
      final progress = await _levelService.getStudentProgress(_studentId!);
      _studentLevel = progress['level'] ?? 1;

      // Get statistics
      final stats = await _quizService.getStatistics(_studentId!);
      
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _generateNewQuestion() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _currentQuestion = null;
      _selectedOptionIndex = null;
      _answerSubmitted = false;
      _showExplanation = false;
    });

    try {
      // Check if we need to generate a new batch
      if (_questionCache.isEmpty || _currentQuestionIndex >= _questionCache.length) {
        // Generate a batch of questions
        final questions = await _quizService.generateQuestions(
          level: _studentLevel,
          count: _batchSize,
          language: 'English',
        );

        if (questions != null && questions.isNotEmpty) {
          setState(() {
            _questionCache = questions;
            _currentQuestionIndex = 0;
            _currentQuestion = _questionCache[0];
            _isGenerating = false;
          });
        } else {
          setState(() {
            _isGenerating = false;
            _errorMessage = 'Failed to generate questions. Please try again.';
          });
        }
      } else {
        // Use next question from cache
        setState(() {
          _currentQuestion = _questionCache[_currentQuestionIndex];
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _submitAnswer() async {
    if (_selectedOptionIndex == null || _currentQuestion == null) return;

    final selectedAnswer = _currentQuestion!['options'][_selectedOptionIndex!];
    final correctAnswer = _currentQuestion!['correct_answer'];
    final isCorrect = selectedAnswer == correctAnswer;

    // Save result
    await _quizService.saveResult(
      studentId: _studentId!,
      level: _studentLevel,
      question: _currentQuestion!['question'],
      options: List<String>.from(_currentQuestion!['options']),
      correctAnswer: correctAnswer,
      studentAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );

    // Update statistics
    final stats = await _quizService.getStatistics(_studentId!);

    setState(() {
      _answerSubmitted = true;
      _showExplanation = true;
      _statistics = stats;
    });

    // Move to next question in cache
    _currentQuestionIndex++;
    
    // Show result dialog
    if (mounted) {
      _showResultDialog(isCorrect);
    }
  }

  void _showResultDialog(bool isCorrect) {
    final pointsEarned = isCorrect ? (5 + (_studentLevel ~/ 10)) : 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            FaIcon(
              isCorrect ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
              color: isCorrect ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              isCorrect ? 'Correct!' : 'Incorrect',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCorrect) ...[
              Text(
                'Well done! You earned $pointsEarned points.',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ] else ...[
              const Text(
                'The correct answer is:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentQuestion!['correct_answer'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _currentQuestion!['explanation'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateNewQuestion();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Next Question',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),
            
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : !_hasProSubscription
                      ? _buildProRequiredMessage()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 20),
                              _buildStatisticsCard(),
                              const SizedBox(height: 20),
                              if (_currentQuestion == null && !_isGenerating)
                                _buildStartButton()
                              else if (_isGenerating)
                                _buildLoadingState()
                              else
                                _buildQuestionCard(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back Icon
          const CustomBackButton(),
          
          const Expanded(
            child: Center(
              child: Text(
                'LANGUAGE QUIZ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          
          // Placeholder for right side (to keep centered)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade400.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.penToSquare,
                  size: 24,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language Quiz',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Practice vocabulary, grammar & more',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.star, size: 14, color: Colors.purple.shade700),
                const SizedBox(width: 6),
                Text(
                  'Level $_studentLevel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                _statistics['total_questions'].toString(),
                FontAwesomeIcons.clipboardQuestion,
                Colors.blue.shade400,
              ),
              _buildStatItem(
                'Correct',
                _statistics['correct_answers'].toString(),
                FontAwesomeIcons.circleCheck,
                Colors.green.shade400,
              ),
              _buildStatItem(
                'Accuracy',
                '${_statistics['accuracy'].toStringAsFixed(0)}%',
                FontAwesomeIcons.chartLine,
                Colors.orange.shade400,
              ),
              _buildStatItem(
                'Points',
                _statistics['total_points_earned'].toString(),
                FontAwesomeIcons.star,
                Colors.amber.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        FaIcon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _generateNewQuestion,
          icon: const FaIcon(FontAwesomeIcons.play, size: 18),
          label: const Text(
            'Start Practice',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Generating question...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentQuestion!['topic'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                _currentQuestion!['topic'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _currentQuestion!['question'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            _currentQuestion!['options'].length,
            (index) => _buildOptionButton(index),
          ),
          if (_showExplanation) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(FontAwesomeIcons.lightbulb, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Explanation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentQuestion!['explanation'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!_answerSubmitted)
            ElevatedButton(
              onPressed: _selectedOptionIndex != null ? _submitAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit Answer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _generateNewQuestion,
              icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
              label: const Text('Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index) {
    final option = _currentQuestion!['options'][index];
    final isSelected = _selectedOptionIndex == index;
    final isCorrect = option == _currentQuestion!['correct_answer'];
    
    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;
    
    if (_answerSubmitted) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
      } else if (isSelected) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
      }
    } else if (isSelected) {
      backgroundColor = AppColors.primary.withOpacity(0.1);
      borderColor = AppColors.primary;
      textColor = AppColors.primaryDark;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answerSubmitted ? null : () {
            setState(() {
              _selectedOptionIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.lightGrey,
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
                    color: backgroundColor ?? AppColors.white,
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
                        color: textColor ?? AppColors.textSecondary,
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
                      color: textColor ?? AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (_answerSubmitted && isCorrect)
                  FaIcon(FontAwesomeIcons.circleCheck, color: Colors.green, size: 20),
                if (_answerSubmitted && isSelected && !isCorrect)
                  FaIcon(FontAwesomeIcons.circleXmark, color: Colors.red, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProRequiredMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.crown,
                size: 64,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PRO Subscription Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Language Quiz is available for PRO members only.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const FaIcon(FontAwesomeIcons.crown, size: 16),
              label: const Text('Upgrade to PRO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

