import 'package:supabase_flutter/supabase_flutter.dart';

class PackageService {
  final _supabase = Supabase.instance.client;

  /// Fetch active packages
  Future<List<Map<String, dynamic>>> getActivePackages() async {
    try {
      final response = await _supabase
          .from('packages')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching packages: $e');
      return [];
    }
  }

  /// Fetch featured packages
  Future<List<Map<String, dynamic>>> getFeaturedPackages() async {
    try {
      final response = await _supabase
          .from('packages')
          .select()
          .eq('is_active', true)
          .eq('is_featured', true)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching featured packages: $e');
      return [];
    }
  }
}





