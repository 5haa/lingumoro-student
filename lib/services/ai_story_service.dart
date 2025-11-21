import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';

class AIStoryService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  
  // AI server URL configuration
  static const String _serverUrl = 'https://lingumoroai-production.up.railway.app';

  /// Get AI settings from Supabase
  Future<Map<String, String>> getAISettings() async {
    try {
      final response = await _supabase
          .from('ai_settings')
          .select('setting_key, setting_value');

      final settings = <String, String>{};
      for (final setting in response as List) {
        settings[setting['setting_key']] = setting['setting_value'];
      }

      return settings;
    } catch (e) {
      print('Error fetching AI settings: $e');
      rethrow;
    }
  }

  /// Check if student has reached their daily limit
  Future<bool> checkDailyLimit(String studentId) async {
    try {
      final settings = await getAISettings();
      final dailyLimit = int.parse(settings['daily_limit_per_student'] ?? '5');

      // Get today's date - use UTC to match database
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Count stories generated today
      final response = await _supabase
          .from('story_generations')
          .select('id')
          .eq('student_id', studentId)
          .gte('generated_at', today.toIso8601String())
          .lt('generated_at', tomorrow.toIso8601String());

      final count = (response as List).length;
      final canGenerate = count < dailyLimit;
      
      print('🔍 Daily limit check: $count/$dailyLimit - Can generate: $canGenerate');
      
      return canGenerate;
    } catch (e) {
      print('❌ Error checking daily limit: $e');
      return false;
    }
  }

  /// Get remaining stories for today
  Future<int> getRemainingStories(String studentId) async {
    try {
      final settings = await getAISettings();
      final dailyLimit = int.parse(settings['daily_limit_per_student'] ?? '5');

      final now = DateTime.now().toUtc();
      // Use UTC to match database timestamps
      final today = DateTime.utc(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      print('📊 Checking stories for student: $studentId');
      print('📅 Today (UTC): ${today.toIso8601String()}');
      print('📅 Tomorrow (UTC): ${tomorrow.toIso8601String()}');

      final response = await _supabase
          .from('story_generations')
          .select('id, generated_at, theme')
          .eq('student_id', studentId)
          .gte('generated_at', today.toIso8601String())
          .lt('generated_at', tomorrow.toIso8601String());

      final stories = response as List;
      print('📚 Stories found today: ${stories.length}');
      if (stories.isNotEmpty) {
        print('📖 Stories:');
        for (var story in stories) {
          print('   - ${story['theme']} at ${story['generated_at']}');
        }
      }
      print('📊 Daily limit: $dailyLimit');
      print('✅ Remaining: ${dailyLimit - stories.length}');
      
      return dailyLimit - stories.length;
    } catch (e) {
      print('❌ Error getting remaining stories: $e');
      return 0;
    }
  }

  /// Generate story using Google Gemini API
  Future<Map<String, dynamic>> generateStory(
    String studentId,
    String theme,
  ) async {
    try {
      // Check daily limit first
      final canGenerate = await checkDailyLimit(studentId);
      if (!canGenerate) {
        return {
          'success': false,
          'error': 'You have reached your daily limit for story generation.',
        };
      }

      // Get AI settings for prompt customization (optional)
      final settings = await getAISettings();
      final basePrompt = settings['story_prompt'];
      final minPoints = int.parse(settings['min_points'] ?? '15');
      final maxPoints = int.parse(settings['max_points'] ?? '50');

      print('Calling AI Server for story generation...');
      
      // Call AI Server instead of Gemini directly
      final response = await http.post(
        Uri.parse('$_serverUrl/api/generate-story'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'theme': theme,
          'base_prompt': basePrompt,
          'min_points': minPoints,
          'max_points': maxPoints,
        }),
      ).timeout(const Duration(seconds: 40));

      print('AI Server Response Status: ${response.statusCode}');
      print('AI Server Response Body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Story generation failed';
        return {
          'success': false,
          'error': 'Failed to generate story: $errorMessage',
        };
      }

      final data = jsonDecode(response.body);
      
      // Check if response has expected structure
      if (data['success'] != true || data['story'] == null) {
        print('Unexpected API response structure: $data');
        return {
          'success': false,
          'error': 'Unexpected response from AI. Please try again.',
        };
      }
      
      final story = data['story'] as String;
      int points = data['points'] ?? minPoints;
      int wordCount = data['word_count'] ?? story.split(' ').length;

      print('Generated story: $wordCount words, $points points');

      // Save story to database (no points awarded)
      final now = DateTime.now().toUtc();
      print('💾 Saving story with timestamp: ${now.toIso8601String()}');
      
      try {
        final insertResult = await _supabase.from('story_generations').insert({
          'student_id': studentId,
          'theme': theme,
          'story_text': story,
          'points_awarded': 0,  // No points for story generation
          'word_count': wordCount,
          'generated_at': now.toIso8601String(),  // Explicitly set UTC timestamp
        }).select();  // Add select() to get the inserted row
        
        print('✅ Story saved to database: $insertResult');
      } catch (insertError) {
        print('❌ Error saving story to database: $insertError');
        // Continue anyway - the story was generated successfully
      }

      // Points removed - students don't get points for story generation anymore

      return {
        'success': true,
        'story': story,
        'points': 0,  // No points awarded
        'wordCount': wordCount,
        'theme': theme,
      };
    } catch (e) {
      print('Error generating story: $e');
      return {
        'success': false,
        'error': 'An error occurred while generating the story. Please try again.',
      };
    }
  }

  /// Get student's story history
  Future<List<Map<String, dynamic>>> getStoryHistory(String studentId) async {
    try {
      final response = await _supabase
          .from('story_generations')
          .select('*')
          .eq('student_id', studentId)
          .order('generated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching story history: $e');
      return [];
    }
  }

}

