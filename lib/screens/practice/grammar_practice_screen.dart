import 'package:flutter/material.dart';
import 'package:student/services/grammar_practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';

class GrammarPracticeScreen extends StatefulWidget {
  const GrammarPracticeScreen({super.key});

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  final _grammarService = GrammarPracticeService();
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
          _errorMessage = 'Please log in to access grammar practice';
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
      final stats = await _grammarService.getStatistics(_studentId!);
      
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
        final questions = await _grammarService.generateQuestions(
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
    await _grammarService.saveResult(
      studentId: _studentId!,
      level: _studentLevel,
      question: _currentQuestion!['question'],
      options: List<String>.from(_currentQuestion!['options']),
      correctAnswer: correctAnswer,
      studentAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );

    // Update statistics
    final stats = await _grammarService.getStatistics(_studentId!);

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
        title: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(isCorrect ? 'Correct!' : 'Incorrect'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCorrect) ...[
              Text(
                'Well done! You earned $pointsEarned points.',
                style: const TextStyle(fontSize: 16),
              ),
            ] else ...[
              Text(
                'The correct answer is:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
            child: const Text('Next Question'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_hasProSubscription) {
      return _buildProRequiredMessage();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grammar Practice',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Level: $_studentLevel',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Practice grammar with AI-generated questions tailored to your level',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  _statistics['total_questions'].toString(),
                  Icons.quiz,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Correct',
                  _statistics['correct_answers'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  'Accuracy',
                  '${_statistics['accuracy'].toStringAsFixed(0)}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Points',
                  _statistics['total_points_earned'].toString(),
                  Icons.star,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _generateNewQuestion,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Practice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Generating question...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentQuestion!['grammar_topic'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentQuestion!['grammar_topic'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Explanation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentQuestion!['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
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
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Answer'),
              )
            else
              ElevatedButton.icon(
                onPressed: _generateNewQuestion,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
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
        textColor = Colors.green[800];
      } else if (isSelected) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        textColor = Colors.red[800];
      }
    } else if (isSelected) {
      backgroundColor = Colors.deepPurple.withOpacity(0.1);
      borderColor = Colors.deepPurple;
      textColor = Colors.deepPurple[800];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            color: backgroundColor ?? Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? Colors.grey.withOpacity(0.3),
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
                  color: (backgroundColor ?? Colors.white),
                  border: Border.all(
                    color: borderColor ?? Colors.grey.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Colors.grey[700],
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
                    color: textColor ?? Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (_answerSubmitted && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
              if (_answerSubmitted && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 24),
            ],
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
            const Icon(
              Icons.lock,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'PRO Subscription Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Grammar practice is available for PRO members only.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('Upgrade to PRO'),
            ),
          ],
        ),
      ),
    );
  }
}

