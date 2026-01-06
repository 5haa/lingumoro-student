import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/student_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/session_update_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/screens/students/student_public_profile_screen.dart';
import 'package:student/screens/chat/chat_requests_screen.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
import 'package:student/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _studentService = StudentService();
  final _chatService = ChatService();
  final _proService = ProSubscriptionService();
  final _authService = AuthService();
  final _sessionUpdateService = SessionUpdateService();
  final _preloadService = PreloadService();
  List<Map<String, dynamic>> _students = [];
  List<String> _myLanguages = [];
  List<Map<String, dynamic>> _sentRequests = [];
  Map<String, String> _chatRequestStatus = {}; // studentId -> status
  Map<String, bool> _isRecipientOfRequest = {}; // studentId -> isRecipient
  Map<String, String> _chatRequestIds = {}; // studentId -> requestId
  bool _isLoading = true;
  bool _hasProSubscription = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentsFromCache();
    // Listen for subscription updates (when student subscribes to a course)
    _sessionUpdateService.addListener(_handleSubscriptionUpdate);
  }

  @override
  void dispose() {
    _sessionUpdateService.removeListener(_handleSubscriptionUpdate);
    super.dispose();
  }

  void _handleSubscriptionUpdate() {
    // Invalidate cache and reload when subscriptions change
    _preloadService.invalidateStudents();
    _loadStudents(forceRefresh: true);
  }

  void _loadStudentsFromCache() {
    // Try to load from cache first
    final cached = _preloadService.students;
    if (cached != null && cached.isNotEmpty) {
      // Check if enrollment hasn't changed
      final cachedEnrollment = _preloadService.enrolledLanguages;
      if (cachedEnrollment != null) {
        setState(() {
          _students = cached;
          _myLanguages = cachedEnrollment;
          _hasProSubscription = _preloadService.proSubscription != null;
          _isLoading = false;
        });
        print('✅ Loaded ${cached.length} students from cache');
        
        // Still fetch chat status since it's real-time
        _loadChatStatus();
        return;
      }
    }
    
    // No cache, load from API
    _loadStudents(forceRefresh: false);
  }

  Future<void> _loadChatStatus() async {
    final currentUserId = _chatService.supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final statusMap = <String, String>{};
    final recipientMap = <String, bool>{};
    final requestIdMap = <String, String>{};
    
    try {
      final allRequests = await _chatService.supabase
          .from('chat_requests')
          .select('id, status, requester_id, recipient_id')
          .or('requester_id.eq.$currentUserId,recipient_id.eq.$currentUserId');

      for (var request in allRequests) {
        final requesterId = request['requester_id'] as String;
        final recipientId = request['recipient_id'] as String;
        
        String otherStudentId;
        if (requesterId == currentUserId) {
          otherStudentId = recipientId;
        } else {
          otherStudentId = requesterId;
        }
        
        statusMap[otherStudentId] = request['status'] as String;
        requestIdMap[otherStudentId] = request['id'] as String;
        recipientMap[otherStudentId] = recipientId == currentUserId;
      }
      
      final sentRequests = await _chatService.getSentChatRequests();
      
      if (mounted) {
        setState(() {
          _chatRequestStatus = statusMap;
          _isRecipientOfRequest = recipientMap;
          _chatRequestIds = requestIdMap;
          _sentRequests = sentRequests;
        });
      }
    } catch (e) {
      print('Error loading chat status: $e');
    }
  }

  Future<void> _loadStudents({bool forceRefresh = false}) async {
    final stopwatch = Stopwatch()..start();
    print('⏱️ START: Loading students (Parallel Mode)...');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final studentId = _authService.currentUser?.id;
      final currentUserId = _chatService.supabase.auth.currentUser?.id;

      // 1. Start independent tasks in parallel
      
      // Task A: Check PRO (Removed restriction, just checking for UI if needed or defaulting to true)
      // We no longer block access based on PRO, so we can treat everyone as having access
      Future<bool> proFuture = Future.value(true);

      // Task B: Chat Requests (Optimized Single Query)
      // Chat requests are real-time, so we fetch fresh (but optimized)
      Future<List<Map<String, dynamic>>> chatRequestsFuture;
      if (currentUserId != null) {
        chatRequestsFuture = _chatService.supabase
            .from('chat_requests')
            .select('id, status, requester_id, recipient_id')
            .or('requester_id.eq.$currentUserId,recipient_id.eq.$currentUserId');
      } else {
        chatRequestsFuture = Future.value([]);
      }

      // Task C: Sent Requests (Legacy)
      final sentRequestsFuture = _chatService.getSentChatRequests();

      // Task D: Get Languages (Use Cache if available)
      final langStart = stopwatch.elapsedMilliseconds;
      Future<List<String>> languagesFuture;
      if (_preloadService.hasEnrolledLanguages && _preloadService.enrolledLanguages != null) {
        languagesFuture = Future.value(_preloadService.enrolledLanguages!);
        print('⏱️ Languages used CACHE');
      } else {
        languagesFuture = _studentService.getStudentLanguages();
      }
      
      final languages = await languagesFuture;
      print('⏱️ Languages Fetch took: ${stopwatch.elapsedMilliseconds - langStart}ms');
      
      if (languages.isEmpty) {
        _myLanguages = [];
      }

      // 2. Start dependent task immediately after languages are ready
      // Use cached blocked users if available
      final studentsStart = stopwatch.elapsedMilliseconds;
      // Fetch ALL students without course restrictions
      final studentsFuture = _studentService.getAllStudents(
        knownBlockedIds: _preloadService.blockedUserIds,
      );
      
      // 3. Wait for all tasks to complete
      final results = await Future.wait([
        proFuture,
        chatRequestsFuture,
        sentRequestsFuture,
        studentsFuture,
      ]);

      print('⏱️ All Futures Completed at: ${stopwatch.elapsedMilliseconds}ms');

      // 4. Process Results
      final hasPro = results[0] as bool;
      final allRequests = results[1] as List<Map<String, dynamic>>; // The raw list, not typed strongly here but castable
      final sentRequests = results[2] as List<Map<String, dynamic>>;
      final students = results[3] as List<Map<String, dynamic>>;

      print('⏱️ Students Query (Parallel) finished. Found ${students.length} students');

      if (!hasPro) {
        if (mounted) {
          setState(() {
            _hasProSubscription = false;
            _isLoading = false;
            _errorMessage = 'PRO subscription required';
          });
        }
        return;
      }

      // Build status maps in memory (CPU bound, fast)
      final statusMap = <String, String>{};
      final recipientMap = <String, bool>{};
      final requestIdMap = <String, String>{};
      
      if (currentUserId != null) {
        for (var request in allRequests) {
          final requesterId = request['requester_id'] as String;
          final recipientId = request['recipient_id'] as String;
          
          String otherStudentId;
          if (requesterId == currentUserId) {
            otherStudentId = recipientId;
          } else {
            otherStudentId = requesterId;
          }
          
          statusMap[otherStudentId] = request['status'] as String;
          requestIdMap[otherStudentId] = request['id'] as String;
          recipientMap[otherStudentId] = recipientId == currentUserId;
        }
      }

      // Cache the students data
      _preloadService.cacheStudents(students);
      
      // Precache student avatars for instant display in public profile
      if (mounted) {
        for (var student in students) {
          final avatarUrl = student['avatar_url'] as String?;
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(avatarUrl), context)
              .catchError((e) => print('Failed to precache avatar: $e'));
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _hasProSubscription = true;
          _myLanguages = languages;
          _students = students;
          _sentRequests = sentRequests;
          _chatRequestStatus = statusMap;
          _isRecipientOfRequest = recipientMap;
          _chatRequestIds = requestIdMap;
          _isLoading = false;
        });
      }
      print('✅ TOTAL PARALLEL LOAD TIME: ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.stop();

    } catch (e) {
      print('❌ ERROR after ${stopwatch.elapsedMilliseconds}ms: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load students: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _sendChatRequest(String recipientId, String recipientName) async {
    final messageController = TextEditingController();
    final l = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient - full width
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.chatRequestTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recipientName,
                            style: TextStyle(
                              fontSize: 13,
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
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.messageHint,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: l.messageHint,
                        hintStyle: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        counterText: '',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.grey.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              l.cancel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, messageController.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l.sendMessage,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    final success = await _chatService.sendChatRequest(
      recipientId,
      message: result.isEmpty ? null : result,
    );

    if (mounted) {
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.chatRequestSent),
            backgroundColor: Colors.green,
          ),
        );
        _loadStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.failedToSendMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _acceptAndOpenChat(String studentId, String studentName) async {
    final requestId = _chatRequestIds[studentId];
    if (requestId == null) return;

    // Accept the request
    final success = await _chatService.acceptChatRequest(requestId);

    if (mounted) {
      final l = AppLocalizations.of(context);
      if (success) {
        // Refresh status and open chat
        await _loadStudents();
        _openChat(studentId, studentName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.failedToAcceptRequest),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openChat(String studentId, String studentName) async {
    // Try to get/create conversation
    final conversation = await _chatService.getOrCreateStudentConversation(studentId);
    
    if (conversation != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatConversationScreen(
            conversationId: conversation['id'],
            recipientId: studentId,
            recipientName: studentName,
            recipientAvatar: null,
            recipientType: 'student',
          ),
        ),
      );
    } else if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.unableToStartChat),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  Text(
                    l.studentsList,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  // Chat requests button
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.envelope,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatRequestsScreen(),
                        ),
                      );
                      _loadStudents();
                    },
                    tooltip: l.chatRequests,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Students Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 80,
                                    color: AppColors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l.noStudentsFound,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l.beFirstInYourLanguage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadStudents,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.1,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _students.length,
                                  itemBuilder: (context, index) {
                                    return _buildStudentCard(_students[index]);
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    // Check if it's a PRO subscription error
    if (_errorMessage == 'PRO subscription required') {
      final l = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.crown,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.proSubscriptionRequired,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l.upgradeToAccess,
                style: const TextStyle(
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

    // Regular error state
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage == 'You need to enroll in a course to see other students'
                  ? l.enrollToSeeOtherStudents
                  : l.errorLoadingData,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentId = student['id'] as String;
    final l = AppLocalizations.of(context);
    final studentName = student['full_name'] ?? l.studentPlaceholder;
    final status = _chatRequestStatus[studentId];
    
    // Calculate level from languages or use default
    final languages = student['languages'] as List<Map<String, dynamic>>? ?? [];
    final level = languages.length > 0 ? languages.length : 1;
    
    return GestureDetector(
      onTap: () {
        // Navigate to public profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentPublicProfileScreen(
              studentId: studentId,
              studentData: student,
            ),
          ),
        ); // No reload needed - data unchanged
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Student Image - Left Side (Full Height)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
              ),
              child: student['avatar_url'] != null
                  ? CachedNetworkImage(
                      imageUrl: student['avatar_url'],
                      fit: BoxFit.cover,
                      memCacheWidth: 200, // Optimize memory usage
                      placeholder: (context, url) => Container(
                        color: AppColors.lightGrey,
                        child: const Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.grey,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightGrey,
                        child: const Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.lightGrey,
                      child: Center(
                        child: Text(
                          studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          
          // Right Side Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Student Name
                  Text(
                    studentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${l.level} $level',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Chat Button - Centered
                  (status == 'pending' && _isRecipientOfRequest[studentId] == true)
                      ? Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            icon: const FaIcon(
                              FontAwesomeIcons.comment,
                              size: 14,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              _acceptAndOpenChat(studentId, studentName);
                            },
                          ),
                        )
                      : status == 'pending'
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      : Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            icon: FaIcon(
                              status == 'accepted'
                                  ? FontAwesomeIcons.comment
                                  : FontAwesomeIcons.userPlus,
                              size: 14,
                              color: status == 'accepted' 
                                  ? Colors.green 
                                  : AppColors.primary,
                            ),
                            onPressed: () {
                              if (status == 'accepted') {
                                _openChat(studentId, studentName);
                              } else {
                                _sendChatRequest(studentId, studentName);
                              }
                            },
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
}
