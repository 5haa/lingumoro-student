import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/reading_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/services/preload_service.dart';
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
  final _preloadService = PreloadService();
  
  bool _isLoading = true;
  bool _isLevelLoading = false;
  int _selectedDifficulty = 1;
  Map<int, bool> _unlockedByLevel = {1: true};
  bool _canReadToday = true;
  String _timeUntilReset = '';
  
  List<Map<String, dynamic>> _currentLevelReadings = [];
  Map<String, bool> _progressMap = {};
  Map<int, Map<String, dynamic>> _progressByLevel = {};
  ReadingGlobalProgress? _globalProgress;
  final Map<int, List<Map<String, dynamic>>> _readingsByLevelCache = {};
  int _difficultyLoadSeq = 0;
  bool _didChange = false;

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

    // If valid, hydrate from cache for instant UI, then refresh from network.
    _tryHydrateFromCache(studentId);
    _loadData();
  }

  void _tryHydrateFromCache(String studentId) {
    final cachedGlobal = _preloadService.getReadingGlobalProgressCached(studentId);
    if (cachedGlobal != null) {
      final progressByLevel = <int, Map<String, dynamic>>{};
      for (int level = 1; level <= 4; level++) {
        final summary = cachedGlobal.progressByLevel[level] ??
            const ReadingLevelProgressSummary(total: 0, completed: 0);
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
        _preloadService.getReadingsLevelCached(studentId, _selectedDifficulty);
    if (cachedLevel != null) {
      _readingsByLevelCache[_selectedDifficulty] = cachedLevel;
      setState(() {
        _currentLevelReadings = cachedLevel;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    setState(() => _isLoading = true);

    try {
      // Do NOT clear caches here. We cache across visits and only invalidate on completion.

      await _loadGlobalProgress(studentId);

      final readingsFuture = _fetchReadingsForLevel(_selectedDifficulty);
      final dailyLimitFuture = _checkDailyLimit();
      final readings = await readingsFuture;
      await dailyLimitFuture;

      setState(() {
        _currentLevelReadings = readings;
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

  Future<void> _loadGlobalProgress(String studentId) async {
    final global = await _readingService.getReadingGlobalProgress(studentId);
    _preloadService.cacheReadingGlobalProgress(studentId, global);

    final progressByLevel = <int, Map<String, dynamic>>{};
    for (int level = 1; level <= 4; level++) {
      final summary = global.progressByLevel[level] ??
          const ReadingLevelProgressSummary(total: 0, completed: 0);
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

  Future<void> _checkDailyLimit() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    final canRead = await _readingService.canReadToday(studentId);
    setState(() {
      _canReadToday = canRead;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchReadingsForLevel(int level, {bool force = false}) async {
    if (!force && _readingsByLevelCache.containsKey(level)) {
      return _readingsByLevelCache[level]!;
    }

    final studentId = _authService.currentUser?.id;
    if (!force && studentId != null) {
      final cached = _preloadService.getReadingsLevelCached(studentId, level);
      if (cached != null) {
        _readingsByLevelCache[level] = cached;
        return cached;
      }
    }

    final readings = await _readingService.getReadingsByDifficulty(level);

    final global = _globalProgress;
    final decorated = global != null
        ? _readingService.buildReadingsWithProgressUsingGlobal(readings, level, global)
        : readings;

    // Keep compatibility with existing UI bits
    final progressMap = <String, bool>{};
    for (final r in decorated) {
      final id = r['id'] as String;
      progressMap[id] = r['is_completed'] == true;
    }
    _progressMap = progressMap;

    _readingsByLevelCache[level] = decorated;
    if (studentId != null) {
      _preloadService.cacheReadingsLevel(studentId, level, decorated);
    }
    return decorated;
  }

  void _onDifficultyChanged(int level) async {
    if (level == _selectedDifficulty) return;
    final isUnlocked = _unlockedByLevel[level] == true || level == 1;
    if (!isUnlocked) return;

    final requestSeq = ++_difficultyLoadSeq;

    final cached = _readingsByLevelCache[level];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _selectedDifficulty = level;
        _currentLevelReadings = cached;
        _isLevelLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedDifficulty = level;
      _isLevelLoading = true;
      _currentLevelReadings = [];
    });

    final readings = await _fetchReadingsForLevel(level);
    if (!mounted || requestSeq != _difficultyLoadSeq) return;

    setState(() {
      _currentLevelReadings = readings;
      _isLevelLoading = false;
    });
  }

  Future<void> _openReading(Map<String, dynamic> reading) async {
    final l10n = AppLocalizations.of(context);
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    final isCompleted = reading['is_completed'] == true || _progressMap[reading['id']] == true;
    final isLocked = reading['is_locked'] == true;

    if (isLocked) {
      _showErrorDialog(l10n.completePreviousReading);
      return;
    }

    // Daily limit blocks starting a NEW reading; allow opening completed items.
    if (!_canReadToday && !isCompleted) {
      _showErrorDialog('You have already completed your reading for today. Resets in $_timeUntilReset.');
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
      _didChange = true;
      _preloadService.invalidateReadingCache();
      _preloadService.invalidatePractice();
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
    ));
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
              Icons.menu_book,
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
                  l10n.readings,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete readings in order to unlock higher levels.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _canReadToday
              ? [Color(0xFF10B981), Color(0xFF059669)]
              : [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (_canReadToday ? Colors.green : Colors.red).withOpacity(0.2),
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
                _canReadToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
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
                    _canReadToday ? 'Reading Available' : 'Daily Limit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _canReadToday
                        ? '1 reading today'
                        : 'Resets in $_timeUntilReset',
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
            final isLocked = _unlockedByLevel[level.value] != true && level.value != 1;
            
            return GestureDetector(
              onTap: isLocked ? null : () => _onDifficultyChanged(level.value),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isLocked
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
                    color: isLocked
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
                          color: isLocked
                              ? Colors.grey.shade400
                              : (isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isLocked
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
                            color: isLocked
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
    if (_isLevelLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.loading,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
    final isCompleted = reading['is_completed'] == true || _progressMap[reading['id']] == true;
    final isLocked = reading['is_locked'] == true;
    final isBlockedByDailyLimit = !_canReadToday && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.shade300
              : (isLocked || isBlockedByDailyLimit)
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
                : (isLocked || isBlockedByDailyLimit)
                    ? Colors.grey.shade200
                    : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.green.shade700)
                : (isLocked || isBlockedByDailyLimit)
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
            color: (isLocked || isBlockedByDailyLimit) ? Colors.grey.shade600 : AppColors.textPrimary,
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
                    l10n.completed,
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
        trailing: (isLocked || isBlockedByDailyLimit)
            ? null
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isCompleted ? Colors.grey.shade400 : AppColors.primary,
              ),
        onTap: () {
          if (isLocked) {
            _showErrorDialog(l10n.completePreviousReading);
            return;
          }
          if (isBlockedByDailyLimit) {
            _showErrorDialog('You have already completed your reading for today. Resets in $_timeUntilReset.');
            return;
          }
          _openReading(reading);
        },
      ),
    );
  }
}
