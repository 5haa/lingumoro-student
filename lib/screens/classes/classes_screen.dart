import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flag/flag.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../services/session_service.dart';
import '../../services/session_update_service.dart';
import '../../services/chat_service.dart';
import '../../services/preload_service.dart';
import '../chat/chat_conversation_screen.dart';
import '../teachers/teacher_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/error_helper.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({Key? key}) : super(key: key);

  @override
  _ClassesScreenState createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final SessionService _sessionService = SessionService();
  final SessionUpdateService _sessionUpdateService = SessionUpdateService();
  final ChatService _chatService = ChatService();
  final PreloadService _preloadService = PreloadService();
  
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _finishedSessions = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessionsFromCache();
    
    // Listen for session updates
    _sessionUpdateService.addListener(_handleSessionUpdate);
  }

  @override
  void dispose() {
    _sessionUpdateService.removeListener(_handleSessionUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _handleSessionUpdate() {
    _preloadService.invalidateSessions();
    _loadSessions();
  }

  void _loadSessionsFromCache() {
    // Try to load from cache first
    final cached = _preloadService.sessions;
    if (cached != null) {
      final now = DateTime.now();
      final upcomingSessions = <Map<String, dynamic>>[];
      final finishedSessions = List<Map<String, dynamic>>.from(cached.finished);
      
      // Filter cached upcoming sessions: move expired ones to finished
      for (var session in cached.upcoming) {
        try {
          final scheduledDate = DateTime.parse(session['scheduled_date']);
          final startTime = session['scheduled_start_time'] ?? '00:00:00';
          final timeParts = startTime.split(':');
          final scheduledDateTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
          
          final status = session['status'] ?? '';
          // Move to finished if: completed, cancelled, or time has passed (unless in_progress)
          if (status == 'completed' || status == 'cancelled' || status == 'missed' ||
              (scheduledDateTime.isBefore(now) && status != 'in_progress')) {
            finishedSessions.add(session);
          } else {
            upcomingSessions.add(session);
          }
        } catch (e) {
          // If parsing fails, keep in upcoming
          upcomingSessions.add(session);
        }
      }
      
      // Sort upcoming sessions
      upcomingSessions.sort((a, b) {
        try {
          final fullDateTimeA = DateTime.parse('${a['scheduled_date']} ${a['scheduled_start_time'] ?? '00:00:00'}');
          final fullDateTimeB = DateTime.parse('${b['scheduled_date']} ${b['scheduled_start_time'] ?? '00:00:00'}');
          return fullDateTimeA.compareTo(fullDateTimeB);
        } catch (e) {
          return 0;
        }
      });
      
      setState(() {
        _upcomingSessions = upcomingSessions;
        _finishedSessions = finishedSessions;
        _isLoading = false;
      });
      print('✅ Loaded sessions from cache');
      return;
    }
    
    // No cache, load from API
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      // Load both upcoming and finished sessions in parallel
      final results = await Future.wait([
        _sessionService.getUpcomingSessions(),
        _sessionService.getPastSessions(),
      ]);
      
      final upcomingSessions = <Map<String, dynamic>>[];
      final finishedSessions = List<Map<String, dynamic>>.from(results[1]);
      final now = DateTime.now();
      
      // Filter sessions: move expired ones to finished
      for (var session in results[0]) {
        try {
          final scheduledDate = DateTime.parse(session['scheduled_date']);
          final startTime = session['scheduled_start_time'] ?? '00:00:00';
          final timeParts = startTime.split(':');
          final scheduledDateTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
          
          final status = session['status'] ?? '';
          // Move to finished if: completed, cancelled, or time has passed (unless in_progress)
          if (status == 'completed' || status == 'cancelled' || status == 'missed' ||
              (scheduledDateTime.isBefore(now) && status != 'in_progress')) {
            finishedSessions.add(session);
          } else {
            upcomingSessions.add(session);
          }
        } catch (e) {
          // If parsing fails, check status
          final status = session['status'] ?? '';
          if (status == 'completed' || status == 'cancelled' || status == 'missed') {
            finishedSessions.add(session);
          } else {
            upcomingSessions.add(session);
          }
        }
      }
      
      // Sort upcoming sessions by date and time - closest to start at the top
      upcomingSessions.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['scheduled_date']);
          final dateB = DateTime.parse(b['scheduled_date']);
          
          final timeA = a['scheduled_start_time'] ?? '00:00:00';
          final timeB = b['scheduled_start_time'] ?? '00:00:00';
          
          final fullDateTimeA = DateTime.parse('${a['scheduled_date']} $timeA');
          final fullDateTimeB = DateTime.parse('${b['scheduled_date']} $timeB');
          
          return fullDateTimeA.compareTo(fullDateTimeB);
        } catch (e) {
          return 0;
        }
      });
      
      // Sort finished sessions by date and time - most recent first
      finishedSessions.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['scheduled_date']);
          final dateB = DateTime.parse(b['scheduled_date']);
          
          final timeA = a['scheduled_start_time'] ?? '00:00:00';
          final timeB = b['scheduled_start_time'] ?? '00:00:00';
          
          final fullDateTimeA = DateTime.parse('${a['scheduled_date']} $timeA');
          final fullDateTimeB = DateTime.parse('${b['scheduled_date']} $timeB');
          
          return fullDateTimeB.compareTo(fullDateTimeA);
        } catch (e) {
          return 0;
        }
      });
      
      // Cache the sessions
      _preloadService.cacheSessions(
        upcoming: upcomingSessions,
        finished: finishedSessions,
      );
      
      setState(() {
        _upcomingSessions = upcomingSessions;
        _finishedSessions = finishedSessions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getUserFriendlyError(e)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinSession(Map<String, dynamic> session) async {
    final meetingLink = session['meeting_link'];
    if (meetingLink == null || meetingLink.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).meetingLinkNotAvailable),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      String url = meetingLink.toString().trim();
      
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open the meeting link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorJoiningSession} ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openChatWithTeacher(Map<String, dynamic> session) async {
    try {
      final teacher = session['teacher'];
      if (teacher == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).teacherInformationNotAvailable),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final teacherId = teacher['id'];
      final teacherName = teacher['full_name'] ?? 'Teacher';
      final teacherAvatar = teacher['avatar_url'];

      // Get or create conversation
      final conversation = await _chatService.getOrCreateConversation(teacherId);
      
      if (conversation != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversationId: conversation['id'],
              recipientId: teacherId,
              recipientName: teacherName,
              recipientAvatar: teacherAvatar,
              recipientType: 'teacher',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).unableToStartChat),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorOpeningChat} ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
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
                        AppLocalizations.of(context).myClasses,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 45), // Balance the menu button
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: AppLocalizations.of(context).upcoming),
                  Tab(text: AppLocalizations.of(context).finished),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Upcoming Classes
                        RefreshIndicator(
                          onRefresh: _loadSessions,
                          color: AppColors.primary,
                          child: _buildClassesList(_upcomingSessions, isUpcoming: true),
                        ),
                        // Finished Classes
                        RefreshIndicator(
                          onRefresh: _loadSessions,
                          color: AppColors.primary,
                          child: _buildClassesList(_finishedSessions, isUpcoming: false),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList(List<Map<String, dynamic>> classes,
      {required bool isUpcoming}) {
    if (classes.isEmpty) {
      // Wrap in ListView to enable pull-to-refresh even when empty
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.calendarXmark,
                    size: 60,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isUpcoming ? AppLocalizations.of(context).noUpcomingClasses : AppLocalizations.of(context).noFinishedClasses,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary.withOpacity(0.6),
                    ),
                  ),
                  if (isUpcoming) ...[
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context).subscribeToSeeClasses,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Icon(
                      Icons.arrow_downward,
                      color: AppColors.textSecondary.withOpacity(0.3),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).pullDownToRefresh,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classData = classes[index];
        return _buildClassCard(classData, isUpcoming: isUpcoming);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> session,
      {required bool isUpcoming}) {
    final teacher = session['teacher'] ?? {};
    final language = session['language'] ?? {};
    final subscription = session['subscription'] ?? {};

    final sessionStatus = _sessionService.getSessionStatus(session);
    final canJoin = _sessionService.canJoinSession(session);
    final timeUntil = _sessionService.getTimeUntilSession(session);
    final isMakeup = session['is_makeup'] == true;
    final isTeacherCreated = session['teacher_created'] == true;
    final isCancelled = session['status'] == 'cancelled';

    final scheduledDate = DateTime.parse(session['scheduled_date']);
    final dateStr =
        '${_getWeekday(scheduledDate.weekday)}, ${scheduledDate.day}';
    final monthStr = '${_getMonth(scheduledDate.month)} ${scheduledDate.year}';
    final timeStr =
        '${session['scheduled_start_time']?.substring(0, 5)} : ${session['scheduled_end_time']?.substring(0, 5)}';

    // Calculate duration
    final startTime = session['scheduled_start_time'];
    final endTime = session['scheduled_end_time'];
    String duration = '45 ${AppLocalizations.of(context).min}'; // default
    if (startTime != null && endTime != null) {
      try {
        final start = DateTime.parse('2000-01-01 $startTime');
        final end = DateTime.parse('2000-01-01 $endTime');
        final diff = end.difference(start).inMinutes;
        duration = '$diff ${AppLocalizations.of(context).min}';
      } catch (e) {
        // Keep default
      }
    }

    // Get flag code from language name
    FlagsCode? flagCode = _getFlagCodeFromLanguage(language['name'] ?? '');

    final isInProgress = session['status'] == 'in_progress';
    
    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: isInProgress 
            ? Border.all(color: Colors.green.shade400, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isInProgress 
                ? Colors.green.withOpacity(0.15)
                : Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Makeup session indicator
          if (isMakeup) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.orange.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).makeupClass,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Cancelled session indicator
          if (isCancelled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.red.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).cancelled,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Teacher-created session indicator
          if (isTeacherCreated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).extraClass,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Live indicator for in-progress sessions
          if (isInProgress) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).liveNow,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Language and Flag
          Row(
            children: [
              if (flagCode != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Flag.fromCode(
                      flagCode,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (language['flag_url'] != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: language['flag_url'],
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      memCacheWidth: 120,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.language,
                        size: 30,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.language,
                    size: 25,
                    color: AppColors.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                '${language['name'] ?? 'Language'} ${AppLocalizations.of(context).languageClass}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Teacher Info
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: teacher['avatar_url'] != null
                          ? CachedNetworkImage(
                              imageUrl: teacher['avatar_url'],
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholderFadeInDuration: Duration.zero,
                              memCacheWidth: 120,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person, color: Colors.grey, size: 20),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person, color: Colors.grey, size: 20),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.person, color: Colors.grey, size: 20),
                            ),
                    ),
                  ),
                  // Online indicator - you can add logic to check if teacher is online
                  if (teacher['is_online'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  teacher['full_name'] ?? AppLocalizations.of(context).teacherNamePlaceholder,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const FaIcon(
                    FontAwesomeIcons.comment,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _openChatWithTeacher(session),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),

          const SizedBox(height: 12),

          // Date and Time Info
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.calendar,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        monthStr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).yourTime, // You can add timezone logic here
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Duration
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.clock,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).classDuration,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                duration,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Join Button or Status (only for upcoming classes)
          if (isUpcoming) ...[
            if (canJoin) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _joinSession(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6BB6D6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.link,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).join,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (session['meeting_link'] == null ||
                session['meeting_link'].toString().isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).waitingForMeetingLink,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: timeUntil == 'Now' 
                      ? Colors.green.shade50 
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      timeUntil == 'Now' ? Icons.play_circle : Icons.schedule, 
                      color: timeUntil == 'Now' 
                          ? Colors.green.shade700 
                          : Colors.blue.shade700, 
                      size: 18
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeUntil == 'Now' 
                          ? AppLocalizations.of(context).waitingForTeacherToStart 
                          : '${AppLocalizations.of(context).startsIn} $timeUntil',
                      style: TextStyle(
                        color: timeUntil == 'Now' 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // For finished sessions, show status-specific message
            const SizedBox(height: 12),
            if (isCancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).classWasCancelled,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (session['teacher_notes'] != null && session['teacher_notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.red.shade600, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                session['teacher_notes'],
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).tapToViewTeacherAndRate,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
    
    // Wrap finished sessions in GestureDetector to navigate to teacher details
    // But not for cancelled sessions
    if (!isUpcoming && session['status'] == 'completed') {
      return GestureDetector(
        onTap: () => _navigateToTeacherDetail(session),
        child: cardWidget,
      );
    }
    
    return cardWidget;
  }
  
  void _navigateToTeacherDetail(Map<String, dynamic> session) {
    final teacher = session['teacher'] ?? {};
    final language = session['language'] ?? {};
    
    final teacherId = teacher['id'];
    final languageId = language['id'];
    final languageName = language['name'];
    
    if (teacherId == null || languageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).unableToLoadTeacherDetails),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherDetailScreen(
          teacherId: teacherId,
          languageId: languageId,
          languageName: languageName ?? 'Language',
        ),
      ),
    );
  }

  FlagsCode? _getFlagCodeFromLanguage(String languageName) {
    final name = languageName.toLowerCase();
    if (name.contains('english')) return FlagsCode.GB;
    if (name.contains('spanish')) return FlagsCode.ES;
    if (name.contains('french')) return FlagsCode.FR;
    if (name.contains('german')) return FlagsCode.DE;
    if (name.contains('italian')) return FlagsCode.IT;
    if (name.contains('portuguese')) return FlagsCode.PT;
    if (name.contains('chinese')) return FlagsCode.CN;
    if (name.contains('japanese')) return FlagsCode.JP;
    if (name.contains('korean')) return FlagsCode.KR;
    if (name.contains('arabic')) return FlagsCode.SA;
    if (name.contains('russian')) return FlagsCode.RU;
    if (name.contains('turkish')) return FlagsCode.TR;
    if (name.contains('dutch')) return FlagsCode.NL;
    if (name.contains('polish')) return FlagsCode.PL;
    if (name.contains('swedish')) return FlagsCode.SE;
    if (name.contains('norwegian')) return FlagsCode.NO;
    if (name.contains('danish')) return FlagsCode.DK;
    if (name.contains('finnish')) return FlagsCode.FI;
    return null;
  }

  String _getWeekday(int weekday) {
    final loc = AppLocalizations.of(context);
    final weekdays = [loc.mon, loc.tue, loc.wed, loc.thu, loc.fri, loc.sat, loc.sun];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    final loc = AppLocalizations.of(context);
    final months = [
      loc.january,
      loc.february,
      loc.march,
      loc.april,
      loc.may,
      loc.june,
      loc.july,
      loc.august,
      loc.september,
      loc.october,
      loc.november,
      loc.december
    ];
    return months[month - 1];
  }
}
