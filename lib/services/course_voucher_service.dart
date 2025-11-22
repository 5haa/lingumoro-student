import 'package:supabase_flutter/supabase_flutter.dart';

class CourseVoucherService {
  final _supabase = Supabase.instance.client;

  /// Redeem a course voucher code
  /// This validates the voucher and creates a subscription with automatic session generation
  /// Sessions are generated from today onwards - no backend required!
  Future<Map<String, dynamic>> redeemCourseVoucher({
    required String studentId,
    required String voucherCode,
    required String teacherId,
    required String languageId,
    required List<int> selectedDays,
    required String startTime,
    required String endTime,
  }) async {
    try {
      // Call the new database function that handles everything automatically
      final response = await _supabase.rpc('redeem_course_voucher_v2', params: {
        'p_student_id': studentId,
        'p_voucher_code': voucherCode.toUpperCase(),
        'p_teacher_id': teacherId,
        'p_language_id': languageId,
        'p_selected_days': selectedDays,
        'p_selected_start_time': startTime,
        'p_selected_end_time': endTime,
      });

      if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error redeeming course voucher: $e');
      rethrow;
    }
  }

  /// Check if a voucher code is valid (basic validation without redeeming)
  Future<bool> validateVoucherFormat(String voucherCode) async {
    // Basic format validation: 16 characters, alphanumeric
    if (voucherCode.length != 16) {
      return false;
    }
    
    final validCharacters = RegExp(r'^[A-Z0-9]+$');
    return validCharacters.hasMatch(voucherCode.toUpperCase());
  }
}

