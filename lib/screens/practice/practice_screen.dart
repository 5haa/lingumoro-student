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
  
  List<Map<String, dynamic>> _videos = [];
  Map<String, bool> _watchedVideos = {};
  bool _isLoading = false;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  
  // Statistics for cards
  Map<String, dynamic> _quizStats = {
    'total_sessions': 0,
    'total_questions': 0,
    'accuracy': 0.0,
  };
  int _completedReadings = 0;
  int _totalReadings = 0;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _loadDataFromCache();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this screen (e.g., after activation in Profile)
    if (mounted && !_isLoading) {
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

  Future<void> _loadAllData() async {
    final l10n = AppLocalizations.of(context);
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
      final stats = await _quizService.getStatistics(_studentId!);
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
                        _buildPracticeCard(
                          title: l10n.languageQuiz,
                          icon: FontAwesomeIcons.penToSquare,
                          emoji: '✏️',
                          color: Colors.orange.shade600,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF9966), Color(0xFFFF6B6B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          stat2Label: '${_quizStats['total_sessions'] ?? 0} ${l10n.quizzes}',
                          onTap: () => _navigateToQuiz(),
                          isLocked: false,
                          showProgress: false,
                        ),
                        const SizedBox(height: 12),

                        _buildPracticeCard(
                          title: l10n.aiVoicePractice,
                          icon: FontAwesomeIcons.microphone,
                          emoji: '🎙️',
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
                        ),
                        const SizedBox(height: 12),

                        _buildPracticeCard(
                          title: l10n.readings,
                          icon: FontAwesomeIcons.book,
                          emoji: '📖',
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
                        ),
                        const SizedBox(height: 12),

                        _buildPracticeCard(
                          title: l10n.videos,
                          icon: FontAwesomeIcons.play,
                          emoji: '📹',
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
    String emoji = '📚',
    required LinearGradient gradient,
    bool showProgress = false,
    int? progressValue,
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
              : gradient,
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
              // Emoji
              Text(
                isLocked ? '🔒' : emoji,
                style: const TextStyle(fontSize: 42),
              ),
              
              const SizedBox(height: 12),
              
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Badges row
              Wrap(
                spacing: 6,
                children: [
                  _buildBadge(stat2Label, color),
                  if (isLocked)
                    _buildBadge(l10n.proFeature, Colors.amber.shade700),
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
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isLocked ? '0%' : '${progressValue ?? 0}% ${l10n.completed}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.9),
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
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildBadge(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AIVoicePracticeScreen(),
        ),
      ).then((_) {
        _preloadService.invalidatePractice();
        _loadAllData();
      });
    }
  }

  void _navigateToVideoPractice() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VideoPracticeListScreen(),
        ),
      ).then((_) {
        _preloadService.invalidatePractice();
        _loadAllData();
      });
    }
  }

  void _navigateToReading() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReadingScreen(),
        ),
      ).then((_) {
        _preloadService.invalidatePractice();
        _loadAllData();
      });
    }
  }

  void _navigateToQuiz() async {
    if (await _checkProBeforeNavigation()) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QuizPracticeScreen(),
        ),
      ).then((_) {
        _preloadService.invalidatePractice();
        _loadAllData();
      });
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
  
  List<Map<String, dynamic>> _videos = [];
  Map<String, bool> _watchedVideos = {};
  bool _isLoading = true;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _loadPracticeVideos();
  }

  Future<void> _loadPracticeVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

      final videos = await _practiceService.getPracticeVideos(null);
      
      // OPTIMIZATION: Batch query for watched status
      final videoIds = videos.map((v) => v['id'] as String).toList();
      final watchedStatus = await _practiceService.getWatchedStatusBatch(_studentId!, videoIds);

      setState(() {
        _videos = videos;
        _watchedVideos = watchedStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load practice videos: ${e.toString()}';
      });
    }
  }

  bool _canWatchVideo(int index) {
    if (index == 0) return true;
    if (index > 0) {
      final previousVideo = _videos[index - 1];
      return _watchedVideos[previousVideo['id']] ?? false;
    }
    return false;
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
                      : _videos.isEmpty
                          ? _buildEmptyState()
                          : _buildVideoList(),
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

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade50, Colors.red.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: FaIcon(
                FontAwesomeIcons.video,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.noVideosYet,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.videosComingSoon,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'New videos coming soon',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildVideoList() {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadPracticeVideos,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero Header with Gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFED4264), Color(0xFFFFEDBC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📹', style: TextStyle(fontSize: 48)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.videoPracticeTitle,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.videos} ${_videos.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.overallProgress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_watchedVideos.values.where((w) => w).length}/${_videos.length} ${l10n.completed}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _videos.isNotEmpty 
                            ? _watchedVideos.values.where((w) => w).length / _videos.length 
                            : 0,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_videos.isNotEmpty ? ((_watchedVideos.values.where((w) => w).length / _videos.length) * 100).toInt() : 0}% ${l10n.completed}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(
                  FontAwesomeIcons.listUl,
                  color: Colors.red.shade600,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.lessonPlaylist,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Videos List
          ...List.generate(_videos.length, (index) {
            final video = _videos[index];
            final isWatched = _watchedVideos[video['id']] ?? false;
            final canWatch = _canWatchVideo(index);
            
            return _buildVideoCard(video, index + 1, isWatched, canWatch);
          }),
        ],
      ),
    );
  }

  Widget _buildVideoCard(
    Map<String, dynamic> video,
    int number,
    bool isWatched,
    bool canWatch,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isWatched 
            ? Border.all(color: Colors.green.shade300, width: 2)
            : Border.all(color: AppColors.border.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: isWatched 
                ? Colors.green.withOpacity(0.1)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canWatch
              ? () => _openVideoPlayer(video)
              : () => _showLockedDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Enhanced Thumbnail/Number Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: isWatched
                            ? LinearGradient(
                                colors: [Colors.green.shade400, Colors.green.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : canWatch
                                ? const LinearGradient(
                                    colors: [Color(0xFFED4264), Color(0xFFFFB88C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isWatched ? Colors.green : canWatch ? Colors.red : Colors.grey)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isWatched
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 36,
                              )
                            : !canWatch
                                ? const Icon(
                                    Icons.lock_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : const FaIcon(
                                    FontAwesomeIcons.play,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                      ),
                    ),
                    if (!isWatched && canWatch)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$number',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Video Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              video['title'] ?? 'Untitled',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: canWatch ? AppColors.textPrimary : AppColors.textSecondary,
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
                                borderRadius: BorderRadius.circular(6),
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
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (video['description'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          video['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: canWatch ? AppColors.textSecondary : AppColors.textHint,
                            height: 1.3,
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
                          if (video['duration_seconds'] != null)
                            _buildInfoChip(
                              icon: FontAwesomeIcons.clock,
                              text: _formatDuration(video['duration_seconds']),
                              color: Colors.blue,
                            ),
                          if (video['level'] != null)
                            _buildInfoChip(
                              icon: FontAwesomeIcons.signal,
                              text: '${l10n.level} ${video['level']}',
                              color: Colors.purple,
                            ),
                          _buildInfoChip(
                            icon: FontAwesomeIcons.star,
                            text: '+${video['points_reward'] ?? 10}',
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      if (!canWatch) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.completePreviousVideoToUnlock,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow Icon
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: canWatch 
                        ? Colors.red.shade50 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(
                    canWatch ? FontAwesomeIcons.chevronRight : FontAwesomeIcons.lock,
                    color: canWatch ? Colors.red.shade600 : Colors.grey.shade400,
                    size: 16,
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

  void _openVideoPlayer(Map<String, dynamic> video) {
    Navigator.push(
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
  final _levelService = LevelService();
  final _pointsNotificationService = PointsNotificationService();
  bool _hasMarkedAsWatched = false;
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
      Navigator.of(context).pop();
    }
  }

  Future<void> _markVideoAsWatched() async {
    try {
      // Mark video as watched
      await _practiceService.markVideoAsWatched(
        widget.studentId,
        widget.video['id'],
      );
      
      // Award points
      final pointsReward = (widget.video['points_reward'] as int?) ?? 10;
      final result = await _levelService.awardPoints(
        widget.studentId,
        pointsReward,
      );
      
      if (mounted) {
        // Show points notification using the new service
        _pointsNotificationService.showPointsEarnedNotification(
          context: context,
          pointsGained: pointsReward,
          message: 'Video completed! +$pointsReward points ✨',
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


