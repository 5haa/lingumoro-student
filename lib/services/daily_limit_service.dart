import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing daily practice limits (1 quiz + 1 video + 1 reading per day)
class DailyLimitService {
  final _supabase = Supabase.instance.client;

  // Iraq uses Asia/Baghdad (UTC+3). We enforce the same day-boundary in DB via trigger.
  static const Duration _iraqOffset = Duration(hours: 3);

  /// Practice types for daily limits
  static const String practiceTypeQuiz = 'quiz';
  static const String practiceTypeVideo = 'video';
  static const String practiceTypeReading = 'reading';

  DateTime _nowUtc() => DateTime.now().toUtc();

  /// Returns a UTC DateTime whose date components represent Iraq local date/time (UTC shifted by +3h).
  DateTime _nowIraqAsUtc() => _nowUtc().add(_iraqOffset);

  String _formatDateYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _todayIraqDateString() {
    final iraqNow = _nowIraqAsUtc();
    return _formatDateYmd(iraqNow);
  }

  /// Check if student can practice a specific type today
  /// Returns true if limit not reached, false if already completed today
  Future<bool> checkDailyLimit(String studentId, String practiceType) async {
    try {
      final todayDateString = _todayIraqDateString();

      final response = await _supabase
          .from('daily_practice_limits')
          .select('quiz_completed, video_completed, reading_completed')
          .eq('student_id', studentId)
          .eq('practice_date', todayDateString)
          .maybeSingle();

      if (response == null) {
        // No record for today, all limits available
        return true;
      }

      // Check specific practice type
      switch (practiceType) {
        case practiceTypeQuiz:
          return response['quiz_completed'] != true;
        case practiceTypeVideo:
          return response['video_completed'] != true;
        case practiceTypeReading:
          return response['reading_completed'] != true;
        default:
          return false;
      }
    } catch (e) {
      print('Error checking daily limit: $e');
      return false;
    }
  }

  /// Record practice completion for today
  Future<bool> recordPracticeCompletion(
      String studentId, String practiceType, {String? attemptId}) async {
    try {
      final todayDateString = _todayIraqDateString();
      final now = _nowUtc().toIso8601String();

      print('🔄 Recording practice completion: type=$practiceType, studentId=$studentId, date=$todayDateString');

      // Check if record exists for today
      final existing = await _supabase
          .from('daily_practice_limits')
          .select('id, quiz_completed, video_completed, reading_completed')
          .eq('student_id', studentId)
          .eq('practice_date', todayDateString)
          .maybeSingle();

      print('📊 Existing record: $existing');

      Map<String, dynamic> updateData = {
        'updated_at': now,
      };

      switch (practiceType) {
        case practiceTypeQuiz:
          updateData['quiz_completed'] = true;
          updateData['quiz_completed_at'] = now;
          if (attemptId != null) {
            updateData['quiz_attempt_id'] = attemptId;
          }
          break;
        case practiceTypeVideo:
          updateData['video_completed'] = true;
          updateData['video_completed_at'] = now;
          break;
        case practiceTypeReading:
          updateData['reading_completed'] = true;
          updateData['reading_completed_at'] = now;
          break;
      }

      if (existing != null) {
        // Update existing record
        print('✏️ Updating existing record with: $updateData');
        final result = await _supabase
            .from('daily_practice_limits')
            .update(updateData)
            .eq('student_id', studentId)
            .eq('practice_date', todayDateString)
            .select();
        print('✅ Update result: $result');
      } else {
        // Create new record
        updateData.addAll({
          'student_id': studentId,
          'practice_date': todayDateString,
          'quiz_completed': practiceType == practiceTypeQuiz,
          'video_completed': practiceType == practiceTypeVideo,
          'reading_completed': practiceType == practiceTypeReading,
          'created_at': now,
        });

        print('➕ Inserting new record with: $updateData');
        final result = await _supabase
            .from('daily_practice_limits')
            .insert(updateData)
            .select();
        print('✅ Insert result: $result');
      }

      print('✅ Successfully recorded practice completion');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error recording practice completion: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get today's practice status for all types
  /// Returns map with keys: quiz_completed, video_completed, reading_completed
  Future<Map<String, bool>> getDailyLimitStatus(String studentId) async {
    try {
      final todayDateString = _todayIraqDateString();

      final response = await _supabase
          .from('daily_practice_limits')
          .select('quiz_completed, video_completed, reading_completed')
          .eq('student_id', studentId)
          .eq('practice_date', todayDateString)
          .maybeSingle();

      if (response == null) {
        return {
          'quiz_completed': false,
          'video_completed': false,
          'reading_completed': false,
        };
      }

      return {
        'quiz_completed': response['quiz_completed'] == true,
        'video_completed': response['video_completed'] == true,
        'reading_completed': response['reading_completed'] == true,
      };
    } catch (e) {
      print('Error getting daily limit status: $e');
      return {
        'quiz_completed': false,
        'video_completed': false,
        'reading_completed': false,
      };
    }
  }

  /// Calculate time until daily reset (midnight Iraq time, Asia/Baghdad).
  Duration getTimeUntilReset() {
    final nowIraq = _nowIraqAsUtc();
    final nextMidnightIraq = DateTime.utc(nowIraq.year, nowIraq.month, nowIraq.day + 1);
    return nextMidnightIraq.difference(nowIraq);
  }

  /// Get time until reset as a formatted string (e.g., "5h 23m")
  String getTimeUntilResetFormatted() {
    final duration = getTimeUntilReset();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if all three practice types have been completed today
  Future<bool> allPracticesCompletedToday(String studentId) async {
    final status = await getDailyLimitStatus(studentId);
    return status['quiz_completed']! &&
        status['video_completed']! &&
        status['reading_completed']!;
  }

  /// Get count of completed practices today (0-3)
  Future<int> getCompletedCountToday(String studentId) async {
    final status = await getDailyLimitStatus(studentId);
    int count = 0;
    if (status['quiz_completed']!) count++;
    if (status['video_completed']!) count++;
    if (status['reading_completed']!) count++;
    return count;
  }

  /// Check if student can practice any type today
  Future<bool> canPracticeAnyTypeToday(String studentId) async {
    final completed = await allPracticesCompletedToday(studentId);
    return !completed;
  }
}



