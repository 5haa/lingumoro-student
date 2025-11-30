import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProSubscriptionService {
  final _supabase = Supabase.instance.client;
  
  // Cache for device session validation
  Map<String, dynamic>? _cachedDeviceSession;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(seconds: 30); // Reduced to 30s for better responsiveness

  /// Get current session token
  String? getSessionToken() {
    try {
      final session = _supabase.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      print('Error getting session token: $e');
      return null;
    }
  }

  /// Validate and update device session for PRO subscription
  /// [forceClaim] - If true, will take over session from another device
  Future<Map<String, dynamic>> validateAndUpdateDeviceSession(String studentId, {bool forceClaim = false}) async {
    try {
      final sessionToken = getSessionToken();
      
      if (sessionToken == null) {
        return {
          'has_pro': false,
          'is_valid': false,
          'active_on_other_device': false,
          'device_changed': false,
          'error': 'No session token available',
        };
      }

      final response = await _supabase.rpc('check_pro_device_session', params: {
        'p_student_id': studentId,
        'p_session_token': sessionToken,
        'p_force_claim': forceClaim,
      });

      if (response is Map<String, dynamic>) {
        // Cache the result
        _cachedDeviceSession = response;
        _cacheTimestamp = DateTime.now();
        
        print('✅ Device session validated: $response');
        return response;
      }
      
      throw Exception('Invalid response format');
    } catch (e) {
      print('❌ Error validating device session: $e');
      return {
        'has_pro': false,
        'is_valid': false,
        'active_on_other_device': false,
        'device_changed': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if device session is valid (uses cache if available)
  Future<bool> isDeviceSessionValid(String studentId) async {
    // Check cache first
    if (_cachedDeviceSession != null && _cacheTimestamp != null) {
      final cacheAge = DateTime.now().difference(_cacheTimestamp!);
      if (cacheAge < _cacheValidity) {
        return _cachedDeviceSession!['is_valid'] == true;
      }
    }

    // Cache expired or doesn't exist, validate
    final result = await validateAndUpdateDeviceSession(studentId);
    return result['is_valid'] == true;
  }

  /// Get cached device session info (without making network call)
  Map<String, dynamic>? getCachedDeviceSession() {
    if (_cachedDeviceSession != null && _cacheTimestamp != null) {
      final cacheAge = DateTime.now().difference(_cacheTimestamp!);
      if (cacheAge < _cacheValidity) {
        return _cachedDeviceSession;
      }
    }
    return null;
  }

  /// Clear device session cache
  void clearDeviceSessionCache() {
    _cachedDeviceSession = null;
    _cacheTimestamp = null;
  }

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
  /// This now validates device session by default
  Future<bool> hasActivePro(String studentId, {bool checkDeviceSession = true}) async {
    try {
      if (checkDeviceSession) {
        // Check device session validity
        final sessionValid = await isDeviceSessionValid(studentId);
        return sessionValid;
      } else {
        // Old behavior - just check if pro exists
        final response = await _supabase.rpc('has_active_pro_subscription', params: {
          'p_student_id': studentId,
        });
        return response == true;
      }
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

