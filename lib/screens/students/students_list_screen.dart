import 'package:flutter/material.dart';
import 'package:student/services/student_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/screens/students/student_public_profile_screen.dart';
import 'package:student/screens/chat/chat_requests_screen.dart';
import 'package:student/screens/chat/chat_conversation_screen.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _studentService = StudentService();
  final _chatService = ChatService();
  List<Map<String, dynamic>> _students = [];
  List<String> _myLanguages = [];
  List<Map<String, dynamic>> _sentRequests = [];
  Map<String, String> _chatRequestStatus = {}; // studentId -> status
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Get languages the current student is learning
      final languages = await _studentService.getStudentLanguages();
      
      if (languages.isEmpty) {
        if (mounted) {
          setState(() {
            _myLanguages = [];
            _students = [];
            _isLoading = false;
            _errorMessage = 'You need to enroll in a course to see other students';
          });
        }
        return;
      }

      // Get students learning the same languages
      final students = await _studentService.getStudentsInSameLanguages();
      
      // Get sent chat requests to check status
      final sentRequests = await _chatService.getSentChatRequests();
      
      // Build status map
      final statusMap = <String, String>{};
      for (var request in sentRequests) {
        final recipientData = request['recipient'];
        if (recipientData != null) {
          final recipientId = recipientData['id'] as String;
          statusMap[recipientId] = request['status'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _myLanguages = languages;
          _students = students;
          _sentRequests = sentRequests;
          _chatRequestStatus = statusMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load students: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _sendChatRequest(String recipientId, String recipientName) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send chat request to $recipientName?'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Optional message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) {},
          controller: TextEditingController(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final controller = (context as Element).findAncestorStateOfType<State>();
              Navigator.pop(context, '');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final success = await _chatService.sendChatRequest(recipientId, message: result.isEmpty ? null : result);

    if (mounted) {
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request sent!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _openChat(String studentId, String studentName) async {
    // Try to get/create conversation
    final conversation = await _chatService.getOrCreateStudentConversation(studentId);
    
    if (conversation != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatConversationScreen(
            conversationId: conversation['id'],
            recipientId: studentId,
            recipientName: studentName,
            recipientAvatar: null,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start chat. Make sure request is accepted.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fellow Students'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mail),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatRequestsScreen(),
                ),
              );
              _loadStudents();
            },
            tooltip: 'Chat Requests',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No other students found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Be the first in your language!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStudents,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.teal.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connect with Fellow Learners',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_students.length} student${_students.length != 1 ? 's' : ''} learning your languages',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Students List
                          ...(_students.map((student) => _buildStudentCard(student))),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final languages = student['languages'] as List<Map<String, dynamic>>? ?? [];
    final province = student['province'] as Map<String, dynamic>?;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentPublicProfileScreen(
                studentId: student['id'],
                studentData: student,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.shade300,
                    Colors.teal.shade600,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: student['avatar_url'] != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: student['avatar_url'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => _buildDefaultAvatar(student['full_name']),
                      ),
                    )
                  : _buildDefaultAvatar(student['full_name']),
            ),
            const SizedBox(width: 16),

            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['full_name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student['email'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (province != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${province['name']} (${province['name_ar']})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (languages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: languages.map((language) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (language['flag_url'] != null)
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: language['flag_url'],
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.language, size: 16),
                                  ),
                                )
                              else
                                const Icon(Icons.language, size: 16, color: Colors.teal),
                              const SizedBox(width: 4),
                              Text(
                                language['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Chat Button
            const SizedBox(width: 8),
            _buildChatButton(student),
          ],
        ),
      ),
      ),
    );
  }
  
  Widget _buildChatButton(Map<String, dynamic> student) {
    final studentId = student['id'] as String;
    final studentName = student['full_name'] as String?  ?? 'Student';
    final status = _chatRequestStatus[studentId];
    
    if (status == 'accepted') {
      // Can chat
      return IconButton(
        icon: const Icon(Icons.chat, color: Colors.green),
        onPressed: () => _openChat(studentId, studentName),
        tooltip: 'Chat',
      );
    } else if (status == 'pending') {
      // Request sent, waiting
      return const Chip(
        label: Text('Pending', style: TextStyle(fontSize: 11)),
        backgroundColor: Colors.orange,
        labelStyle: TextStyle(color: Colors.white),
        padding: EdgeInsets.symmetric(horizontal: 8),
      );
    } else {
      // Can send request
      return IconButton(
        icon: const Icon(Icons.person_add, color: Colors.deepPurple),
        onPressed: () => _sendChatRequest(studentId, studentName),
        tooltip: 'Send Chat Request',
      );
    }
  }

  Widget _buildDefaultAvatar(String? fullName) {
    final initial = (fullName?.isNotEmpty ?? false) 
        ? fullName![0].toUpperCase() 
        : '?';
    
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

