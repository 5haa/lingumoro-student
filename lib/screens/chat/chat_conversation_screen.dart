import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/presence_service.dart';
import 'package:student/services/blocking_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../teachers/teacher_detail_screen.dart';
import '../students/student_public_profile_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final String recipientType; // 'teacher' or 'student'
  final String? previewMessage;
  final String? previewTime;
  final bool isUnread;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.recipientType,
    this.previewMessage,
    this.previewTime,
    this.isUnread = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> with WidgetsBindingObserver {
  final _chatService = ChatService();
  final _presenceService = PresenceService();
  final _blockingService = BlockingService();
  final _preloadService = PreloadService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  File? _selectedFile;
  bool _isTyping = false;
  Timer? _typingDebounce;
  bool _isOtherUserTyping = false;
  bool _isOnline = false;
  String _lastSeen = '';
  String? _currentUserId;
  String? _recipientType; 
  Timer? _typingTimer;
  Timer? _statusRefreshTimer;
  
  // Pagination variables
  static const int _messagesPerPage = 50;
  static const int _moreMessagesCount = 20;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  
  // Voice recording state
  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  String _recordingDuration = '0:00';
  Timer? _recordingTimer;
  
  // Audio players for voice messages (one per message)
  final Map<String, AudioPlayer> _audioPlayers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = _chatService.supabase.auth.currentUser?.id;
    _recipientType = widget.recipientType; // Use provided type or determine later
    _messageController.addListener(() {
      setState(() {}); // Rebuild to show/hide mic button
    });
    
    // Check for preview message to show instantly
    if (widget.previewMessage != null && widget.previewMessage!.isNotEmpty) {
      final cached = _preloadService.getMessages(widget.conversationId);
      if (cached == null || cached.isEmpty) {
        // Create a temporary preview message
        // Use a preview message structure that mimics real message
        _messages = [{
          'id': 'preview_${DateTime.now().millisecondsSinceEpoch}',
          'conversation_id': widget.conversationId,
          'sender_id': widget.isUnread ? widget.recipientId : (_currentUserId ?? 'unknown'),
          'sender_type': widget.isUnread ? widget.recipientType : 'student',
          'message_text': widget.previewMessage,
          'created_at': widget.previewTime ?? DateTime.now().toIso8601String(),
          'has_attachment': widget.previewMessage == '📷 Photo' || widget.previewMessage == '📎 Attachment' || widget.previewMessage == '🎤 Voice Message',
          'is_read': !widget.isUnread,
          'is_preview': true, // flag to identify and remove later
        }];
        _isLoading = false; // Show content immediately
      }
    }

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
    
    _loadMessagesFromCache();
    _setupRealtimeSubscriptions();
    _markMessagesAsRead();
    _subscribeToOnlineStatus();
    _determineRecipientType(); // Determine recipient type if not provided
  }

  Future<void> _determineRecipientType() async {
    if (_recipientType != null) return; // Already set
    
    try {
      final conversation = await _chatService.supabase
          .from('chat_conversations')
          .select('conversation_type, teacher_id')
          .eq('id', widget.conversationId)
          .single();
      
      if (mounted) {
        setState(() {
          if (conversation['conversation_type'] == 'student_student') {
            _recipientType = 'student';
          } else {
            _recipientType = 'teacher';
          }
        });
      }
    } catch (e) {
      print('Error determining recipient type: $e');
      // Default to teacher if we can't determine
      if (mounted) {
        setState(() {
          _recipientType = 'teacher';
        });
      }
    }
  }

  void _loadMessagesFromCache() {
    // Try to load from cache first for instant UI
    final cached = _preloadService.getMessages(widget.conversationId);
    final hasCache = cached != null && cached.isNotEmpty;
    
    // We consider "has cache" if we successfully loaded from cache OR if we have a preview message
    final hasDataToShow = hasCache || _messages.isNotEmpty;
    
    if (hasCache) {
      setState(() {
        _messages = List.from(cached); // Use a copy to avoid mutation issues
        _isLoading = false;
      });
      print('✅ Loaded ${cached.length} messages from cache');
    }
    
    // Fetch latest from API in background (without showing loading if we have data to show)
    _loadMessages(showLoading: !hasDataToShow);
  }

  void _subscribeToOnlineStatus() {
    // Wait a moment for recipient type to be determined
    Future.delayed(const Duration(milliseconds: 500), () {
      final userType = _recipientType ?? 'teacher';
      
      // Subscribe to recipient's online status
      _presenceService.subscribeToUserStatus(widget.recipientId, userType).listen((isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
        }
      });
      
      // Periodically refresh online status (every 30 seconds)
      _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (mounted) {
          final userType = _recipientType ?? 'teacher';
          final isOnline = await _presenceService.isUserOnline(widget.recipientId, userType);
          if (mounted) {
            setState(() {
              _isOnline = isOnline;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.unsubscribeAll();
    final userType = _recipientType ?? 'teacher';
    _presenceService.unsubscribeFromUser(widget.recipientId, userType);
    _presenceService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder?.dispose();
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh messages
      print('🔄 Chat conversation: App resumed - refreshing messages');
      _loadMessages();
      _markMessagesAsRead();
    }
  }

  void _setupRealtimeSubscriptions() {
    // Subscribe to new messages
    _chatService.subscribeToMessages(widget.conversationId);
    _chatService.onMessage.listen((message) {
      if (mounted) {
        final messageId = message['id'];
        final existingIndex = _messages.indexWhere((m) => m['id'] == messageId);

        if (existingIndex != -1) {
          // Message with this ID already exists, update it with full data
          setState(() {
            _messages[existingIndex] = message;
          });
          _preloadService.addMessageToCache(widget.conversationId, message);
        } else {
          // Check if this is a message from the current user that might be replacing a temp message
          final isFromCurrentUser = message['sender_id'] == _currentUserId;
          
          if (isFromCurrentUser) {
            // For messages from current user, find any temp message that:
            // 1. Is marked as temp
            // 2. Is from the same sender
            // 3. Is still in "sending" state (not yet replaced by API return)
            // This handles text, attachments, and voice messages uniformly
            final tempIndex = _messages.indexWhere((m) => 
                m['is_temp'] == true && 
                m['is_sending'] == true &&
                m['sender_id'] == message['sender_id']);
            
            if (tempIndex != -1) {
              // Replace the temporary message with the real one
              // CHECK: If real message has incomplete attachments (race condition), wait for API return
              final hasAttachments = message['has_attachment'] == true;
              final attachments = message['attachments'] as List?;
              final isAttachmentsIncomplete = hasAttachments && (attachments == null || attachments.isEmpty);
              
              if (!isAttachmentsIncomplete) {
                setState(() {
                  _messages[tempIndex] = message;
                });
                _preloadService.addMessageToCache(widget.conversationId, message);
              } else {
                // Ignore this update to prevent flicker (image -> loading -> image)
                // The API call return will handle the full update shortly
                print('⏳ Ignoring incomplete real-time message to prevent flicker');
              }
            } else {
              // No temp message found - this could be a message already handled by API return
              // Check if a message with similar content exists (race condition)
              final createdAt = DateTime.tryParse(message['created_at'] ?? '');
              final recentDuplicate = createdAt != null && _messages.any((m) =>
                  m['sender_id'] == message['sender_id'] &&
                  m['is_temp'] != true &&
                  m['id'] != messageId &&
                  (DateTime.tryParse(m['created_at'] ?? '')?.difference(createdAt).inSeconds.abs() ?? 999) < 5);
              
              if (!recentDuplicate) {
                // Only add if not a duplicate
                setState(() {
                  _messages.add(message);
                });
                _preloadService.addMessageToCache(widget.conversationId, message);
              }
            }
          } else {
            // Message from another user - simply add it
            setState(() {
              _messages.add(message);
            });
            _preloadService.addMessageToCache(widget.conversationId, message);
          }
        }
        _scrollToBottom(animate: true); // Smooth scroll for new messages
        _markMessagesAsRead();
      }
    });

    // Subscribe to typing indicators
    _chatService.subscribeToTyping(widget.conversationId);
    _chatService.onTyping.listen((data) {
      if (mounted) {
        setState(() {
          _isTyping = data['is_typing'] == true;
        });
      }
    });

    // Subscribe to message updates (e.g. read status)
    _chatService.onMessageUpdate.listen((updatedMessage) {
      if (mounted) {
        final index = _messages.indexWhere((m) => m['id'] == updatedMessage['id']);
        if (index != -1) {
          setState(() {
            // Preserve attachments if not in update payload
            final existingAttachments = _messages[index]['attachments'];
            _messages[index] = {
              ..._messages[index],
              ...updatedMessage,
            };
            // Ensure attachments aren't lost
            if (existingAttachments != null && _messages[index]['attachments'] == null) {
              _messages[index]['attachments'] = existingAttachments;
            }
          });
          print('📩 Message updated - ID: ${updatedMessage['id']}, is_read: ${_messages[index]['is_read']}');
        }
      }
    });
  }

  void _onScroll() {
    // Check if user scrolled to the top (remember, list is reversed)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    // Only show loading if explicitly requested (i.e., no cache available)
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    
    // Load initial batch of messages
    final messages = await _chatService.getMessages(
      widget.conversationId,
      limit: _messagesPerPage,
      offset: 0,
    );
    
    // Cache the messages
    _preloadService.cacheMessages(widget.conversationId, messages);
    
    if (mounted) {
      setState(() {
        // If we already have messages (from cache or realtime), merge intelligently
        if (_messages.isNotEmpty && !showLoading) {
          // Create a map of existing messages by ID for quick lookup
          final existingIds = <String>{};
          for (var msg in _messages) {
            existingIds.add(msg['id'] as String);
          }
          
          // Start with API messages (they're the source of truth for historical data)
          final mergedMessages = List<Map<String, dynamic>>.from(messages);
          
          // Add any messages from _messages that aren't in the API response
          // (these could be messages received via realtime that haven't synced yet)
          // BUT skip preview messages as they are replaced by API data
          for (var msg in _messages) {
            if (msg['is_preview'] == true) continue; // Skip preview messages
            
            final msgId = msg['id'] as String;
            final alreadyExists = mergedMessages.any((m) => m['id'] == msgId);
            if (!alreadyExists) {
              // This is a newer message not yet in API response, keep it
              mergedMessages.add(msg);
            }
          }
          
          // Sort by created_at to ensure proper order
          mergedMessages.sort((a, b) {
            final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
            final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
            return aTime.compareTo(bTime);
          });
          
          _messages = mergedMessages;
        } else {
          // No existing messages or full reload requested - just use API response
          _messages = messages;
        }
        
        _isLoading = false;
        // Check if there might be more messages
        _hasMoreMessages = messages.length >= _messagesPerPage;
      });
      
      // No need to scroll - reverse: true handles it naturally
    }
  }


  Future<void> _refreshMessages() async {
    if (_isLoading) return;

    final shouldStayAtBottom = _scrollController.hasClients && _scrollController.offset < 50;

    if (mounted) {
      setState(() {
        _hasMoreMessages = true;
        _isLoadingMore = false;
      });
    }

    // Force a fresh fetch instead of showing stale cached messages
    _preloadService.invalidateMessages(widget.conversationId);

    await _loadMessages();
    await _markMessagesAsRead();

    if (shouldStayAtBottom) {
      _scrollToBottom(animate: false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      // Load more messages with offset
      final moreMessages = await _chatService.getMessages(
        widget.conversationId,
        limit: _moreMessagesCount,
        offset: _messages.length,
      );
      
      if (mounted) {
        setState(() {
          // Insert at the beginning since messages are in chronological order
          _messages.insertAll(0, moreMessages);
          _isLoadingMore = false;
          // Check if there are still more messages
          _hasMoreMessages = moreMessages.length >= _moreMessagesCount;
        });
        
        // Update cache with all messages
        _preloadService.cacheMessages(widget.conversationId, _messages);
      }
    } catch (e) {
      print('Error loading more messages: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.conversationId);
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            0, // Scroll to 0 because list is reversed
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0); // Instant scroll to bottom (0 in reversed list)
        }
      }
    });
  }

  void _onTyping() {
    _chatService.updateTypingIndicator(widget.conversationId, true);
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTypingIndicator(widget.conversationId, false);
    });
  }

  Future<void> _downloadAndOpenFile(String fileUrl, String fileName) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('${AppLocalizations.of(context).downloading} $fileName...'),
            ],
          ),
        ),
      );

      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      
      // Create downloads directory if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/$fileName';

      // Download file
      await Dio().download(
        fileUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Open the downloaded file
      final result = await OpenFile.open(filePath);
      
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).downloadedToUnableToOpen.replaceAll('{filePath}', filePath).replaceAll('{message}', result.message)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).downloadFailed} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retryMessage(String tempId, String messageText) async {
    // Mark as sending again
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == tempId);
      if (index != -1) {
        _messages[index]['is_failed'] = false;
        _messages[index]['is_sending'] = true;
      }
    });

    try {
      final message = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        messageText: messageText,
      );

      if (message != null) {
        final realMessage = message; // Capture non-null value
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index] = realMessage;
          }
        });
        _preloadService.addMessageToCache(widget.conversationId, realMessage);
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['is_sending'] = false;
            _messages[index]['is_failed'] = true;
          }
        });
      }
    } catch (e) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _messages[index]['is_sending'] = false;
          _messages[index]['is_failed'] = true;
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    // Create temporary message for optimistic UI
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Determine attachment type from file
    String? attachmentType;
    String? fileName;
    if (_selectedFile != null) {
      fileName = _selectedFile!.path.split('/').last;
      final extension = fileName.toLowerCase().split('.').last;
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        attachmentType = 'image';
      } else {
        attachmentType = 'file';
      }
    }
    
    final tempMessage = {
      'id': tempId,
      'conversation_id': widget.conversationId,
      'sender_id': _currentUserId,
      'sender_type': 'student',
      'message_text': text,
      'has_attachment': _selectedFile != null,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
      'is_sending': true, // Custom flag for optimistic UI
      'is_temp': true, // Mark as temporary
      // Add temporary attachment details for preview
      if (_selectedFile != null)
        'attachments': [
          {
            'id': tempId,
            'message_id': tempId,
            'file_name': fileName,
            'file_type': fileName?.split('.').last ?? 'file',
            'attachment_type': attachmentType,
            'file_url': '', // Empty during upload
          }
        ],
    };

    // Add to UI immediately
    setState(() {
      _messages.add(tempMessage);
      _isSending = true;
    });
    _scrollToBottom(animate: true);

    _messageController.clear();
    _chatService.updateTypingIndicator(widget.conversationId, false);

    try {
      Map<String, dynamic>? message;
      
      if (_selectedFile != null) {
        message = await _chatService.sendMessageWithAttachment(
          conversationId: widget.conversationId,
          messageText: text,
          file: _selectedFile!,
        );
        setState(() => _selectedFile = null);
      } else {
        message = await _chatService.sendMessage(
          conversationId: widget.conversationId,
          messageText: text,
        );
      }

      if (message != null) {
        // Replace temporary message with real message
        final realMessage = message; // Capture non-null value
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index] = realMessage;
          }
        });
        // Cache updated message
        _preloadService.addMessageToCache(widget.conversationId, realMessage);
      } else {
        // Mark as failed
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['is_sending'] = false;
            _messages[index]['is_failed'] = true;
          }
        });
        _showError('Failed to send message');
      }
    } catch (e) {
      // Mark as failed
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _messages[index]['is_sending'] = false;
          _messages[index]['is_failed'] = true;
        }
      });
      _showError('Error sending message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await _chatService.pickFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _startRecording() async {
    final recorder = await _chatService.startRecording();
    if (recorder != null) {
      setState(() {
        _audioRecorder = recorder;
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = '0:00';
      });
      
      // Update duration every second
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingStartTime != null) {
          final duration = DateTime.now().difference(_recordingStartTime!);
          setState(() {
            _recordingDuration = '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
          });
        }
      });
    } else {
      _showError('Failed to start recording. Please check microphone permissions.');
    }
  }

  Future<void> _stopRecording() async {
    if (_audioRecorder == null || _recordingStartTime == null) return;

    _recordingTimer?.cancel();
    
    final result = await _chatService.stopRecording(_audioRecorder!, _recordingStartTime!);
    
    setState(() {
      _isRecording = false;
      _recordingTimer?.cancel();
    });

    if (result != null && result.file != null) {
      // Create temporary message for optimistic UI
      final tempId = 'temp_voice_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = result.file!.path.split('/').last;
      
      final tempMessage = {
        'id': tempId,
        'conversation_id': widget.conversationId,
        'sender_id': _currentUserId,
        'sender_type': 'student',
        'message_text': '',
        'has_attachment': true,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'is_sending': true,
        'is_temp': true,
        'attachments': [
          {
            'id': tempId,
            'message_id': tempId,
            'file_name': fileName,
            'file_type': 'mp3',
            'attachment_type': 'voice',
            'duration_seconds': result.duration,
            'file_url': '', // Empty during upload
          }
        ],
      };
      
      // Add to UI immediately
      setState(() {
        _messages.add(tempMessage);
        _isSending = true;
      });
      _scrollToBottom(animate: true);
      
      try {
        final message = await _chatService.sendVoiceMessage(
          conversationId: widget.conversationId,
          audioFile: result.file!,
          durationSeconds: result.duration,
        );

        if (message != null) {
          // Replace temporary message with real message
          setState(() {
            final index = _messages.indexWhere((m) => m['id'] == tempId);
            if (index != -1) {
              _messages[index] = message;
            }
          });
          _preloadService.addMessageToCache(widget.conversationId, message);
          _scrollToBottom(animate: true);
        } else {
          // Mark as failed
          setState(() {
            final index = _messages.indexWhere((m) => m['id'] == tempId);
            if (index != -1) {
              _messages[index]['is_sending'] = false;
              _messages[index]['is_failed'] = true;
            }
          });
          _showError('Failed to send voice message');
        }
      } catch (e) {
        // Mark as failed
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['is_sending'] = false;
            _messages[index]['is_failed'] = true;
          }
        });
        _showError('Error sending voice message: $e');
      } finally {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_audioRecorder == null) return;
    
    await _chatService.cancelRecording(_audioRecorder!);
    _recordingTimer?.cancel();
    
    setState(() {
      _isRecording = false;
      _audioRecorder = null;
      _recordingStartTime = null;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatMessageTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp).toLocal();
      return DateFormat.jm().format(date);
    } catch (e) {
      return '';
    }
  }

  String _formatMessageDate(String timestamp) {
  try {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0 && date.day == now.day) {
      return 'Today';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && date.day != now.day)) {
      // Handle edge case where difference is < 24h but it's previous calendar day
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  } catch (e) {
    return '';
  }
}

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    
    try {
      final currentDate = DateTime.parse(_messages[index]['created_at']);
      final previousDate = DateTime.parse(_messages[index - 1]['created_at']);
      
      return currentDate.day != previousDate.day ||
             currentDate.month != previousDate.month ||
             currentDate.year != previousDate.year;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: SafeArea(
          child: Column(
            children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _viewRecipientProfile,
                    child: Stack(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          child: ClipOval(
                            child: widget.recipientAvatar != null && widget.recipientAvatar!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.recipientAvatar!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: Text(
                                        widget.recipientName[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        widget.recipientName[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      widget.recipientName[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (_isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _viewRecipientProfile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recipientName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _isTyping ? 'typing...' : (_isOnline ? 'Online' : 'Offline'),
                            style: TextStyle(
                              fontSize: 11,
                              color: _isTyping 
                                  ? AppColors.primary
                                  : (_isOnline ? Colors.green : AppColors.textSecondary),
                              fontStyle: _isTyping ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 40),
                    color: AppColors.white,
                    elevation: 8,
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.circleInfo,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.ban,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Block User',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'profile') {
                        _viewRecipientProfile();
                      } else if (value == 'block') {
                        _showBlockConfirmation();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshMessages,
                color: AppColors.primary,
                triggerMode: RefreshIndicatorTriggerMode.anywhere,
                child: _isLoading && _messages.isEmpty
                    ? ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ],
                      )
                    : _messages.isEmpty
                        ? ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: AppColors.grey.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        FontAwesomeIcons.comment,
                                        size: 40,
                                        color: AppColors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start the conversation',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            reverse: true, // Latest messages at bottom
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at the end (top when reversed)
                              if (index == _messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Reverse index since list is reversed
                              final reversedIndex = _messages.length - 1 - index;
                              final message = _messages[reversedIndex];
                              final isMe = message['sender_id'] == _currentUserId;
                              final showDateSeparator = _shouldShowDateSeparator(reversedIndex);

                              return Column(
                                children: [
                                  if (showDateSeparator)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _formatMessageDate(message['created_at']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                  _buildMessageBubble(message, isMe),
                                ],
                              );
                            },
                          ),
              ),
            ),

            // Selected File Preview
            if (_selectedFile != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.paperclip,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const FaIcon(
                        FontAwesomeIcons.xmark,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _selectedFile = null);
                      },
                    ),
                  ],
                ),
              ),

            // Input Area
            _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final hasAttachment = message['has_attachment'] == true;
    final attachments = message['attachments'] as List?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: isMe ? () => _showMessageOptions(message) : null,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFE3F2FD) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 2),
                        bottomRight: Radius.circular(isMe ? 2 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasAttachment && attachments != null && attachments.isNotEmpty)
                          ...attachments.map(
                            (attachment) => _buildAttachment(
                              Map<String, dynamic>.from(attachment as Map),
                              isMe,
                              message['is_sending'] == true,
                            ),
                          ),
                        if (message['message_text'] != null && message['message_text'].toString().isNotEmpty)
                          Text(
                            message['message_text'],
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                              height: 1.4,
                            ),
                          )
                        else if (hasAttachment && (attachments == null || attachments.isEmpty))
                          // Show loading state while attachments are being fetched/processed
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMe ? 'Sending attachment...' : 'Loading attachment...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        else if (hasAttachment && (message['message_text'] == null || message['message_text'].toString().isEmpty))
                          // Fallback should not be reached if above logic works, but keep as safety
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Failed message - show retry button
                    if (isMe && message['is_failed'] == true) ...[
                      InkWell(
                        onTap: () => _retryMessage(message['id'], message['message_text']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 12, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(AppLocalizations.of(context).tapToRetry, style: const TextStyle(fontSize: 10, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(message['created_at']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999),
                            ),
                          ),
                          // Status indicators for sent messages
                          if (isMe && message['is_failed'] != true) ...[
                            const SizedBox(width: 4),
                            if (message['is_sending'] == true)
                              const Icon(Icons.access_time, size: 12, color: Color(0xFF999999))
                            else if (message['is_read'] == true)
                              const Icon(Icons.done_all, size: 14, color: Colors.blue)
                            else
                              const Icon(Icons.done, size: 14, color: Color(0xFF999999)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildAttachment(Map<String, dynamic> attachment, bool isMe, bool isSending) {
    final fileName = attachment['file_name'] ?? 'File';
    final fileType = attachment['file_type'] ?? '';
    final fileUrl = attachment['file_url'] ?? '';
    final attachmentType = attachment['attachment_type'] ?? 'file';
    final durationSeconds = attachment['duration_seconds'] as int?;
    final messageId = attachment['message_id'] as String;

    // Voice message player (show placeholder while sending)
    if (attachmentType == 'voice') {
      if (isSending) {
        // Show voice message placeholder while uploading
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF90CAF9) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: Color(0xFF1A1A1A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: isMe ? const Color(0xFF90CAF9) : Colors.grey[400],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1A1A1A),
                      ),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0:${durationSeconds?.toString().padLeft(2, '0') ?? '00'}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      }
      return _buildVoiceMessagePlayer(messageId, fileUrl, durationSeconds ?? 0, isMe);
    }

    // Image attachment - display inline
    if (attachmentType == 'image' || _isImageFile(fileType)) {
      if (isSending || fileUrl.isEmpty) {
        // Show image placeholder while uploading
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFBBDEFB) : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            height: 150,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.grey[600], size: 48),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
      
      return GestureDetector(
        onTap: () => _showFullImage(fileUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: fileUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              placeholder: (context, url) => Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              errorWidget: (context, url, error) {
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context).failedToLoadImage, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Regular file attachment
    return GestureDetector(
      onTap: isSending ? null : () => _downloadAndOpenFile(fileUrl, fileName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFBBDEFB) : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              _getFileIcon(fileType),
              color: const Color(0xFF1A1A1A),
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                fileName,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImageFile(String fileType) {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileType.toLowerCase());
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessagePlayer(String messageId, String audioUrl, int durationSeconds, bool isMe) {
    if (!_audioPlayers.containsKey(messageId)) {
      final newPlayer = AudioPlayer();
      _audioPlayers[messageId] = newPlayer;
      newPlayer.setUrl(audioUrl).catchError((e) {
        print('Error loading audio: $e');
      });
    }
    
    final player = _audioPlayers[messageId]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final isPlaying = playerState?.playing ?? false;
              final processingState = playerState?.processingState;
              final isLoading = processingState == ProcessingState.loading ||
                                processingState == ProcessingState.buffering;

              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF90CAF9) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1A1A1A),
                            ),
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: const Color(0xFF1A1A1A),
                          size: 18,
                        ),
                  onPressed: isLoading ? null : () async {
                    try {
                      if (isPlaying) {
                        await player.pause();
                      } else {
                        if (processingState == ProcessingState.completed) {
                          await player.seek(Duration.zero);
                        }
                        await player.play();
                      }
                    } catch (e) {
                      print('Error playing audio: $e');
                      _showError('Could not play audio');
                    }
                  },
                  padding: EdgeInsets.zero,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          StreamBuilder<Duration?>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.duration ?? Duration(seconds: durationSeconds);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0,
                      backgroundColor: isMe ? const Color(0xFF90CAF9) : Colors.grey[400],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1A1A1A),
                      ),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return FontAwesomeIcons.filePdf;
      case 'doc':
      case 'docx':
        return FontAwesomeIcons.fileWord;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return FontAwesomeIcons.fileImage;
      default:
        return FontAwesomeIcons.file;
    }
  }

  Widget _buildMessageInput() {
    // Recording UI
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _recordingDuration,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const FaIcon(FontAwesomeIcons.trash, size: 16, color: Colors.red),
                onPressed: _cancelRecording,
                tooltip: 'Cancel',
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 18, color: Colors.white),
                onPressed: _stopRecording,
                tooltip: 'Send',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    }

    // Normal input UI with floating design
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Text Input - Floating with border and plus icon inside
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 44,
                maxHeight: 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(25),
                color: AppColors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).messageHint,
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF999999),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _onTyping();
                        }
                        setState(() {}); // Rebuild to show/hide plus icon
                      },
                      onSubmitted: (_) {
                        if (_messageController.text.trim().isNotEmpty) _sendMessage();
                      },
                    ),
                  ),
                  // Plus Icon inside input field (only when not typing)
                  if (_messageController.text.isEmpty && !_isSending)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.plus,
                        size: 18,
                        color: Color(0xFF666666),
                      ),
                      onPressed: _showAttachmentOptions,
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Voice or Send Button - Circular
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _messageController.text.trim().isNotEmpty || _selectedFile != null
                ? Container(
                    key: const ValueKey('send'),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            icon: const FaIcon(
                              FontAwesomeIcons.paperPlane,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                  )
                : Container(
                    key: const ValueKey('voice'),
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const FaIcon(
                        FontAwesomeIcons.microphone,
                        size: 18,
                        color: Color(0xFF666666),
                      ),
                      onPressed: _startRecording,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: const Text(
          'Delete Chat?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this chat with ${widget.recipientName}? This action cannot be undone.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteChat();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat() async {
    try {
      final response = await _chatService.supabase
          .from('chat_conversations')
          .update({
            'deleted_by_student': true,
            'student_deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.conversationId);

      if (mounted) {
        Navigator.pop(context); // Go back to chat list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatDeletedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToDeleteChat),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle at top
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const FaIcon(
                FontAwesomeIcons.trashCan,
                color: Colors.red,
                size: 20,
              ),
              title: const Text(
                'Unsend Message',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _unsendMessage(message['id']);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _unsendMessage(String messageId) async {
    try {
      final userId = _chatService.supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _chatService.supabase
          .from('chat_messages')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'deleted_by': userId,
            'deleted_by_type': 'student',
          })
          .eq('id', messageId);

      // Update local state
      setState(() {
        _messages.removeWhere((msg) => msg['id'] == messageId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).messageUnsent),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error unsending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToUnsendMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewRecipientProfile() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final recipientType = _recipientType ?? 'teacher';

      if (recipientType == 'student') {
        // Fetch student profile data
        await _viewStudentProfile();
      } else {
        // Fetch teacher profile data
        await _viewTeacherProfile();
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        _showProfileError('Error: $e');
      }
    }
  }

  Future<void> _viewStudentProfile() async {
    try {
      // Fetch complete student data
      final studentData = await _chatService.supabase
          .from('students')
          .select('''
            *,
            province:province_id (
              id,
              name,
              name_ar
            )
          ''')
          .eq('id', widget.recipientId)
          .single();

      // Fetch student's languages through subscriptions
      final subscriptions = await _chatService.supabase
          .from('student_subscriptions')
          .select('''
            language:language_id (
              id,
              name,
              flag_url
            )
          ''')
          .eq('student_id', widget.recipientId)
          .eq('status', 'active');

      // Transform the data to match expected format
      final languages = subscriptions
          .map((sub) {
            final lang = sub['language'] as Map<String, dynamic>?;
            if (lang != null) {
              return {
                'id': lang['id'],
                'name': lang['name'],
                'flag_url': lang['flag_url'],
              };
            }
            return null;
          })
          .where((l) => l != null)
          .cast<Map<String, dynamic>>()
          .toList();

      final formattedData = {
        ...studentData,
        'languages': languages,
      };
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to profile screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentPublicProfileScreen(
              studentId: widget.recipientId,
              studentData: formattedData,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        _showProfileError('Error loading student profile: $e');
      }
    }
  }

  Future<void> _viewTeacherProfile() async {
    try {
      // Fetch teacher's language data from teacher_languages table
      final teacherLanguages = await _chatService.supabase
          .from('teacher_languages')
          .select('''
            language_id,
            language:language_id (
              id,
              name
            )
          ''')
          .eq('teacher_id', widget.recipientId)
          .limit(1);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Use the first language or a default
      if (teacherLanguages.isNotEmpty && mounted) {
        final languageData = teacherLanguages[0]['language'] as Map<String, dynamic>?;
        if (languageData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherDetailScreen(
                teacherId: widget.recipientId,
                languageId: languageData['id'],
                languageName: languageData['name'] ?? 'Language',
              ),
            ),
          );
        } else {
          _showProfileError('Unable to load teacher profile data');
        }
      } else if (mounted) {
        _showProfileError('Teacher has no available languages');
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        _showProfileError('Error loading teacher profile: $e');
      }
    }
  }

  void _showProfileError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: const Text(
          'Block User?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to block ${widget.recipientName}? You won\'t be able to send or receive messages from this user.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Call blocking service
              final blocked = await _blockingService.blockUser(widget.recipientId);
              
              if (blocked && mounted) {
                Navigator.pop(context); // Go back to chat list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.recipientName} has been blocked'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).failedToBlockUserTryAgain),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Block',
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Send Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: FontAwesomeIcons.image,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: FontAwesomeIcons.camera,
                  label: 'Camera',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: FontAwesomeIcons.file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FaIcon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
