import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  
  // Public getter for supabase client
  SupabaseClient get supabase => _supabase;
  
  // Realtime subscriptions
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _chatRequestsChannel;
  
  // Stream controllers
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatRequestController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdate => _conversationUpdateController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onChatRequest => _chatRequestController.stream;

  /// Get or create conversation with a teacher
  Future<Map<String, dynamic>?> getOrCreateConversation(String teacherId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if student has active subscription with this teacher
      final subscription = await _supabase
          .from('student_subscriptions')
          .select()
          .eq('student_id', userId)
          .eq('teacher_id', teacherId)
          .eq('status', 'active')
          .maybeSingle();

      if (subscription == null) {
        throw Exception('You must have an active subscription with this teacher to chat');
      }

      // Check if conversation exists
      var conversation = await _supabase
          .from('chat_conversations')
          .select('''
            *,
            teacher:teacher_id (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('student_id', userId)
          .eq('teacher_id', teacherId)
          .maybeSingle();

      // Create conversation if it doesn't exist
      if (conversation == null) {
        final newConversation = await _supabase
            .from('chat_conversations')
            .insert({
              'student_id': userId,
              'teacher_id': teacherId,
            })
            .select('''
              *,
              teacher:teacher_id (
                id,
                full_name,
                avatar_url,
                email
              )
            ''')
            .single();
        
        conversation = newConversation;
      }

      return conversation;
    } catch (e) {
      print('Error getting/creating conversation: $e');
      return null;
    }
  }

  /// Get all conversations for current student (both teacher and peer chats)
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final conversations = await _supabase
          .from('chat_conversations')
          .select('''
            *,
            teacher:teacher_id (
              id,
              full_name,
              avatar_url,
              email
            ),
            student:student_id (
              id,
              full_name,
              avatar_url,
              email
            ),
            peer:participant2_id (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .or('student_id.eq.$userId,participant2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(conversations);
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  /// Get teachers that student can chat with (has active subscription)
  Future<List<Map<String, dynamic>>> getAvailableTeachers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get all active subscriptions
      final subscriptions = await _supabase
          .from('student_subscriptions')
          .select('''
            teacher_id,
            teacher:teacher_id (
              id,
              full_name,
              avatar_url,
              email,
              bio
            )
          ''')
          .eq('student_id', userId)
          .eq('status', 'active');

      // Get existing conversations
      final conversations = await _supabase
          .from('chat_conversations')
          .select('teacher_id, student_unread_count')
          .eq('student_id', userId);

      final conversationMap = {
        for (var conv in conversations)
          conv['teacher_id']: conv['student_unread_count'] ?? 0
      };

      // Combine teacher data with unread counts
      final teachers = subscriptions
          .where((sub) => sub['teacher'] != null)
          .map((sub) {
        final teacher = sub['teacher'] as Map<String, dynamic>;
        return {
          ...teacher,
          'unread_count': conversationMap[teacher['id']] ?? 0,
        };
      }).toList();

      return teachers;
    } catch (e) {
      print('Error fetching available teachers: $e');
      return [];
    }
  }

  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    try {
      final messages = await _supabase
          .from('chat_messages')
          .select('''
            *,
            attachments:chat_attachments (*)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(messages).reversed.toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a text message
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String messageText,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final message = await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'sender_type': 'student',
            'message_text': messageText,
            'has_attachment': false,
          })
          .select('''
            *,
            attachments:chat_attachments (*)
          ''')
          .single();

      return message;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  /// Send a message with attachment
  Future<Map<String, dynamic>?> sendMessageWithAttachment({
    required String conversationId,
    required String messageText,
    required File file,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Upload file to storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final filePath = '$userId/$fileName';
      
      await _supabase.storage
          .from('chat-attachments')
          .upload(filePath, file);

      final fileUrl = _supabase.storage
          .from('chat-attachments')
          .getPublicUrl(filePath);

      // Create message
      final message = await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'sender_type': 'student',
            'message_text': messageText,
            'has_attachment': true,
          })
          .select()
          .single();

      // Create attachment record
      await _supabase
          .from('chat_attachments')
          .insert({
            'message_id': message['id'],
            'file_name': path.basename(file.path),
            'file_url': fileUrl,
            'file_type': path.extension(file.path).replaceAll('.', ''),
            'file_size': await file.length(),
          });

      // Fetch complete message with attachments
      final completeMessage = await _supabase
          .from('chat_messages')
          .select('''
            *,
            attachments:chat_attachments (*)
          ''')
          .eq('id', message['id'])
          .single();

      return completeMessage;
    } catch (e) {
      print('Error sending message with attachment: $e');
      return null;
    }
  }

  /// Pick and upload file
  Future<File?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  /// Send voice message
  Future<Map<String, dynamic>?> sendVoiceMessage({
    required String conversationId,
    required File audioFile,
    required int durationSeconds,
    String? messageText,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Upload audio file to storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_voice.m4a';
      final filePath = '$userId/$fileName';
      
      await _supabase.storage
          .from('chat-attachments')
          .upload(filePath, audioFile);

      final fileUrl = _supabase.storage
          .from('chat-attachments')
          .getPublicUrl(filePath);

      // Create message
      final message = await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'sender_type': 'student',
            'message_text': messageText ?? '',
            'has_attachment': true,
          })
          .select()
          .single();

      // Create voice attachment record
      await _supabase
          .from('chat_attachments')
          .insert({
            'message_id': message['id'],
            'file_name': 'Voice Message',
            'file_url': fileUrl,
            'file_type': 'm4a',
            'file_size': await audioFile.length(),
            'attachment_type': 'voice',
            'duration_seconds': durationSeconds,
          });

      // Fetch complete message with attachments
      final completeMessage = await _supabase
          .from('chat_messages')
          .select('''
            *,
            attachments:chat_attachments (*)
          ''')
          .eq('id', message['id'])
          .single();

      return completeMessage;
    } catch (e) {
      print('Error sending voice message: $e');
      return null;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio
  Future<AudioRecorder?> startRecording() async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final recorder = AudioRecorder();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.start(const RecordConfig(), path: filePath);
      return recorder;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  /// Stop recording and get file
  Future<({File? file, int duration})?> stopRecording(AudioRecorder recorder, DateTime startTime) async {
    try {
      final path = await recorder.stop();
      final duration = DateTime.now().difference(startTime).inSeconds;
      
      if (path != null) {
        return (file: File(path), duration: duration);
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  /// Cancel recording
  Future<void> cancelRecording(AudioRecorder recorder) async {
    try {
      await recorder.cancel();
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.rpc('mark_messages_as_read', params: {
        'p_conversation_id': conversationId,
        'p_user_id': userId,
      });

      await _supabase.rpc('reset_unread_count', params: {
        'p_conversation_id': conversationId,
        'p_user_id': userId,
        'p_user_type': 'student',
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Update typing indicator
  Future<void> updateTypingIndicator(String conversationId, bool isTyping) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('typing_indicators')
          .upsert({
            'conversation_id': conversationId,
            'user_id': userId,
            'user_type': 'student',
            'is_typing': isTyping,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'conversation_id,user_id');
    } catch (e) {
      print('Error updating typing indicator: $e');
    }
  }

  /// Subscribe to realtime messages for a conversation
  void subscribeToMessages(String conversationId) {
    _messagesChannel?.unsubscribe();
    
    _messagesChannel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            // Fetch complete message with attachments
            final message = await _supabase
                .from('chat_messages')
                .select('''
                  *,
                  attachments:chat_attachments (*)
                ''')
                .eq('id', payload.newRecord['id'])
                .single();
            
            _messageController.add(message);
          },
        )
        .subscribe();
  }

  /// Subscribe to realtime conversation updates
  void subscribeToConversations() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _conversationsChannel?.unsubscribe();
    
    _conversationsChannel = _supabase
        .channel('conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: userId,
          ),
          callback: (payload) {
            _conversationUpdateController.add(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Subscribe to typing indicators for a conversation
  void subscribeToTyping(String conversationId) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _typingChannel?.unsubscribe();
    
    _typingChannel = _supabase
        .channel('typing:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            // Only emit if it's not the current user typing
            if (payload.newRecord['user_id'] != userId) {
              _typingController.add(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  /// Get students who have taken the same course
  Future<List<Map<String, dynamic>>> getStudentsInSameCourse() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get students who have subscriptions to the same languages
      final students = await _supabase
          .from('student_subscriptions')
          .select('''
            student:student_id (
              id,
              full_name,
              avatar_url,
              email,
              level
            )
          ''')
          .eq('status', 'active')
          .neq('student_id', userId);

      // Get my languages
      final myLanguages = await _supabase
          .from('student_subscriptions')
          .select('language_id')
          .eq('student_id', userId)
          .eq('status', 'active');

      final myLanguageIds = myLanguages.map((l) => l['language_id']).toSet();

      // Filter students who share at least one language
      final filteredStudents = <Map<String, dynamic>>[];
      final seenStudents = <String>{};

      for (var record in students) {
        if (record['student'] == null) continue;
        
        final student = record['student'] as Map<String, dynamic>;
        final studentId = student['id'] as String;
        
        if (seenStudents.contains(studentId)) continue;
        
        // Check if this student shares a language
        final studentLanguages = await _supabase
            .from('student_subscriptions')
            .select('language_id')
            .eq('student_id', studentId)
            .eq('status', 'active');
        
        final hasSharedLanguage = studentLanguages.any(
          (l) => myLanguageIds.contains(l['language_id'])
        );
        
        if (hasSharedLanguage) {
          seenStudents.add(studentId);
          filteredStudents.add(student);
        }
      }

      return filteredStudents;
    } catch (e) {
      print('Error fetching students in same course: $e');
      return [];
    }
  }

  /// Send chat request to another student
  Future<Map<String, dynamic>?> sendChatRequest(String recipientId, {String? message}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final request = await _supabase
          .from('chat_requests')
          .insert({
            'requester_id': userId,
            'recipient_id': recipientId,
            if (message != null) 'message': message,
            'status': 'pending',
          })
          .select()
          .single();

      return request;
    } catch (e) {
      print('Error sending chat request: $e');
      return null;
    }
  }

  /// Get pending chat requests (received)
  Future<List<Map<String, dynamic>>> getPendingChatRequests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final requests = await _supabase
          .from('chat_requests')
          .select('''
            *,
            requester:requester_id (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('recipient_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      print('Error fetching pending chat requests: $e');
      return [];
    }
  }

  /// Get sent chat requests
  Future<List<Map<String, dynamic>>> getSentChatRequests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final requests = await _supabase
          .from('chat_requests')
          .select('''
            *,
            recipient:recipient_id (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('requester_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      print('Error fetching sent chat requests: $e');
      return [];
    }
  }

  /// Accept chat request
  Future<bool> acceptChatRequest(String requestId) async {
    try {
      await _supabase
          .from('chat_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);
      return true;
    } catch (e) {
      print('Error accepting chat request: $e');
      return false;
    }
  }

  /// Reject chat request
  Future<bool> rejectChatRequest(String requestId) async {
    try {
      await _supabase
          .from('chat_requests')
          .delete()
          .eq('id', requestId);
      return true;
    } catch (e) {
      print('Error rejecting chat request: $e');
      return false;
    }
  }

  /// Get or create conversation with another student
  Future<Map<String, dynamic>?> getOrCreateStudentConversation(String otherStudentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if accepted chat request exists
      final request = await _supabase
          .from('chat_requests')
          .select()
          .or('requester_id.eq.$userId,recipient_id.eq.$userId')
          .or('requester_id.eq.$otherStudentId,recipient_id.eq.$otherStudentId')
          .eq('status', 'accepted')
          .maybeSingle();

      if (request == null) {
        throw Exception('No accepted chat request found');
      }

      // Check if conversation exists
      var conversation = await _supabase
          .from('chat_conversations')
          .select('''
            *,
            peer:participant2_id (
              id,
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('conversation_type', 'student_student')
          .or('student_id.eq.$userId,participant2_id.eq.$userId')
          .or('student_id.eq.$otherStudentId,participant2_id.eq.$otherStudentId')
          .maybeSingle();

      if (conversation == null) {
        // Create conversation
        final newConversation = await _supabase
            .from('chat_conversations')
            .insert({
              'student_id': userId,
              'participant2_id': otherStudentId,
              'conversation_type': 'student_student',
            })
            .select('''
              *,
              peer:participant2_id (
                id,
                full_name,
                avatar_url,
                email
              )
            ''')
            .single();

        conversation = newConversation;
      }

      return conversation;
    } catch (e) {
      print('Error getting/creating student conversation: $e');
      return null;
    }
  }

  /// Subscribe to chat requests
  void subscribeToChatRequests() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatRequestsChannel?.unsubscribe();
    
    _chatRequestsChannel = _supabase
        .channel('chat_requests:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            _chatRequestController.add(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Unsubscribe from all realtime channels
  void unsubscribeAll() {
    _messagesChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _chatRequestsChannel?.unsubscribe();
  }

  /// Dispose
  void dispose() {
    unsubscribeAll();
    _messageController.close();
    _conversationUpdateController.close();
    _typingController.close();
    _chatRequestController.close();
  }
}

