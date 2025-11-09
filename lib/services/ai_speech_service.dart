import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Enhanced AI Speech Service
/// Provides text-to-speech and AI chat capabilities
class AiSpeechService {
  // Server configuration
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://192.168.152.58:5000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost directly
      return 'http://localhost:5000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms
      return 'http://localhost:5000';
    } else {
      // Fallback
      return 'http://localhost:5000';
    }
  }

  /// Set a custom server URL (for production or custom deployments)
  static String? _customUrl;
  
  static void setServerUrl(String url) {
    _customUrl = url;
  }

  static String get serverUrl => _customUrl ?? baseUrl;

  /// Check if the AI server is healthy and configured
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {
        'status': 'error',
        'error': 'Server returned status ${response.statusCode}'
      };
    } catch (e) {
      print('Health check error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  /// Generate voice from text using Cloudflare Workers AI
  /// 
  /// [text] - The text to convert to speech
  /// [language] - Language code (EN, ES, FR, ZH, JP, KR, etc.)
  /// [cleanText] - Whether to clean the text for optimal TTS (default: true)
  Future<Uint8List?> generateVoice({
    required String text,
    String language = 'EN',
    bool cleanText = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/generate-voice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'language': language,
          'clean_text': cleanText,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Voice generation error: ${response.statusCode}');
        try {
          final errorData = json.decode(response.body);
          print('Error details: ${errorData['error']}');
        } catch (_) {}
        return null;
      }
    } catch (e) {
      print('Voice generation error: $e');
      return null;
    }
  }

  /// Chat with Gemini AI
  /// 
  /// [message] - The user's message
  /// [history] - Conversation history (optional)
  Future<ChatResponse?> chatWithAI({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'history': history ?? [],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatResponse(
          text: data['response'],
          success: data['success'] ?? true,
          metadata: data['metadata'] != null
              ? ChatMetadata.fromJson(data['metadata'])
              : null,
        );
      } else {
        print('Chat error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Chat error: $e');
      return null;
    }
  }

  /// Combined chat with voice response
  /// More efficient than calling chat and generateVoice separately
  /// 
  /// [message] - The user's message
  /// [history] - Conversation history (optional)
  /// [language] - Language code for voice generation
  Future<ChatWithVoiceResponse?> chatWithVoice({
    required String message,
    List<Map<String, String>>? history,
    String language = 'EN',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/chat-with-voice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'history': history ?? [],
          'language': language,
        }),
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        // Extract text response from header
        final textResponse = response.headers['x-ai-response'] ?? '';
        final processingTime = response.headers['x-processing-time'];

        return ChatWithVoiceResponse(
          text: textResponse,
          audioBytes: response.bodyBytes,
          processingTime: processingTime != null
              ? double.tryParse(processingTime)
              : null,
        );
      } else {
        print('Chat with voice error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Chat with voice error: $e');
      return null;
    }
  }

  /// Get supported languages
  Future<Map<String, String>> getSupportedLanguages() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/languages'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, String>.from(data['languages']);
      }
      return {};
    } catch (e) {
      print('Get languages error: $e');
      return {};
    }
  }

  /// Clean text for optimal TTS
  Future<String?> cleanTextForTTS(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/clean-text'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['cleaned'];
      }
      return null;
    } catch (e) {
      print('Text cleaning error: $e');
      return null;
    }
  }
}

/// Chat response model
class ChatResponse {
  final String text;
  final bool success;
  final ChatMetadata? metadata;

  ChatResponse({
    required this.text,
    this.success = true,
    this.metadata,
  });
}

/// Chat metadata model
class ChatMetadata {
  final double processingTime;
  final double estimatedSpeechDuration;

  ChatMetadata({
    required this.processingTime,
    required this.estimatedSpeechDuration,
  });

  factory ChatMetadata.fromJson(Map<String, dynamic> json) {
    return ChatMetadata(
      processingTime: (json['processing_time'] ?? 0).toDouble(),
      estimatedSpeechDuration:
          (json['estimated_speech_duration'] ?? 0).toDouble(),
    );
  }
}

/// Combined chat with voice response model
class ChatWithVoiceResponse {
  final String text;
  final Uint8List audioBytes;
  final double? processingTime;

  ChatWithVoiceResponse({
    required this.text,
    required this.audioBytes,
    this.processingTime,
  });
}

