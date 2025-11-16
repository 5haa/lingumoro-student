import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Enhanced AI Speech Service
/// Provides text-to-speech and AI chat capabilities
class AiSpeechService {
  // Server configuration
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://192.168.177.58:5000';
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

  /// Generate voice from text using LemonFox AI
  /// 
  /// [text] - The text to convert to speech
  /// [language] - Language code (EN, ES, FR, ZH, JP, KR, etc.)
  /// [voice] - Voice to use (heart, sarah, alloy, echo, fable, onyx, nova, shimmer)
  /// [speed] - Speech speed (default 1.0)
  /// [cleanText] - Whether to clean the text for optimal TTS (default: true)
  Future<Uint8List?> generateVoice({
    required String text,
    String language = 'EN',
    String voice = 'heart',
    double speed = 1.0,
    bool cleanText = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/generate-voice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'language': language,
          'voice': voice,
          'speed': speed,
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
  /// [voice] - Voice to use (heart, sarah, alloy, echo, fable, onyx, nova, shimmer)
  /// [speed] - Speech speed (default 1.0)
  Future<ChatWithVoiceResponse?> chatWithVoice({
    required String message,
    List<Map<String, String>>? history,
    String language = 'EN',
    String voice = 'heart',
    double speed = 1.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/chat-with-voice'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'history': history ?? [],
          'language': language,
          'voice': voice,
          'speed': speed,
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

/// Available voices for TTS
class VoiceOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const VoiceOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// Get available voices
class AvailableVoices {
  static const List<VoiceOption> voices = [
    VoiceOption(
      id: 'heart',
      name: 'Heart',
      description: 'Default voice, warm and friendly',
      icon: Icons.favorite,
    ),
    VoiceOption(
      id: 'sarah',
      name: 'Sarah',
      description: 'Female voice, clear and professional',
      icon: Icons.person,
    ),
    VoiceOption(
      id: 'alloy',
      name: 'Alloy',
      description: 'Neutral voice, versatile',
      icon: Icons.psychology,
    ),
    VoiceOption(
      id: 'echo',
      name: 'Echo',
      description: 'Male voice, strong and confident',
      icon: Icons.record_voice_over,
    ),
    VoiceOption(
      id: 'fable',
      name: 'Fable',
      description: 'Storyteller voice, expressive',
      icon: Icons.menu_book,
    ),
    VoiceOption(
      id: 'onyx',
      name: 'Onyx',
      description: 'Deep male voice, authoritative',
      icon: Icons.badge,
    ),
    VoiceOption(
      id: 'nova',
      name: 'Nova',
      description: 'Female voice, energetic',
      icon: Icons.star,
    ),
    VoiceOption(
      id: 'shimmer',
      name: 'Shimmer',
      description: 'Female voice, soft and gentle',
      icon: Icons.auto_awesome,
    ),
  ];

  static VoiceOption getVoiceById(String id) {
    return voices.firstWhere(
      (voice) => voice.id == id,
      orElse: () => voices.first,
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

