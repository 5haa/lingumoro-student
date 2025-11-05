import 'package:flutter/material.dart';
import 'package:student/services/chat_service.dart';
import 'package:intl/intl.dart';

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _chatService.subscribeToChatRequests();
    
    // Listen to new chat requests
    _chatService.onChatRequest.listen((request) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    final pending = await _chatService.getPendingChatRequests();
    final sent = await _chatService.getSentChatRequests();
    
    if (mounted) {
      setState(() {
        _pendingRequests = pending;
        _sentRequests = sent;
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final success = await _chatService.acceptChatRequest(requestId);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
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
            content: Text('Chat request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRequests();
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
        title: const Text('Chat Requests'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          onTap: (index) => setState(() => _selectedTab = index),
          tabs: [
            Tab(
              text: 'Received${_pendingRequests.isNotEmpty ? ' (${_pendingRequests.length})' : ''}',
            ),
            Tab(
              text: 'Sent${_sentRequests.isNotEmpty ? ' (${_sentRequests.length})' : ''}',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          controller: TabController(length: 2, vsync: Navigator.of(context)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _selectedTab == 0
                  ? _buildPendingRequests()
                  : _buildSentRequests(),
            ),
    );
  }

  Widget _buildPendingRequests() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        final requesterData = request['requester'];
        
        if (requesterData == null) {
          return const SizedBox.shrink();
        }
        
        final requester = requesterData as Map<String, dynamic>;
        final message = request['message'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: requester['avatar_url'] != null
                  ? NetworkImage(requester['avatar_url'])
                  : null,
              backgroundColor: Colors.deepPurple[100],
              child: requester['avatar_url'] == null
                  ? Text(
                      requester['full_name']?[0]?.toUpperCase() ?? 'S',
                      style: TextStyle(
                        color: Colors.deepPurple[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            title: Text(
              requester['full_name'] ?? 'Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(request['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptRequest(request['id']),
                  tooltip: 'Accept',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _rejectRequest(request['id']),
                  tooltip: 'Reject',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSentRequests() {
    if (_sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No sent requests',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _sentRequests.length,
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
        final recipientData = request['recipient'];
        
        if (recipientData == null) {
          return const SizedBox.shrink();
        }
        
        final recipient = recipientData as Map<String, dynamic>;
        final status = request['status'] as String;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: recipient['avatar_url'] != null
                  ? NetworkImage(recipient['avatar_url'])
                  : null,
              backgroundColor: Colors.deepPurple[100],
              child: recipient['avatar_url'] == null
                  ? Text(
                      recipient['full_name']?[0]?.toUpperCase() ?? 'S',
                      style: TextStyle(
                        color: Colors.deepPurple[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            title: Text(
              recipient['full_name'] ?? 'Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(request['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: Chip(
              label: Text(
                status.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: status == 'accepted'
                  ? Colors.green[100]
                  : status == 'rejected'
                      ? Colors.red[100]
                      : Colors.orange[100],
            ),
          ),
        );
      },
    );
  }
}


