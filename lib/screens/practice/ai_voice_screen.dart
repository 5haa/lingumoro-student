import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/config/voice_ai_config.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/ai_voice_session_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/points_notification_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as kStatus;
import '../../l10n/app_localizations.dart';

enum AppStatus {
  disconnected,
  connecting,
  connected,
  listening,
  thinking,
  speaking,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isComplete;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isComplete = false,
  });
}

class AIVoicePracticeScreen extends StatefulWidget {
  const AIVoicePracticeScreen({super.key});

  @override
  State<AIVoicePracticeScreen> createState() => _AIVoicePracticeScreenState();
}

class _AIVoicePracticeScreenState extends State<AIVoicePracticeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final AIVoiceSessionService _sessionService = AIVoiceSessionService();
  final AuthService _authService = AuthService();
  final LevelService _levelService = LevelService();
  final PointsNotificationService _pointsNotificationService = PointsNotificationService();
  final ProSubscriptionService _proService = ProSubscriptionService();

  // Force AI/TTS playback to use the normal/media audio mode (not "in-call").
  // This prevents very-low/unhearable playback when the recorder puts Android
  // into communication mode (different volume stream).
  late final AudioContext _ttsAudioContext = AudioContext(
    android: const AudioContextAndroid(
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
      isSpeakerphoneOn: true,
    ),
  );

  final RecordConfig _recordConfig = const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    bitRate: 256000,
    numChannels: 1,
    streamBufferSize: 4096,
    echoCancel: true,
    noiseSuppress: true,
    audioInterruption: AudioInterruptionMode.none,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceCommunication,
      speakerphone: true,
      // Using "in communication" can route playback to the call volume stream,
      // which is often much lower than media volume. Keep this on normal.
      audioManagerMode: AudioManagerMode.modeNormal,
    ),
  );

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _recorderSubscription;
  StreamSubscription? _channelSubscription;
  bool _allowRecorderRestart = false;
  bool _isStartingRecorder = false;
  bool _isPlayingTts = false;
  final Queue<List<int>> _audioQueue = Queue<List<int>>();
  bool _isProcessingAudio = false;
  bool _sessionReady = false;
  bool _isWarmingUp = false;

  AppStatus _status = AppStatus.disconnected;
  String _statusMessage = "Not connected";
  
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  // Buffer for current streaming transcript
  String _currentTranscript = "";
  
  // UI state for bubble and chat
  double _soundLevel = 0.0;
  Timer? _amplitudeTimer;
  bool _isChatExpanded = false;
  bool _isHoldingToTalk = false;

  // Voice Settings
  String _selectedVoice = VoiceAIConfig.defaultVoice;
  double _speechSpeed = VoiceAIConfig.defaultSpeechSpeed;
  final List<String> _availableVoices = VoiceAIConfig.availableVoices;

  // Session tracking
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  int _sessionDurationSeconds = 0;
  int _maxSessionDurationMinutes = 15;
  int _dailyLimitMinutes = 30;
  int _remainingSeconds = 0;
  bool _canStartSession = true;
  String _sessionLimitReason = "";
  
  // Loading state
  bool _isLoadingSession = true;
  bool _isExiting = false;
  bool _isStopping = false;
  bool _didChange = false;
  
  // Points and stats
  Map<String, dynamic> _todayStats = {};

  @override
  void initState() {
    super.initState();
    _checkProAndLoadSessionInfo();
  }

  Future<void> _checkProAndLoadSessionInfo() async {
    final user = _authService.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    // Check device session validity
    final result = await _proService.validateAndUpdateDeviceSession(
      user.id,
      forceClaim: false,
    );

    if (result['is_valid'] != true) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).proFeaturesActiveOnAnotherDevice),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // If valid, load session info
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final sessionInfo = await _sessionService.canStartSession(user.id);
      final todayStats = await _sessionService.getTodayStats(user.id);

      if (mounted) {
        setState(() {
          _canStartSession = sessionInfo['canStart'];
          _remainingSeconds = sessionInfo['remainingSeconds'];
          _dailyLimitMinutes = sessionInfo['dailyLimitMinutes'];
          _maxSessionDurationMinutes = sessionInfo['sessionMaxDurationMinutes'];
          _sessionLimitReason = sessionInfo['reason'];
          _todayStats = todayStats;
          _isLoadingSession = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading session info: $e");
      if (mounted) {
        setState(() {
          _isLoadingSession = false;
        });
      }
    }
  }

  void _startSessionTimer() {
    _sessionStartTime = DateTime.now();
    _sessionDurationSeconds = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionDurationSeconds++;
      });

      // Check if session limit reached
      // Stop if:
      // 1. Session hits max per-session duration (e.g. 15 mins)
      // 2. OR Total daily usage hits the limit (remainingSeconds counts down)
      
      // sessionDuration is how long we've been in THIS session.
      // _remainingSeconds is how much time was left when we STARTED.
      
      final sessionLimitSeconds = _maxSessionDurationMinutes * 60;
      final dailyLimitReached = _sessionDurationSeconds >= _remainingSeconds;
      final sessionLimitReached = _sessionDurationSeconds >= sessionLimitSeconds;

      if (dailyLimitReached || sessionLimitReached) {
        _showTimeUpDialog(dailyLimitReached: dailyLimitReached);
        _disconnect(showCompletionDialog: false);
      }
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _showTimeUpDialog({bool dailyLimitReached = false}) {
    final message = dailyLimitReached
        ? "You have used your $_dailyLimitMinutes minutes for today. Good job!"
        : AppLocalizations.of(context).sessionEndedMessage.replaceAll('{minutes}', _maxSessionDurationMinutes.toString());
        
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_off_outlined,
                  size: 48,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                AppLocalizations.of(context).timesUp,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).gotIt,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopSessionTimer();
    _amplitudeTimer?.cancel();
    // Best-effort: persist/count any active session without showing UI.
    unawaited(_disconnect(showCompletionDialog: false, isDisposing: true));
    _player.dispose();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ({String? sessionId, int durationSeconds}) _drainSessionForFinalize() {
    final drained = (sessionId: _currentSessionId, durationSeconds: _sessionDurationSeconds);
    _currentSessionId = null;
    _sessionDurationSeconds = 0;
    _sessionStartTime = null;
    return drained;
  }

  Future<void> _stopRealtimeNow({required bool isDisposing}) async {
    _allowRecorderRestart = false;
    _isWarmingUp = false;

    // Stop timers first (instant UI response)
    _amplitudeTimer?.cancel();
    _stopSessionTimer();

    // Stop audio/streaming
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    await _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close(kStatus.goingAway);
    _channel = null;

    _audioQueue.clear();
    _isProcessingAudio = false;
    _isPlayingTts = false;
    try {
      await _player.stop();
    } catch (_) {}

    _sessionReady = false;

    if (!isDisposing && mounted) {
      setState(() {
        _soundLevel = 0.0;
        _status = AppStatus.disconnected;
        _statusMessage = AppLocalizations.of(context).notConnected;
      });
    } else {
      _soundLevel = 0.0;
      _status = AppStatus.disconnected;
      _statusMessage = "Not connected";
    }
  }

  Future<void> _finalizeSessionInBackground(
    ({String? sessionId, int durationSeconds}) drained, {
    required bool showCompletionDialog,
    required bool isDisposing,
  }) async {
    final sessionId = drained.sessionId;
    if (sessionId == null) return;

    try {
      if (drained.durationSeconds > 0) {
        final result = await _sessionService.endSession(sessionId, drained.durationSeconds);

        if (showCompletionDialog &&
            result['success'] == true &&
            (result['pointsAwarded'] as int? ?? 0) > 0 &&
            mounted) {
          _pointsNotificationService.showPointsEarnedNotification(
            context: context,
            pointsGained: result['pointsAwarded'],
          );

          _showSessionCompletedDialog(
            result['pointsAwarded'],
            result['durationMinutes'],
            math.max(0, _remainingSeconds - drained.durationSeconds),
          );
        }
      } else {
        await _sessionService.cancelSession(sessionId);
      }
    } catch (e) {
      debugPrint("Error finalizing session: $e");
    } finally {
      if (!isDisposing && mounted) {
        await _loadSessionInfo();
      }
    }
  }

  Future<void> _stopSessionFast() async {
    if (_isStopping || _isExiting) return;
    if (_status == AppStatus.disconnected && _currentSessionId == null) return;

    if (mounted) {
      setState(() {
        _isStopping = true;
        _status = AppStatus.disconnected;
        _statusMessage = AppLocalizations.of(context).notConnected;
        _soundLevel = 0.0;
        _isWarmingUp = false;
      });
    } else {
      _isStopping = true;
      _status = AppStatus.disconnected;
      _statusMessage = "Not connected";
      _soundLevel = 0.0;
      _isWarmingUp = false;
    }

    // Yield a frame so the UI updates immediately.
    await Future<void>.delayed(Duration.zero);

    final drained = _drainSessionForFinalize();
    await _stopRealtimeNow(isDisposing: false);
    await _finalizeSessionInBackground(
      drained,
      showCompletionDialog: true,
      isDisposing: false,
    );

    if (mounted) {
      setState(() => _isStopping = false);
    } else {
      _isStopping = false;
    }
  }

  void _updateSettings() {
    if (_channel != null && _status != AppStatus.disconnected) {
      final config = {
        "type": "config",
        "voice": _selectedVoice,
        "speed": _speechSpeed,
      };
      _channel!.sink.add(jsonEncode(config));
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).voiceSettings,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).voice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVoice,
                        isExpanded: true,
                        items: _availableVoices.map((String voice) {
                          return DropdownMenuItem<String>(
                            value: voice,
                            child: Text(
                              voice[0].toUpperCase() + voice.substring(1),
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setModalState(() {
                              _selectedVoice = newValue;
                            });
                            setState(() {
                              _selectedVoice = newValue;
                            });
                            _updateSettings();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).speed,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "${_speechSpeed.toStringAsFixed(1)}x",
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _speechSpeed,
                    min: VoiceAIConfig.minSpeechSpeed,
                    max: VoiceAIConfig.maxSpeechSpeed,
                    divisions: 15,
                    activeColor: AppColors.primary,
                    label: "${_speechSpeed.toStringAsFixed(1)}x",
                    onChanged: (double value) {
                      setModalState(() {
                        _speechSpeed = value;
                      });
                      setState(() {
                        _speechSpeed = value;
                      });
                    },
                    onChangeEnd: (double value) {
                      _updateSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _disconnect({bool showCompletionDialog = true, bool isDisposing = false}) async {
    // Make the UI feel instant: disconnect locally first, then persist remotely.
    if (!isDisposing && mounted) {
      setState(() {
        _status = AppStatus.disconnected;
        _statusMessage = AppLocalizations.of(context).notConnected;
        _soundLevel = 0.0;
        _isWarmingUp = false;
      });
    }

    final drained = _drainSessionForFinalize();
    await _stopRealtimeNow(isDisposing: isDisposing);
    await _finalizeSessionInBackground(
      drained,
      showCompletionDialog: showCompletionDialog,
      isDisposing: isDisposing,
    );
  }

  void _showSessionCompletedDialog(int points, int minutes, int remainingSeconds) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '🎉',
                  style: TextStyle(fontSize: 42),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                AppLocalizations.of(context).greatJob,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                AppLocalizations.of(context).practicedForMinutes.replaceAll('{minutes}', minutes.toString()).replaceAll('{plural}', minutes != 1 ? 's' : ''),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Points Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    Text(
                      '+$points ${AppLocalizations.of(context).points}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Remaining time
              Text(
                '${remainingSeconds ~/ 60} min ${remainingSeconds % 60} sec remaining today',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).awesome,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startConversation() async {
    // Check session availability
    final user = _authService.currentUser;
    if (user == null) {
      _showError(AppLocalizations.of(context).pleaseLoginToUseAI);
      return;
    }

    // Check if can start session
    final sessionInfo = await _sessionService.canStartSession(user.id);
    if (!sessionInfo['canStart']) {
      _showSessionLimitDialog(sessionInfo['reason']);
      return;
    }

    // Request permissions
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showError(AppLocalizations.of(context).microphonePermissionRequired);
      return;
    }

    _sessionReady = false;
    _allowRecorderRestart = false;

    setState(() {
      _status = AppStatus.connecting;
      _statusMessage = AppLocalizations.of(context).preparingVoiceSession;
      _isWarmingUp = true;
      _messages.clear();
      _currentTranscript = "";
    });

    try {
      // Start session in database
      final sessionId = await _sessionService.startSession(user.id);
      if (sessionId == null) {
        _showError(AppLocalizations.of(context).failedToStartSession);
        return;
      }

      _currentSessionId = sessionId;
      _startSessionTimer();
      _didChange = true;

      // WebSocket URL - Connect to aiagent server
      const String wsUrl = VoiceAIConfig.wsUrl;

      debugPrint("Connecting to $wsUrl");
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen to WebSocket
      _channelSubscription = _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint("WebSocket error: $error");
          _showError("${AppLocalizations.of(context).connectionError} $error");
          _disconnect(showCompletionDialog: false);
        },
        onDone: () {
          debugPrint("WebSocket connection closed");
          _disconnect(showCompletionDialog: false);
        },
      );

      // Start Recording
      final hasNativePermission = await _audioRecorder.hasPermission();
      if (!hasNativePermission) {
        _showError(AppLocalizations.of(context).recorderPermissionDenied);
        await _disconnect(showCompletionDialog: false);
        return;
      }

    } catch (e) {
      debugPrint("Error starting conversation: $e");
      _showError("${AppLocalizations.of(context).failedToStart} $e");
      _disconnect(showCompletionDialog: false);
    }
  }

  void _showSessionLimitDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  size: 48,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                AppLocalizations.of(context).sessionLimitReached,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                reason,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).gotIt,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is List<int> || message is Uint8List) {
      _enqueueAudioPlayback(List<int>.from(message as Iterable<int>));
    } else if (message is String) {
      // JSON Data
      try {
        final data = jsonDecode(message);
        final type = data['type'];

        switch (type) {
          case 'status':
            _updateStatus(data['status'], data['message']);
            break;
          case 'transcript':
            _handleTranscript(data);
            break;
          case 'ai_response':
            _handleAiResponse(data['text']);
            break;
          case 'error':
            _showError(data['message']);
            break;
          case 'session_started':
            _handleSessionStarted(data['session_id'] as String?);
            break;
        }
      } catch (e) {
        debugPrint("Error parsing JSON: $e");
      }
    }
  }

  void _updateStatus(String statusStr, String message) {
    AppStatus newStatus;
    switch (statusStr) {
      case 'listening':
        newStatus = AppStatus.listening;
        break;
      case 'thinking':
        newStatus = AppStatus.thinking;
        break;
      case 'speaking':
        newStatus = AppStatus.speaking;
        break;
      default:
        newStatus = AppStatus.connected;
    }
    
    setState(() {
      _status = newStatus;
      _statusMessage = message;
    });
  }

  void _handleTranscript(Map<String, dynamic> data) {
    final text = data['text'] as String;
    final isFinal = data['end_of_turn'] as bool;
    final isFormatted = data['turn_is_formatted'] as bool? ?? false;
    
    if (text.trim().isEmpty) return;

    setState(() {
      _currentTranscript = text;
      if (isFinal && isFormatted) {
        _messages.add(ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
          isComplete: true,
        ));
        _currentTranscript = "";
      }
    });
    if (isFinal && isFormatted) {
      _scrollToBottom();
    }
  }

  void _handleAiResponse(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        isComplete: true,
      ));
    });
    _scrollToBottom();
  }

  void _handleSessionStarted(String? sessionId) {
    if (_sessionReady) {
      return;
    }
    debugPrint("Session started: $sessionId");
    _sessionReady = true;
    _allowRecorderRestart = true;
    _isWarmingUp = false;
    setState(() {
      _status = AppStatus.listening;
      _statusMessage = AppLocalizations.of(context).listening;
    });
  }

  bool get _canHoldToTalk {
    return _channel != null &&
        _status != AppStatus.disconnected &&
        _sessionReady &&
        !_isWarmingUp &&
        !_isStopping &&
        !_isExiting &&
        !_isPlayingTts;
  }

  Future<void> _startHoldToTalk() async {
    if (!_canHoldToTalk || _isHoldingToTalk) return;
    setState(() {
      _isHoldingToTalk = true;
    });

    try {
      _channel?.sink.add(jsonEncode({"type": "utt_start"}));
    } catch (e) {
      debugPrint("Failed to send utt_start: $e");
    }

    // Start streaming mic audio only while the user is holding.
    _allowRecorderRestart = true;
    await _startRecorderStream();
  }

  Future<void> _stopHoldRecordingOnly() async {
    _amplitudeTimer?.cancel();
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _soundLevel = 0.0);
    } else {
      _soundLevel = 0.0;
    }
  }

  Future<void> _endHoldToTalk({required bool cancelled}) async {
    if (!_isHoldingToTalk) return;
    setState(() {
      _isHoldingToTalk = false;
    });

    // Stop mic streaming first (no more bytes after release).
    await _stopHoldRecordingOnly();

    if (cancelled) return;
    try {
      // Send ~500ms of silence (16000hz * 2 bytes/sample * 0.5s = 16000 bytes)
      // This forces the VAD to recognize end-of-speech immediately so we don't cut off the last word.
      final silence = Uint8List(16000); 
      _channel?.sink.add(silence);
      
      _channel?.sink.add(jsonEncode({"type": "utt_end"}));
    } catch (e) {
      debugPrint("Failed to send silence/utt_end: $e");
    }
  }

  Future<void> _playAudio(List<int> audioBytes) async {
    if (audioBytes.isEmpty) return;
    // Ensure no mic streaming occurs during TTS playback.
    if (_isHoldingToTalk) {
      await _endHoldToTalk(cancelled: true);
    } else {
      await _stopHoldRecordingOnly();
    }
    if (mounted) {
      setState(() => _isPlayingTts = true);
    } else {
      _isPlayingTts = true;
    }
    try {
      await _player.stop();
      await _player.play(
        BytesSource(Uint8List.fromList(audioBytes)),
        volume: 1.0,
        ctx: _ttsAudioContext,
      );
      try {
        await _player.onPlayerComplete.first
            .timeout(const Duration(minutes: 1));
      } on TimeoutException {
        await _player.stop();
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
    } finally {
      // Push-to-talk: do NOT auto-resume recording after playback.
      if (mounted) {
        setState(() => _isPlayingTts = false);
      } else {
        _isPlayingTts = false;
      }
      _allowRecorderRestart = true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getStatusColor() {
    switch (_status) {
      case AppStatus.disconnected:
        return Colors.red;
      case AppStatus.connecting:
        return Colors.orange;
      case AppStatus.connected:
        return Colors.green;
      case AppStatus.listening:
        return AppColors.primary;
      case AppStatus.thinking:
        return Colors.amber;
      case AppStatus.speaking:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMessages = _isChatExpanded
        ? _messages
        : _messages.length > 2
            ? _messages.sublist(_messages.length - 2)
            : _messages;

    // Show floating button when session is active (not disconnected)
    final bool showFloatingButton = _status != AppStatus.disconnected;

    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content column
              Column(
                children: [
                  // Top Bar
                  _buildTopBar(),
                  
                  // Session Timer Header (Always visible)
                  _buildSessionHeader(),

                  // Chat-only mode: show full chat and hide the agent bubble
                  if (_isChatExpanded) ...[
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  AppLocalizations.of(context).chat,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isChatExpanded = false;
                                    });
                                  },
                                  child: Text(AppLocalizations.of(context).close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _messages.isEmpty
                                  ? Center(
                                      child: Text(
                                        AppLocalizations.of(context).startToSeeConversation,
                                        style: const TextStyle(color: AppColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : _buildMessageList(_messages, expanded: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom padding for floating button area
                    const SizedBox(height: 120),
                  ] else ...[
                    // Main Content - Active Session
                    Expanded(
                      child: _status == AppStatus.disconnected
                          // DISCONNECTED STATE - Show start button
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AIAgentBubble(
                                  soundLevel: 0.0,
                                  isAgentSpeaking: false,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: 160,
                                  child: ElevatedButton(
                                    onPressed: (_isLoadingSession || _isStopping) ? null : _startConversation,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text(
                                      _isStopping
                                          ? AppLocalizations.of(context).loading
                                          : AppLocalizations.of(context).start,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          // ACTIVE SESSION - Display bubble + stop button
                          : SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 16),
                                  // AI Bubble (display only)
                                  AIAgentBubble(
                                    soundLevel: _soundLevel,
                                    isAgentSpeaking: _isPlayingTts,
                                    isHolding: _isHoldingToTalk,
                                  ),
                                  const SizedBox(height: 16),
                                  // Stop button
                                  TextButton.icon(
                                    onPressed: (_isStopping || _isExiting) ? null : _stopSessionFast,
                                    icon: const Icon(Icons.stop_rounded, size: 20),
                                    label: Text(AppLocalizations.of(context).stop),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.black54,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // Chat preview - only show when there are messages
                    if (_messages.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _isChatExpanded = true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Handle bar
                              Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Tap to open chat label - ABOVE messages
                              Text(
                                AppLocalizations.of(context).tapToOpenChat,
                                style: const TextStyle(fontSize: 11, color: Colors.black38),
                              ),
                              const SizedBox(height: 8),
                              // Message preview
                              _buildMessageList(_messages.takeLast(2), expanded: false),
                            ],
                          ),
                        ),
                      ),
                    // Bottom padding for floating button area
                    const SizedBox(height: 130),
                  ],
                ],
              ),

              // Floating Hold-to-Talk Button with label - always visible when session is active
              if (showFloatingButton)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingHoldToTalkButton(),
                      const SizedBox(height: 8),
                      // Hold to speak / Release to send label - BELOW button
                      Text(
                        _isHoldingToTalk
                            ? AppLocalizations.of(context).releaseToSend
                            : AppLocalizations.of(context).holdToSpeak,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isHoldingToTalk ? AppColors.primary : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHoldToTalkButton() {
    final bool isActive = _canHoldToTalk;
    final bool isHolding = _isHoldingToTalk;
    
    return GestureDetector(
      onTapDown: isActive ? (_) => unawaited(_startHoldToTalk()) : null,
      onTapUp: isActive ? (_) => unawaited(_endHoldToTalk(cancelled: false)) : null,
      onTapCancel: isActive ? () => unawaited(_endHoldToTalk(cancelled: true)) : null,
      onLongPressStart: isActive ? (_) => unawaited(_startHoldToTalk()) : null,
      onLongPressEnd: isActive ? (_) => unawaited(_endHoldToTalk(cancelled: false)) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: isHolding ? 88 : 72,
        height: isHolding ? 88 : 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring when holding
            if (isHolding)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 1.3),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Container(
                    width: 88 * value,
                    height: 88 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3 / value),
                        width: 3,
                      ),
                    ),
                  );
                },
              ),
            // Middle ring when holding
            if (isHolding)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
            // Main button
            Container(
              width: isHolding ? 88 : 72,
              height: isHolding ? 88 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isHolding
                      ? [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ]
                      : isActive
                          ? [
                              const Color(0xFF2A2A2A),
                              const Color(0xFF000000),
                            ]
                          : [
                              const Color(0xFF9E9E9E),
                              const Color(0xFF757575),
                            ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHolding
                        ? AppColors.primary.withOpacity(0.4)
                        : Colors.black.withOpacity(0.3),
                    blurRadius: isHolding ? 20 : 12,
                    offset: const Offset(0, 4),
                    spreadRadius: isHolding ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                isHolding ? Icons.mic : Icons.mic_none_rounded,
                color: Colors.white,
                size: isHolding ? 36 : 30,
              ),
            ),
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
          CustomBackButton(onPressed: _handleBackPressed),
                  Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context).aiVoicePractice,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
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
              icon: const FaIcon(
                FontAwesomeIcons.gear,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: _showSettings,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionHeader() {
    if (_isLoadingSession) {
      // Avoid flashing incorrect defaults (e.g. 0/2) while session limits are still loading.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '00:00',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
    // Calculate current session number properly
    // Calculate time based metrics
    final actualRemainingSeconds = (_remainingSeconds - _sessionDurationSeconds).clamp(0, _remainingSeconds);
    final remainingMins = actualRemainingSeconds ~/ 60;
    final remainingSecs = actualRemainingSeconds % 60;
    final formattedRemaining = '${remainingMins.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
    final minutes = _sessionDurationSeconds ~/ 60;
    final seconds = _sessionDurationSeconds % 60;
    final formattedTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Session Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.av_timer, size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  '$formattedRemaining left',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageList(List<ChatMessage> messages, {required bool expanded}) {
    return ListView.separated(
      controller: expanded ? _scrollController : null,
      shrinkWrap: !expanded,
      physics: expanded ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
      padding: expanded ? const EdgeInsets.only(bottom: 120) : EdgeInsets.zero,
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[index];
        return Row(
          mainAxisAlignment: message.isUser 
              ? MainAxisAlignment.end 
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isUser 
                      ? const Color(0xFFE0E0E0) 
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 20),
                  ),
                  boxShadow: message.isUser ? [] : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: message.isUser ? FontWeight.w400 : FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _handleSystemBack() async {
    // Intercept Android back / iOS swipe-back to ensure session is counted & stopped.
    if (_isExiting) return false;
    if (_status != AppStatus.disconnected || _currentSessionId != null) {
      await _exitAndPersistSession();
      return false; // we manually popped
    }
    return true;
  }

  Future<void> _handleBackPressed() async {
    if (_isExiting) return;
    if (_status != AppStatus.disconnected || _currentSessionId != null) {
      await _exitAndPersistSession();
      return;
    }
    if (mounted) Navigator.of(context).pop(_didChange);
  }

  Future<void> _exitAndPersistSession() async {
    if (!mounted) return;
    setState(() => _isExiting = true);
    final drained = _drainSessionForFinalize();
    // Stop local audio/websocket immediately, then persist in the background.
    await _stopRealtimeNow(isDisposing: true);
    unawaited(_finalizeSessionInBackground(
      drained,
      showCompletionDialog: false,
      isDisposing: true,
    ));
    if (mounted) Navigator.of(context).pop(_didChange);
  }

  Future<void> _startRecorderStream() async {
    if (!_allowRecorderRestart ||
        _isStartingRecorder ||
        !_sessionReady ||
        !_isHoldingToTalk) {
      return;
    }
    _isStartingRecorder = true;
    try {
      await _recorderSubscription?.cancel();
      final stream = await _audioRecorder.startStream(_recordConfig);
      _recorderSubscription = stream.listen(
        (Uint8List data) {
          if (_channel != null &&
              _status != AppStatus.disconnected &&
              _isHoldingToTalk &&
              !_isPlayingTts) {
            _channel!.sink.add(data);
          }
        },
        onError: (error, stack) {
          debugPrint("Recorder stream error: $error");
          _handleRecorderStreamClosed();
        },
        onDone: _handleRecorderStreamClosed,
      );
      
      // Start amplitude timer for bubble visualization
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (timer) async {
          try {
            final amplitude = await _audioRecorder.getAmplitude();
            if (mounted && _status != AppStatus.disconnected) {
              setState(() {
                final normalized = (amplitude.current + 50).clamp(0.0, 50.0) / 50.0;
                _soundLevel = normalized;
              });
            }
          } catch (e) {
            // Ignore amplitude errors
          }
        },
      );
    } catch (e) {
      debugPrint("Failed to start recorder stream: $e");
      _scheduleRecorderRestart();
    } finally {
      _isStartingRecorder = false;
    }
  }

  void _handleRecorderStreamClosed() {
    _recorderSubscription = null;
    if (!_isHoldingToTalk) return;
    _scheduleRecorderRestart();
  }

  void _scheduleRecorderRestart() {
    if (!_allowRecorderRestart || _isStartingRecorder || !_isHoldingToTalk) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_allowRecorderRestart && !_isStartingRecorder && _isHoldingToTalk) {
        _startRecorderStream();
      }
    });
  }

  void _enqueueAudioPlayback(List<int> audioBytes) {
    if (audioBytes.isEmpty) return;
    _audioQueue.add(audioBytes);
    if (!_isProcessingAudio) {
      _processAudioQueue();
    }
  }

  Future<void> _processAudioQueue() async {
    _isProcessingAudio = true;
    while (_audioQueue.isNotEmpty) {
      final audioBytes = _audioQueue.removeFirst();
      await _playAudio(audioBytes);
    }
    _isProcessingAudio = false;
  }

  Future<void> _pauseRecordingForPlayback() async {
    if (_isPlayingTts) return;
    _isPlayingTts = true;
    _allowRecorderRestart = false;
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
    try {
      final recording = await _audioRecorder.isRecording();
      if (recording) {
        await _audioRecorder.pause();
      }
    } catch (e) {
      debugPrint("Error pausing recorder: $e");
    }
  }

  Future<void> _resumeRecordingAfterPlayback() async {
    _isPlayingTts = false;
    if (_status == AppStatus.disconnected || !_sessionReady || !_isHoldingToTalk) return;
    _allowRecorderRestart = true;
    await _startRecorderStream();
  }
}

// Extension for taking last N elements from list
extension ListExtension<E> on List<E> {
  List<E> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}

class AIAgentBubble extends StatefulWidget {
  final double soundLevel;
  final bool isAgentSpeaking;
  final bool isHolding;

  const AIAgentBubble({
    super.key, 
    required this.soundLevel,
    required this.isAgentSpeaking,
    this.isHolding = false,
  });

  @override
  State<AIAgentBubble> createState() => _AIAgentBubbleState();
}

class _AIAgentBubbleState extends State<AIAgentBubble>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soundMultiplier = 1.0 + (widget.soundLevel * 2.0);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, child) {
        return CustomPaint(
          painter: AIBubblePainter(
            pulseValue: _pulseAnimation.value,
            waveValue: _waveController.value,
            soundLevel: widget.soundLevel,
            soundMultiplier: soundMultiplier,
            isAgentSpeaking: widget.isAgentSpeaking,
            isHolding: widget.isHolding,
          ),
          size: const Size(220, 220),
        );
      },
    );
  }
}

class AIBubblePainter extends CustomPainter {
  final double pulseValue;
  final double waveValue;
  final double soundLevel;
  final double soundMultiplier;
  final bool isAgentSpeaking;
  final bool isHolding;

  AIBubblePainter({
    required this.pulseValue,
    required this.waveValue,
    required this.soundLevel,
    required this.soundMultiplier,
    required this.isAgentSpeaking,
    this.isHolding = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 4;

    if (soundLevel > 0.01) {
      _drawSoundWaves(canvas, center, baseRadius);
    }

    _drawMainBubble(canvas, center, baseRadius);
  }

  void _drawSoundWaves(Canvas canvas, Offset center, double baseRadius) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.5 + (soundLevel * 0.3);

    final numWaves = 3 + (soundLevel * 2).round();
    
    for (int i = 0; i < numWaves; i++) {
      final waveProgress = (waveValue + (i * 0.33)) % 1.0;
      final waveRadius = baseRadius * (1.0 + waveProgress * (1.2 + soundLevel * 0.5));
      final opacity = (1.0 - waveProgress) * (0.2 + soundLevel * 0.3);

      wavePaint.color = Colors.black.withOpacity(opacity);

      final path = Path();
      const segments = 120;
      
      for (int j = 0; j <= segments; j++) {
        final angle = (j / segments) * 2 * math.pi;
        final waveIntensity = 2.0 + (soundLevel * 4.0);
        final waveOffset = math.sin(angle * 8 + waveValue * 2 * math.pi) * waveIntensity;
        
        final radius = waveRadius + waveOffset;
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);

        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawMainBubble(Canvas canvas, Offset center, double baseRadius) {
    final bubblePath = Path();
    const segments = 120; 

    final soundExpansion = isAgentSpeaking 
        ? 1.0 
        : 1.0 + (soundLevel * 0.1); 

    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * math.pi;

      double waveIntensity;
      
      if (isAgentSpeaking) {
        waveIntensity = 2.5; 
      } else {
        waveIntensity = 0.2; 
      }
      
      final wave1 = math.sin(angle * 2 + waveValue * 2 * math.pi) * 4.0 * waveIntensity;
      final wave2 = math.sin(angle * 3 - waveValue * 4 * math.pi) * 2.5 * waveIntensity;
      final wave3 = math.cos(angle * 5 + waveValue * 2 * math.pi) * 1.5 * waveIntensity;

      final radius = (baseRadius * pulseValue * soundExpansion) + wave1 + wave2 + wave3;

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        bubblePath.moveTo(x, y);
      } else {
        bubblePath.lineTo(x, y);
      }
    }
    bubblePath.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawPath(
      bubblePath.shift(const Offset(0, 5)),
      shadowPaint,
    );

    final bubblePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2A2A2A),
          const Color(0xFF000000),
        ],
        stops: const [0.0, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawPath(bubblePath, bubblePaint);
  }

  @override
  bool shouldRepaint(AIBubblePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.waveValue != waveValue ||
        oldDelegate.soundLevel != soundLevel ||
        oldDelegate.isAgentSpeaking != isAgentSpeaking;
  }
}

void unawaited(Future<void> future) {}

