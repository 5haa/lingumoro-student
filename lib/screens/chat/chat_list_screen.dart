import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/presence_service.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _presenceService = PresenceService();
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  List<Map<String, dynamic>> _availableTeachers = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  bool _showAvailable = false;
  Timer? _statusRefreshTimer;
  
  // Track online status for each user
  final Map<String, bool> _onlineStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _chatService.subscribeToConversations();
    
    // Listen to conversation updates
    _chatService.onConversationUpdate.listen((update) {
      _loadData();
    });
    
    // Search listener
    _searchController.addListener(_filterConversations);
    
    // Periodically refresh online status (every 30 seconds)
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshOnlineStatus();
    });
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _searchController.dispose();
    _chatService.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((conv) {
          final conversationType = conv['conversation_type'] ?? 'teacher_student';
          String name = '';
          
          if (conversationType == 'teacher_student') {
            final teacher = conv['teacher'] as Map<String, dynamic>?;
            name = teacher?['full_name'] ?? '';
          } else {
            final currentUserId = _chatService.supabase.auth.currentUser?.id;
            if (conv['student_id'] == currentUserId) {
              final peer = conv['peer'] as Map<String, dynamic>?;
              name = peer?['full_name'] ?? '';
            } else {
              final student = conv['student'] as Map<String, dynamic>?;
              name = student?['full_name'] ?? '';
            }
          }
          
          final lastMessage = conv['last_message'] ?? '';
          return name.toLowerCase().contains(query) || 
                 lastMessage.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    final conversations = await _chatService.getConversations();
    final teachers = await _chatService.getAvailableTeachers();
    final pendingRequests = await _chatService.getPendingChatRequests();
    
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _filteredConversations = conversations;
        _availableTeachers = teachers;
        _pendingRequests = pendingRequests;
        _isLoading = false;
      });
      
      // Subscribe to online status for all conversation participants
      for (var conversation in conversations) {
        final conversationType = conversation['conversation_type'] ?? 'teacher_student';
        String? otherPartyId;
        String otherPartyType;
        
        if (conversationType == 'teacher_student') {
          otherPartyId = conversation['teacher_id'];
          otherPartyType = 'teacher';
        } else {
          final currentUserId = _chatService.supabase.auth.currentUser?.id;
          if (conversation['student_id'] == currentUserId) {
            otherPartyId = conversation['participant2_id'];
          } else {
            otherPartyId = conversation['student_id'];
          }
          otherPartyType = 'student';
        }
        
        if (otherPartyId != null) {
          _subscribeToUserStatus(otherPartyId, otherPartyType);
        }
      }
      
      // Subscribe to online status for available teachers
      for (var teacher in teachers) {
        final teacherId = teacher['id'];
        if (teacherId != null) {
          _subscribeToUserStatus(teacherId, 'teacher');
        }
      }
      
      // Subscribe to online status for pending requests
      for (var request in pendingRequests) {
        final requester = request['requester'] as Map<String, dynamic>?;
        if (requester != null && requester['id'] != null) {
          _subscribeToUserStatus(requester['id'], 'student');
        }
      }
    }
  }
  
  void _subscribeToUserStatus(String userId, String userType) {
    final key = '$userId-$userType';
    if (_onlineStatus.containsKey(key)) return; // Already subscribed
    
    _presenceService.subscribeToUserStatus(userId, userType).listen((isOnline) {
      if (mounted) {
        setState(() {
          _onlineStatus[key] = isOnline;
        });
      }
    });
  }
  
  /// Refresh online status for all tracked users
  Future<void> _refreshOnlineStatus() async {
    if (!mounted) return;
    
    for (var key in _onlineStatus.keys.toList()) {
      final parts = key.split('-');
      if (parts.length != 2) continue;
      
      final userId = parts[0];
      final userType = parts[1];
      
      try {
        final isOnline = await _presenceService.isUserOnline(userId, userType);
        if (mounted) {
          setState(() {
            _onlineStatus[key] = isOnline;
          });
        }
      } catch (e) {
        print('Error refreshing status for $key: $e');
      }
    }
  }

  Future<void> _acceptRequest(String requestId, String studentId, String studentName) async {
    final success = await _chatService.acceptChatRequest(requestId);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data to refresh the list
        await _loadData();
        
        // Open the chat immediately
        final conversation = await _chatService.getOrCreateStudentConversation(studentId);
        if (conversation != null && mounted) {
          Navigator.push(
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
        }
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

  Future<void> _rejectRequest(String requestId) async {
    final success = await _chatService.rejectChatRequest(requestId);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays == 0) {
        return DateFormat.jm().format(date);
      } else if (difference.inDays == 1) {
        return '1d ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat.MMMd().format(date);
      }
    } catch (e) {
      return '';
    }
  }

  // Get online users from conversations
  List<Map<String, dynamic>> get _onlineUsers {
    return _conversations.where((conv) {
      final conversationType = conv['conversation_type'] ?? 'teacher_student';
      String? otherPartyId;
      String otherPartyType;
      
      if (conversationType == 'teacher_student') {
        otherPartyId = conv['teacher_id'];
        otherPartyType = 'teacher';
      } else {
        final currentUserId = _chatService.supabase.auth.currentUser?.id;
        if (conv['student_id'] == currentUserId) {
          otherPartyId = conv['participant2_id'];
        } else {
          otherPartyId = conv['student_id'];
        }
        otherPartyType = 'student';
      }
      
      if (otherPartyId == null) return false;
      final key = '$otherPartyId-$otherPartyType';
      return _onlineStatus[key] == true;
    }).map((conv) {
      final conversationType = conv['conversation_type'] ?? 'teacher_student';
      Map<String, dynamic>? otherParty;
      
      if (conversationType == 'teacher_student') {
        otherParty = conv['teacher'] as Map<String, dynamic>?;
      } else {
        final currentUserId = _chatService.supabase.auth.currentUser?.id;
        if (conv['student_id'] == currentUserId) {
          otherParty = conv['peer'] as Map<String, dynamic>?;
        } else {
          final studentData = conv['student'];
          if (studentData != null) {
            otherParty = {'id': conv['student_id'], ...studentData};
          }
        }
      }
      
      return {
        'name': (otherParty?['full_name'] ?? 'User').split(' ')[0], // First name only
        'image': otherParty?['avatar_url'] ?? '',
      };
    }).toList();
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'MESSAGES',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
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
                      icon: FaIcon(
                        _showAvailable ? FontAwesomeIcons.message : FontAwesomeIcons.userPlus,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAvailable = !_showAvailable;
                        });
                      },
                      tooltip: _showAvailable ? 'Show Conversations' : 'Start New Chat',
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 15),

                          // Search Bar - Bean Shaped
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.magnifyingGlass,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Search messages...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 15,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Online Users Horizontal List
                          if (_onlineUsers.isNotEmpty && !_showAvailable)
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _onlineUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _onlineUsers[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      children: [
                                        Stack(
                                          children: [
                                            ClipOval(
                                              child: user['image'] != null && user['image'].toString().isNotEmpty
                                                  ? Image.network(
                                                      user['image'],
                                                      width: 60,
                                                      height: 60,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        width: 60,
                                                        height: 60,
                                                        color: AppColors.primary.withOpacity(0.1),
                                                        child: Center(
                                                          child: Text(
                                                            user['name'][0].toUpperCase(),
                                                            style: const TextStyle(
                                                              fontSize: 24,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 60,
                                                      height: 60,
                                                      color: AppColors.primary.withOpacity(0.1),
                                                      child: Center(
                                                        child: Text(
                                                          user['name'][0].toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 24,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                            // Online indicator
                                            Positioned(
                                              bottom: 2,
                                              right: 2,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF4CAF50),
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
                                        const SizedBox(height: 6),
                                        Text(
                                          user['name'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Chat List or Available Teachers
                          _showAvailable
                              ? _buildAvailableTeachersList()
                              : _buildConversationsList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_filteredConversations.isEmpty && _pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FontAwesomeIcons.message,
                  size: 40,
                  color: AppColors.grey.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _searchController.text.isNotEmpty ? 'No results found' : 'No messages yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty 
                    ? 'Try searching with different keywords'
                    : 'Start a conversation with your teachers',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAvailable = true;
                    });
                  },
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: const Text('Start New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Combine pending requests and conversations, with requests first
    final allItems = <Map<String, dynamic>>[];
    
    // Add pending requests first (only if not searching)
    if (_searchController.text.isEmpty) {
      for (var request in _pendingRequests) {
        allItems.add({
          'type': 'pending_request',
          'data': request,
        });
      }
    }
    
    // Add conversations
    for (var conversation in _filteredConversations) {
      allItems.add({
        'type': 'conversation',
        'data': conversation,
      });
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item['type'] == 'pending_request') {
          return _buildPendingRequestItem(item['data'] as Map<String, dynamic>);
        } else {
          return _buildChatItem(item['data'] as Map<String, dynamic>);
        }
      },
    );
  }

  Widget _buildPendingRequestItem(Map<String, dynamic> request) {
    final requester = request['requester'] as Map<String, dynamic>?;
    if (requester == null) return const SizedBox.shrink();
    
    final requesterId = requester['id'] as String;
    final requesterName = requester['full_name'] ?? 'Student';
    final requesterAvatar = requester['avatar_url'];
    final requestId = request['id'] as String;
    final message = request['message'] as String?;
    final createdAt = request['created_at'] as String?;
    
    final userKey = '$requesterId-student';
    final isOnline = _onlineStatus[userKey] ?? false;
    
    return GestureDetector(
      onTap: () {
        // Show request message dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: requesterAvatar != null
                        ? DecorationImage(
                            image: NetworkImage(requesterAvatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: requesterAvatar == null ? AppColors.redGradient : null,
                  ),
                  child: requesterAvatar == null
                      ? Center(
                          child: Text(
                            requesterName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requesterName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Chat Request',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: message != null && message.isNotEmpty
                ? Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  )
                : const Text(
                    'No message provided',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFEEEEEE),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Profile Image with Online Status
            Stack(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: requesterAvatar != null && requesterAvatar.toString().isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(requesterAvatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.teal.withOpacity(0.1),
                  ),
                  child: requesterAvatar == null || requesterAvatar.toString().isEmpty
                      ? Center(
                          child: Text(
                            requesterName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
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

            // Message Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requesterName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message != null && message.isNotEmpty
                        ? message
                        : 'Sent a chat request',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Accept/Reject Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reject Button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark,
                      color: Colors.red,
                      size: 14,
                    ),
                    onPressed: () => _rejectRequest(requestId),
                  ),
                ),
                const SizedBox(width: 8),
                // Accept Button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const FaIcon(
                      FontAwesomeIcons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                    onPressed: () => _acceptRequest(requestId, requesterId, requesterName),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> conversation) {
    final conversationType = conversation['conversation_type'] ?? 'teacher_student';
    
    // Determine who is the other party
    Map<String, dynamic>? otherParty;
    String? otherPartyId;
    String otherPartyType;
    bool isTeacher = conversationType == 'teacher_student';
    
    if (conversationType == 'teacher_student') {
      otherParty = conversation['teacher'] as Map<String, dynamic>?;
      otherPartyId = conversation['teacher_id'];
      otherPartyType = 'teacher';
    } else {
      // Student-to-student conversation
      final currentUserId = _chatService.supabase.auth.currentUser?.id;
      if (conversation['student_id'] == currentUserId) {
        otherParty = conversation['peer'] as Map<String, dynamic>?;
        otherPartyId = conversation['participant2_id'];
      } else {
        final studentData = conversation['student'];
        if (studentData != null) {
          otherParty = {'id': conversation['student_id'], ...studentData};
        }
        otherPartyId = conversation['student_id'];
      }
      otherPartyType = 'student';
    }
    
    // Skip if other party data is null
    if (otherParty == null || otherPartyId == null) {
      return const SizedBox.shrink();
    }
    
    final unreadCount = conversation['student_unread_count'] ?? 0;
    final lastMessage = conversation['last_message'] ?? '';
    final lastMessageAt = conversation['last_message_at'];
    final name = otherParty['full_name'] ?? 'User';
    final avatarUrl = otherParty['avatar_url'];

    final userKey = '$otherPartyId-$otherPartyType';
    final isOnline = _onlineStatus[userKey] ?? false;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversationId: conversation['id'],
              recipientId: otherPartyId!,
              recipientName: name,
              recipientAvatar: avatarUrl,
            ),
          ),
        );
        _loadData(); // Refresh after returning
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFEEEEEE),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Profile Image with Online Status
            Stack(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTeacher
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.teal.withOpacity(0.1),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isTeacher ? AppColors.primary : Colors.teal,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isTeacher ? AppColors.primary : Colors.teal,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isTeacher ? AppColors.primary : Colors.teal,
                              ),
                            ),
                          ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
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

            // Message Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF999999),
                      fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time and Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(lastMessageAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableTeachersList() {
    if (_availableTeachers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FontAwesomeIcons.chalkboardUser,
                  size: 40,
                  color: AppColors.grey.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No teachers available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Subscribe to a course to chat with teachers',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _availableTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _availableTeachers[index];
        final unreadCount = teacher['unread_count'] ?? 0;
        final userKey = '${teacher['id']}-teacher';
        final isOnline = _onlineStatus[userKey] ?? false;
        final name = teacher['full_name'] ?? 'Teacher';
        final avatarUrl = teacher['avatar_url'];

        return GestureDetector(
          onTap: () async {
            // Create or get conversation
            final conversation = await _chatService.getOrCreateConversation(teacher['id']);
            
            if (conversation != null && mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatConversationScreen(
                    conversationId: conversation['id'],
                    recipientId: teacher['id'],
                    recipientName: name,
                    recipientAvatar: avatarUrl,
                  ),
                ),
              );
              setState(() {
                _showAvailable = false;
              });
              _loadData();
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to start chat. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEEEEEE),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Profile Image with Online Status
                Stack(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: avatarUrl != null && avatarUrl.toString().isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                      child: avatarUrl == null || avatarUrl.toString().isEmpty
                          ? Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
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

                // Teacher Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher['bio'] ?? teacher['email'] ?? 'Teacher',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Badge and Arrow
                Row(
                  children: [
                    if (unreadCount > 0) ...[
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 14,
                      color: Color(0xFF999999),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
