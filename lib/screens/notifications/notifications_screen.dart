import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';
import '../../services/notification_service.dart';
import '../../services/notification_badge_controller.dart';
import '../../l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final NotificationBadgeController _badgeController = NotificationBadgeController();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_notificationChannel != null) {
      _notificationService.unsubscribe(_notificationChannel!);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh notifications
      print('🔄 Notifications screen: App resumed - refreshing data');
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToNotifications() {
    try {
      _notificationChannel = _notificationService.subscribeToNotifications((notification) {
        // Filter out chat notifications - they should only appear as push notifications
        final type = notification['type'] as String?;
        if (type == 'chat_message' || 
            type == 'chat_request_received' || 
            type == 'chat_request_accepted' || 
            type == 'chat_request_rejected') {
          // Don't add chat notifications to in-app notification list
          return;
        }
        
        setState(() {
          _notifications.insert(0, notification);
        });
        // Don't show in-app snackbar for any messages - push notifications handle this
        // Only the notification list updates in real-time
      });
    } catch (e) {
      print('Error subscribing to notifications: $e');
    }
  }

  int get _unreadCount => _notifications.where((n) => n['is_read'] == false).length;

  Future<void> _markAsRead(String id) async {
    final success = await _notificationService.markAsRead(id);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
      // Trigger badge update
      _badgeController.triggerUpdate();
    }
  }

  Future<void> _markAllAsRead() async {
    final count = await _notificationService.markAllAsRead();
    if (count > 0) {
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });
      
      // Trigger badge update
      _badgeController.triggerUpdate();
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.allNotificationsMarkedRead),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    // Show confirmation dialog
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAllNotificationsTitle),
        content: Text(l10n.clearAllNotificationsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.clearAllButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final count = await _notificationService.clearAllNotifications();
    if (count > 0) {
      setState(() {
        _notifications.clear();
      });
      
      // Trigger badge update
      _badgeController.triggerUpdate();
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notificationsCleared(count)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat_message':
      case 'chat_request_received':
      case 'chat_request_accepted':
      case 'chat_request_rejected':
        return FontAwesomeIcons.message;
      case 'session_scheduled':
      case 'session_reminder':
      case 'session_cancelled':
      case 'session_completed':
      case 'meeting_link_available':
        return FontAwesomeIcons.graduationCap;
      case 'payment_approved':
      case 'payment_rejected':
      case 'subscription_expiry':
      case 'points_low':
        return FontAwesomeIcons.creditCard;
      case 'points_awarded':
        return FontAwesomeIcons.star;
      case 'pro_activated':
      case 'pro_expiry':
        return FontAwesomeIcons.crown;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  String _getTimeAgo(String? createdAt) {
    final l10n = AppLocalizations.of(context);
    if (createdAt == null) return l10n.unknownError;
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return l10n.justNow;
      if (difference.inMinutes < 60) return l10n.minutesAgo(difference.inMinutes);
      if (difference.inHours < 24) return '${difference.inHours}${l10n.hoursAgo}';
      if (difference.inDays < 7) return l10n.daysAgo(difference.inDays);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return l10n.unknownError;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read
    if (notification['is_read'] == false) {
      _markAsRead(notification['id']);
    }

    // Navigate based on notification action
    final data = notification['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final action = data['action'];
    // TODO: Implement navigation based on action
    // Example:
    // if (action == 'open_chat') Navigator.push(...);
    // if (action == 'open_session') Navigator.push(...);
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.notifications,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (_notifications.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_unreadCount > 0)
                          TextButton(
                            onPressed: _markAllAsRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(45, 30),
                            ),
                            child: Text(
                              l10n.readAll,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: _clearAllNotifications,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(45, 30),
                          ),
                          child: Text(
                            l10n.clear,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(width: 45),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Notifications List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _notifications.isEmpty
                      ? Center(
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
                              FontAwesomeIcons.bell,
                              size: 40,
                              color: AppColors.grey.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.noNotifications,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.youreAllCaughtUp,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['is_read'] ?? false;
    final String type = notification['type'] ?? 'default';
    final IconData icon = _getIconForType(type);
    final String timeAgo = _getTimeAgo(notification['created_at']);
    
    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? AppColors.white : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            gradient: AppColors.redGradient,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification['body'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.clock,
                        size: 12,
                        color: AppColors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
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
    );
  }
}

