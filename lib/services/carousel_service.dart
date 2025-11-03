import 'package:supabase_flutter/supabase_flutter.dart';

class CarouselService {
  final _supabase = Supabase.instance.client;

  /// Fetch active carousel slides
  Future<List<Map<String, dynamic>>> getActiveSlides() async {
    try {
      final response = await _supabase
          .from('carousel_slides')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching carousel slides: $e');
      return [];
    }
  }
}



