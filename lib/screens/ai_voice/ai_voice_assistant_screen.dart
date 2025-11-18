import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/ai_speech_service.dart';
import '../../services/ai_voice_session_service.dart';
import '../../services/auth_service.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

/// Enhanced AI Voice Assistant Screen
/// Provides real-time voice conversation with AI tutor
class AiVoiceAssistantScreen extends StatefulWidget {
  final bool hideAppBar;
  
  const AiVoiceAssistantScreen({Key? key, this.hideAppBar = false}) : super(key: key);

  @override
  State<AiVoiceAssistantScreen> createState() => _AiVoiceAssistantScreenState();
}

class _AiVoiceAssistantScreenState extends State<AiVoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final AiSpeechService _aiService = AiSpeechService();
  final AIVoiceSessionService _sessionService = AIVoiceSessionService();
  final AuthService _authService = AuthService();
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
  bool? _serverConfigured; // null = checking, true = connected, false = not connected
  String _selectedVoice = 'heart'; // Default voice
  
  // Session tracking
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  int _sessionDurationSeconds = 0;
  int _maxSessionDurationSeconds = 900; // Will be updated from settings
  int _maxSessionsPerDay = 2; // Will be updated from settings
  Map<String, dynamic> _sessionStats = {
    'sessions_today': 0,
    'remaining_sessions': 2,
    'has_active_session': false,
  };
  Map<String, dynamic> _sessionSettings = {
    'max_voice_sessions_per_day': 2,
    'voice_session_duration_minutes': 15,
  };
  
  // Inactivity timer for AI follow-ups
  Timer? _inactivityTimer;
  DateTime? _lastUserInteraction;
  static const Duration _inactivityDuration = Duration(seconds: 30);

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initSpeech();
    _setupAudioPlayer();
    _checkServerHealth();
    _loadSessionSettings();
    _loadSessionStats();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _sessionTimer?.cancel();
    // Cancel session if still active (fire and forget - can't await in dispose)
    if (_currentSessionId != null && _isActive) {
      _sessionService.cancelSession(_currentSessionId!, durationSeconds: _sessionDurationSeconds);
    }
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
      final isHealthy = health['status'] == 'healthy';
      setState(() {
        _serverConfigured = isHealthy;
      });

      if (!isHealthy) {
        _showError(
            'AI Server not configured. Please start the server and configure API keys.');
      }
    } catch (e) {
      setState(() => _serverConfigured = false);
      _showError('Cannot connect to AI server. Please check if it\'s running.');
    }
  }

  Future<void> _loadSessionSettings() async {
    try {
      final settings = await _sessionService.getSessionSettings();
      setState(() {
        _sessionSettings = settings;
        _maxSessionsPerDay = settings['max_voice_sessions_per_day'] ?? 2;
        _maxSessionDurationSeconds = (settings['voice_session_duration_minutes'] ?? 15) * 60;
      });
    } catch (e) {
      print('Error loading session settings: $e');
    }
  }

  Future<void> _loadSessionStats() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final stats = await _sessionService.getSessionStats(user.id);
      setState(() {
        _sessionStats = stats;
      });
    } catch (e) {
      print('Error loading session stats: $e');
    }
  }

  Future<void> _startSession() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Start new session (checks limits internally)
      final response = await _sessionService.startSession(user.id);
      
      if (response == null) {
        _showError('Failed to start session. Please try again.');
        return;
      }
      
      // Check if session start was blocked
      if (response['can_start'] == false || response['success'] == false) {
        final message = response['message'] ?? 'Cannot start session';
        _showError(message);
        return;
      }

      // Session started successfully
      final sessionId = response['session_id'] as String?;
      final settings = response['settings'] as Map<String, dynamic>?;
      
      if (sessionId != null) {
        // Update settings if returned from start session
        if (settings != null) {
          setState(() {
            _sessionSettings = settings;
            _maxSessionsPerDay = settings['max_voice_sessions_per_day'] ?? 2;
            _maxSessionDurationSeconds = (settings['voice_session_duration_minutes'] ?? 15) * 60;
          });
        }
        
        setState(() {
          _currentSessionId = sessionId;
          _sessionStartTime = DateTime.now();
          _sessionDurationSeconds = 0;
        });
        
        // Start session timer
        _startSessionTimer();
        
        // Reload stats to update UI
        await _loadSessionStats();
      }
    } catch (e) {
      print('Error starting session: $e');
      _showError('Failed to start session. Please try again.');
    }
  }

  Future<void> _completeSession() async {
    if (_currentSessionId == null) return;

    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      _sessionTimer?.cancel();
      
      final duration = _sessionDurationSeconds;
      final result = await _sessionService.completeSession(
        _currentSessionId!, 
        user.id,
        durationSeconds: duration
      );
      
      if (result != null && result['success'] == true) {
        final pointsAwarded = result['points_awarded'] as int? ?? 0;
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session completed! You earned $pointsAwarded points 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // Reload session stats
        await _loadSessionStats();
      }
      
      setState(() {
        _currentSessionId = null;
        _sessionStartTime = null;
        _sessionDurationSeconds = 0;
      });
    } catch (e) {
      print('Error completing session: $e');
    }
  }

  Future<void> _cancelSession() async {
    if (_currentSessionId == null) return;

    try {
      _sessionTimer?.cancel();
      
      final duration = _sessionDurationSeconds;
      await _sessionService.cancelSession(_currentSessionId!, durationSeconds: duration);
      
      setState(() {
        _currentSessionId = null;
        _sessionStartTime = null;
        _sessionDurationSeconds = 0;
      });
      
      // Reload session stats
      await _loadSessionStats();
    } catch (e) {
      print('Error cancelling session: $e');
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;
        setState(() {
          _sessionDurationSeconds = duration;
        });

        // Auto-stop at max duration
        if (duration >= _maxSessionDurationSeconds) {
          timer.cancel();
          if (mounted) {
            final minutes = _maxSessionDurationSeconds ~/ 60;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Session time limit reached ($minutes minutes). Session ended.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          _stopAgent();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isSpeaking) {
          print('🔊 Audio playback completed, will restart listening...');
          
          // Stop player explicitly to clear playing state
          _audioPlayer.stop();
          
          setState(() => _isSpeaking = false);
          _animationController.stop();

          // Reset timer AFTER AI finishes speaking
          _lastUserInteraction = DateTime.now();

          // Auto-resume listening if active - single coordinated restart
          if (_isActive) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (_isActive && !_isSpeaking && !_isProcessing && !_isListening) {
                print('🎤 Restarting listening after AI speech');
                _startListening();
              } else {
                print('⏭️ Skipping restart - already listening or not in correct state');
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

            // Auto-retry listening if active and got an error (not normal timeout)
            if (_isActive && !_isProcessing && !_isSpeaking) {
              Future.delayed(const Duration(seconds: 2), () {
                if (_isActive && !_isProcessing && !_isSpeaking && !_isListening) {
                  print('🔄 Restarting listening after error');
                  _startListening();
                }
              });
            }
          },
          onStatus: (status) {
            print('🎙️ Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
              // Don't auto-restart here - let the audio player callback handle it
              // This prevents restart loops
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

  Future<void> _startAgent() async {
    // Only block if server is explicitly not configured (false)
    // Allow if still checking (null) or configured (true)
    if (_serverConfigured == false) {
      _showError('Server not configured. Please check the AI server.');
      return;
    }

    // Check session limits and start session
    await _startSession();
    
    // If session start failed, don't proceed
    if (_currentSessionId == null) {
      return;
    }

    setState(() {
      _isActive = true;
      _statusText = 'Listening...';
    });
    _lastUserInteraction = DateTime.now();
    _startListening();
    _startInactivityTimer(); // Start timer monitoring
  }

  Future<void> _stopAgent() async {
    _inactivityTimer?.cancel();
    _sessionTimer?.cancel();
    
    // Complete the session and award points
    await _completeSession();
    
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
    if (!_isActive) {
      print('❌ Not starting listening - agent not active');
      return;
    }
    
    if (_isListening) {
      print('❌ Already listening');
      return;
    }
    
    if (_isSpeaking) {
      print('❌ Not starting listening - AI is speaking');
      return;
    }
    
    if (_isProcessing) {
      print('❌ Not starting listening - processing');
      return;
    }

    // Don't check _audioPlayer.playing - it can still be true briefly after completion
    // We rely on _isSpeaking flag which is more reliable

    try {
      print('✅ Starting listening...');
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
              _lastUserInteraction = DateTime.now();
              _handleUserMessage(text);
            }
          }
          // Interrupt AI if user starts speaking
          else if (result.recognizedWords.trim().length >= 2 && _isSpeaking) {
            _lastUserInteraction = DateTime.now();
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
        voice: _selectedVoice,
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
    // Stop listening to prevent AI hearing itself
    _speech.stop();
    
    setState(() {
      _isListening = false;
      _isSpeaking = true;
      _statusText = 'AI is speaking...';
    });
    _animationController.repeat(reverse: true);

    try {
      if (_isSpeaking) {
        // Save audio to temporary file (MP3 format from LemonFox)
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/ai_speech_${DateTime.now().millisecondsSinceEpoch}.mp3');
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
    _lastUserInteraction = DateTime.now();
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

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Don't check while AI is speaking or processing
      if (!_isActive || _isSpeaking || _isProcessing) {
        return;
      }

      final now = DateTime.now();
      final lastInteraction = _lastUserInteraction ?? now;
      final inactiveDuration = now.difference(lastInteraction);

      if (inactiveDuration >= _inactivityDuration) {
        // User has been inactive for 30+ seconds AFTER AI finished speaking
        _generateAIFollowUp();
      }
    });
  }

  Future<void> _generateAIFollowUp() async {
    if (!_isActive || _isSpeaking || _isProcessing) return;

    // Stop listening before AI speaks to prevent feedback
    _speech.stop();
    
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = 'AI is checking in...';
    });
    _animationController.repeat(reverse: true);

    try {
      // Create a meta-prompt for the AI to generate a check-in
      String metaPrompt;
      
      if (_conversationHistory.isEmpty) {
        metaPrompt = "The user hasn't started speaking yet. Greet them warmly and ask what they'd like to practice today. Keep it brief and friendly.";
      } else {
        metaPrompt = "The user hasn't been speaking for 30 seconds. Check in with them in a natural, friendly way. Ask if they're still there, if they want to continue, or if they need help. Keep it brief and conversational - just 1-2 short sentences.";
      }

      // Use AI to generate a contextual check-in based on conversation history
      final response = await _aiService.chatWithVoice(
        message: metaPrompt,
        history: _conversationHistory,
        language: 'EN',
        voice: _selectedVoice,
      );

      if (response != null) {
        setState(() {
          _conversationHistory.add({'role': 'assistant', 'content': response.text});
          _isProcessing = false;
        });
        _scrollToBottom();

        // Play audio response
        await _speakResponse(response.audioBytes);
      } else {
        setState(() => _isProcessing = false);
        _animationController.stop();
        
        // Resume listening
        if (_isActive && !_isListening) {
          _startListening();
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _animationController.stop();
      print('Follow-up generation error: $e');
      
      // Resume listening
      if (_isActive && !_isListening) {
        _startListening();
      }
    }
  }

  void _showVoiceSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select AI Voice',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AvailableVoices.voices.length,
              itemBuilder: (context, index) {
                final voice = AvailableVoices.voices[index];
                final isSelected = _selectedVoice == voice.id;
                
                return ListTile(
                  leading: Icon(
                    voice.icon,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    voice.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    voice.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: isSelected
                      ? FaIcon(FontAwesomeIcons.circleCheck, color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedVoice = voice.id;
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Voice changed to ${voice.name}'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildBody() {
    return Column(
      children: [
          // Server status indicator - only show when explicitly checked and failed
          if (_serverConfigured == false)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Server not connected. Start the AI server.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Session limit info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _sessionStats['remaining_sessions'] == 0 
                ? Colors.orange.shade50 
                : Colors.blue.shade50,
            child: Row(
              children: [
                FaIcon(
                  _sessionStats['remaining_sessions'] == 0 
                      ? FontAwesomeIcons.circleExclamation 
                      : FontAwesomeIcons.clock,
                  color: _sessionStats['remaining_sessions'] == 0 
                      ? Colors.orange.shade700 
                      : Colors.blue.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sessionStats['remaining_sessions'] == 0
                        ? 'Daily limit reached ($_maxSessionsPerDay/$_maxSessionsPerDay sessions). Try again tomorrow!'
                        : 'Sessions today: ${_sessionStats['sessions_today']}/$_maxSessionsPerDay • Remaining: ${_sessionStats['remaining_sessions']}',
                    style: TextStyle(
                      color: _sessionStats['remaining_sessions'] == 0 
                          ? Colors.orange.shade700 
                          : Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Session timer (when active)
          if (_isActive && _sessionStartTime != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.hourglassHalf, color: Colors.green.shade700, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Session: ${_formatDuration(_sessionDurationSeconds)} / ${_formatDuration(_maxSessionDurationSeconds)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_sessionDurationSeconds >= _maxSessionDurationSeconds - 60)
                    Text(
                      'Ending soon...',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleExclamation,
                      color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
                  child: Column(
                    children: [
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AvailableVoices.getVoiceById(_selectedVoice).icon,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Voice: ${AvailableVoices.getVoiceById(_selectedVoice).name}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        _currentListeningText!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
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
                      onPressed: (_serverConfigured != false && 
                                  (_isActive || _sessionStats['remaining_sessions'] > 0)) 
                          ? _toggleAgent 
                          : null,
                      icon: FaIcon(_isActive ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone, size: 18),
                      label: Text(_isActive ? 'Stop' : 'Start Voice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isActive ? Colors.red.shade400 : AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: AppColors.border, height: 1),

                // Conversation history
                Expanded(
                  child: _conversationHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.grey.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.microphone,
                                    size: 32,
                                    color: AppColors.grey.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Start speaking with your AI tutor',
                                style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.6),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Start Voice" to begin',
                                style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                  fontSize: 13,
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
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendTextMessage,
                    icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 18),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    
    if (widget.hideAppBar) {
      // When used as a tab, return just the body without Scaffold/AppBar
      return Container(
        color: AppColors.background,
        child: Column(
          children: [
            // Action buttons bar when used as tab
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: AppColors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.recordVinyl, color: AppColors.textSecondary),
                    onPressed: _showVoiceSelector,
                    tooltip: 'Select voice',
                  ),
                  if (_conversationHistory.isNotEmpty)
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.trash, color: AppColors.textSecondary),
                      onPressed: _clearConversation,
                      tooltip: 'Clear conversation',
                    ),
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.arrowRotateRight, color: AppColors.textSecondary),
                    onPressed: _checkServerHealth,
                    tooltip: 'Check server',
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    
    // When used standalone, return with Scaffold and custom top bar
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),
            
            // Body
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back Icon
          const CustomBackButton(),
          
          const Expanded(
            child: Center(
              child: Text(
                'AI VOICE TUTOR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: FaIcon(FontAwesomeIcons.recordVinyl, color: AppColors.primary, size: 18),
                  onPressed: _showVoiceSelector,
                  tooltip: 'Select voice',
                ),
              ),
              if (_conversationHistory.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: FaIcon(FontAwesomeIcons.trash, color: AppColors.textSecondary, size: 18),
                    onPressed: _clearConversation,
                    tooltip: 'Clear conversation',
                  ),
                ),
              ],
            ],
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
              color: _isListening
                  ? Colors.blue.shade400
                  : _isSpeaking
                      ? AppColors.primary
                      : _isProcessing
                          ? Colors.orange.shade400
                          : AppColors.lightGrey,
              boxShadow: [
                BoxShadow(
                  color: (_isListening || _isSpeaking || _isProcessing)
                      ? (_isListening 
                          ? Colors.blue.withOpacity(0.3)
                          : _isSpeaking
                              ? AppColors.primary.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3))
                      : Colors.transparent,
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: FaIcon(
                _isListening
                    ? FontAwesomeIcons.microphone
                    : _isSpeaking
                        ? FontAwesomeIcons.volumeHigh
                        : _isProcessing
                            ? FontAwesomeIcons.brain
                            : FontAwesomeIcons.microphoneSlash,
                size: 50,
                color: (_isListening || _isSpeaking || _isProcessing)
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
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
          color: isUser ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message['content']!,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
