import 'package:supabase_flutter/supabase_flutter.dart';

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get languages that the current student is learning (has active subscriptions for)
  Future<List<String>> getStudentLanguages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('student_subscriptions')
          .select('language_id')
          .eq('student_id', user.id)
          .eq('status', 'active');

      // Extract unique language IDs
      final languageIds = <String>{};
      for (var subscription in response) {
        if (subscription['language_id'] != null) {
          languageIds.add(subscription['language_id']);
        }
      }

      return languageIds.toList();
    } catch (e) {
      print('Error fetching student languages: $e');
      return [];
    }
  }

  /// Get students learning the same languages as the current student
  Future<List<Map<String, dynamic>>> getStudentsInSameLanguages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // First, get the languages the current student is learning
      final studentLanguages = await getStudentLanguages();

      // If student hasn't taken any courses, return empty list
      if (studentLanguages.isEmpty) {
        return [];
      }

      // Get all students with subscriptions in the same languages
      final response = await _supabase
          .from('student_subscriptions')
          .select('''
            student_id,
            language_id,
            student:students(id, full_name, email, avatar_url, bio, province:provinces(id, name, name_ar, code)),
            language:language_courses(id, name, code, flag_url)
          ''')
          .inFilter('language_id', studentLanguages)
          .eq('status', 'active')
          .neq('student_id', user.id); // Exclude current user

      // Group students by ID to avoid duplicates and collect their languages
      final Map<String, Map<String, dynamic>> studentsMap = {};
      
      for (var subscription in response) {
        final studentData = subscription['student'];
        final languageData = subscription['language'];
        
        if (studentData != null && languageData != null) {
          final studentId = studentData['id'];
          
          if (!studentsMap.containsKey(studentId)) {
            studentsMap[studentId] = {
              'id': studentData['id'],
              'full_name': studentData['full_name'],
              'email': studentData['email'],
              'avatar_url': studentData['avatar_url'],
              'bio': studentData['bio'],
              'province': studentData['province'],
              'languages': <Map<String, dynamic>>[],
            };
          }
          
          // Add language if not already added
          final languages = studentsMap[studentId]!['languages'] as List<Map<String, dynamic>>;
          final languageExists = languages.any((lang) => lang['id'] == languageData['id']);
          
          if (!languageExists) {
            languages.add({
              'id': languageData['id'],
              'name': languageData['name'],
              'code': languageData['code'],
              'flag_url': languageData['flag_url'],
            });
          }
        }
      }

      return studentsMap.values.toList();
    } catch (e) {
      print('Error fetching students in same languages: $e');
      throw Exception('Failed to load students');
    }
  }

  /// Get students learning a specific language
  Future<List<Map<String, dynamic>>> getStudentsByLanguage(String languageId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if current student is learning this language
      final studentLanguages = await getStudentLanguages();
      if (!studentLanguages.contains(languageId)) {
        return []; // Student doesn't have access to this language's students
      }

      final response = await _supabase
          .from('student_subscriptions')
          .select('''
            student:students(id, full_name, email, avatar_url, bio, province:provinces(id, name, name_ar, code))
          ''')
          .eq('language_id', languageId)
          .eq('status', 'active')
          .neq('student_id', user.id); // Exclude current user

      // Extract unique students
      final Map<String, Map<String, dynamic>> studentsMap = {};
      
      for (var subscription in response) {
        final studentData = subscription['student'];
        if (studentData != null) {
          final studentId = studentData['id'];
          if (!studentsMap.containsKey(studentId)) {
            studentsMap[studentId] = {
              'id': studentData['id'],
              'full_name': studentData['full_name'],
              'email': studentData['email'],
              'avatar_url': studentData['avatar_url'],
              'bio': studentData['bio'],
              'province': studentData['province'],
            };
          }
        }
      }

      return studentsMap.values.toList();
    } catch (e) {
      print('Error fetching students by language: $e');
      throw Exception('Failed to load students');
    }
  }
}

