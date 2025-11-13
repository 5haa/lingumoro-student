import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/student_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/auth_service.dart';
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
  List<Map<String, dynamic>> _students = [];
  List<String> _myLanguages = [];
  List<Map<String, dynamic>> _sentRequests = [];
  Map<String, String> _chatRequestStatus = {}; // studentId -> status
  bool _isLoading = true;
  bool _hasProSubscription = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
      
      // Get sent chat requests to check status
      final sentRequests = await _chatService.getSentChatRequests();
      
      // Build status map
      final statusMap = <String, String>{};
      for (var request in sentRequests) {
        final recipientData = request['recipient'];
        if (recipientData != null) {
          final recipientId = recipientData['id'] as String;
          statusMap[recipientId] = request['status'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _myLanguages = languages;
          _students = students;
          _sentRequests = sentRequests;
          _chatRequestStatus = statusMap;
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
      builder: (context) => AlertDialog(
        title: Text('Send chat request to $recipientName?'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Optional message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          controller: messageController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, messageController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
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
    
    return Container(
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
                  status == 'pending'
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
    );
  }
}
