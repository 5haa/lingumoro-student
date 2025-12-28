import 'package:supabase_flutter/supabase_flutter.dart';

class AIVoiceSessionService {
  final _supabase = Supabase.instance.client;

  // Iraq uses Asia/Baghdad (UTC+3). We approximate with a fixed +3h offset.
  // This matches the DB-side enforcement we use for daily_practice_limits.
  static const Duration _iraqOffset = Duration(hours: 3);

  DateTime _nowUtc() => DateTime.now().toUtc();

  /// Returns UTC boundaries (start inclusive, end exclusive) for the current Iraq day.
  ({DateTime startUtc, DateTime endUtc}) _iraqDayWindowUtc() {
    final iraqNow = _nowUtc().add(_iraqOffset);
    // Iraq midnight expressed as UTC date (needs subtracting offset to become real UTC boundary).
    final iraqMidnightAsUtc = DateTime.utc(iraqNow.year, iraqNow.month, iraqNow.day);
    final startUtc = iraqMidnightAsUtc.subtract(_iraqOffset);
    final endUtc = startUtc.add(const Duration(days: 1));
    return (startUtc: startUtc, endUtc: endUtc);
  }

  /// Check if student can start a new voice session
  /// Returns a map with: canStart (bool), remainingSeconds (int), reason (String)
  Future<Map<String, dynamic>> canStartSession(String studentId) async {
    try {
      // Get settings
      final settingsResponse = await _supabase
          .from('ai_settings')
          .select()
          .inFilter('setting_key', [
        'daily_voice_limit_minutes',
        'voice_session_duration_minutes'
      ]);

      int dailyLimitMinutes = 30; // Default
      int sessionMaxDurationMinutes = 15; // Default

      for (var setting in settingsResponse) {
        if (setting['setting_key'] == 'daily_voice_limit_minutes') {
          dailyLimitMinutes = int.tryParse(setting['setting_value'] ?? '30') ?? 30;
        } else if (setting['setting_key'] == 'voice_session_duration_minutes') {
          sessionMaxDurationMinutes =
              int.tryParse(setting['setting_value'] ?? '15') ?? 15;
        }
      }

      // Get today's completed sessions to calculate used time
      final window = _iraqDayWindowUtc();

      final sessionsResponse = await _supabase
          .from('ai_voice_sessions')
          .select('duration_seconds')
          .eq('student_id', studentId)
          .inFilter('status', ['completed', 'active']) // active ones count too
          .gte('started_at', window.startUtc.toIso8601String())
          .lt('started_at', window.endUtc.toIso8601String());

      int usedSeconds = 0;
      for (var session in sessionsResponse) {
        usedSeconds += (session['duration_seconds'] as int? ?? 0);
      }

      final dailyLimitSeconds = dailyLimitMinutes * 60;
      final remainingSeconds = dailyLimitSeconds - usedSeconds;

      if (remainingSeconds <= 0) {
        return {
          'canStart': false,
          'remainingSeconds': 0,
          'dailyLimitMinutes': dailyLimitMinutes,
          'usedSeconds': usedSeconds,
          'sessionMaxDurationMinutes': sessionMaxDurationMinutes,
          'reason':
              'You have reached your daily limit of $dailyLimitMinutes minutes. Try again tomorrow!',
        };
      }

      // We allow starting if there is ANY time left, but the session 
      // will be capped at min(sessionMaxDuration, remainingTime)
      // The returning 'remainingSeconds' is the ABSOLUTE daily remaining time.
      
      return {
        'canStart': true,
        'remainingSeconds': remainingSeconds,
        'dailyLimitMinutes': dailyLimitMinutes,
        'usedSeconds': usedSeconds,
        'sessionMaxDurationMinutes': sessionMaxDurationMinutes,
        'reason': 'You have ${(remainingSeconds / 60).ceil()} minutes remaining today.',
      };
    } catch (e) {
      print('Error checking session availability: $e');
      return {
        'canStart': true, // Allow on error (graceful degradation)
        'remainingSeconds': 30 * 60,
        'dailyLimitMinutes': 30,
        'usedSeconds': 0,
        'sessionMaxDurationMinutes': 15,
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
      final window = _iraqDayWindowUtc();

      final sessionsResponse = await _supabase
          .from('ai_voice_sessions')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'completed')
          .gte('started_at', window.startUtc.toIso8601String())
          .lt('started_at', window.endUtc.toIso8601String());

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






