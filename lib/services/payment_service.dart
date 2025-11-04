import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await _supabase
          .from('payment_methods')
          .select()
          .eq('is_active', true)
          .order('order_index');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching payment methods: $e');
      throw Exception('Failed to load payment methods');
    }
  }

  Future<String> uploadPaymentProof(String filePath) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'payment-proofs/$fileName';

      // Upload to Supabase Storage
      final file = File(filePath);
      await _supabase.storage
          .from('payments')
          .upload(storagePath, file);

      // Get public URL
      final url = _supabase.storage
          .from('payments')
          .getPublicUrl(storagePath);

      return url;
    } catch (e) {
      print('Error uploading payment proof: $e');
      throw Exception('Failed to upload payment proof');
    }
  }

  Future<Map<String, dynamic>> submitPayment({
    required String teacherId,
    required String packageId,
    required String languageId,
    required String paymentMethodId,
    required double amount,
    required String paymentProofUrl,
    String? studentNotes,
    List<int>? selectedDays,
    String? selectedStartTime,
    String? selectedEndTime,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Insert payment submission
      final response = await _supabase.from('payment_submissions').insert({
        'student_id': user.id,
        'teacher_id': teacherId,
        'package_id': packageId,
        'language_id': languageId,
        'payment_method_id': paymentMethodId,
        'amount': amount,
        'payment_proof_url': paymentProofUrl,
        'student_notes': studentNotes,
        'status': 'pending',
        if (selectedDays != null) 'selected_days': selectedDays,
        if (selectedStartTime != null) 'selected_start_time': selectedStartTime,
        if (selectedEndTime != null) 'selected_end_time': selectedEndTime,
      }).select().single();

      // Reserve timeslots temporarily (48 hours) if schedule was provided
      if (selectedDays != null && selectedDays.isNotEmpty && 
          selectedStartTime != null && selectedEndTime != null) {
        try {
          await _supabase.rpc('reserve_timeslots_temporarily', params: {
            'p_teacher_id': teacherId,
            'p_payment_id': response['id'],
            'p_days': selectedDays,
            'p_start_time': selectedStartTime,
            'p_end_time': selectedEndTime,
            'p_reservation_hours': 48,
          });
        } catch (e) {
          print('Warning: Could not reserve timeslots: $e');
          // Continue even if reservation fails - payment is submitted
        }
      }

      return response;
    } catch (e) {
      print('Error submitting payment: $e');
      throw Exception('Failed to submit payment');
    }
  }

  Future<List<Map<String, dynamic>>> getMyPayments() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('payment_submissions')
          .select('''
            *,
            payment_method:payment_methods(name, type),
            package:packages(name, price_monthly),
            teacher:teachers(full_name),
            language:language_courses(name)
          ''')
          .eq('student_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching my payments: $e');
      throw Exception('Failed to load payment history');
    }
  }

  Future<Map<String, dynamic>?> getPendingPayment({
    required String teacherId,
    required String packageId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('payment_submissions')
          .select()
          .eq('student_id', user.id)
          .eq('teacher_id', teacherId)
          .eq('package_id', packageId)
          .eq('status', 'pending')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error checking pending payment: $e');
      return null;
    }
  }
}

