import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProSubscriptionService {
  final _supabase = Supabase.instance.client;

  /// Check if student has active PRO subscription
  Future<Map<String, dynamic>?> getProStatus(String studentId) async {
    try {
      final response = await _supabase.rpc('get_active_pro_subscription', params: {
        'p_student_id': studentId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting PRO status: $e');
      rethrow;
    }
  }

  /// Check if student has active PRO subscription (boolean)
  Future<bool> hasActivePro(String studentId) async {
    try {
      final response = await _supabase.rpc('has_active_pro_subscription', params: {
        'p_student_id': studentId,
      });

      return response == true;
    } catch (e) {
      print('Error checking PRO status: $e');
      return false;
    }
  }

  /// Redeem a voucher code
  Future<Map<String, dynamic>> redeemVoucher(String studentId, String voucherCode) async {
    try {
      final response = await _supabase.rpc('redeem_voucher', params: {
        'p_student_id': studentId,
        'p_voucher_code': voucherCode.toUpperCase(),
      });

      if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error redeeming voucher: $e');
      rethrow;
    }
  }

  /// Get subscription history
  Future<List<Map<String, dynamic>>> getSubscriptionHistory(String studentId) async {
    try {
      final response = await _supabase
          .from('pro_subscriptions')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      print('Error getting subscription history: $e');
      rethrow;
    }
  }

  /// Format expiry date
  String formatExpiryDate(String expiresAt) {
    try {
      final date = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = date.difference(now);

      if (difference.isNegative) {
        return 'Expired';
      }

      if (difference.inDays > 0) {
        return '${difference.inDays} days remaining';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours remaining';
      } else {
        return 'Expires soon';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Get days remaining
  int getDaysRemaining(String expiresAt) {
    try {
      final date = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = date.difference(now);

      return difference.inDays.clamp(0, 9999);
    } catch (e) {
      return 0;
    }
  }
}

