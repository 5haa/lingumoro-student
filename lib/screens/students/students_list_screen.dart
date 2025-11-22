import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/student_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/session_update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/screens/students/student_public_profile_screen.dart';
import 'package:student/screens/chat/chat_requests_screen.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
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
    _loadStudents();
    // Listen for subscription updates (when student subscribes to a course)
    _sessionUpdateService.addListener(_handleSubscriptionUpdate);
  }

  @override
  void dispose() {
    _sessionUpdateService.removeListener(_handleSubscriptionUpdate);
    super.dispose();
  }

  void _handleSubscriptionUpdate() {
    // Reload students list when subscriptions change
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Check PRO subscription first
      final studentId = _authService.currentUser?.id;
      if (studentId != null) {
        final hasPro = await _proService.hasActivePro(studentId);
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
        setState(() {
          _hasProSubscription = true;
        });
      }

      // Get languages the current student is learning
      final languages = await _studentService.getStudentLanguages();
      
      if (languages.isEmpty) {
        if (mounted) {
          setState(() {
            _myLanguages = [];
            _students = [];
            _isLoading = false;
            _errorMessage = 'You need to enroll in a course to see other students';
          });
        }
        return;
      }

      // Get students learning the same languages
      final students = await _studentService.getStudentsInSameLanguages();
      
      // Get current user ID
      final currentUserId = _chatService.supabase.auth.currentUser?.id;
      
      // Build status maps by checking all students
      final statusMap = <String, String>{};
      final recipientMap = <String, bool>{};
      final requestIdMap = <String, String>{};
      
      if (currentUserId != null) {
        for (var student in students) {
          final studentId = student['id'] as String;
          
          // Check for chat request in both directions
          final requests = await _chatService.supabase
              .from('chat_requests')
              .select('id, status, requester_id, recipient_id')
              .or('and(requester_id.eq.$currentUserId,recipient_id.eq.$studentId),and(requester_id.eq.$studentId,recipient_id.eq.$currentUserId)')
              .limit(1);
          
          if (requests.isNotEmpty) {
            final request = requests.first;
            statusMap[studentId] = request['status'] as String;
            requestIdMap[studentId] = request['id'] as String;
            recipientMap[studentId] = request['recipient_id'] == currentUserId;
          }
        }
      }
      
      // Get sent chat requests for backwards compatibility
      final sentRequests = await _chatService.getSentChatRequests();

      if (mounted) {
        setState(() {
          _myLanguages = languages;
          _students = students;
          _sentRequests = sentRequests;
          _chatRequestStatus = statusMap;
          _isRecipientOfRequest = recipientMap;
          _chatRequestIds = requestIdMap;
          _isLoading = false;
        });
      }
    } catch (e) {
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
                          const Text(
                            'Send Message Request',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'To $recipientName',
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
                    const Text(
                      'Message (Optional)',
                      style: TextStyle(
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
                        hintText: 'Hi! I\'d love to practice together...',
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
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
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
                            child: const Text(
                              'Send',
                              style: TextStyle(
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

    final success = await _chatService.sendChatRequest(recipientId, message: result.isEmpty ? null : result);

    if (mounted) {
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request sent!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request'),
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
      if (success) {
        // Refresh status and open chat
        await _loadStudents();
        _openChat(studentId, studentName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept request'),
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
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start chat. Make sure request is accepted.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'STUDENTS',
                    style: TextStyle(
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
                    tooltip: 'Chat Requests',
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
                                    'No other students found',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first in your language!',
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
              Text(
                'Connect with fellow students with a PRO subscription',
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

    // Regular error state
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
              _errorMessage ?? 'Error loading students',
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
    final studentName = student['full_name'] ?? 'Student';
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
        ).then((_) => _loadStudents()); // Refresh on return
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
                      'Lvl $level',
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
