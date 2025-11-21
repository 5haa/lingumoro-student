import 'package:supabase_flutter/supabase_flutter.dart';

class AIVoiceSessionService {
  final _supabase = Supabase.instance.client;

  /// Check if student can start a new voice session
  /// Returns a map with: canStart (bool), remainingSessions (int), reason (String)
  Future<Map<String, dynamic>> canStartSession(String studentId) async {
    try {
      // Get settings
      final settingsResponse = await _supabase
          .from('ai_settings')
          .select()
          .inFilter('setting_key', [
        'max_voice_sessions_per_day',
        'voice_session_duration_minutes'
      ]);

      int maxSessions = 2; // Default
      int durationMinutes = 15; // Default

      for (var setting in settingsResponse) {
        if (setting['setting_key'] == 'max_voice_sessions_per_day') {
          maxSessions = int.tryParse(setting['setting_value'] ?? '2') ?? 2;
        } else if (setting['setting_key'] == 'voice_session_duration_minutes') {
          durationMinutes =
              int.tryParse(setting['setting_value'] ?? '15') ?? 15;
        }
      }

      // Get today's sessions (completed ones only)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final sessionsResponse = await _supabase
          .from('ai_voice_sessions')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'completed')
          .gte('started_at', startOfDay.toUtc().toIso8601String())
          .lte('started_at', endOfDay.toUtc().toIso8601String());

      final sessionCount = (sessionsResponse as List).length;
      final remainingSessions = maxSessions - sessionCount;

      if (remainingSessions <= 0) {
        return {
          'canStart': false,
          'remainingSessions': 0,
          'maxSessions': maxSessions,
          'usedSessions': sessionCount,
          'durationMinutes': durationMinutes,
          'reason':
              'You have reached your daily limit of $maxSessions sessions. Try again tomorrow!',
        };
      }

      return {
        'canStart': true,
        'remainingSessions': remainingSessions,
        'maxSessions': maxSessions,
        'usedSessions': sessionCount,
        'durationMinutes': durationMinutes,
        'reason': 'You have $remainingSessions session(s) remaining today.',
      };
    } catch (e) {
      print('Error checking session availability: $e');
      return {
        'canStart': true, // Allow on error (graceful degradation)
        'remainingSessions': 1,
        'maxSessions': 2,
        'usedSessions': 0,
        'durationMinutes': 15,
        'reason': 'Unable to verify session limit',
      };
    }
  }

  /// Start a new voice session
  Future<String?> startSession(String studentId) async {
    try {
      final response = await _supabase.from('ai_voice_sessions').insert({
        'student_id': studentId,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
        'duration_seconds': 0,
        'points_awarded': 0,
      }).select().single();

      return response['id'] as String;
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  /// End a voice session and award points
  Future<Map<String, dynamic>> endSession(
    String sessionId,
    int durationSeconds,
  ) async {
    try {
      // Get point tiers from settings
      final settingsResponse = await _supabase
          .from('ai_settings')
          .select()
          .inFilter('setting_key', [
        'voice_session_min_points',
        'voice_session_tier_5min_points',
        'voice_session_tier_10min_points',
        'voice_session_full_points',
        'voice_session_duration_minutes',
      ]);

      int minPoints = 5;
      int tier5MinPoints = 10;
      int tier10MinPoints = 15;
      int fullPoints = 20;
      int maxDurationMinutes = 15;

      for (var setting in settingsResponse) {
        final key = setting['setting_key'];
        final value = int.tryParse(setting['setting_value'] ?? '0') ?? 0;
        if (key == 'voice_session_min_points') minPoints = value;
        if (key == 'voice_session_tier_5min_points') tier5MinPoints = value;
        if (key == 'voice_session_tier_10min_points') tier10MinPoints = value;
        if (key == 'voice_session_full_points') fullPoints = value;
        if (key == 'voice_session_duration_minutes') {
          maxDurationMinutes = value;
        }
      }

      // Calculate points based on duration
      int pointsAwarded = 0;
      final durationMinutes = durationSeconds ~/ 60;
      final maxDurationSeconds = maxDurationMinutes * 60;

      if (durationSeconds >= maxDurationSeconds) {
        // Full session (15 minutes)
        pointsAwarded = fullPoints;
      } else if (durationMinutes >= 10) {
        // 10+ minutes
        pointsAwarded = tier10MinPoints;
      } else if (durationMinutes >= 5) {
        // 5+ minutes
        pointsAwarded = tier5MinPoints;
      } else if (durationSeconds >= 60) {
        // At least 1 minute
        pointsAwarded = minPoints;
      } else {
        // Less than 1 minute
        pointsAwarded = 0;
      }

      // Get session to get student_id
      final session = await _supabase
          .from('ai_voice_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final studentId = session['student_id'];

      // Update session
      await _supabase.from('ai_voice_sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
        'status': 'completed',
        'points_awarded': pointsAwarded,
      }).eq('id', sessionId);

      // Award points to student if points > 0
      if (pointsAwarded > 0) {
        await _supabase.rpc('award_points', params: {
          'student_uuid': studentId,
          'points_to_add': pointsAwarded,
        });
      }

      return {
        'success': true,
        'pointsAwarded': pointsAwarded,
        'durationSeconds': durationSeconds,
        'durationMinutes': durationMinutes,
      };
    } catch (e) {
      print('Error ending session: $e');
      return {
        'success': false,
        'pointsAwarded': 0,
        'durationSeconds': durationSeconds,
        'error': e.toString(),
      };
    }
  }

  /// Cancel an active session
  Future<bool> cancelSession(String sessionId) async {
    try {
      await _supabase.from('ai_voice_sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'cancelled',
      }).eq('id', sessionId);

      return true;
    } catch (e) {
      print('Error cancelling session: $e');
      return false;
    }
  }

  /// Get today's session stats
  Future<Map<String, dynamic>> getTodayStats(String studentId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final sessionsResponse = await _supabase
          .from('ai_voice_sessions')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'completed')
          .gte('started_at', startOfDay.toUtc().toIso8601String())
          .lte('started_at', endOfDay.toUtc().toIso8601String());

      final sessions = sessionsResponse as List;
      final totalSessions = sessions.length;
      final totalPoints = sessions.fold<int>(
          0, (sum, session) => sum + (session['points_awarded'] as int? ?? 0));
      final totalDuration = sessions.fold<int>(
          0,
          (sum, session) =>
              sum + (session['duration_seconds'] as int? ?? 0));

      return {
        'totalSessions': totalSessions,
        'totalPoints': totalPoints,
        'totalDuration': totalDuration,
        'totalMinutes': totalDuration ~/ 60,
      };
    } catch (e) {
      print('Error getting today stats: $e');
      return {
        'totalSessions': 0,
        'totalPoints': 0,
        'totalDuration': 0,
        'totalMinutes': 0,
      };
    }
  }

  /// Get all-time session stats
  Future<Map<String, dynamic>> getAllTimeStats(String studentId) async {
    try {
      final sessionsResponse = await _supabase
          .from('ai_voice_sessions')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'completed');

      final sessions = sessionsResponse as List;
      final totalSessions = sessions.length;
      final totalPoints = sessions.fold<int>(
          0, (sum, session) => sum + (session['points_awarded'] as int? ?? 0));
      final totalDuration = sessions.fold<int>(
          0,
          (sum, session) =>
              sum + (session['duration_seconds'] as int? ?? 0));

      return {
        'totalSessions': totalSessions,
        'totalPoints': totalPoints,
        'totalDuration': totalDuration,
        'totalMinutes': totalDuration ~/ 60,
        'totalHours': totalDuration ~/ 3600,
      };
    } catch (e) {
      print('Error getting all-time stats: $e');
      return {
        'totalSessions': 0,
        'totalPoints': 0,
        'totalDuration': 0,
        'totalMinutes': 0,
        'totalHours': 0,
      };
    }
  }
}

