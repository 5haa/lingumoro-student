import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherService {
  final _supabase = Supabase.instance.client;

  /// Fetch teacher details with schedule
  Future<Map<String, dynamic>?> getTeacherWithSchedule(String teacherId) async {
    try {
      final teacherResponse = await _supabase
          .from('teachers')
          .select()
          .eq('id', teacherId)
          .single();

      // Get teacher's schedule
      final scheduleResponse = await _supabase
          .from('teacher_schedules')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_available', true)
          .order('day_of_week', ascending: true)
          .order('start_time', ascending: true);

      final schedule = List<Map<String, dynamic>>.from(scheduleResponse);

      return {
        ...teacherResponse,
        'schedules': schedule,
      };
    } catch (e) {
      print('Error fetching teacher with schedule: $e');
      return null;
    }
  }

  /// Create subscription
  Future<bool> createSubscription({
    required String studentId,
    required String teacherId,
    required String languageId,
    required String packageId,
  }) async {
    try {
      await _supabase.from('student_subscriptions').insert({
        'student_id': studentId,
        'teacher_id': teacherId,
        'language_id': languageId,
        'package_id': packageId,
        'status': 'active',
      });

      return true;
    } catch (e) {
      print('Error creating subscription: $e');
      return false;
    }
  }

  /// Check if student has active subscription with this teacher
  Future<bool> hasActiveSubscription(String studentId, String teacherId) async {
    try {
      final response = await _supabase
          .from('student_subscriptions')
          .select()
          .eq('student_id', studentId)
          .eq('teacher_id', teacherId)
          .eq('status', 'active');

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }
}





