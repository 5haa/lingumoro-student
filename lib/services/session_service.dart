import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUpcomingSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('sessions')
          .select('''
            *,
            teacher:teachers(id, full_name, email, avatar_url, is_online),
            language:language_courses(id, name, flag_url),
            subscription:student_subscriptions(id, points_remaining, status)
          ''')
          .eq('student_id', user.id)
          .gte('scheduled_date', today)
          .inFilter('status', ['scheduled', 'ready', 'in_progress'])
          .order('scheduled_date')
          .order('scheduled_start_time');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching upcoming sessions: $e');
      throw Exception('Failed to load upcoming sessions');
    }
  }

  Future<List<Map<String, dynamic>>> getPastSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('sessions')
          .select('''
            *,
            teacher:teachers(id, full_name, email, avatar_url, is_online),
            language:language_courses(id, name, flag_url),
            subscription:student_subscriptions(id, points_remaining, status)
          ''')
          .eq('student_id', user.id)
          .inFilter('status', ['completed', 'cancelled', 'missed'])
          .order('scheduled_date', ascending: false)
          .order('scheduled_start_time', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching past sessions: $e');
      throw Exception('Failed to load past sessions');
    }
  }

  Future<Map<String, dynamic>?> getTodaySession() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('sessions')
          .select('''
            *,
            teacher:teachers(id, full_name),
            language:language_courses(id, name, flag_url)
          ''')
          .eq('student_id', user.id)
          .eq('scheduled_date', today)
          .inFilter('status', ['scheduled', 'ready', 'in_progress'])
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching today\'s session: $e');
      return null;
    }
  }

  bool canJoinSession(Map<String, dynamic> session) {
    try {
      // Check if meeting link is set
      if (session['meeting_link'] == null || session['meeting_link'].toString().isEmpty) {
        return false;
      }

      final status = session['status'];
      
      // Can always join if session is in progress
      if (status == 'in_progress') {
        return true;
      }

      // Check if it's the right time to join (within 15 minutes before start time)
      final now = DateTime.now();
      final scheduledDate = DateTime.parse(session['scheduled_date']);
      final scheduledTime = _parseTime(session['scheduled_start_time']);
      
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledTime['hour']!,
        scheduledTime['minute']!,
      );

      // Can join 15 minutes before until session end time
      final joinWindowStart = scheduledDateTime.subtract(const Duration(minutes: 15));
      final endTime = _parseTime(session['scheduled_end_time']);
      final sessionEnd = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        endTime['hour']!,
        endTime['minute']!,
      );

      return now.isAfter(joinWindowStart) && now.isBefore(sessionEnd);
    } catch (e) {
      print('Error checking if can join session: $e');
      return false;
    }
  }

  String getSessionStatus(Map<String, dynamic> session) {
    try {
      final status = session['status'];
      
      // If session is in_progress, always show that
      if (status == 'in_progress') {
        return 'in_progress';
      }
      
      final now = DateTime.now();
      final scheduledDate = DateTime.parse(session['scheduled_date']);
      final scheduledTime = _parseTime(session['scheduled_start_time']);
      
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledTime['hour']!,
        scheduledTime['minute']!,
      );

      if (now.isBefore(scheduledDateTime.subtract(const Duration(minutes: 15)))) {
        return 'upcoming';
      } else if (canJoinSession(session)) {
        return 'ready';
      } else {
        return session['status'] ?? 'scheduled';
      }
    } catch (e) {
      return session['status'] ?? 'unknown';
    }
  }

  Map<String, int> _parseTime(String timeString) {
    // Parse time in format "HH:MM:SS" or "HH:MM"
    final parts = timeString.split(':');
    return {
      'hour': int.parse(parts[0]),
      'minute': int.parse(parts[1]),
    };
  }

  String getTimeUntilSession(Map<String, dynamic> session) {
    try {
      final now = DateTime.now();
      final scheduledDate = DateTime.parse(session['scheduled_date']);
      final scheduledTime = _parseTime(session['scheduled_start_time']);
      
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledTime['hour']!,
        scheduledTime['minute']!,
      );

      final difference = scheduledDateTime.difference(now);

      if (difference.isNegative) {
        return 'Now';
      }

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

