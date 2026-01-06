import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/blocking_service.dart';

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _blockingService = BlockingService();

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

  /// Get all students (no course restrictions)
  Future<List<Map<String, dynamic>>> getAllStudents({
    Set<String>? knownBlockedIds,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // OPTIMIZATION: Use cached/known data if available, otherwise fetch in parallel
      final futures = await Future.wait([
        if (knownBlockedIds == null) _blockingService.getBlockedUserIds() else Future.value(<String>{}),
        if (knownBlockedIds == null) _blockingService.getUsersWhoBlockedMe() else Future.value(<String>{}),
      ]);
      
      final Set<String> allBlockedIds;
      if (knownBlockedIds != null) {
        allBlockedIds = knownBlockedIds;
      } else {
        final blockedIds = futures[0] as Set<String>;
        final blockerIds = futures[1] as Set<String>;
        allBlockedIds = {...blockedIds, ...blockerIds};
      }

      // Get all students
      final response = await _supabase
          .from('students')
          .select('''
            id, full_name, email, avatar_url, bio, is_suspended,
            province:provinces(id, name, name_ar, code),
            subscriptions:student_subscriptions(
              language:language_courses(id, name, code, flag_url)
            )
          ''')
          .eq('is_suspended', false) // Filter suspended students
          .neq('id', user.id); // Exclude current user

      // Process students to flatten languages
      final List<Map<String, dynamic>> studentsList = [];
      
      for (var studentData in response) {
        final studentId = studentData['id'];
        
        // Skip blocked users
        if (allBlockedIds.contains(studentId)) {
          continue;
        }
        
        // Process subscriptions to get languages
        final List<Map<String, dynamic>> languages = [];
        final subscriptions = studentData['subscriptions'] as List<dynamic>? ?? [];
        
        for (var sub in subscriptions) {
          final language = sub['language'];
          if (language != null) {
             // Avoid duplicate languages
             if (!languages.any((l) => l['id'] == language['id'])) {
               languages.add({
                'id': language['id'],
                'name': language['name'],
                'code': language['code'],
                'flag_url': language['flag_url'],
               });
             }
          }
        }
        
        studentsList.add({
          'id': studentData['id'],
          'full_name': studentData['full_name'],
          'email': studentData['email'],
          'avatar_url': studentData['avatar_url'],
          'bio': studentData['bio'],
          'province': studentData['province'],
          'languages': languages,
        });
      }

      return studentsList;
    } catch (e) {
      print('Error fetching all students: $e');
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

