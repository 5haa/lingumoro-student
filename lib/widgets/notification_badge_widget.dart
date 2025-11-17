import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/notification_service.dart';

class NotificationBadgeWidget extends StatefulWidget {
  final Widget child;
  final bool showBadge;

  const NotificationBadgeWidget({
    super.key,
    required this.child,
    this.showBadge = true,
  });

  @override
  State<NotificationBadgeWidget> createState() => _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showBadge) {
      _loadUnreadCount();
      // Subscribe to updates
      _subscribeToNotifications();
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  void _subscribeToNotifications() {
    // Refresh count when new notifications arrive
    final channel = _notificationService.subscribeToNotifications((notification) {
      _loadUnreadCount();
    });

    // Store channel for cleanup if needed
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.showBadge && _unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: AppColors.redGradient,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

