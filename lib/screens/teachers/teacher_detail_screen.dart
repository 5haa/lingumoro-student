import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:student/services/teacher_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/rating_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/screens/teachers/subscription_screen.dart';
import 'package:student/screens/teachers/teacher_ratings_screen.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:student/widgets/custom_button.dart';
import 'package:student/l10n/app_localizations.dart';
import '../../config/app_colors.dart';

class TeacherDetailScreen extends StatefulWidget {
  final String teacherId;
  final String languageId;
  final String languageName;

  const TeacherDetailScreen({
    super.key,
    required this.teacherId,
    required this.languageId,
    required this.languageName,
  });

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final _teacherService = TeacherService();
  final _authService = AuthService();
  final _ratingService = RatingService();
  final _chatService = ChatService();
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _ratingStats;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myRating;
  bool _canRate = false;
  bool _isLoading = true;
  bool _hasSubscription = false;
  bool _isCheckingSubscription = true;
  YoutubePlayerController? _youtubeController;
  bool _isExitingScreen = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    
    try {
      // Start everything in parallel
      final teacherFuture = _teacherService.getTeacherWithSchedule(widget.teacherId);
      final statsFuture = _ratingService.getTeacherRatingStats(widget.teacherId);
      final reviewsFuture = _ratingService.getTeacherRatings(widget.teacherId);
      
      // Start subscription checks in parallel (fire and forget, they update state)
      _checkSubscription();
      _checkCanRate();
      
      final results = await Future.wait([
        teacherFuture,
        statsFuture,
        reviewsFuture,
      ]);
      
      final teacherData = results[0] as Map<String, dynamic>?;
      final ratingStats = results[1] as Map<String, dynamic>?;
      final reviews = results[2] as List<Map<String, dynamic>>;
      
      if (teacherData != null) {
        final schedules = teacherData['schedules'] as List<Map<String, dynamic>>? ?? [];
        
        if (mounted) {
          setState(() {
            _teacher = teacherData;
            _schedules = schedules;
            _ratingStats = ratingStats;
            _reviews = reviews;
            _isLoading = false;
          });
          
          // Initialize YouTube player if intro video exists
          _initializeYouTubePlayer();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkCanRate() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final canRate = await _ratingService.canRateTeacher(
        currentUser.id,
        widget.teacherId,
      );
      
      if (canRate) {
        final myRating = await _ratingService.getStudentRating(
          currentUser.id,
          widget.teacherId,
        );
        
        setState(() {
          _canRate = canRate;
          _myRating = myRating;
        });
      }
    } catch (e) {
      print('Error checking if can rate: $e');
    }
  }

  void _initializeYouTubePlayer() {
    final videoUrl = _teacher?['intro_video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: false,
            controlsVisibleAtStart: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposeYoutubeController();
    super.dispose();
  }

  void _disposeYoutubeController() {
    if (_youtubeController != null) {
      try {
        _youtubeController!.pause();
      } catch (_) {}
      _youtubeController!.dispose();
      _youtubeController = null;
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isExitingScreen) {
      setState(() {
        _isExitingScreen = true;
      });
      _disposeYoutubeController();
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return true;
  }

  Future<void> _handleBackNavigation() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _checkSubscription() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      setState(() => _isCheckingSubscription = false);
      return;
    }

    try {
      final hasSubscription = await _teacherService.hasActiveSubscription(
        currentUser.id,
        widget.teacherId,
      );
      
      setState(() {
        _hasSubscription = hasSubscription;
        _isCheckingSubscription = false;
      });
    } catch (e) {
      setState(() => _isCheckingSubscription = false);
    }
  }

  void _handleSubscribe() {
    final l10n = AppLocalizations.of(context);
    if (_hasSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.alreadySubscribedMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to subscription screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionScreen(
          teacherId: widget.teacherId,
          teacherName: _teacher?['full_name'] ?? l10n.teacherNamePlaceholder,
          languageId: widget.languageId,
          languageName: widget.languageName,
        ),
      ),
    );
  }

  void _navigateToRatingsScreen() {
    final l10n = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherRatingsScreen(
          teacherId: widget.teacherId,
          teacherName: _teacher?['full_name'] ?? l10n.teacherNamePlaceholder,
          teacherAvatar: _teacher?['avatar_url'],
        ),
      ),
    ).then((_) {
      // Reload data when returning from ratings screen
      _loadTeacherData();
    });
  }

  Future<void> _openChat() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.needSubscriptionToChat),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final teacherName = _teacher?['full_name'] ?? l10n.teacherNamePlaceholder;
    final teacherAvatar = _teacher?['avatar_url'];
    
    // Try to get/create conversation
    final conversation = await _chatService.getOrCreateConversation(widget.teacherId);
    
    if (conversation != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatConversationScreen(
            conversationId: conversation['id'],
            recipientId: widget.teacherId,
            recipientName: teacherName,
            recipientAvatar: teacherAvatar,
            recipientType: 'teacher',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToStartChat),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    if (_teacher == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_off,
                  size: 64,
                  color: AppColors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.teacherNotFoundTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.teacherNotFoundMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final averageRating = (_ratingStats?['average_rating'] as num?)?.toDouble() ?? 0.0;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teacher Info Section
                      _buildTeacherInfo(l10n, averageRating),
                      
                      const SizedBox(height: 20),
                      
                      // Video Section (Single Video)
                      if (_youtubeController != null && !_isExitingScreen) ...[
                        _buildVideoSection(),
                        const SizedBox(height: 30),
                      ],
                      
                      // Available Schedules Section
                      _buildSchedulesSection(l10n),
                      
                      const SizedBox(height: 30),
                      
                      // Subscribe Button
                      _buildSubscribeButton(l10n),
                      
                      const SizedBox(height: 24),
                      
                      // Ratings & Reviews Section (clickable)
                      _buildRatingsSection(l10n, averageRating),
                      
                      const SizedBox(height: 30),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CustomBackButton(onPressed: _handleBackNavigation),
          const Spacer(),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.message, size: 20),
            onPressed: _hasSubscription ? _openChat : null,
            color: _hasSubscription ? AppColors.primary : AppColors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherInfo(AppLocalizations l10n, double averageRating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(
        minHeight: 180,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Teacher Image - Left Side (Full Height)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  gradient: _teacher!['avatar_url'] == null ? AppColors.redGradient : null,
                ),
                child: _teacher!['avatar_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: _teacher!['avatar_url'],
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
                        memCacheWidth: 300, // Optimize
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.redGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.redGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            
            // Right Side Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Teacher Name
                    Text(
                      _teacher!['full_name'] ?? l10n.teacherNamePlaceholder,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Specialization (if available)
                    if (_teacher!['specialization'] != null)
                      Text(
                        _teacher!['specialization'],
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Rating
                    if (averageRating > 0)
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            if (index < averageRating.floor()) {
                              return const Icon(Icons.star, color: Colors.amber, size: 18);
                            } else if (index < averageRating) {
                              return const Icon(Icons.star_half, color: Colors.amber, size: 18);
                            } else {
                              return Icon(Icons.star_border, color: Colors.grey.shade300, size: 18);
                            }
                          }),
                          const SizedBox(width: 6),
                          Text(
                            '${averageRating.toStringAsFixed(1)} (${_ratingStats?['total_ratings'] ?? 0})',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Description/Bio
                    if (_teacher!['bio'] != null)
                      Text(
                        _teacher!['bio'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildVideoSection() {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        // Lock to portrait to prevent rotation when going fullscreen
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      onExitFullScreen: () {
        // Restore portrait orientation when exiting fullscreen
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
        progressColors: ProgressBarColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primaryDark,
        ),
      ),
      builder: (context, player) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: player,
          ),
        );
      },
    );
  }

  Widget _buildSchedulesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.availableSchedulesTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        _schedules.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 48,
                          color: AppColors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noScheduleAvailable,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _buildScheduleList(l10n),
      ],
    );
  }

  Widget _buildSubscribeButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: _hasSubscription
            ? l10n.subscriptionActive.toUpperCase()
            : l10n.subscribe.toUpperCase(),
        onPressed: _isCheckingSubscription ? () {} : _handleSubscribe,
        isLoading: _isCheckingSubscription,
      ),
    );
  }

  Widget _buildScheduleList(AppLocalizations l10n) {
    // Group schedules by day
    final Map<int, List<String>> schedulesByDay = {};
    for (var schedule in _schedules) {
      final day = schedule['day_of_week'] as int;
      final startTime = schedule['start_time'] as String;
      final endTime = schedule['end_time'] as String;
      final timeString = '${_formatTime(startTime)} - ${_formatTime(endTime)}';
      
      if (!schedulesByDay.containsKey(day)) {
        schedulesByDay[day] = [];
      }
      schedulesByDay[day]!.add(timeString);
    }

    // Create a list of all 7 days, marking which ones have schedules
    final List<Map<String, dynamic>> calendarDays = [
      {
        'day': 0,
        'name': l10n.sun,
        'hasSchedule': schedulesByDay.containsKey(0),
        'times': schedulesByDay[0] ?? [],
      },
      {
        'day': 1,
        'name': l10n.mon,
        'hasSchedule': schedulesByDay.containsKey(1),
        'times': schedulesByDay[1] ?? [],
      },
      {
        'day': 2,
        'name': l10n.tue,
        'hasSchedule': schedulesByDay.containsKey(2),
        'times': schedulesByDay[2] ?? [],
      },
      {
        'day': 3,
        'name': l10n.wed,
        'hasSchedule': schedulesByDay.containsKey(3),
        'times': schedulesByDay[3] ?? [],
      },
      {
        'day': 4,
        'name': l10n.thu,
        'hasSchedule': schedulesByDay.containsKey(4),
        'times': schedulesByDay[4] ?? [],
      },
      {
        'day': 5,
        'name': l10n.fri,
        'hasSchedule': schedulesByDay.containsKey(5),
        'times': schedulesByDay[5] ?? [],
      },
      {
        'day': 6,
        'name': l10n.sat,
        'hasSchedule': schedulesByDay.containsKey(6),
        'times': schedulesByDay[6] ?? [],
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calendar Grid - Horizontally Scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Container(
              width: 700, // Fixed width to make it scrollable
              child: Column(
                children: [
                  // Calendar Grid Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: calendarDays.map((day) {
                        return SizedBox(
                          width: 90,
                          child: Center(
                            child: Text(
                              (day['name'] as String).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // Calendar Grid Body
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: calendarDays.map((day) {
                        final hasSchedule = day['hasSchedule'] as bool;
                        final times = day['times'] as List<String>;
                        
                        return Container(
                          width: 90,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: hasSchedule 
                                ? AppColors.primary.withOpacity(0.05)
                                : AppColors.lightGrey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: hasSchedule
                                ? Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1.5,
                                  )
                                : Border.all(
                                    color: AppColors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                          ),
                          child: Column(
                            children: [
                              // Times - Show all times
                              if (hasSchedule)
                                Column(
                                  children: times.map((time) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.redGradient,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.2),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              if (!hasSchedule)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.grey.withOpacity(0.3),
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
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

  String _formatTime(String time) {
    // Format time from "HH:MM:SS" to "HH:MM AM/PM"
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '$hour:$minute $period';
    } catch (e) {
      return time;
    }
  }

  Widget _buildRatingsSection(AppLocalizations l10n, double averageRating) {
    final totalRatings = _ratingStats?['total_ratings'] as int? ?? 0;
    final hasRatings = totalRatings > 0;

    return GestureDetector(
      onTap: _navigateToRatingsScreen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: _navigateToRatingsScreen,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Left side - Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rate_review,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              
              const SizedBox(width: 14),
              
              // Middle - Text and rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ratingsAndReviewsTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasRatings)
                      Row(
                        children: [
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ...List.generate(5, (index) {
                            if (index < averageRating.floor()) {
                              return const Icon(Icons.star, color: Colors.amber, size: 14);
                            } else if (index < averageRating) {
                              return const Icon(Icons.star_half, color: Colors.amber, size: 14);
                            } else {
                              return Icon(Icons.star_border, color: Colors.grey.shade300, size: 14);
                            }
                          }),
                          const SizedBox(width: 6),
                          Text(
                            '($totalRatings)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        l10n.noReviewsYet,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (_canRate) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: AppColors.primary,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _myRating != null
                                  ? l10n.updateRatingButton
                                  : l10n.rateButton,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Right side - Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


