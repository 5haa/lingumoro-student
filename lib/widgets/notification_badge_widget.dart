import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_colors.dart';
import '../services/notification_service.dart';
import '../services/notification_badge_controller.dart';

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
  final NotificationBadgeController _badgeController = NotificationBadgeController();
  final SupabaseClient _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  RealtimeChannel? _channel;
  StreamSubscription? _badgeUpdateSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.showBadge) {
      _loadUnreadCount();
      // Subscribe to updates
      _subscribeToNotifications();
      _subscribeToBadgeController();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _badgeUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Subscribe to both INSERT and UPDATE events to refresh count
    _channel = _supabase
        .channel('notification_badge:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _loadUnreadCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _loadUnreadCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _loadUnreadCount(),
        )
        .subscribe();
  }

  /// Subscribe to global badge controller for immediate updates
  void _subscribeToBadgeController() {
    _badgeUpdateSubscription = _badgeController.badgeUpdateStream.listen((_) {
      _loadUnreadCount();
    });
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

