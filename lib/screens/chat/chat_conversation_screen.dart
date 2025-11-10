import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/presence_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class ChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _chatService = ChatService();
  final _presenceService = PresenceService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  bool _isOnline = false;
  String? _currentUserId;
  File? _selectedFile;
  Timer? _typingTimer;
  Timer? _statusRefreshTimer;
  
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
    _currentUserId = _chatService.supabase.auth.currentUser?.id;
    _messageController.addListener(() {
      setState(() {}); // Rebuild to show/hide mic button
    });
    _loadMessages();
    _setupRealtimeSubscriptions();
    _markMessagesAsRead();
    _subscribeToOnlineStatus();
  }

  void _subscribeToOnlineStatus() {
    // Subscribe to recipient's online status
    _presenceService.subscribeToUserStatus(widget.recipientId, 'teacher').listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
    
    // Periodically refresh online status (every 30 seconds)
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (mounted) {
        final isOnline = await _presenceService.isUserOnline(widget.recipientId, 'teacher');
        if (mounted) {
          setState(() {
            _isOnline = isOnline;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _chatService.unsubscribeAll();
    _presenceService.unsubscribeFromUser(widget.recipientId, 'teacher');
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

  void _setupRealtimeSubscriptions() {
    // Subscribe to new messages
    _chatService.subscribeToMessages(widget.conversationId);
    _chatService.onMessage.listen((message) {
      if (mounted) {
        // Check if message already exists to prevent duplicates
        final messageId = message['id'];
        final exists = _messages.any((m) => m['id'] == messageId);
        
        if (!exists) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
          _markMessagesAsRead();
        }
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
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    final messages = await _chatService.getMessages(widget.conversationId);
    
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.conversationId);
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

  void _onTyping() {
    _chatService.updateTypingIndicator(widget.conversationId, true);
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTypingIndicator(widget.conversationId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    setState(() => _isSending = true);
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
        // Don't add to local state - let realtime subscription handle it
        // to avoid duplicates
        _scrollToBottom();
      } else {
        _showError('Failed to send message');
      }
    } catch (e) {
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
      // Send voice message
      setState(() => _isSending = true);
      
      try {
        final message = await _chatService.sendVoiceMessage(
          conversationId: widget.conversationId,
          audioFile: result.file!,
          durationSeconds: result.duration,
        );

        if (message != null) {
          _scrollToBottom();
        } else {
          _showError('Failed to send voice message');
        }
      } catch (e) {
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
      final date = DateTime.parse(timestamp);
      return DateFormat.jm().format(date);
    } catch (e) {
      return '';
    }
  }

  String _formatMessageDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
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
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.recipientAvatar != null
                  ? NetworkImage(widget.recipientAvatar!)
                  : null,
              backgroundColor: Colors.white,
              child: widget.recipientAvatar == null
                  ? Text(
                      widget.recipientName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.greenAccent : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _currentUserId;
                          final showDateSeparator = _shouldShowDateSeparator(index);

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
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Icon(Icons.attach_file, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFile!.path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _selectedFile = null);
                    },
                  ),
                ],
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final hasAttachment = message['has_attachment'] == true;
    final attachments = message['attachments'] as List?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasAttachment && attachments != null && attachments.isNotEmpty)
              ...attachments.map((attachment) => _buildAttachment(Map<String, dynamic>.from(attachment as Map), isMe)),
            if (message['message_text'] != null && message['message_text'].toString().isNotEmpty)
              Text(
                message['message_text'],
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message['created_at']),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(Map<String, dynamic> attachment, bool isMe) {
    final fileName = attachment['file_name'] ?? 'File';
    final fileType = attachment['file_type'] ?? '';
    final fileUrl = attachment['file_url'] ?? '';
    final attachmentType = attachment['attachment_type'] ?? 'file';
    final durationSeconds = attachment['duration_seconds'] as int?;
    final messageId = attachment['message_id'] as String;

    // Voice message player
    if (attachmentType == 'voice') {
      return _buildVoiceMessagePlayer(messageId, fileUrl, durationSeconds ?? 0, isMe);
    }

    // Image attachment - display inline
    if (attachmentType == 'image' || _isImageFile(fileType)) {
      return GestureDetector(
        onTap: () => _showFullImage(fileUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMe ? Colors.deepPurple : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              fileUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 8),
                      Text('Failed to load image', style: TextStyle(color: Colors.grey[600])),
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
      onTap: () async {
        if (fileUrl.isNotEmpty) {
          final uri = Uri.parse(fileUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple[700] : Colors.grey[400],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(fileType),
              color: isMe ? Colors.white : Colors.black87,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 13,
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
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessagePlayer(String messageId, String audioUrl, int durationSeconds, bool isMe) {
    // Create player if it doesn't exist and initialize it
    if (!_audioPlayers.containsKey(messageId)) {
      final newPlayer = AudioPlayer();
      _audioPlayers[messageId] = newPlayer;
      // Pre-load the audio source
      newPlayer.setUrl(audioUrl).catchError((e) {
        print('Error loading audio: $e');
      });
    }
    
    final player = _audioPlayers[messageId]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? Colors.deepPurple[700] : Colors.grey[400],
        borderRadius: BorderRadius.circular(16),
      ),
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

              return IconButton(
                icon: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: isMe ? Colors.white : Colors.black87,
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
                constraints: const BoxConstraints(),
              );
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: StreamBuilder<Duration?>(
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
                        backgroundColor: isMe ? Colors.deepPurple[800] : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? Colors.white : Colors.deepPurple,
                        ),
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
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
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.attach_file;
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
              decoration: BoxDecoration(
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
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _cancelRecording,
              tooltip: 'Cancel',
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _stopRecording,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      );
    }

    // Normal input UI
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
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
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _isSending ? null : _pickFile,
            color: Colors.deepPurple,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _onTyping();
                }
              },
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          if (_messageController.text.isEmpty && !_isSending)
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: _startRecording,
              color: Colors.deepPurple,
              tooltip: 'Voice message',
            )
          else
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
            ),
        ],
      ),
    );
  }
}

