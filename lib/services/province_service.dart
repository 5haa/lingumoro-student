import 'package:supabase_flutter/supabase_flutter.dart';

class ProvinceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all active provinces
  Future<List<Map<String, dynamic>>> getActiveProvinces() async {
    try {
      final response = await _supabase
          .from('provinces')
          .select()
          .eq('is_active', true)
          .order('order_index');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching provinces: $e');
      throw Exception('Failed to load provinces');
    }
  }

  /// Get province by ID
  Future<Map<String, dynamic>?> getProvinceById(String provinceId) async {
    try {
      final response = await _supabase
          .from('provinces')
          .select()
          .eq('id', provinceId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching province: $e');
      return null;
    }
  }
}

