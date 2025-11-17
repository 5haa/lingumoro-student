import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get notifications for current user
  /// Filters based on in-app notification preferences
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    int offset = 0,
    bool respectInAppPreferences = true,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('user_type', 'student')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(response);
      
      // Filter based on preferences if requested
      if (respectInAppPreferences) {
        final prefs = await getPreferences();
        if (prefs != null) {
          // Global in-app notification toggle
          if (prefs['in_app_notifications_enabled'] == false) {
            return [];
          }
          
          // Filter by category preferences
          notifications = notifications.where((notif) {
            final type = notif['type'] as String?;
            if (type == null) return true;
            
            // Check category-specific preferences for in-app display
            if (type.startsWith('chat_') && prefs['chat_enabled'] == false) return false;
            if (type.startsWith('session_') && prefs['session_enabled'] == false) return false;
            if (type.startsWith('payment_') && prefs['payment_enabled'] == false) return false;
            if (type.startsWith('points_') && prefs['points_enabled'] == false) return false;
            if (type.startsWith('rating_') && prefs['rating_enabled'] == false) return false;
            if (type.startsWith('marketing_') && prefs['marketing_enabled'] == false) return false;
            if (type.startsWith('system_') && prefs['system_enabled'] == false) return false;
            
            return true;
          }).toList();
        }
      }

      return notifications;
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  /// Respects in-app notification preferences
  Future<int> getUnreadCount({bool respectInAppPreferences = true}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      if (respectInAppPreferences) {
        // Get notifications and filter, then count unread
        final notifications = await getNotifications(
          limit: 1000, // Get all unread
          respectInAppPreferences: true,
        );
        return notifications.where((n) => n['is_read'] == false).length;
      } else {
        // Use RPC for faster count without filtering
        final response = await _supabase.rpc(
          'get_unread_notification_count',
          params: {
            'p_user_id': userId,
            'p_user_type': 'student',
          },
        );

        return response as int;
      }
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _supabase.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );

      return response as bool;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() async {
    try {
      final response = await _supabase.rpc(
        'mark_all_notifications_read',
        params: {'p_user_type': 'student'},
      );

      return response as int;
    } catch (e) {
      print('Error marking all as read: $e');
      return 0;
    }
  }

  /// Get user notification preferences
  Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .eq('user_type', 'student')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting notification preferences: $e');
      return null;
    }
  }

  /// Update notification preferences
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('notification_preferences')
          .update(preferences)
          .eq('user_id', userId)
          .eq('user_type', 'student');

      return true;
    } catch (e) {
      print('Error updating notification preferences: $e');
      return false;
    }
  }

  /// Subscribe to real-time notification updates
  RealtimeChannel subscribeToNotifications(Function(Map<String, dynamic>) onNotification) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onNotification(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from notification updates
  void unsubscribe(RealtimeChannel channel) {
    channel.unsubscribe();
  }

  /// Delete old notifications (older than 90 days)
  Future<void> cleanupOldNotifications() async {
    try {
      await _supabase.rpc('cleanup_old_notifications');
      print('Old notifications cleaned up');
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }
}

