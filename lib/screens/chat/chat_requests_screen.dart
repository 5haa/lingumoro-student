import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/widgets/custom_back_button.dart';

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
      final l10n = AppLocalizations.of(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.requestAccepted),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToAcceptRequest),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final success = await _chatService.rejectChatRequest(requestId);
    
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.requestRejected),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToRejectRequest),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(AppLocalizations l10n, String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return DateFormat.jm().format(date);
      } else if (difference.inDays == 1) {
        return l10n.yesterday;
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
    final l10n = AppLocalizations.of(context);
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
                    l10n.chatRequests.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Custom Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        0,
                        l10n.chatRequestsReceived,
                        _pendingRequests.length,
                        FontAwesomeIcons.inbox,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.lightGrey,
                    ),
                    Expanded(
                      child: _buildTabButton(
                        1,
                        l10n.chatRequestsSent,
                        _sentRequests.length,
                        FontAwesomeIcons.paperPlane,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: AppColors.primary,
                      child: _selectedTab == 0
                          ? _buildPendingRequests(l10n)
                          : _buildSentRequests(l10n),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int count, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.redGradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequests(AppLocalizations l10n) {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.inbox,
              size: 80,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noChatRequests,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startConversation,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        final requesterData = request['requester'];
        
        if (requesterData == null) {
          return const SizedBox.shrink();
        }
        
        final requester = requesterData as Map<String, dynamic>;
        final message = request['message'] as String?;
        final requesterName = requester['full_name'] ?? l10n.studentPlaceholder;
        final initials = requesterName.isNotEmpty
            ? requesterName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
            : 'ST';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: requester['avatar_url'] == null
                            ? AppColors.redGradient
                            : null,
                      ),
                      child: requester['avatar_url'] != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: requester['avatar_url'],
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.redGradient,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Name and time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requesterName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(l10n, request['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons - horizontal thin card
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Accept button
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppColors.redGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _acceptRequest(request['id']),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Center(
                                  child: Text(
                                    l10n.accept,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reject button with X icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _rejectRequest(request['id']),
                              borderRadius: BorderRadius.circular(8),
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.xmark,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Message
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSentRequests(AppLocalizations l10n) {
    if (_sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.paperPlane,
              size: 80,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noChatRequests,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startConversation,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _sentRequests.length,
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
        final recipientData = request['recipient'];
        
        if (recipientData == null) {
          return const SizedBox.shrink();
        }
        
        final recipient = recipientData as Map<String, dynamic>;
        final status = request['status'] as String;
        final recipientName = recipient['full_name'] ?? l10n.studentPlaceholder;
        final initials = recipientName.isNotEmpty
            ? recipientName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
            : 'ST';

        Color statusColor;
        Color statusBgColor;
        IconData statusIcon;
        
        if (status == 'accepted') {
          statusColor = Colors.green;
          statusBgColor = Colors.green.withOpacity(0.1);
          statusIcon = FontAwesomeIcons.circleCheck;
        } else if (status == 'rejected') {
          statusColor = Colors.red;
          statusBgColor = Colors.red.withOpacity(0.1);
          statusIcon = FontAwesomeIcons.circleXmark;
        } else {
          statusColor = Colors.orange;
          statusBgColor = Colors.orange.withOpacity(0.1);
          statusIcon = FontAwesomeIcons.clock;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: recipient['avatar_url'] == null
                        ? AppColors.redGradient
                        : null,
                  ),
                  child: recipient['avatar_url'] != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: recipient['avatar_url'],
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.redGradient,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(l10n, request['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        statusIcon,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(l10n, status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'accepted':
        return l10n.requestAccepted;
      case 'rejected':
        return l10n.requestRejected;
      default:
        return l10n.chatRequestPendingStatus;
    }
  }
}

