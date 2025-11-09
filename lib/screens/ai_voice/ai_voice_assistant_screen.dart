import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/ai_speech_service.dart';

/// Enhanced AI Voice Assistant Screen
/// Provides real-time voice conversation with AI tutor
class AiVoiceAssistantScreen extends StatefulWidget {
  const AiVoiceAssistantScreen({Key? key}) : super(key: key);

  @override
  State<AiVoiceAssistantScreen> createState() => _AiVoiceAssistantScreenState();
}

class _AiVoiceAssistantScreenState extends State<AiVoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final AiSpeechService _aiService = AiSpeechService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  bool _isActive = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _statusText = 'Tap to start voice chat';
  List<Map<String, String>> _conversationHistory = [];
  String? _errorMessage;
  String? _currentListeningText;
  bool _serverConfigured = false;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initSpeech();
    _setupAudioPlayer();
    _checkServerHealth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    _speech.stop();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _checkServerHealth() async {
    try {
      final health = await _aiService.checkHealth();
      setState(() {
        _serverConfigured = health['status'] == 'healthy';
      });

      if (!_serverConfigured) {
        _showError(
            'AI Server not configured. Please start the server and configure API keys.');
      }
    } catch (e) {
      setState(() => _serverConfigured = false);
      _showError('Cannot connect to AI server. Please check if it\'s running.');
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isSpeaking) {
          setState(() => _isSpeaking = false);
          _animationController.stop();

          // Auto-resume listening if active
          if (_isActive && !_isListening) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!_isSpeaking && !_isListening && _isActive) {
                _startListening();
              }
            });
          }
        }
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        bool available = await _speech.initialize(
          onError: (error) {
            if (error.errorMsg != 'error_no_match' &&
                error.errorMsg != 'error_speech_timeout') {
              _showError('Speech error: ${error.errorMsg}');
            }

            // Auto-retry listening if active
            if (_isActive && !_isProcessing) {
              Future.delayed(const Duration(seconds: 1), () {
                if (_isActive && !_isProcessing) _startListening();
              });
            }
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);

              // Auto-resume if active
              if (_isActive && !_isSpeaking && !_isProcessing) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!_isSpeaking && !_isProcessing && _isActive) {
                    _startListening();
                  }
                });
              }
            }
          },
        );

        if (!available) {
          _showError('Speech recognition not available');
        }
      } else {
        _showError('Microphone permission denied');
      }
    } catch (e) {
      _showError('Failed to initialize speech: $e');
    }
  }

  void _toggleAgent() {
    if (_isActive) {
      _stopAgent();
    } else {
      _startAgent();
    }
  }

  void _startAgent() {
    if (!_serverConfigured) {
      _showError('Server not configured. Please check the AI server.');
      return;
    }

    setState(() {
      _isActive = true;
      _statusText = 'Listening...';
    });
    _startListening();
  }

  void _stopAgent() {
    setState(() {
      _isActive = false;
      _isListening = false;
      _isSpeaking = false;
      _isProcessing = false;
      _statusText = 'Tap to start voice chat';
      _currentListeningText = null;
    });
    _speech.stop();
    _audioPlayer.stop();
    _animationController.stop();
  }

  void _startListening() {
    if (!_isActive || _isListening || _isSpeaking || _isProcessing) return;

    try {
      setState(() {
        _isListening = true;
        _statusText = 'Listening...';
        _currentListeningText = '';
      });
      _animationController.repeat(reverse: true);

      _speech.listen(
        onResult: (result) {
          setState(() {
            _currentListeningText = result.recognizedWords;
          });

          if (result.finalResult) {
            final text = result.recognizedWords.trim();
            if (text.isNotEmpty) {
              _handleUserMessage(text);
            }
          }
          // Interrupt AI if user starts speaking
          else if (result.recognizedWords.trim().length >= 2 && _isSpeaking) {
            _stopSpeaking();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
      );
    } catch (e) {
      setState(() => _isListening = false);
      _showError('Failed to start listening: $e');
    }
  }

  void _stopSpeaking() {
    _audioPlayer.stop();
    setState(() => _isSpeaking = false);
    _animationController.stop();
  }

  Future<void> _handleUserMessage(String message) async {
    if (message.isEmpty) return;

    _speech.stop();
    setState(() {
      _isListening = false;
      _isSpeaking = false;
      _isProcessing = true;
      _currentListeningText = null;
    });
    _audioPlayer.stop();

    // Add user message to history
    setState(() {
      _conversationHistory.add({'role': 'user', 'content': message});
      _statusText = 'AI is thinking...';
    });
    _scrollToBottom();
    _animationController.repeat(reverse: true);

    try {
      // Use combined endpoint for efficiency
      final response = await _aiService.chatWithVoice(
        message: message,
        history: _conversationHistory,
        language: 'EN',
      );

      if (response != null) {
        // Add AI response to history
        setState(() {
          _conversationHistory
              .add({'role': 'assistant', 'content': response.text});
          _isProcessing = false;
        });
        _scrollToBottom();

        // Play audio response
        await _speakResponse(response.audioBytes);
      } else {
        _showError('Failed to get AI response');
        setState(() => _isProcessing = false);

        if (_isActive) {
          Future.delayed(const Duration(seconds: 1), _startListening);
        }
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isProcessing = false);

      if (_isActive) {
        Future.delayed(const Duration(seconds: 1), _startListening);
      }
    }
  }

  Future<void> _speakResponse(Uint8List audioData) async {
    setState(() {
      _isSpeaking = true;
      _statusText = 'AI is speaking...';
    });
    _animationController.repeat(reverse: true);

    try {
      if (_isSpeaking) {
        // Save audio to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/ai_speech_${DateTime.now().millisecondsSinceEpoch}.wav');
        await tempFile.writeAsBytes(audioData);

        // Play audio
        await _audioPlayer.setFilePath(tempFile.path);
        await _audioPlayer.play();
      }
    } catch (e) {
      _showError('Failed to play speech: $e');
      setState(() => _isSpeaking = false);
      _animationController.stop();

      if (_isActive && !_isListening) {
        Future.delayed(const Duration(milliseconds: 800), _startListening);
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    await _handleUserMessage(text);
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _clearConversation() {
    setState(() {
      _conversationHistory.clear();
      _statusText = _isActive ? 'Listening...' : 'Tap to start voice chat';
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('AI Voice Tutor'),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          if (_conversationHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearConversation,
              tooltip: 'Clear conversation',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerHealth,
            tooltip: 'Check server',
          ),
        ],
      ),
      body: Column(
        children: [
          // Server status indicator
          if (!_serverConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Server not connected. Start the AI server.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style:
                          const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Voice visualizer
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: _buildVoiceVisualizer(),
                ),

                // Status text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Current listening text
                if (_currentListeningText != null &&
                    _currentListeningText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        _currentListeningText!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _serverConfigured ? _toggleAgent : null,
                      icon: Icon(_isActive ? Icons.stop : Icons.mic),
                      label: Text(_isActive ? 'Stop' : 'Start Voice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isActive ? Colors.red : const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),

                // Conversation history
                Expanded(
                  child: _conversationHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mic_none,
                                size: 80,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Start speaking with your AI tutor',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap "Start Voice" to begin',
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _conversationHistory.length,
                          itemBuilder: (context, index) {
                            final message = _conversationHistory[index];
                            final isUser = message['role'] == 'user';
                            return _buildMessageBubble(message, isUser);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Text input for manual typing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendTextMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceVisualizer() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: (_isListening || _isSpeaking || _isProcessing)
              ? _pulseAnimation.value
              : 1.0,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isListening
                    ? [const Color(0xFF00D4FF), const Color(0xFF0099CC)]
                    : _isSpeaking
                        ? [const Color(0xFF6C63FF), const Color(0xFF5A52D5)]
                        : _isProcessing
                            ? [
                                const Color(0xFFFF6B6B),
                                const Color(0xFFEE5A6F)
                              ]
                            : [
                                const Color(0xFF2E2E3E),
                                const Color(0xFF1A1A2E)
                              ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening || _isSpeaking || _isProcessing)
                      ? Colors.blue.withOpacity(0.5)
                      : Colors.transparent,
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              _isListening
                  ? Icons.mic
                  : _isSpeaking
                      ? Icons.volume_up
                      : _isProcessing
                          ? Icons.psychology
                          : Icons.mic_none,
              size: 70,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, String> message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                )
              : null,
          color: isUser ? null : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['content']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



