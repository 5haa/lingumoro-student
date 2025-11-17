import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get notifications for current user
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    int offset = 0,
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

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase.rpc(
        'get_unread_notification_count',
        params: {
          'p_user_id': userId,
          'p_user_type': 'student',
        },
      );

      return response as int;
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

