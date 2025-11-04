import 'package:supabase_flutter/supabase_flutter.dart';

class RatingService {
  final _supabase = Supabase.instance.client;

  /// Get teacher rating statistics
  Future<Map<String, dynamic>?> getTeacherRatingStats(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_rating_stats')
          .select()
          .eq('teacher_id', teacherId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching teacher rating stats: $e');
      return null;
    }
  }

  /// Get all ratings for a teacher
  Future<List<Map<String, dynamic>>> getTeacherRatings(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_ratings')
          .select('''
            *,
            students:student_id (
              full_name,
              avatar_url
            )
          ''')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teacher ratings: $e');
      return [];
    }
  }

  /// Get student's rating for a specific teacher
  Future<Map<String, dynamic>?> getStudentRating(
    String studentId,
    String teacherId,
  ) async {
    try {
      final response = await _supabase
          .from('teacher_ratings')
          .select()
          .eq('student_id', studentId)
          .eq('teacher_id', teacherId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching student rating: $e');
      return null;
    }
  }

  /// Check if student can rate teacher (has/had subscription)
  Future<bool> canRateTeacher(String studentId, String teacherId) async {
    try {
      final response = await _supabase
          .from('student_subscriptions')
          .select()
          .eq('student_id', studentId)
          .eq('teacher_id', teacherId);

      // Check if any subscription exists with allowed statuses
      if (response.isEmpty) return false;
      
      for (var sub in response) {
        final status = sub['status'] as String?;
        if (status == 'active' || status == 'expired' || status == 'cancelled') {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking if can rate teacher: $e');
      return false;
    }
  }

  /// Submit or update rating
  Future<bool> submitRating({
    required String studentId,
    required String teacherId,
    required int rating,
    String? comment,
  }) async {
    try {
      // Check if rating already exists
      final existingRating = await getStudentRating(studentId, teacherId);

      if (existingRating != null) {
        // Update existing rating
        await _supabase
            .from('teacher_ratings')
            .update({
              'rating': rating,
              'comment': comment,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('student_id', studentId)
            .eq('teacher_id', teacherId);
      } else {
        // Insert new rating
        await _supabase.from('teacher_ratings').insert({
          'student_id': studentId,
          'teacher_id': teacherId,
          'rating': rating,
          'comment': comment,
        });
      }

      return true;
    } catch (e) {
      print('Error submitting rating: $e');
      return false;
    }
  }

  /// Delete rating
  Future<bool> deleteRating(String studentId, String teacherId) async {
    try {
      await _supabase
          .from('teacher_ratings')
          .delete()
          .eq('student_id', studentId)
          .eq('teacher_id', teacherId);

      return true;
    } catch (e) {
      print('Error deleting rating: $e');
      return false;
    }
  }
}

