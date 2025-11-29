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
  final _messageUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatRequestController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageUpdate => _messageUpdateController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdate => _conversationUpdateController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onChatRequest => _chatRequestController.stream;

  /// Get or create conversation with a teacher
  Future<Map<String, dynamic>?> getOrCreateConversation(String teacherId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if student has active subscription with this teacher
      final subscriptions = await _supabase
          .from('student_subscriptions')
          .select()
          .eq('student_id', userId)
          .eq('teacher_id', teacherId)
          .eq('status', 'active')
          .limit(1);

      if (subscriptions.isEmpty) {
        throw Exception('You must have an active subscription with this teacher to chat');
      }

      // Check if conversation exists (get all to clean up duplicates)
      final conversations = await _supabase
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
          .order('created_at', ascending: true);
      
      Map<String, dynamic>? conversation;
      
      if (conversations.isNotEmpty) {
        // Keep the first (oldest) conversation
        conversation = conversations.first;
        
        // If conversation was deleted by student, undelete it
        if (conversation['deleted_by_student'] == true) {
          await _supabase
              .from('chat_conversations')
              .update({
                'deleted_by_student': false,
                'student_deleted_at': null,
              })
              .eq('id', conversation['id']);
          
          // Refresh conversation data
          conversation = await _supabase
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
              .eq('id', conversation['id'])
              .single();
        }
        
        // Delete duplicates if they exist
        if (conversations.length > 1) {
          print('Found ${conversations.length} duplicate conversations, cleaning up...');
          final duplicateIds = conversations.skip(1).map((c) => c['id']).toList();
          for (var id in duplicateIds) {
            try {
              await _supabase
                  .from('chat_conversations')
                  .delete()
                  .eq('id', id);
            } catch (deleteError) {
              print('Error deleting duplicate conversation $id: $deleteError');
            }
          }
        }
      } else {
        // Create conversation if it doesn't exist
        try {
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
        } catch (insertError) {
          // If insert fails (maybe duplicate was created by another request), try fetching again
          print('Insert failed, fetching conversation again: $insertError');
          final retryConversations = await _supabase
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
              .order('created_at', ascending: true)
              .limit(1);
          
          if (retryConversations.isNotEmpty) {
            conversation = retryConversations.first;
            
            // If this conversation was deleted by student, undelete it
            if (conversation['deleted_by_student'] == true) {
              await _supabase
                  .from('chat_conversations')
                  .update({
                    'deleted_by_student': false,
                    'student_deleted_at': null,
                  })
                  .eq('id', conversation['id']);
              
              // Refresh conversation data
              conversation = await _supabase
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
                  .eq('id', conversation['id'])
                  .single();
            }
          } else {
            rethrow;
          }
        }
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
          .eq('deleted_by_student', false)
          .order('last_message_at', ascending: false);

      // Deduplicate conversations with the same student_id and teacher_id
      final seenPairs = <String>{};
      final uniqueConversations = <Map<String, dynamic>>[];

      for (var conv in conversations) {
        final studentId = conv['student_id'];
        final teacherId = conv['teacher_id'];
        final participant2Id = conv['participant2_id'];
        
        String key;
        if (teacherId != null) {
          // Teacher-student conversation
          key = 'teacher:$studentId-$teacherId';
        } else if (participant2Id != null) {
          // Student-student conversation (normalize the key so A-B and B-A are the same)
          final ids = [studentId, participant2Id]..sort();
          key = 'student:${ids[0]}-${ids[1]}';
        } else {
          continue;
        }

        if (!seenPairs.contains(key)) {
          seenPairs.add(key);
          uniqueConversations.add(conv);
        }
      }

      return uniqueConversations;
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

      // Deduplicate teachers by ID
      final seenTeacherIds = <String>{};
      final uniqueTeachers = <Map<String, dynamic>>[];

      for (var sub in subscriptions) {
        final teacher = sub['teacher'];
        if (teacher == null) continue;
        
        final teacherId = teacher['id'] as String;
        
        // Skip if we've already seen this teacher
        if (seenTeacherIds.contains(teacherId)) continue;
        
        seenTeacherIds.add(teacherId);
        uniqueTeachers.add({
          ...teacher,
          'unread_count': conversationMap[teacherId] ?? 0,
        });
      }

      return uniqueTeachers;
    } catch (e) {
      print('Error fetching available teachers: $e');
      return [];
    }
  }

  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get conversation to check deletion timestamp
      final conversation = await _supabase
          .from('chat_conversations')
          .select('student_id, participant2_id, student_deleted_at, teacher_deleted_at, conversation_type')
          .eq('id', conversationId)
          .maybeSingle();

      if (conversation == null) return [];

      // Determine the user's deletion timestamp based on their role in the conversation
      DateTime? deletedAt;
      if (conversation['conversation_type'] == 'teacher_student') {
        // For teacher-student chats, student always uses student_deleted_at
        deletedAt = conversation['student_deleted_at'] != null
            ? DateTime.parse(conversation['student_deleted_at'])
            : null;
      } else {
        // For student-student chats, check if user is student_id or participant2_id
        if (conversation['student_id'] == userId) {
          deletedAt = conversation['student_deleted_at'] != null
              ? DateTime.parse(conversation['student_deleted_at'])
              : null;
        } else if (conversation['participant2_id'] == userId) {
          // participant2 uses teacher_deleted_at
          deletedAt = conversation['teacher_deleted_at'] != null
              ? DateTime.parse(conversation['teacher_deleted_at'])
              : null;
        }
      }

      var query = _supabase
          .from('chat_messages')
          .select('''
            *,
            attachments:chat_attachments (*)
          ''')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null);

      // Only show messages created after the deletion timestamp
      if (deletedAt != null) {
        query = query.gt('created_at', deletedAt.toIso8601String());
      }

      final messages = await query
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

      // Update conversation preview
      try {
        final extension = path.extension(file.path).toLowerCase();
        final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension);
        final previewText = messageText.isNotEmpty ? messageText : (isImage ? '📷 Photo' : '📎 Attachment');
        
        await _supabase.from('chat_conversations').update({
          'last_message': previewText,
          'last_message_at': DateTime.now().toIso8601String(),
          'has_attachment': true,
        }).eq('id', conversationId);
      } catch (e) {
        print('Error updating conversation preview: $e');
      }

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

      // Update conversation preview
      try {
        final previewText = (messageText != null && messageText.isNotEmpty) ? messageText : '🎤 Voice Message';
        await _supabase.from('chat_conversations').update({
          'last_message': previewText,
          'last_message_at': DateTime.now().toIso8601String(),
          'has_attachment': true,
        }).eq('id', conversationId);
      } catch (e) {
        print('Error updating conversation preview: $e');
      }

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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            // Just emit the new record, UI should merge it or we can fetch full if needed
            // For read status updates, the new record is enough
            _messageUpdateController.add(payload.newRecord);
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
        // Listen for updates where student is the primary participant
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
        // Listen for inserts where student is the primary participant
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
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
        // Listen for updates where student is participant2 (student-to-student chats)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
            value: userId,
          ),
          callback: (payload) {
            _conversationUpdateController.add(payload.newRecord);
          },
        )
        // Listen for inserts where student is participant2 (student-to-student chats)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
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
      // Get the chat request details first
      final request = await _supabase
          .from('chat_requests')
          .select()
          .eq('id', requestId)
          .single();
      
      final requesterId = request['requester_id'] as String;
      final recipientId = request['recipient_id'] as String;
      
      // Update the request status to accepted
      await _supabase
          .from('chat_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);
      
      // Create the conversation immediately so both students can see it
      // Check if conversation already exists
      final existingConversations = await _supabase
          .from('chat_conversations')
          .select()
          .eq('conversation_type', 'student_student')
          .or('and(student_id.eq.$requesterId,participant2_id.eq.$recipientId),and(student_id.eq.$recipientId,participant2_id.eq.$requesterId)')
          .limit(1);
      
      if (existingConversations.isEmpty) {
        // Create new conversation
        await _supabase
            .from('chat_conversations')
            .insert({
              'student_id': requesterId,
              'participant2_id': recipientId,
              'conversation_type': 'student_student',
            });
      }
      
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

      // Check if accepted chat request exists (in either direction)
      final requests = await _supabase
          .from('chat_requests')
          .select()
          .or('and(requester_id.eq.$userId,recipient_id.eq.$otherStudentId),and(requester_id.eq.$otherStudentId,recipient_id.eq.$userId)')
          .eq('status', 'accepted')
          .limit(1);

      if (requests.isEmpty) {
        throw Exception('No accepted chat request found');
      }

      // Check if conversation exists (in either direction)
      final conversations = await _supabase
          .from('chat_conversations')
          .select('''
            *,
            peer:participant2_id (
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
            )
          ''')
          .eq('conversation_type', 'student_student')
          .or('and(student_id.eq.$userId,participant2_id.eq.$otherStudentId),and(student_id.eq.$otherStudentId,participant2_id.eq.$userId)')
          .order('created_at', ascending: true)
          .limit(1);
      
      var conversation = conversations.isNotEmpty ? conversations.first : null;

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
      } else {
        // If conversation was deleted by current user, undelete it
        final isStudent1 = conversation['student_id'] == userId;
        final isStudent2 = conversation['participant2_id'] == userId;
        
        bool needsUpdate = false;
        Map<String, dynamic> updates = {};
        
        if (isStudent1 && conversation['deleted_by_student'] == true) {
          updates['deleted_by_student'] = false;
          updates['student_deleted_at'] = null;
          needsUpdate = true;
        } else if (isStudent2 && conversation['deleted_by_teacher'] == true) {
          // For participant2, the deleted flag is stored in deleted_by_teacher
          updates['deleted_by_teacher'] = false;
          updates['teacher_deleted_at'] = null;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await _supabase
              .from('chat_conversations')
              .update(updates)
              .eq('id', conversation['id']);
          
          // Refresh conversation data
          conversation = await _supabase
              .from('chat_conversations')
              .select('''
                *,
                peer:participant2_id (
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
                )
              ''')
              .eq('id', conversation['id'])
              .single();
        }
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
    _messageUpdateController.close();
    _conversationUpdateController.close();
    _typingController.close();
    _chatRequestController.close();
  }
}

