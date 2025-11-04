import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/level_service.dart';

class AIStoryService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();

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

      // Get today's date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Count stories generated today
      final response = await _supabase
          .from('story_generations')
          .select('id')
          .eq('student_id', studentId)
          .gte('generated_at', today.toIso8601String())
          .lt('generated_at', tomorrow.toIso8601String());

      final count = (response as List).length;
      return count < dailyLimit;
    } catch (e) {
      print('Error checking daily limit: $e');
      return false;
    }
  }

  /// Get remaining stories for today
  Future<int> getRemainingStories(String studentId) async {
    try {
      final settings = await getAISettings();
      final dailyLimit = int.parse(settings['daily_limit_per_student'] ?? '5');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final response = await _supabase
          .from('story_generations')
          .select('id')
          .eq('student_id', studentId)
          .gte('generated_at', today.toIso8601String())
          .lt('generated_at', tomorrow.toIso8601String());

      final count = (response as List).length;
      return dailyLimit - count;
    } catch (e) {
      print('Error getting remaining stories: $e');
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

      // Get AI settings
      final settings = await getAISettings();
      final apiKey = settings['api_key'] ?? '';
      final basePrompt = settings['story_prompt'] ?? '';
      final modelName = settings['model_name'] ?? 'gemini-2.0-flash-lite';
      final minPoints = int.parse(settings['min_points'] ?? '15');
      final maxPoints = int.parse(settings['max_points'] ?? '50');

      if (apiKey.isEmpty) {
        return {
          'success': false,
          'error': 'AI service is not configured. Please contact admin.',
        };
      }

      // Construct the full prompt
      final fullPrompt = '''
$basePrompt "$theme"

IMPORTANT: After writing the story, you must evaluate it and assign points based on these criteria:

Scoring Guide (Total: $minPoints-$maxPoints points):
- Word Count: 
  * Under 150 words: Low points (towards $minPoints)
  * 150-250 words: Medium points (middle range)
  * Over 250 words: Higher points (towards $maxPoints)
  
- Vocabulary Complexity:
  * Simple vocabulary only: Lower points
  * Mix of simple and intermediate words: Medium points
  * Rich, varied vocabulary with some advanced words: Higher points
  
- Story Structure:
  * Basic beginning-middle-end: Lower points
  * Well-developed plot with good flow: Medium points
  * Excellent narrative with engaging elements: Higher points
  
- Educational Value:
  * Minimal learning value: Lower points
  * Some useful language patterns: Medium points
  * Rich learning content with clear lesson: Higher points

Examples:
- Short simple story (120 words, basic vocab): ${minPoints}-${minPoints + 5} points
- Medium story (200 words, good vocab, clear plot): ${minPoints + 10}-${minPoints + 20} points
- Excellent story (280+ words, rich vocab, engaging): ${maxPoints - 10}-$maxPoints points

Vary your scoring! Each story should get different points based on its actual quality.

Format your response EXACTLY as follows:
[STORY_START]
(write the story here)
[STORY_END]

[POINTS]
(write only the number of points, e.g., "25")
[POINTS_END]

[WORD_COUNT]
(write only the word count number, e.g., "250")
[WORD_COUNT_END]
''';

      // Call Google Gemini API (using v1beta for Gemini 2.0 models)
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
      );

      print('Calling Gemini API with model: $modelName');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.9,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'API request failed';
        return {
          'success': false,
          'error': 'Failed to generate story: $errorMessage',
        };
      }

      final data = jsonDecode(response.body);
      
      // Check if response has expected structure
      if (data['candidates'] == null || 
          data['candidates'].isEmpty ||
          data['candidates'][0]['content'] == null ||
          data['candidates'][0]['content']['parts'] == null ||
          data['candidates'][0]['content']['parts'].isEmpty) {
        print('Unexpected API response structure: $data');
        return {
          'success': false,
          'error': 'Unexpected response from AI. Please try again.',
        };
      }
      
      final generatedText = data['candidates'][0]['content']['parts'][0]['text'] as String;
      print('Generated text: $generatedText');

      // Parse the response
      final story = _extractBetween(generatedText, '[STORY_START]', '[STORY_END]').trim();
      final pointsStr = _extractBetween(generatedText, '[POINTS]', '[POINTS_END]').trim();
      final wordCountStr = _extractBetween(generatedText, '[WORD_COUNT]', '[WORD_COUNT_END]').trim();

      int points = int.tryParse(pointsStr) ?? minPoints;
      int wordCount = int.tryParse(wordCountStr) ?? story.split(' ').length;

      // Ensure points are within range
      points = points.clamp(minPoints, maxPoints);

      // Save story to database
      await _supabase.from('story_generations').insert({
        'student_id': studentId,
        'theme': theme,
        'story_text': story,
        'points_awarded': points,
        'word_count': wordCount,
      });

      // Award points to student
      await _levelService.awardPoints(studentId, points);

      return {
        'success': true,
        'story': story,
        'points': points,
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

  /// Helper to extract text between markers
  String _extractBetween(String text, String start, String end) {
    final startIndex = text.indexOf(start);
    final endIndex = text.indexOf(end);

    if (startIndex == -1 || endIndex == -1) {
      return text; // Return full text if markers not found
    }

    return text.substring(startIndex + start.length, endIndex);
  }
}

