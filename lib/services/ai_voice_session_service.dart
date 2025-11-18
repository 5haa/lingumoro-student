import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:student/services/level_service.dart';
import 'package:student/services/ai_speech_service.dart';

class AIVoiceSessionService {
  final _levelService = LevelService();
  
  // Use the same base URL as AiSpeechService
  String get _baseUrl => AiSpeechService.baseUrl;

  /// Start a new AI voice session
  Future<Map<String, dynamic>?> startSession(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/voice-session/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        // Session limit reached or active session exists
        final error = jsonDecode(response.body);
        print('Cannot start session: ${error['message']}');
        return error;
      } else {
        print('Error starting session: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  /// Complete an AI voice session and award points
  Future<Map<String, dynamic>?> completeSession(String sessionId, String studentId, {int? durationSeconds}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/voice-session/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'duration_seconds': durationSeconds ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        // Refresh student progress to update points display
        await _levelService.getStudentProgress(studentId);
        
        return result;
      } else {
        print('Error completing session: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to complete session',
        };
      }
    } catch (e) {
      print('Error completing session: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Cancel an active session (no points awarded)
  Future<Map<String, dynamic>?> cancelSession(String sessionId, {int? durationSeconds}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/voice-session/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'duration_seconds': durationSeconds ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error cancelling session: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to cancel session',
        };
      }
    } catch (e) {
      print('Error cancelling session: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get student's session statistics
  Future<Map<String, dynamic>> getSessionStats(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/voice-session/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error getting session stats: ${response.statusCode}');
        return {
          'sessions_today': 0,
          'remaining_sessions': 2,
          'has_active_session': false,
          'total_points_earned_today': 0,
        };
      }
    } catch (e) {
      print('Error getting session stats: $e');
      return {
        'sessions_today': 0,
        'remaining_sessions': 2,
        'has_active_session': false,
        'total_points_earned_today': 0,
      };
    }
  }

  /// Get session settings (limits, duration, points config)
  Future<Map<String, dynamic>> getSessionSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/voice-session/settings'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error getting session settings: ${response.statusCode}');
        return {
          'max_voice_sessions_per_day': 2,
          'voice_session_duration_minutes': 15,
        };
      }
    } catch (e) {
      print('Error getting session settings: $e');
      return {
        'max_voice_sessions_per_day': 2,
        'voice_session_duration_minutes': 15,
      };
    }
  }
}
