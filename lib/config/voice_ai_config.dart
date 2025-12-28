/// Configuration for Voice AI Practice feature
class VoiceAIConfig {
  // WebSocket URL for the AI Voice Assistant server (aiagent)
  // This connects to your deployed Railway server
  static const String wsUrl = 'wss://lingumoroagent-production-79f0.up.railway.app/ws';
  
  // Available voice options
  static const List<String> availableVoices = [
    "heart",
    "sarah",
    "rachel",
    "alice",
    "george",
    "lily",
    "charlie",
    "emily",
    "james",
    "thomas"
  ];
  
  // Default settings
  static const String defaultVoice = "heart";
  static const double defaultSpeechSpeed = 1.0;
  static const double minSpeechSpeed = 0.5;
  static const double maxSpeechSpeed = 2.0;
}

