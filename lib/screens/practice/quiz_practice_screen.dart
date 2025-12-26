import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:student/models/quiz.dart';
import 'package:student/models/difficulty_level.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/practice/quiz_session_screen.dart';
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
  final _proService = ProSubscriptionService();
  final _dailyLimitService = DailyLimitService();
  final _preloadService = PreloadService();

  bool _isLoading = true;
  bool _isLevelLoading = false;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  int _selectedDifficulty = 1;
  bool _canAttemptToday = true;
  String _timeUntilReset = '';
  Timer? _resetTimer;
  
  List<Quiz> _quizzes = [];
  Map<int, Map<String, dynamic>> _progressByLevel = {};
  Map<int, bool> _unlockedByLevel = {1: true};
  final Map<int, List<Quiz>> _quizzesByLevelCache = {};
  QuizGlobalProgress? _globalProgress;
  int _difficultyLoadSeq = 0;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _checkProAndLoadData();
    _startResetTimer();
  }

  void _startResetTimer() {
    // Update immediately, then every minute
    _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
    _resetTimer?.cancel();
    _resetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
      });
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkProAndLoadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) {
      Navigator.pop(context);
      return;
    }

    _studentId = studentId;

    // Check device session validity
    final result = await _proService.validateAndUpdateDeviceSession(
      studentId,
      forceClaim: false,
    );

    if (result['is_valid'] != true) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).proFeaturesActiveOnAnotherDevice),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // If valid, hydrate from cache for instant UI, then refresh from network.
    _tryHydrateFromCache();
    _loadInitialData();
  }

  void _tryHydrateFromCache() {
    final studentId = _studentId;
    if (studentId == null) return;

    final cachedGlobal = _preloadService.getQuizGlobalProgressCached(studentId);
    if (cachedGlobal != null) {
      final progressByLevel = <int, Map<String, dynamic>>{};
      for (int level = 1; level <= 4; level++) {
        final summary = cachedGlobal.progressByLevel[level] ??
            const QuizLevelProgressSummary(total: 0, completed: 0);
        progressByLevel[level] = {
          'total': summary.total,
          'completed': summary.completed,
          'percentage': summary.percentage,
        };
      }
      setState(() {
        _globalProgress = cachedGlobal;
        _progressByLevel = progressByLevel;
        _unlockedByLevel = {
          1: true,
          2: cachedGlobal.unlockedByLevel[2] == true,
          3: cachedGlobal.unlockedByLevel[3] == true,
          4: cachedGlobal.unlockedByLevel[4] == true,
        };
      });
    }

    final cachedLevel =
        _preloadService.getQuizLevelCached(studentId, _selectedDifficulty);
    if (cachedLevel != null) {
      _quizzesByLevelCache[_selectedDifficulty] = cachedLevel;
      setState(() {
        _quizzes = cachedLevel;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isLevelLoading = false;
    });

    try {
      // Do NOT clear caches here. We cache across visits and only invalidate on completion.

      // Load global progress/unlocks (batched) first
      await _loadGlobalProgress();

      // Load current level quizzes + daily limit in parallel
      final quizzesFuture = _fetchQuizzesForLevel(_selectedDifficulty);
      final dailyLimitFuture = _checkDailyLimit();
      final quizzes = await quizzesFuture;
      await dailyLimitFuture;

      if (!mounted) return;
      setState(() {
        _quizzes = quizzes;
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

  Future<void> _loadGlobalProgress() async {
    final global = await _quizService.getQuizGlobalProgress(_studentId!);
    _preloadService.cacheQuizGlobalProgress(_studentId!, global);

    final progressByLevel = <int, Map<String, dynamic>>{};
    for (int level = 1; level <= 4; level++) {
      final summary = global.progressByLevel[level] ??
          const QuizLevelProgressSummary(total: 0, completed: 0);
      progressByLevel[level] = {
        'total': summary.total,
        'completed': summary.completed,
        'percentage': summary.percentage,
      };
    }

    if (!mounted) return;
    setState(() {
      _globalProgress = global;
      _progressByLevel = progressByLevel;
      _unlockedByLevel = {
        1: true,
        2: global.unlockedByLevel[2] == true,
        3: global.unlockedByLevel[3] == true,
        4: global.unlockedByLevel[4] == true,
      };
    });
  }

  Future<List<Quiz>> _fetchQuizzesForLevel(int level, {bool force = false}) async {
    if (!force && _quizzesByLevelCache.containsKey(level)) {
      return _quizzesByLevelCache[level]!;
    }

    if (!force && _studentId != null) {
      final cached = _preloadService.getQuizLevelCached(_studentId!, level);
      if (cached != null) {
        _quizzesByLevelCache[level] = cached;
        return cached;
      }
    }

    final global = _globalProgress;
    final quizzes = global != null
        ? await _quizService.getQuizzesWithProgressUsingGlobal(
            _studentId!,
            level,
            global,
          )
        : await _quizService.getQuizzesWithProgress(_studentId!, level);

    _quizzesByLevelCache[level] = quizzes;
    if (_studentId != null) {
      _preloadService.cacheQuizLevel(_studentId!, level, quizzes);
    }
    return quizzes;
  }

  Future<void> _checkDailyLimit() async {
    final canAttempt = await _quizService.canAttemptQuizToday(_studentId!);
    setState(() {
      _canAttemptToday = canAttempt;
    });
  }

  void _onDifficultyChanged(int level) async {
    if (level == _selectedDifficulty) return;

    final isUnlocked = _unlockedByLevel[level] == true || level == 1;
    if (!isUnlocked) return;

    final requestSeq = ++_difficultyLoadSeq;

    // Instant swap if cached
    final cached = _quizzesByLevelCache[level];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _selectedDifficulty = level;
        _quizzes = cached;
        _isLevelLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedDifficulty = level;
      _isLevelLoading = true;
      _quizzes = [];
    });

    final quizzes = await _fetchQuizzesForLevel(level);
    if (!mounted || requestSeq != _difficultyLoadSeq) return;

    setState(() {
      _quizzes = quizzes;
      _isLevelLoading = false;
    });
  }

  Future<void> _startQuiz(Quiz quiz) async {
    // Check if locked
    if (quiz.isLocked == true) {
      _showErrorDialog('Complete the previous quiz first to unlock this one!');
      return;
    }

    // Check daily limit
    if (!_canAttemptToday) {
      _showErrorDialog('You have already completed one quiz today. Come back tomorrow!');
      return;
    }

    // Navigate to quiz session screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSessionScreen(
          quiz: quiz,
          studentId: _studentId!,
        ),
      ),
    );

    // Reload data after completing quiz
    if (result == true) {
      _didChange = true;
      _preloadService.invalidateQuizCache();
      _preloadService.invalidatePractice();
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _didChange);
        return false;
      },
      child: Scaffold(
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
                    : _errorMessage != null
                        ? _buildErrorState()
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
                                  _buildQuizzesList(l10n),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CustomBackButton(onPressed: () => Navigator.pop(context, _didChange)),
          Expanded(
            child: Center(
              child: Text(
                'Quiz Practice',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              FontAwesomeIcons.clipboardQuestion,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz practice',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete quizzes in order to unlock higher levels.',
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
    );
  }

  Widget _buildDailyLimitCard(AppLocalizations l10n) {
    final resetText = _timeUntilReset.isNotEmpty
        ? _timeUntilReset
        : _dailyLimitService.getTimeUntilResetFormatted();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _canAttemptToday
              ? [Color(0xFF10B981), Color(0xFF059669)]
              : [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (_canAttemptToday ? Colors.green : Colors.red).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _canAttemptToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _canAttemptToday ? 'Quiz Available' : 'Daily Limit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _canAttemptToday
                        ? '1 quiz today'
                        : 'Resets in $resetText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: DifficultyLevel.values.map((level) {
            final isSelected = level.value == _selectedDifficulty;
            final isUnlocked = _unlockedByLevel[level.value] == true || level.value == 1;
            
            return GestureDetector(
              onTap: isUnlocked ? () => _onDifficultyChanged(level.value) : null,
              child: Container(
                decoration: BoxDecoration(
                  gradient: !isUnlocked
                      ? LinearGradient(
                          colors: [Colors.grey.shade200, Colors.grey.shade300],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isSelected
                          ? LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !isUnlocked
                        ? Colors.grey.shade400
                        : (isSelected ? AppColors.primary : AppColors.border),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: !isUnlocked
                              ? Colors.grey.shade400
                              : (isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: !isUnlocked
                              ? Icon(Icons.lock, size: 14, color: Colors.grey.shade600)
                              : Text(
                                  '${level.value}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          level.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !isUnlocked
                                ? Colors.grey.shade600
                                : (isSelected ? Colors.white : AppColors.textPrimary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
        ],
      ),
    );
  }

  Widget _buildQuizzesList(AppLocalizations l10n) {
    if (_isLevelLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading quizzes...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_quizzes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              FontAwesomeIcons.clipboardQuestion,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Quizzes Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No quizzes have been created for this level yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Quizzes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_quizzes.length, (index) => _buildQuizCard(_quizzes[index])),
      ],
    );
  }

  Widget _buildQuizCard(Quiz quiz) {
    final isLocked = quiz.isLocked == true;
    final isCompleted = quiz.isCompleted == true;
    final hasScore = quiz.bestScore != null;
    final cardBorder = isLocked ? Colors.grey.shade300 : AppColors.border;
    final cardBg = isLocked ? Colors.grey.shade100 : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorder,
        ),
        boxShadow: isLocked
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? null : () => _startQuiz(quiz),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.grey.shade300 : AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Quiz ${quiz.orderIndex}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.grey.shade600 : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLocked)
                      Icon(Icons.lock, size: 16, color: Colors.grey.shade600)
                    else if (isCompleted)
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const Spacer(),
                    if (hasScore)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getScoreColor(quiz.bestScore!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.star,
                              size: 12,
                              color: _getScoreColor(quiz.bestScore!),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${quiz.bestScore!.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(quiz.bestScore!),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quiz.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? Colors.grey.shade600 : AppColors.textPrimary,
                  ),
                ),
                if (quiz.description != null && quiz.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    quiz.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLocked ? Colors.grey.shade500 : AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMetaChip(
                      icon: FontAwesomeIcons.clipboardQuestion,
                      text: '${quiz.totalQuestions ?? 0} Q',
                      disabled: isLocked,
                    ),
                    const SizedBox(width: 8),
                    _buildMetaChip(
                      icon: Icons.timer_outlined,
                      text: '~${quiz.estimatedDurationMinutes} min',
                      disabled: isLocked,
                    ),
                  ],
                ),
                if (!isLocked) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startQuiz(quiz),
                      icon: Icon(
                        isCompleted ? FontAwesomeIcons.arrowsRotate : FontAwesomeIcons.play,
                        size: 14,
                      ),
                      label: Text(isCompleted ? 'Retake' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required bool disabled,
  }) {
    final fg = disabled ? Colors.grey.shade500 : AppColors.textSecondary;
    final bg = disabled ? Colors.grey.shade200 : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: disabled ? Colors.grey.shade300 : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation,
              size: 64,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
