import 'package:supabase_flutter/supabase_flutter.dart';

class LanguageService {
  final _supabase = Supabase.instance.client;

  /// Fetch active language courses
  Future<List<Map<String, dynamic>>> getActiveLanguages() async {
    try {
      final response = await _supabase
          .from('language_courses')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching language courses: $e');
      return [];
    }
  }

  /// Fetch teachers for a specific language
  Future<List<Map<String, dynamic>>> getTeachersForLanguage(String languageId) async {
    try {
      final response = await _supabase
          .from('teacher_languages')
          .select('*, teachers(*)')
          .eq('language_id', languageId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teachers for language: $e');
      return [];
    }
  }

  /// Fetch all teachers with their languages
  Future<List<Map<String, dynamic>>> getAllTeachersWithLanguages() async {
    try {
      final response = await _supabase
          .from('teachers')
          .select('*, teacher_languages(*, language_courses(*))');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teachers with languages: $e');
      return [];
    }
  }
}
