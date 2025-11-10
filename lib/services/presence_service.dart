import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  final _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  
  // Stream controllers for online status updates
  final Map<String, StreamController<bool>> _statusControllers = {};
  final Map<String, RealtimeChannel> _statusChannels = {};

  /// Start tracking user's online status
  Future<void> startTracking() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Set user as online
      await _supabase.rpc('update_user_last_seen', params: {
        'p_user_id': userId,
        'p_user_type': 'student',
      });

      // Start heartbeat to keep status updated (every 30 seconds)
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateHeartbeat();
      });
    } catch (e) {
      print('Error starting presence tracking: $e');
    }
  }

  /// Update heartbeat to keep user online
  Future<void> _updateHeartbeat() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.rpc('update_user_last_seen', params: {
        'p_user_id': userId,
        'p_user_type': 'student',
      });
    } catch (e) {
      print('Error updating heartbeat: $e');
    }
  }

  /// Stop tracking user's online status
  Future<void> stopTracking() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // Set user as offline
      await _supabase.rpc('set_user_offline', params: {
        'p_user_id': userId,
        'p_user_type': 'student',
      });
    } catch (e) {
      print('Error stopping presence tracking: $e');
    }
  }

  /// Subscribe to a user's online status
  Stream<bool> subscribeToUserStatus(String userId, String userType) {
    final key = '$userId-$userType';
    
    // Return existing stream if already subscribed
    if (_statusControllers.containsKey(key)) {
      return _statusControllers[key]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<bool>.broadcast();
    _statusControllers[key] = controller;

    // Subscribe to realtime updates
    final tableName = userType == 'teacher' ? 'teachers' : 'students';
    final channel = _supabase
        .channel('presence:$key')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final isOnline = _computeOnlineStatus(
              payload.newRecord['is_online'] as bool?,
              payload.newRecord['last_seen'] as String?,
            );
            if (!controller.isClosed) {
              controller.add(isOnline);
            }
          },
        )
        .subscribe();

    _statusChannels[key] = channel;

    // Fetch initial status
    _fetchInitialStatus(userId, userType, controller);

    return controller.stream;
  }

  /// Fetch initial online status
  Future<void> _fetchInitialStatus(
    String userId,
    String userType,
    StreamController<bool> controller,
  ) async {
    try {
      final tableName = userType == 'teacher' ? 'teachers' : 'students';
      final result = await _supabase
          .from(tableName)
          .select('is_online, last_seen')
          .eq('id', userId)
          .single();

      final isOnline = _computeOnlineStatus(
        result['is_online'] as bool?,
        result['last_seen'] as String?,
      );
      
      if (!controller.isClosed) {
        controller.add(isOnline);
      }
    } catch (e) {
      print('Error fetching initial status: $e');
      if (!controller.isClosed) {
        controller.add(false);
      }
    }
  }

  /// Compute actual online status based on is_online flag and last_seen timestamp
  bool _computeOnlineStatus(bool? isOnlineFlag, String? lastSeenStr) {
    // If explicitly offline, return false
    if (isOnlineFlag == false) return false;
    
    // If no last seen data, consider offline
    if (lastSeenStr == null) return false;
    
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
      
      // Consider online only if seen within last 90 seconds (3 heartbeat cycles)
      return difference.inSeconds < 90;
    } catch (e) {
      print('Error parsing last_seen: $e');
      return false;
    }
  }

  /// Check if a user is currently online
  Future<bool> isUserOnline(String userId, String userType) async {
    try {
      final tableName = userType == 'teacher' ? 'teachers' : 'students';
      final result = await _supabase
          .from(tableName)
          .select('is_online, last_seen')
          .eq('id', userId)
          .single();

      return _computeOnlineStatus(
        result['is_online'] as bool?,
        result['last_seen'] as String?,
      );
    } catch (e) {
      print('Error checking online status: $e');
      return false;
    }
  }

  /// Get last seen time for a user
  Future<DateTime?> getLastSeen(String userId, String userType) async {
    try {
      final tableName = userType == 'teacher' ? 'teachers' : 'students';
      final result = await _supabase
          .from(tableName)
          .select('last_seen')
          .eq('id', userId)
          .single();

      final lastSeen = result['last_seen'] as String?;
      return lastSeen != null ? DateTime.parse(lastSeen) : null;
    } catch (e) {
      print('Error getting last seen: $e');
      return null;
    }
  }

  /// Format last seen time for display
  String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'Long ago';
    }
  }

  /// Unsubscribe from a user's status
  void unsubscribeFromUser(String userId, String userType) {
    final key = '$userId-$userType';
    
    _statusChannels[key]?.unsubscribe();
    _statusChannels.remove(key);
    
    _statusControllers[key]?.close();
    _statusControllers.remove(key);
  }

  /// Clean up all subscriptions
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    for (var channel in _statusChannels.values) {
      channel.unsubscribe();
    }
    _statusChannels.clear();

    for (var controller in _statusControllers.values) {
      controller.close();
    }
    _statusControllers.clear();
  }
}
