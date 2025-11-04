import 'package:flutter/material.dart';
import 'package:student/services/teacher_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/screens/teachers/package_selection_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  bool _hasSubscription = false;
  bool _isCheckingSubscription = true;
  YoutubePlayerController? _youtubeController;

  final List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    
    try {
      final teacherData = await _teacherService.getTeacherWithSchedule(widget.teacherId);
      
      if (teacherData != null) {
        final schedules = teacherData['schedules'] as List<Map<String, dynamic>>? ?? [];
        
        setState(() {
          _teacher = teacherData;
          _schedules = schedules;
          _isLoading = false;
        });
        
        // Initialize YouTube player if intro video exists
        _initializeYouTubePlayer();
        
        // Check if student has subscription
        _checkSubscription();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
            enableCaption: true,
            controlsVisibleAtStart: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
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
    if (_hasSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription with this teacher'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to package selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageSelectionScreen(
          teacherId: widget.teacherId,
          teacherName: _teacher?['full_name'] ?? 'Teacher',
          languageId: widget.languageId,
          languageName: widget.languageName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_teacher == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Not Found'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Teacher not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_teacher!['full_name'] ?? 'Teacher'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher Header Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade600,
                    Colors.deepPurple.shade800,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Hero(
                    tag: 'teacher_${widget.teacherId}',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _teacher!['avatar_url'] != null
                            ? CachedNetworkImage(
                                imageUrl: _teacher!['avatar_url'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.deepPurple,
                                ),
                              ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    _teacher!['full_name'] ?? 'Teacher',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Specialization
                  if (_teacher!['specialization'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _teacher!['specialization'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Intro Video Section
            if (_youtubeController != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Introduction Video',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: YoutubePlayer(
                        controller: _youtubeController!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: Colors.deepPurple,
                        progressColors: ProgressBarColors(
                          playedColor: Colors.deepPurple,
                          handleColor: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

            // About Section
            if (_teacher!['bio'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _teacher!['bio'],
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Weekly Schedule Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Schedule',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _schedules.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No schedule available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildScheduleList(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Subscribe Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCheckingSubscription ? null : _handleSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubscription
                        ? Colors.grey
                        : Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCheckingSubscription
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _hasSubscription
                              ? 'Already Subscribed'
                              : 'Subscribe to ${_teacher!['full_name']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    // Group schedules by day
    final Map<int, List<Map<String, dynamic>>> schedulesByDay = {};
    for (var schedule in _schedules) {
      final day = schedule['day_of_week'] as int;
      if (!schedulesByDay.containsKey(day)) {
        schedulesByDay[day] = [];
      }
      schedulesByDay[day]!.add(schedule);
    }

    return Column(
      children: schedulesByDay.entries.map((entry) {
        final dayOfWeek = entry.key;
        final daySchedules = entry.value;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurple.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dayNames[dayOfWeek],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: daySchedules.map((schedule) {
                    final startTime = schedule['start_time'] as String;
                    final endTime = schedule['end_time'] as String;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
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
        );
      }).toList(),
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
}


