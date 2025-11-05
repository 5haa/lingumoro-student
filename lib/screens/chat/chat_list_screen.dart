import 'package:flutter/material.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _availableTeachers = [];
  bool _isLoading = true;
  bool _showAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _chatService.subscribeToConversations();
    
    // Listen to conversation updates
    _chatService.onConversationUpdate.listen((update) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
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
              'Start chatting with your teachers',
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
        final teacherData = conversation['teacher'];
        
        // Skip if teacher data is null
        if (teacherData == null) {
          return const SizedBox.shrink();
        }
        
        final teacher = teacherData as Map<String, dynamic>;
        final unreadCount = conversation['student_unread_count'] ?? 0;
        final lastMessage = conversation['last_message'] ?? '';
        final lastMessageAt = conversation['last_message_at'];

        return ListTile(
          leading: CircleAvatar(
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
          title: Row(
            children: [
              Expanded(
                child: Text(
                  teacher['full_name'] ?? 'Teacher',
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
                  recipientId: teacher['id'],
                  recipientName: teacher['full_name'] ?? 'Teacher',
                  recipientAvatar: teacher['avatar_url'],
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

        return ListTile(
          leading: CircleAvatar(
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

