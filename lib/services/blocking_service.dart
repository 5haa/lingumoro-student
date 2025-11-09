import 'package:supabase_flutter/supabase_flutter.dart';

class BlockingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Block another student
  Future<bool> blockUser(String blockedId, {String? reason}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('user_blocks').insert({
        'blocker_id': userId,
        'blocked_id': blockedId,
        if (reason != null) 'reason': reason,
      });

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a student
  Future<bool> unblockUser(String blockedId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', blockedId);

      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  /// Get list of users I've blocked
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final blocks = await _supabase
          .from('user_blocks')
          .select('''
            *,
            blocked:blocked_id (
              id,
              full_name,
              email,
              avatar_url
            )
          ''')
          .eq('blocker_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(blocks);
    } catch (e) {
      print('Error fetching blocked users: $e');
      return [];
    }
  }

  /// Check if I've blocked a specific user
  Future<bool> isUserBlocked(String userId) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return false;

      final result = await _supabase.rpc('is_user_blocked', params: {
        'p_blocker_id': myId,
        'p_blocked_id': userId,
      });

      return result == true;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Check if there's any block between two users (either direction)
  Future<bool> areUsersBlocked(String user1Id, String user2Id) async {
    try {
      final result = await _supabase.rpc('are_users_blocked', params: {
        'p_user1_id': user1Id,
        'p_user2_id': user2Id,
      });

      return result == true;
    } catch (e) {
      print('Error checking mutual blocks: $e');
      return false;
    }
  }

  /// Get my blocked users IDs only (for filtering)
  Future<Set<String>> getBlockedUserIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final blocks = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);

      return blocks.map((b) => b['blocked_id'] as String).toSet();
    } catch (e) {
      print('Error fetching blocked user IDs: $e');
      return {};
    }
  }

  /// Get users who have blocked me (for filtering)
  Future<Set<String>> getUsersWhoBlockedMe() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final blocks = await _supabase
          .from('user_blocks')
          .select('blocker_id')
          .eq('blocked_id', userId);

      return blocks.map((b) => b['blocker_id'] as String).toSet();
    } catch (e) {
      print('Error fetching users who blocked me: $e');
      return {};
    }
  }

  /// Check if my account is suspended
  Future<Map<String, dynamic>?> checkSuspensionStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final result = await _supabase
          .from('account_suspensions')
          .select()
          .eq('user_id', userId)
          .eq('user_type', 'student')
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
          .maybeSingle();

      return result;
    } catch (e) {
      print('Error checking suspension status: $e');
      return null;
    }
  }
}

