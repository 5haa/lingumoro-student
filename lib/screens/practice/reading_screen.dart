import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/reading_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/models/difficulty_level.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/practice/reading_detail_screen.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _readingService = ReadingService();
  final _authService = AuthService();
  final _proService = ProSubscriptionService();
  final _dailyLimitService = DailyLimitService();
  
  bool _isLoading = true;
  int _selectedDifficulty = 1;
  int _highestUnlockedLevel = 1;
  bool _canReadToday = true;
  String _timeUntilReset = '';
  
  List<Map<String, dynamic>> _currentLevelReadings = [];
  Map<String, bool> _progressMap = {};
  Map<int, Map<String, dynamic>> _progressByLevel = {};

  @override
  void initState() {
    super.initState();
    _checkProAndLoadData();
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
  
  Future<void> _checkProAndLoadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) {
      Navigator.pop(context);
      return;
    }

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

    // If valid, load data
    _loadData();
  }

  Future<void> _loadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadHighestUnlockedLevel(),
        _loadProgressForAllLevels(),
        _checkDailyLimit(),
      ]);

      await _loadReadingsForLevel(_selectedDifficulty);

      setState(() {
        _isLoading = false;
        _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorLoadingReadings} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadHighestUnlockedLevel() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    int unlockedLevel = 1;
    
    for (int level = 1; level <= 4; level++) {
      if (level == 1) {
        unlockedLevel = 1;
        continue;
      }

      final canUnlock = await _readingService.canUnlockNextLevel(studentId, level - 1);
      if (canUnlock) {
        unlockedLevel = level;
      } else {
        break;
      }
    }

    setState(() {
      _highestUnlockedLevel = unlockedLevel;
    });
  }

  Future<void> _loadProgressForAllLevels() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    for (int level = 1; level <= 4; level++) {
      final readings = await _readingService.getReadingsByDifficulty(level);
      final progressMap = await _readingService.getStudentProgress(studentId);
      
      int completed = 0;
      for (var reading in readings) {
        if (progressMap[reading['id']] == true) {
          completed++;
        }
      }

      _progressByLevel[level] = {
        'total': readings.length,
        'completed': completed,
        'percentage': readings.isEmpty ? 0.0 : (completed / readings.length * 100),
      };
    }
    setState(() {});
  }

  Future<void> _checkDailyLimit() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    final canRead = await _readingService.canReadToday(studentId);
    setState(() {
      _canReadToday = canRead;
    });
  }

  Future<void> _loadReadingsForLevel(int level) async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    final readings = await _readingService.getReadingsByDifficulty(level);
    final progressMap = await _readingService.getStudentProgress(studentId);

    setState(() {
      _currentLevelReadings = readings;
      _progressMap = progressMap;
    });
  }

  void _onDifficultyChanged(int level) async {
    setState(() {
      _selectedDifficulty = level;
      _isLoading = true;
    });
    await _loadReadingsForLevel(level);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _openReading(Map<String, dynamic> reading) async {
    final l10n = AppLocalizations.of(context);
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    // Check daily limit
    if (!_canReadToday) {
      _showErrorDialog('You have already completed your reading for today. Come back tomorrow!');
      return;
    }

    // Check if unlocked
    final isUnlocked = await _readingService.isReadingUnlocked(
      studentId,
      reading['id'],
      reading['title'] ?? '',
      reading['order'] ?? 0,
    );

    if (!isUnlocked) {
      _showErrorDialog('Complete previous readings first to unlock this one.');
      return;
    }

    // Navigate to reading detail
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingDetailScreen(
          reading: reading,
          studentId: studentId,
        ),
      ),
    );

    // Reload if reading was completed
    if (result == true) {
      _loadData();
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
                  : RefreshIndicator(
                      onRefresh: _loadData,
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
                            _buildReadingsList(l10n),
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
                l10n.readings,
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
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.readings,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Practice Reading • 4 Levels',
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
        color: _canReadToday ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canReadToday ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _canReadToday ? Icons.check_circle : Icons.timer,
            color: _canReadToday ? Colors.green.shade700 : Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _canReadToday ? 'Reading Available Today' : 'Daily Limit Reached',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _canReadToday ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _canReadToday
                      ? 'You can complete 1 reading today'
                      : 'Resets in $_timeUntilReset',
                  style: TextStyle(
                    fontSize: 13,
                    color: _canReadToday ? Colors.green.shade700 : Colors.red.shade700,
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

  Widget _buildReadingsList(AppLocalizations l10n) {
    if (_currentLevelReadings.isEmpty) {
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
              'No readings available for this level yet.',
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
          'Readings (${_currentLevelReadings.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _currentLevelReadings.length,
          (index) => _buildReadingCard(_currentLevelReadings[index], index, l10n),
        ),
      ],
    );
  }

  Widget _buildReadingCard(Map<String, dynamic> reading, int index, AppLocalizations l10n) {
    final isCompleted = _progressMap[reading['id']] == true;
    
    // Check if previous reading is completed (for lock state)
    final isLocked = index > 0 && _progressMap[_currentLevelReadings[index - 1]['id']] != true;

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
          reading['title'] ?? 'Untitled',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.grey.shade600 : AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${reading['reading_time'] ?? 5} min read',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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
        onTap: isLocked || !_canReadToday
            ? null
            : () => _openReading(reading),
      ),
    );
  }
}
