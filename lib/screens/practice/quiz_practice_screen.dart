import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/models/difficulty_level.dart';
import 'package:student/models/quiz_question.dart';
import 'package:student/config/app_colors.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

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
  final _dailyLimitService = DailyLimitService();

  bool _isLoading = true;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  int _selectedDifficulty = 1;
  int _highestUnlockedLevel = 1;
  bool _canAttemptToday = true;
  String _timeUntilReset = '';
  
  Map<int, Map<String, dynamic>> _progressByLevel = {};
  List<QuizQuestion> _currentLevelQuestions = [];
  Set<String> _completedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startResetTimer();
  }

  void _startResetTimer() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 60));
      if (mounted) {
        setState(() {
          _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
        });
      }
      return mounted;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.loginRequired;
          });
        }
        return;
      }

      _studentId = user.id;

      // Check PRO subscription
      final hasPro = await _proService.hasActivePro(_studentId!);
      if (!hasPro) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(() {
            _isLoading = false;
            _hasProSubscription = false;
            _errorMessage = l10n.proSubscriptionRequired;
          });
        }
        return;
      }

      setState(() => _hasProSubscription = true);

      // Load data
      await Future.wait([
        _loadHighestUnlockedLevel(),
        _loadProgressForAllLevels(),
        _checkDailyLimit(),
      ]);

      await _loadQuestionsForLevel(_selectedDifficulty);

      setState(() {
        _isLoading = false;
        _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isLoading = false;
          _errorMessage = '${l10n.errorLoadingData}: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadHighestUnlockedLevel() async {
    final level = await _quizService.getHighestUnlockedLevel(_studentId!);
    setState(() {
      _highestUnlockedLevel = level;
    });
  }

  Future<void> _loadProgressForAllLevels() async {
    for (int level = 1; level <= 4; level++) {
      final progress = await _quizService.getQuizProgress(_studentId!, level);
      _progressByLevel[level] = progress;
    }
    setState(() {});
  }

  Future<void> _checkDailyLimit() async {
    final canAttempt = await _quizService.canAttemptQuiz(_studentId!);
    setState(() {
      _canAttemptToday = canAttempt;
    });
  }

  Future<void> _loadQuestionsForLevel(int level) async {
    final questions = await _quizService.getQuizQuestionsByDifficulty(level);
    
    // Load completion status for all questions
    _completedQuestionIds.clear();
    for (final question in questions) {
      final isCompleted = await _quizService.isQuestionCompleted(_studentId!, question.id);
      if (isCompleted) {
        _completedQuestionIds.add(question.id);
      }
    }
    
    setState(() {
      _currentLevelQuestions = questions;
    });
  }

  void _onDifficultyChanged(int level) async {
    setState(() {
      _selectedDifficulty = level;
      _isLoading = true;
    });
    await _loadQuestionsForLevel(level);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _startQuiz(QuizQuestion question) async {
    final l10n = AppLocalizations.of(context);

    // Check daily limit
    if (!_canAttemptToday) {
      _showErrorDialog('You have already completed your quiz for today. Come back tomorrow!');
      return;
    }

    // Navigate to quiz question screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizQuestionScreen(
          question: question,
          studentId: _studentId!,
          difficultyLevel: _selectedDifficulty,
        ),
      ),
    );

    // Reload data after completing question
    if (result == true) {
      _loadInitialData();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n),
            
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : !_hasProSubscription
                      ? _buildProRequiredMessage(l10n)
                      : RefreshIndicator(
                          onRefresh: _loadInitialData,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(l10n),
                                const SizedBox(height: 20),
                                _buildDailyLimitCard(l10n),
                                const SizedBox(height: 20),
                                _buildDifficultySelector(l10n),
                                const SizedBox(height: 20),
                                _buildProgressCard(l10n),
                                const SizedBox(height: 20),
                                _buildQuestionsList(l10n),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CustomBackButton(),
          Expanded(
            child: Center(
              child: Text(
                l10n.languageQuiz,
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

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9966), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('✏️', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quizPractice,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manual Quiz Questions • 4 Levels',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canAttemptToday ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canAttemptToday ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _canAttemptToday ? Icons.check_circle : Icons.timer,
            color: _canAttemptToday ? Colors.green.shade700 : Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _canAttemptToday ? 'Quiz Available Today' : 'Daily Limit Reached',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _canAttemptToday ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _canAttemptToday
                      ? 'You can complete 1 quiz today'
                      : 'Resets in $_timeUntilReset',
                  style: TextStyle(
                    fontSize: 13,
                    color: _canAttemptToday ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Difficulty Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: DifficultyLevel.values.map((level) {
            final isSelected = level.value == _selectedDifficulty;
            final isLocked = level.value > _highestUnlockedLevel;
            
            return Expanded(
              child: GestureDetector(
                onTap: isLocked ? null : () => _onDifficultyChanged(level.value),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.shade200
                        : isSelected
                            ? AppColors.primary
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.grey.shade300
                          : isSelected
                              ? AppColors.primary
                              : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (isLocked)
                        Icon(Icons.lock, size: 16, color: Colors.grey.shade600)
                      else
                        Text(
                          '${level.value}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        level.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLocked
                              ? Colors.grey.shade600
                              : isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProgressCard(AppLocalizations l10n) {
    final progress = _progressByLevel[_selectedDifficulty];
    final total = progress?['total'] ?? 0;
    final completed = progress?['completed'] ?? 0;
    final percentage = progress?['percentage'] ?? 0.0;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level $_selectedDifficulty Progress',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(0)}% Complete',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (completed == total && total > 0 && !DifficultyLevel.fromValue(_selectedDifficulty).isLastLevel)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Level completed! Next level unlocked.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(AppLocalizations l10n) {
    if (_currentLevelQuestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No questions available for this level yet.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quiz Questions (${_currentLevelQuestions.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _currentLevelQuestions.length,
          (index) => _buildQuestionCard(_currentLevelQuestions[index], index, l10n),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QuizQuestion question, int index, AppLocalizations l10n) {
    // Check if completed
    final isCompleted = _isQuestionCompleted(question.id);
    
    // Check if previous question is completed (for lock state)
    final isLocked = index > 0 && !_isQuestionCompleted(_currentLevelQuestions[index - 1].id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.shade300
              : isLocked
                  ? Colors.grey.shade300
                  : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.shade100
                : isLocked
                    ? Colors.grey.shade200
                    : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.green.shade700)
                : isLocked
                    ? Icon(Icons.lock, color: Colors.grey.shade600, size: 20)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
          ),
        ),
        title: Text(
          question.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.grey.shade600 : AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text(
                '${question.pointsReward} points',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCompleted) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: isLocked
            ? null
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isCompleted ? Colors.grey.shade400 : AppColors.primary,
              ),
        onTap: isLocked || !_canAttemptToday
            ? null
            : () => _startQuiz(question),
      ),
    );
  }

  bool _isQuestionCompleted(String questionId) {
    return _completedQuestionIds.contains(questionId);
  }

  Widget _buildProRequiredMessage(AppLocalizations l10n) {
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
            Text(
              l10n.proSubscriptionRequired,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.languageQuizProOnly,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.goBack),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual quiz question screen
class QuizQuestionScreen extends StatefulWidget {
  final QuizQuestion question;
  final String studentId;
  final int difficultyLevel;

  const QuizQuestionScreen({
    super.key,
    required this.question,
    required this.studentId,
    required this.difficultyLevel,
  });

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> {
  final _quizService = QuizPracticeService();
  int? _selectedAnswer;
  bool _isSubmitted = false;
  bool _isCorrect = false;
  int _pointsAwarded = 0;
  String _explanation = '';

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null) return;

    setState(() {
      _isSubmitted = true;
    });

    try {
      final result = await _quizService.submitQuizAnswer(
        studentId: widget.studentId,
        question: widget.question,
        studentAnswerIndex: _selectedAnswer!,
      );

      setState(() {
        _isCorrect = result['isCorrect'] as bool;
        _pointsAwarded = result['pointsAwarded'] as int;
        _explanation = result['explanation'] as String;
      });

      // Show result dialog after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _showResultDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _isCorrect ? Icons.check_circle : Icons.cancel,
              color: _isCorrect ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(_isCorrect ? 'Correct!' : 'Incorrect'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isCorrect) ...[
              Text(
                'You earned $_pointsAwarded points!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Explanation:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _explanation,
              style: const TextStyle(fontSize: 14),
            ),
            if (!_isCorrect) ...[
              const SizedBox(height: 12),
              Text(
                'Correct answer: ${widget.question.correctAnswer}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Go back to quiz list with success
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Question ${widget.question.orderIndex + 1}'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Question
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
              child: Text(
                widget.question.questionText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Options
            ...List.generate(
              widget.question.options.length,
              (index) => _buildOptionCard(index),
            ),

            const SizedBox(height: 24),

            // Submit button
            if (!_isSubmitted)
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != null ? _submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(int index) {
    final isSelected = _selectedAnswer == index;
    final option = widget.question.options[index];

    Color borderColor = AppColors.border;
    Color backgroundColor = AppColors.white;

    if (_isSubmitted) {
      if (index == widget.question.correctOptionIndex) {
        borderColor = Colors.green.shade400;
        backgroundColor = Colors.green.shade50;
      } else if (isSelected) {
        borderColor = Colors.red.shade400;
        backgroundColor = Colors.red.shade50;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primary.withOpacity(0.05);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isSubmitted
                ? (index == widget.question.correctOptionIndex
                    ? Colors.green
                    : isSelected
                        ? Colors.red
                        : Colors.grey.shade300)
                : isSelected
                    ? AppColors.primary
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              String.fromCharCode(65 + index), // A, B, C, D
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isSubmitted
                    ? (index == widget.question.correctOptionIndex || isSelected
                        ? Colors.white
                        : Colors.grey.shade600)
                    : isSelected
                        ? Colors.white
                        : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        title: Text(
          option,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _isSubmitted && (index == widget.question.correctOptionIndex || isSelected)
                ? Colors.black87
                : AppColors.textPrimary,
          ),
        ),
        trailing: _isSubmitted
            ? Icon(
                index == widget.question.correctOptionIndex
                    ? Icons.check_circle
                    : isSelected
                        ? Icons.cancel
                        : null,
                color: index == widget.question.correctOptionIndex
                    ? Colors.green
                    : Colors.red,
              )
            : null,
        onTap: _isSubmitted
            ? null
            : () {
                setState(() {
                  _selectedAnswer = index;
                });
              },
      ),
    );
  }
}
