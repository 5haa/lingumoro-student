import 'dart:async';
import 'package:flutter/material.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/presence_service.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _presenceService = PresenceService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _availableTeachers = [];
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
    
    // Periodically refresh online status (every 30 seconds)
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshOnlineStatus();
    });
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _chatService.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    final conversations = await _chatService.getConversations();
    final teachers = await _chatService.getAvailableTeachers();
    
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _availableTeachers = teachers;
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

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return DateFormat.jm().format(date);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat.E().format(date);
      } else {
        return DateFormat.MMMd().format(date);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showAvailable ? Icons.chat : Icons.person_add),
            onPressed: () {
              setState(() {
                _showAvailable = !_showAvailable;
              });
            },
            tooltip: _showAvailable ? 'Show Conversations' : 'Start New Chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _showAvailable
                  ? _buildAvailableTeachersList()
                  : _buildConversationsList(),
            ),
    );
  }

  Widget _buildConversationsList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with teachers or students',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showAvailable = true;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final conversationType = conversation['conversation_type'] ?? 'teacher_student';
        
        // Determine who is the other party
        Map<String, dynamic>? otherParty;
        String? otherPartyId;
        String otherPartyType;
        
        if (conversationType == 'teacher_student') {
          otherParty = conversation['teacher'] as Map<String, dynamic>?;
          otherPartyId = conversation['teacher_id'];
          otherPartyType = 'teacher';
        } else {
          // Student-to-student conversation
          final currentUserId = _chatService.supabase.auth.currentUser?.id;
          if (conversation['student_id'] == currentUserId) {
            // I'm student_id, other is participant2
            otherParty = conversation['peer'] as Map<String, dynamic>?;
            otherPartyId = conversation['participant2_id'];
          } else {
            // I'm participant2, other is student
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

        final userKey = '$otherPartyId-$otherPartyType';
        final isOnline = _onlineStatus[userKey] ?? false;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: otherParty['avatar_url'] != null
                    ? NetworkImage(otherParty['avatar_url'])
                    : null,
                backgroundColor: otherPartyType == 'teacher' 
                    ? Colors.deepPurple[100] 
                    : Colors.teal[100],
                child: otherParty['avatar_url'] == null
                    ? Text(
                        otherParty['full_name']?[0]?.toUpperCase() ?? 'U',
                        style: TextStyle(
                          color: otherPartyType == 'teacher' 
                              ? Colors.deepPurple[700] 
                              : Colors.teal[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              // Badge to indicate type
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: otherPartyType == 'teacher' ? Colors.deepPurple : Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    otherPartyType == 'teacher' ? Icons.school : Icons.person,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              // Online status indicator
              if (isOnline)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  otherParty['full_name'] ?? 'User',
                  style: TextStyle(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatTimestamp(lastMessageAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                    fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatConversationScreen(
                  conversationId: conversation['id'],
                  recipientId: otherPartyId!,
                  recipientName: otherParty!['full_name'] ?? 'User',
                  recipientAvatar: otherParty['avatar_url'],
                ),
              ),
            );
            _loadData(); // Refresh after returning
          },
        );
      },
    );
  }

  Widget _buildAvailableTeachersList() {
    if (_availableTeachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No teachers available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subscribe to a course to chat with teachers',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _availableTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _availableTeachers[index];
        final unreadCount = teacher['unread_count'] ?? 0;
        final userKey = '${teacher['id']}-teacher';
        final isOnline = _onlineStatus[userKey] ?? false;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: teacher['avatar_url'] != null
                    ? NetworkImage(teacher['avatar_url'])
                    : null,
                backgroundColor: Colors.deepPurple[100],
                child: teacher['avatar_url'] == null
                    ? Text(
                        teacher['full_name']?[0]?.toUpperCase() ?? 'T',
                        style: TextStyle(
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              // Online status indicator
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  teacher['full_name'] ?? 'Teacher',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            teacher['bio'] ?? teacher['email'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
                    recipientName: teacher['full_name'] ?? 'Teacher',
                    recipientAvatar: teacher['avatar_url'],
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
        );
      },
    );
  }
}

