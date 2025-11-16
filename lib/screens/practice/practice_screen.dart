import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/practice_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/grammar_practice_service.dart';
import 'package:student/services/ai_story_service.dart';
import 'package:student/screens/practice/reading_screen.dart';
import 'package:student/screens/practice/grammar_practice_screen.dart';
import 'package:student/screens/ai_voice/ai_voice_assistant_screen.dart';
import 'package:student/config/app_colors.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../widgets/custom_back_button.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _practiceService = PracticeService();
  final _authService = AuthService();
  final _proService = ProSubscriptionService();
  final _grammarService = GrammarPracticeService();
  final _aiStoryService = AIStoryService();
  
  List<Map<String, dynamic>> _videos = [];
  Map<String, bool> _watchedVideos = {};
  bool _isLoading = true;
  bool _hasProSubscription = false;
  String? _errorMessage;
  String? _studentId;
  
  // Statistics for cards
  Map<String, dynamic> _grammarStats = {
    'total_questions': 0,
    'accuracy': 0.0,
  };
  int _storiesGenerated = 0;
  int _remainingStories = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
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
          _errorMessage = 'Please log in to access practice';
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
        _loadGrammarStats(),
        _loadReadingStats(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadVideosData() async {
    try {
      if (_studentId == null) return;

      // Get all practice videos
      final videos = await _practiceService.getPracticeVideos(null);

      // Get watched status for each video
      final watchedStatus = <String, bool>{};
      for (final video in videos) {
        final isWatched = await _practiceService.isVideoWatched(
          _studentId!,
          video['id'],
        );
        watchedStatus[video['id']] = isWatched;
      }

      setState(() {
        _videos = videos;
        _watchedVideos = watchedStatus;
      });
    } catch (e) {
      print('Error loading videos: $e');
    }
  }

  Future<void> _loadGrammarStats() async {
    try {
      if (_studentId == null) return;
      final stats = await _grammarService.getStatistics(_studentId!);
      setState(() {
        _grammarStats = stats;
      });
    } catch (e) {
      print('Error loading grammar stats: $e');
    }
  }

  Future<void> _loadReadingStats() async {
    try {
      if (_studentId == null) return;
      final remaining = await _aiStoryService.getRemainingStories(_studentId!);
      final history = await _aiStoryService.getStoryHistory(_studentId!);
      setState(() {
        _remainingStories = remaining;
        _storiesGenerated = history.length;
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
                  : _errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Practice Cards Grid
                        _buildPracticeCard(
                          title: 'Video Practice',
                          icon: FontAwesomeIcons.play,
                          color: Colors.red.shade400,
                          stat1Label: 'Completed',
                          stat1Value: '${_watchedVideos.values.where((w) => w).length}/${_videos.length}',
                          stat2Label: 'Progress',
                          stat2Value: _videos.isNotEmpty
                              ? '${((_watchedVideos.values.where((w) => w).length / _videos.length) * 100).toInt()}%'
                              : '0%',
                          onTap: () => _navigateToVideoPractice(),
                          isLocked: !_hasProSubscription,
                        ),
                        const SizedBox(height: 15),

                        _buildPracticeCard(
                          title: 'Reading Stories',
                          icon: FontAwesomeIcons.book,
                          color: Colors.blue.shade400,
                          stat1Label: 'Total Stories',
                          stat1Value: '$_storiesGenerated',
                          stat2Label: 'Remaining',
                          stat2Value: '$_remainingStories',
                          onTap: () => _navigateToReading(),
                          isLocked: !_hasProSubscription,
                        ),
                        const SizedBox(height: 15),

                        _buildPracticeCard(
                          title: 'Grammar Practice',
                          icon: FontAwesomeIcons.penToSquare,
                          color: Colors.purple.shade400,
                          stat1Label: 'Questions',
                          stat1Value: '${_grammarStats['total_questions'] ?? 0}',
                          stat2Label: 'Accuracy',
                          stat2Value: '${(_grammarStats['accuracy'] ?? 0.0).toInt()}%',
                          onTap: () => _navigateToGrammar(),
                          isLocked: !_hasProSubscription,
                        ),
                        const SizedBox(height: 15),

                        _buildPracticeCard(
                          title: 'AI Voice Tutor',
                          icon: FontAwesomeIcons.microphone,
                          color: Colors.orange.shade400,
                          stat1Label: 'Practice',
                          stat1Value: 'Anytime',
                          stat2Label: 'Status',
                          stat2Value: 'Active',
                          onTap: () => _navigateToAIVoice(),
                          isLocked: false,
                        ),
                                const SizedBox(height: 20),
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

  Widget _buildTopBar() {
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
          
          const Expanded(
            child: Center(
              child: Text(
                'PRACTICE',
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

  Widget _buildPracticeCard({
    required String title,
    required IconData icon,
    required Color color,
    required String stat1Label,
    required String stat1Value,
    required String stat2Label,
    required String stat2Value,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: isLocked ? _showProRequiredDialog : onTap,
      child: Container(
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
          children: [
            Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLocked ? Colors.grey.shade300 : color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                        child: FaIcon(
                          isLocked ? FontAwesomeIcons.lock : icon,
                          size: 30,
                          color: isLocked ? Colors.grey.shade600 : color,
                        ),
                ),
                const SizedBox(width: 15),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            FaIcon(FontAwesomeIcons.crown, size: 14, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'PRO Required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Stats
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(stat1Label, stat1Value, color),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _buildStatColumn(stat2Label, stat2Value, color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _navigateToVideoPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VideoPracticeListScreen(),
      ),
    ).then((_) => _loadAllData());
  }

  void _navigateToReading() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReadingScreen(),
      ),
    ).then((_) => _loadAllData());
  }

  void _navigateToGrammar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GrammarPracticeScreen(),
      ),
    ).then((_) => _loadAllData());
  }

  void _navigateToAIVoice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AiVoiceAssistantScreen(),
      ),
    );
  }

  void _showProRequiredDialog() {
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
            const Text(
              'PRO Required',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: const Text(
          'This practice type requires a PRO subscription. Please upgrade to access all features.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to profile/upgrade screen
            },
            icon: const FaIcon(FontAwesomeIcons.crown),
            label: const Text('Upgrade'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
              label: const Text('Retry'),
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
      final watchedStatus = <String, bool>{};
      for (final video in videos) {
        final isWatched = await _practiceService.isVideoWatched(
          _studentId!,
          video['id'],
        );
        watchedStatus[video['id']] = isWatched;
      }

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
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _videos.isEmpty
                          ? _buildEmptyState()
                          : _buildVideoList(),
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
                'VIDEO PRACTICE',
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

  Widget _buildErrorState() {
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
              const Text(
                'Unlock practice videos with a PRO subscription',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
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
              label: const Text('Retry'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.video,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Practice Videos Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check back later for new practice content!',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList() {
    return RefreshIndicator(
      onRefresh: _loadPracticeVideos,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.video,
                        color: Colors.red.shade400,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Practice Videos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Watch videos in order to unlock the next one',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildProgressIndicator(),
                    const SizedBox(width: 12),
                    Text(
                      '${_watchedVideos.values.where((w) => w).length} / ${_videos.length} completed',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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

  Widget _buildProgressIndicator() {
    final watchedCount = _watchedVideos.values.where((w) => w).length;
    final totalCount = _videos.length;
    final progress = totalCount > 0 ? watchedCount / totalCount : 0.0;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: AppColors.lightGrey,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            strokeWidth: 6,
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canWatch
              ? () => _openVideoPlayer(video)
              : () => _showLockedDialog(),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                // Video Number Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: canWatch
                        ? Colors.red.shade400
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: isWatched
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 28,
                          )
                        : !canWatch
                            ? Icon(
                                Icons.lock,
                                color: Colors.grey.shade600,
                                size: 24,
                              )
                            : Text(
                                '$number',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 15),

                // Video Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: canWatch ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      if (video['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          video['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: canWatch ? AppColors.textSecondary : AppColors.textHint,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (video['level'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Level ${video['level']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Points reward badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${video['points_reward'] ?? 10}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (video['duration_seconds'] != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(video['duration_seconds']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                FaIcon(
                  canWatch ? FontAwesomeIcons.play : FontAwesomeIcons.lock,
                  color: canWatch ? Colors.red.shade400 : Colors.grey[400],
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showLockedDialog() {
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
            const Text('Video Locked', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          'Please watch the previous video first to unlock this one.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
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
  bool _hasMarkedAsWatched = false;

  @override
  void initState() {
    super.initState();
    
    final videoId = widget.video['youtube_video_id'];
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        controlsVisibleAtStart: true,
        disableDragSeek: true, // Prevent skipping
        enableCaption: true,
      ),
    );

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isReady && !_hasMarkedAsWatched) {
      // Check if video is near the end (95% watched)
      final position = _controller.value.position.inSeconds;
      final duration = _controller.metadata.duration.inSeconds;
      
      if (duration > 0) {
        final percentage = (position / duration * 100).round();
        
        // Mark as watched when 95% complete
        if (percentage >= 95 && !_hasMarkedAsWatched) {
          _hasMarkedAsWatched = true;
          _markVideoAsWatched();
        }
      }
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
        // Show completion message with points
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Video completed! +$pointsReward points ✨'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Check if leveled up and show dialog
        if (result['leveledUp'] == true) {
          _showLevelUpDialog(
            result['previousLevel'],
            result['newLevel'],
            result['newPoints'],
          );
        }
        
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
    _controller.dispose();
    super.dispose();
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
            
            // Video Player
            YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: AppColors.primary,
            progressColors: ProgressBarColors(
              playedColor: AppColors.primary,
              handleColor: Colors.red.shade600,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (widget.video['level'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Level ${widget.video['level']}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.video['description'] != null) ...[
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.video['description'],
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Watch the entire video to unlock the next one!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
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
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back Icon
          const CustomBackButton(),
          
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
}

