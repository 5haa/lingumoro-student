import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/services/ai_story_service.dart';
import 'package:student/services/reading_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:student/services/points_notification_service.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/models/difficulty_level.dart';
import 'package:student/screens/practice/reading_screen.dart';
import 'package:student/screens/practice/quiz_practice_screen.dart';
import 'package:student/screens/practice/ai_voice_screen.dart';
import 'package:student/config/app_colors.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_back_button.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with AutomaticKeepAliveClientMixin {
  final _practiceService = PracticeService();
  final _authService = AuthService();
  final _proService = ProSubscriptionService();
  final _quizService = QuizPracticeService();
  final _aiStoryService = AIStoryService();
  final _readingService = ReadingService();
  final _preloadService = PreloadService();
  final _dailyLimitService = DailyLimitService();
  
  List<Map<String, dynamic>> _videos = [];
  Map<String, bool> _watchedVideos = {};
  bool _isLoading = false;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  bool _isInitialLoadDone = false;
  
  // Daily limit status
  Map<String, bool> _dailyLimitStatus = {
    'quiz_completed': false,
    'video_completed': false,
    'reading_completed': false,
  };
  
  // Statistics for cards
  Map<String, dynamic> _quizStats = {
    'total_attempts': 0,
    'total_questions_answered': 0,
    'accuracy': 0.0,
  };
  int _completedReadings = 0;
  int _totalReadings = 0;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    // Defer loading to after initState completes to avoid context access issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataFromCache();
      _isInitialLoadDone = true;
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload data after initial load is complete (to avoid double-loading)
    if (_isInitialLoadDone && mounted && !_isLoading) {
      _loadDataFromCache();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadDataFromCache() {
    final l10n = AppLocalizations.of(context);
    // Get student ID first
    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginRequired;
      });
      return;
    }
    _studentId = user.id;

    // Check PRO status from cache INCLUDING device session validity
    bool hasPro = false;
    if (_preloadService.proSubscription != null) {
      final sub = _preloadService.proSubscription!;
      final expiresAt = sub['expires_at'] as String?;
      final deviceSessionValid = sub['device_session_valid'] == true;
      
      if (expiresAt != null) {
        final expiryDate = DateTime.parse(expiresAt);
        final notExpired = expiryDate.isAfter(DateTime.now());
        hasPro = notExpired && deviceSessionValid; // Both conditions must be true
      }
    }
    
    // Check cached device session from ProSubscriptionService
    final cachedSession = _proService.getCachedDeviceSession();
    if (cachedSession != null) {
      hasPro = cachedSession['is_valid'] == true;
    }
    
    setState(() {
      _hasProSubscription = hasPro;
    });

    // Try to load from cache
    final cached = _preloadService.practiceData;
    if (cached != null) {
      setState(() {
        _videos = cached.videos;
        _watchedVideos = cached.watchedVideos;
        _quizStats = cached.quizStats;
        _completedReadings = cached.completedReadings ?? 0;
        _totalReadings = cached.totalReadings ?? 0;
        _isLoading = false;
      });
      print('✅ Loaded practice data from cache (Pro: $hasPro)');
      return;
    }
    
    // No cache, load from API
    _loadAllData();
  }

  Future<void> _loadAllData({bool showSpinner = true}) async {
    final l10n = AppLocalizations.of(context);
    if (mounted) {
      setState(() {
        // If we already have data on screen, do a soft refresh without the spinner.
        final hasAnyData =
            _videos.isNotEmpty || _quizStats.isNotEmpty || _totalReadings > 0;
        _isLoading = showSpinner && !hasAnyData;
        _errorMessage = null;
      });
    }

    try {
      // Get current student ID
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.loginRequired;
        });
        return;
      }

      _studentId = user.id;

      // Check PRO subscription
      final hasPro = await _proService.hasActivePro(_studentId!);
      setState(() {
        _hasProSubscription = hasPro;
      });

      // Load all data in parallel
      await Future.wait([
        _loadVideosData(),
        _loadQuizStats(),
        _loadReadingStats(),
        _loadDailyLimitStatus(),
      ]);

      // Cache the practice data
      _preloadService.cachePractice(
        videos: _videos,
        watchedVideos: _watchedVideos,
        quizStats: _quizStats,
        completedReadings: _completedReadings,
        totalReadings: _totalReadings,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${l10n.errorLoadingData}: ${e.toString()}';
      });
    }
  }

  Future<void> _loadVideosData() async {
    try {
      if (_studentId == null) return;

      // Get all practice videos
      final videos = await _practiceService.getPracticeVideos(null);

      // OPTIMIZATION: Batch query for watched status
      final videoIds = videos.map((v) => v['id'] as String).toList();
      final watchedStatus = await _practiceService.getWatchedStatusBatch(_studentId!, videoIds);

      setState(() {
        _videos = videos;
        _watchedVideos = watchedStatus;
      });
    } catch (e) {
      print('Error loading videos: $e');
    }
  }

  Future<void> _loadQuizStats() async {
    try {
      if (_studentId == null) return;
      final stats = await _quizService.getQuizStatistics(_studentId!);
      setState(() {
        _quizStats = stats;
      });
    } catch (e) {
      print('Error loading quiz stats: $e');
    }
  }

  Future<void> _loadReadingStats() async {
    try {
      if (_studentId == null) return;
      final completed = await _readingService.getCompletedCount(_studentId!);
      final total = await _readingService.getTotalReadingsCount();
      setState(() {
        _completedReadings = completed;
        _totalReadings = total;
      });
    } catch (e) {
      print('Error loading reading stats: $e');
    }
  }

  Future<void> _loadDailyLimitStatus() async {
    try {
      if (_studentId == null) return;
      final status = await _dailyLimitService.getDailyLimitStatus(_studentId!);
      setState(() {
        _dailyLimitStatus = status;
      });
    } catch (e) {
      print('Error loading daily limit status: $e');
    }
  }

  bool _canWatchVideo(int index) {
    if (index == 0) return true; // First video can always be watched
    
    // Check if previous video is watched
    if (index > 0) {
      final previousVideo = _videos[index - 1];
      return _watchedVideos[previousVideo['id']] ?? false;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(l10n),
            
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState(l10n)
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Practice Cards Grid
                        // Listening
                        _buildPracticeCard(
                          title: l10n.videos,
                          icon: FontAwesomeIcons.play,
                          color: Colors.red.shade600,
                          gradient: LinearGradient(
                            colors: [Color(0xFFED4264), Color(0xFFFFEDBC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          stat2Label: '${_videos.length} ${l10n.videos}',
                          onTap: () => _navigateToVideoPractice(),
                          isLocked: false,
                          showProgress: true,
                          progressValue: _videos.isNotEmpty
                              ? ((_watchedVideos.values.where((w) => w).length / _videos.length) * 100).toInt()
                              : 0,
                          dailyLimitReached: _dailyLimitStatus['video_completed'],
                          imagePath: 'assets/images/listening.png',
                        ),
                        const SizedBox(height: 12),

                        // Speaking
                        _buildPracticeCard(
                          title: l10n.aiVoicePractice,
                          icon: FontAwesomeIcons.microphone,
                          color: Colors.green.shade600,
                          gradient: LinearGradient(
                            colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          stat2Label: l10n.chat,
                          onTap: () => _navigateToVoiceAI(),
                          isLocked: false,
                          showProgress: false,
                          imagePath: 'assets/images/speaking.jpg',
                        ),
                        const SizedBox(height: 12),

                        // Reading
                        _buildPracticeCard(
                          title: l10n.readings,
                          icon: FontAwesomeIcons.book,
                          color: Colors.blue.shade600,
                          gradient: LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          stat2Label: '$_completedReadings/$_totalReadings ${l10n.completed}',
                          onTap: () => _navigateToReading(),
                          isLocked: false,
                          showProgress: false,
                          dailyLimitReached: _dailyLimitStatus['reading_completed'],
                          imagePath: 'assets/images/reading.png',
                        ),
                        const SizedBox(height: 12),

                        // Quiz
                        _buildPracticeCard(
                          title: l10n.languageQuiz,
                          icon: FontAwesomeIcons.penToSquare,
                          color: Colors.orange.shade600,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF9966), Color(0xFFFF6B6B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          stat2Label: '${_quizStats['total_attempts'] ?? 0} ${l10n.quizzes}',
                          onTap: () => _navigateToQuiz(),
                          isLocked: false,
                          showProgress: false,
                          dailyLimitReached: _dailyLimitStatus['quiz_completed'],
                          imagePath: 'assets/images/quiz.png',
                        ),
                                const SizedBox(height: 16),
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
          // Menu Icon
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const FaIcon(
                FontAwesomeIcons.bars,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          
          Expanded(
            child: Center(
              child: Text(
                l10n.practice,
                style: const TextStyle(
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

  Widget _buildPracticeCard({
    required String title,
    required IconData icon,
    required Color color,
    required String stat2Label,
    required VoidCallback onTap,
    bool isLocked = false,
    required LinearGradient gradient,
    bool showProgress = false,
    int? progressValue,
    bool? dailyLimitReached,
    String? imagePath,
  }) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: isLocked ? _showProRequiredDialog : onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isLocked 
              ? LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : (imagePath != null ? null : gradient),
          image: imagePath != null && !isLocked
              ? DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title (replaces emoji)
              SizedBox(
                height: 50,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: imagePath != null && !isLocked ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Keep original title slot invisible so card height stays the same
              Opacity(
                opacity: 0,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: imagePath != null && !isLocked ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Badges row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(stat2Label, color, hasImage: imagePath != null && !isLocked),
                  if (isLocked)
                    _buildBadge(l10n.proFeature, Colors.amber.shade700, hasImage: false),
                  if (dailyLimitReached == true)
                    _buildBadge('✓ Today', Colors.green.shade700, hasImage: imagePath != null && !isLocked),
                ],
              ),
              
              // Progress bar (only for video card)
              if (showProgress) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.videos,
                          style: TextStyle(
                            fontSize: 10,
                            color: imagePath != null && !isLocked ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isLocked ? '0%' : '${progressValue ?? 0}% ${l10n.completed}',
                          style: TextStyle(
                            fontSize: 10,
                            color: imagePath != null && !isLocked ? Colors.black87 : Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: isLocked ? 0 : (progressValue ?? 0) / 100,
                        backgroundColor: imagePath != null && !isLocked 
                            ? Colors.black.withOpacity(0.2) 
                            : Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          imagePath != null && !isLocked ? Colors.black87 : Colors.white,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ] else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, {bool hasImage = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasImage 
            ? Colors.black.withOpacity(0.15) 
            : Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: hasImage ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<bool> _checkProBeforeNavigation() async {
    if (_studentId == null) return false;
    
    // Show quick loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    try {
      // Validate device session right now
      final result = await _proService.validateAndUpdateDeviceSession(
        _studentId!, 
        forceClaim: false
      );
      
      // Close loading
      if (mounted) Navigator.pop(context);
      
      if (result['is_valid'] == true) {
        return true;
      } else {
        if (mounted) {
          // Refresh state
          setState(() => _hasProSubscription = false);
          
          if (result['active_on_other_device'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Pro features are active on another device. Activate here in Profile.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            _showProRequiredDialog();
          }
        }
        return false;
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      return false;
    }
  }

  void _navigateToVoiceAI() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AIVoicePracticeScreen(),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        _preloadService.invalidatePractice();
        // Soft refresh (avoid showing loading state if we already have cached data)
        await _loadAllData(showSpinner: false);
      }
    }
  }

  void _navigateToVideoPractice() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VideoPracticeListScreen(),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        _preloadService.invalidatePractice();
        await _loadAllData(showSpinner: false);
      }
    }
  }

  void _navigateToReading() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReadingScreen(),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        _preloadService.invalidatePractice();
        await _loadAllData(showSpinner: false);
      }
    }
  }

  void _navigateToQuiz() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QuizPracticeScreen(),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        _preloadService.invalidatePractice();
        await _loadAllData(showSpinner: false);
      }
    }
  }

  void _showProRequiredDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            FaIcon(FontAwesomeIcons.crown, color: Colors.amber.shade600, size: 28),
            const SizedBox(width: 12),
            Text(
              l10n.proFeature,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          l10n.upgradeToAccess,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.close,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to profile/upgrade screen
            },
            icon: const FaIcon(FontAwesomeIcons.crown),
            label: Text(l10n.upgrade),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Separate screen for video practice list
class VideoPracticeListScreen extends StatefulWidget {
  const VideoPracticeListScreen({super.key});

  @override
  State<VideoPracticeListScreen> createState() => _VideoPracticeListScreenState();
}

class _VideoPracticeListScreenState extends State<VideoPracticeListScreen> {
  final _practiceService = PracticeService();
  final _authService = AuthService();
  final _proService = ProSubscriptionService();
  final _dailyLimitService = DailyLimitService();
  final _preloadService = PreloadService();
  
  List<Map<String, dynamic>> _currentLevelVideos = [];
  Map<String, bool> _watchedVideos = {};
  bool _isLoading = true;
  bool _isLevelLoading = false;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  
  int _selectedDifficulty = 1;
  Map<int, bool> _unlockedByLevel = {1: true};
  bool _canWatchToday = true;
  String _timeUntilReset = '';
  Map<int, Map<String, dynamic>> _progressByLevel = {};
  VideoGlobalProgress? _globalProgress;
  final Map<int, List<Map<String, dynamic>>> _videosByLevelCache = {};
  int _difficultyLoadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadPracticeVideos();
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

  Future<void> _loadPracticeVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isLevelLoading = false;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to access practice videos';
        });
        return;
      }

      _studentId = user.id;

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

      // Hydrate from cache for instant UI, then refresh from network.
      _tryHydrateFromCache(_studentId!);

      // Load global progress/unlocks once, then load selected level + daily limit
      await _loadGlobalProgress();
      final videosFuture = _fetchVideosForLevel(_selectedDifficulty);
      final dailyLimitFuture = _checkDailyLimit();
      final videos = await videosFuture;
      await dailyLimitFuture;

      setState(() {
        _currentLevelVideos = videos;
        _isLoading = false;
        _timeUntilReset = _dailyLimitService.getTimeUntilResetFormatted();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load practice videos: ${e.toString()}';
      });
    }
  }

  Future<void> _loadGlobalProgress() async {
    final global = await _practiceService.getVideoGlobalProgress(_studentId!);
    _preloadService.cacheVideoGlobalProgress(_studentId!, global);

    final progressByLevel = <int, Map<String, dynamic>>{};
    for (int level = 1; level <= 4; level++) {
      final summary = global.progressByLevel[level] ??
          const VideoLevelProgressSummary(total: 0, completed: 0);
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
    final canWatch = await _practiceService.canWatchVideoToday(_studentId!);
    setState(() {
      _canWatchToday = canWatch;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchVideosForLevel(int level, {bool force = false}) async {
    if (!force && _videosByLevelCache.containsKey(level)) {
      return _videosByLevelCache[level]!;
    }

    if (!force && _studentId != null) {
      final cached = _preloadService.getVideosLevelCached(_studentId!, level);
      if (cached != null) {
        _videosByLevelCache[level] = cached;
        return cached;
      }
    }

    // NOTE: Practice videos are not language-filtered here, so pass null languageId.
    final videos = await _practiceService.getPracticeVideos(null, difficultyLevel: level);

    final global = _globalProgress;
    final decorated = global != null
        ? _practiceService.buildVideosWithProgressUsingGlobal(videos, level, global)
        : videos;

    // Keep compatibility with existing UI bits
    final watched = <String, bool>{};
    for (final v in decorated) {
      final id = v['id'] as String;
      watched[id] = v['is_watched'] == true;
    }
    _watchedVideos = watched;

    _videosByLevelCache[level] = decorated;
    if (_studentId != null) {
      _preloadService.cacheVideosLevel(_studentId!, level, decorated);
    }
    return decorated;
  }

  void _tryHydrateFromCache(String studentId) {
    final cachedGlobal = _preloadService.getVideoGlobalProgressCached(studentId);
    if (cachedGlobal != null) {
      final progressByLevel = <int, Map<String, dynamic>>{};
      for (int level = 1; level <= 4; level++) {
        final summary = cachedGlobal.progressByLevel[level] ??
            const VideoLevelProgressSummary(total: 0, completed: 0);
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

    final cachedLevel = _preloadService.getVideosLevelCached(studentId, _selectedDifficulty);
    if (cachedLevel != null) {
      _videosByLevelCache[_selectedDifficulty] = cachedLevel;
      setState(() {
        _currentLevelVideos = cachedLevel;
        _isLoading = false;
      });
    }
  }

  void _onDifficultyChanged(int level) async {
    if (level == _selectedDifficulty) return;
    final isUnlocked = _unlockedByLevel[level] == true || level == 1;
    if (!isUnlocked) return;

    final requestSeq = ++_difficultyLoadSeq;

    final cached = _videosByLevelCache[level];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _selectedDifficulty = level;
        _currentLevelVideos = cached;
        _isLevelLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedDifficulty = level;
      _isLevelLoading = true;
      _currentLevelVideos = [];
    });

    final videos = await _fetchVideosForLevel(level);
    if (!mounted || requestSeq != _difficultyLoadSeq) return;

    setState(() {
      _currentLevelVideos = videos;
      _isLevelLoading = false;
    });
  }

  bool _canWatchVideo(int index) {
    final video = _currentLevelVideos[index];
    if (video['is_locked'] == true) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(l10n),
            
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState(l10n)
                      : RefreshIndicator(
                          onRefresh: _loadPracticeVideos,
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
                                _buildVideosList(l10n),
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
          // Back Icon
          const CustomBackButton(),
          
          Expanded(
            child: Center(
              child: Text(
                l10n.videoPracticeTitle,
                style: const TextStyle(
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
              Icons.ondemand_video,
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
                  l10n.videoPracticeTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete videos in order to unlock higher levels.',
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
          colors: _canWatchToday
              ? [Color(0xFF10B981), Color(0xFF059669)]
              : [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (_canWatchToday ? Colors.green : Colors.red).withOpacity(0.2),
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
                _canWatchToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
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
                    _canWatchToday ? 'Video Available' : 'Daily Limit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _canWatchToday
                        ? '1 video today'
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

  Widget _buildVideosList(AppLocalizations l10n) {
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

    if (_currentLevelVideos.isEmpty) {
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
              'No videos available for this level yet.',
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
          'Videos (${_currentLevelVideos.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _currentLevelVideos.length,
          (index) => _buildVideoCard(_currentLevelVideos[index], index, l10n),
        ),
      ],
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    if (_errorMessage == 'PRO subscription required') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPracticeVideos,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, int index, AppLocalizations l10n) {
    final isWatched = _watchedVideos[video['id']] ?? false;
    final canWatch = _canWatchVideo(index);
    final isLocked = !canWatch;
    final isBlockedByDailyLimit = !_canWatchToday && !isWatched;
    final number = index + 1;

    final borderColor = isWatched
        ? Colors.green.shade300
        : (isLocked || isBlockedByDailyLimit)
            ? Colors.grey.shade300
            : AppColors.border;

    final iconBg = isWatched
        ? Colors.green.withOpacity(0.12)
        : (isLocked || isBlockedByDailyLimit)
            ? Colors.grey.shade100
            : AppColors.primary.withOpacity(0.10);

    final iconColor = isWatched
        ? Colors.green.shade700
        : (isLocked || isBlockedByDailyLimit)
            ? Colors.grey.shade600
            : AppColors.primary;

    final iconData = isWatched
        ? Icons.check_circle
        : (isLocked ? Icons.lock : Icons.play_circle_fill);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLocked) {
              _showLockedDialog();
              return;
            }
            if (isBlockedByDailyLimit) {
              _showDailyLimitDialog();
              return;
            }
            _openVideoPlayer(video);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor.withOpacity(0.9)),
                  ),
                  child: Center(
                    child: Icon(iconData, color: iconColor, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (video['title'] ?? 'Untitled').toString(),
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: (isLocked || isBlockedByDailyLimit)
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isWatched) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 12, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.completed,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (video['description'] != null && (video['description'] as String).trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          (video['description'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: (isLocked || isBlockedByDailyLimit)
                                ? AppColors.textHint
                                : AppColors.textSecondary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildInfoChip(
                            icon: FontAwesomeIcons.listOl,
                            text: '#$number',
                            color: Colors.purple,
                          ),
                          if (video['duration_seconds'] != null)
                            _buildInfoChip(
                              icon: FontAwesomeIcons.clock,
                              text: _formatDuration(video['duration_seconds']),
                              color: Colors.blue,
                            ),
                          _buildInfoChip(
                            icon: FontAwesomeIcons.star,
                            text: '+${video['points_reward'] ?? 10}',
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      if (isBlockedByDailyLimit) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: Colors.red.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Daily limit reached. Resets in $_timeUntilReset',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (isLocked) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.completePreviousVideoToUnlock,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isLocked || isBlockedByDailyLimit)
                        ? Colors.grey.shade100
                        : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isLocked || isBlockedByDailyLimit)
                          ? Colors.grey.shade200
                          : AppColors.primary.withOpacity(0.18),
                    ),
                  ),
                  child: Icon(
                    (isLocked || isBlockedByDailyLimit) ? Icons.lock : Icons.chevron_right,
                    size: 18,
                    color: (isLocked || isBlockedByDailyLimit)
                        ? Colors.grey.shade500
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 10,
            color: color.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 14,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red.shade400),
            const SizedBox(width: 12),
            Text(l10n.videoLockedTitle, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          l10n.completePreviousVideoToUnlock,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showDailyLimitDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Text(
              'Daily limit reached',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'You can watch 1 new video per day. Resets in $_timeUntilReset.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideoPlayer(Map<String, dynamic> video) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          video: video,
          studentId: _studentId!,
          onVideoCompleted: () {
            // Refresh the list when video is completed
            _loadPracticeVideos();
          },
        ),
      ),
    );

    // Fallback: if the player returns a completion result, refresh immediately.
    if (result == true) {
      _loadPracticeVideos();
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  final String studentId;
  final VoidCallback onVideoCompleted;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.studentId,
    required this.onVideoCompleted,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  final _practiceService = PracticeService();
  final _pointsNotificationService = PointsNotificationService();
  final PreloadService _preloadService = PreloadService();
  bool _hasMarkedAsWatched = false;
  bool _didCompleteVideo = false;
  bool _isExitingScreen = false;
  bool _controllerDisposed = false;
  int _actualWatchedSeconds = 0;
  int _lastRecordedPosition = 0;

  @override
  void initState() {
    super.initState();
    
    final videoId = widget.video['youtube_video_id'];
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        controlsVisibleAtStart: false, // Hide controls to prevent skipping
        disableDragSeek: true, // Prevent drag seeking
        enableCaption: true,
        hideControls: false,
      ),
    );

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isReady && !_hasMarkedAsWatched) {
      final currentPosition = _controller.value.position.inSeconds;
      
      // Detect if user skipped forward (jumped more than 2 seconds)
      if (currentPosition > _lastRecordedPosition + 2) {
        // User tried to skip, seek back to last valid position
        _controller.seekTo(Duration(seconds: _lastRecordedPosition));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please watch the video without skipping'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Only increment actual watch time if playing normally (max 1 second increment)
      if (currentPosition > _lastRecordedPosition && 
          currentPosition <= _lastRecordedPosition + 2) {
        setState(() {
          _actualWatchedSeconds += (currentPosition - _lastRecordedPosition);
          _lastRecordedPosition = currentPosition;
        });
      }
      
      // Get required watch duration from admin settings (in seconds)
      final requiredDuration = (widget.video['duration_seconds'] as int?) ?? 0;
      
      // If admin didn't set a duration, use 95% of video length as fallback
      int requiredWatchTime;
      if (requiredDuration > 0) {
        requiredWatchTime = requiredDuration;
      } else {
        final videoDuration = _controller.metadata.duration.inSeconds;
        requiredWatchTime = (videoDuration * 0.95).round();
      }
      
      // Mark as watched when required duration is reached
      if (_actualWatchedSeconds >= requiredWatchTime && !_hasMarkedAsWatched) {
        _hasMarkedAsWatched = true;
        _markVideoAsWatched();
      }
    }
  }

  void _pauseAndDisposeController() {
    if (_controllerDisposed) return;
    try {
      _controller.pause();
    } catch (_) {}
    _controller.dispose();
    _controllerDisposed = true;
  }

  Future<bool> _onWillPop() async {
    if (!_isExitingScreen) {
      setState(() {
        _isExitingScreen = true;
      });
      _pauseAndDisposeController();
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return true;
  }

  Future<void> _handleBackButton() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.of(context).pop(_didCompleteVideo);
    }
  }

  Future<void> _markVideoAsWatched() async {
    try {
      final pointsReward = (widget.video['points_reward'] as int?) ?? 10;

      // Mark video as watched
      final pointsAwarded = await _practiceService.markVideoAsWatched(
        widget.studentId,
        widget.video['id'],
        pointsReward: pointsReward,
      );
      
      if (mounted) {
        _didCompleteVideo = true;
        // Invalidate caches so parent Practice/Video screens can refresh quickly (without forced reloads everywhere).
        _preloadService.invalidateVideoCache();
        _preloadService.invalidatePractice();
        // Show points notification using the new service
        _pointsNotificationService.showPointsEarnedNotification(
          context: context,
          pointsGained: pointsAwarded,
          message: 'Video completed! +$pointsAwarded points ✨',
        );
        
        // Call the callback
        widget.onVideoCompleted();
      }
    } catch (e) {
      print('Error marking video as watched: $e');
    }
  }

  void _showLevelUpDialog(String oldLevel, String newLevel, int newPoints) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade300,
                    Colors.amber.shade600,
                  ],
                ),
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Level Up!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Congratulations! 🎉',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        oldLevel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        newLevel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$newPoints points',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Awesome!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pauseAndDisposeController();
    super.dispose();
  }

  Widget _buildWatchProgressIndicator() {
    final l10n = AppLocalizations.of(context);
    final requiredDuration = (widget.video['duration_seconds'] as int?) ?? 0;
    int requiredWatchTime;
    
    if (requiredDuration > 0) {
      requiredWatchTime = requiredDuration;
    } else {
      final videoDuration = _controller.metadata.duration.inSeconds;
      requiredWatchTime = (videoDuration * 0.95).round();
    }
    
    final remainingSeconds = (requiredWatchTime - _actualWatchedSeconds).clamp(0, requiredWatchTime);
    final progressPercent = requiredWatchTime > 0 
        ? (_actualWatchedSeconds / requiredWatchTime * 100).clamp(0, 100) 
        : 0;
    
    final isCompleted = _actualWatchedSeconds >= requiredWatchTime;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompleted 
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : Colors.blue.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? Colors.green : Colors.blue).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.shade600 : Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isCompleted ? Colors.green : Colors.blue).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                      isCompleted 
                          ? l10n.success
                          : l10n.continueWatching,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green.shade900 : Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompleted 
                          ? l10n.completedVideos 
                          : '${_formatTime(remainingSeconds)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${progressPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progressPercent / 100,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted ? Colors.green : Colors.blue).withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),
              
              // Video Player
              _buildVideoPlayerSection(),
              
              // Watch Progress Indicator
              _buildWatchProgressIndicator(),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Title Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFED4264), Color(0xFFFFB88C)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const FaIcon(
                                    FontAwesomeIcons.video,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.video['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (widget.video['level'] != null)
                                  _buildDetailChip(
                                    icon: FontAwesomeIcons.signal,
                                    label: 'Level ${widget.video['level']}',
                                    color: Colors.purple,
                                  ),
                                _buildDetailChip(
                                  icon: FontAwesomeIcons.star,
                                  label: '+${widget.video['points_reward'] ?? 10} points',
                                  color: Colors.amber,
                                ),
                                if (widget.video['duration_seconds'] != null)
                                  _buildDetailChip(
                                    icon: FontAwesomeIcons.clock,
                                    label: _formatDuration(widget.video['duration_seconds']),
                                    color: Colors.blue,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      if (widget.video['description'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
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
                                    child: const FaIcon(
                                      FontAwesomeIcons.alignLeft,
                                      color: AppColors.primary,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(context).aboutThisLesson,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.video['description'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade50, Colors.orange.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.orange.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).watchFullVideoToUnlock,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildVideoPlayerSection() {
    if (_controllerDisposed || _isExitingScreen) {
      return Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: AppColors.grey,
            size: 48,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: false,
          progressIndicatorColor: AppColors.primary,
          progressColors: ProgressBarColors(
            playedColor: Colors.red.shade600,
            handleColor: Colors.red.shade700,
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade400,
          ),
          onReady: () {
            // Video is ready
          },
          onEnded: (metaData) {
            // Video ended naturally
            if (!_hasMarkedAsWatched) {
              _hasMarkedAsWatched = true;
              _markVideoAsWatched();
            }
          },
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
          CustomBackButton(onPressed: _handleBackButton),
          
          Expanded(
            child: Center(
              child: Text(
                widget.video['title'] ?? 'Practice Video',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          // Placeholder for right side (to keep centered)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 14,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
}


