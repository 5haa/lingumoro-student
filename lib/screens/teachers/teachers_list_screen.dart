import 'package:flutter/material.dart';
import 'package:student/services/language_service.dart';
import 'package:student/services/rating_service.dart';
import 'package:student/screens/teachers/teacher_detail_screen.dart';
import 'package:student/widgets/rating_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TeachersListScreen extends StatefulWidget {
  final String languageId;
  final String languageName;

  const TeachersListScreen({
    super.key,
    required this.languageId,
    required this.languageName,
  });

  @override
  State<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends State<TeachersListScreen> {
  final _languageService = LanguageService();
  final _ratingService = RatingService();
  List<Map<String, dynamic>> _teachers = [];
  Map<String, Map<String, dynamic>> _teacherRatings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final teacherLanguages = await _languageService.getTeachersForLanguage(widget.languageId);
      print('Teachers response: $teacherLanguages');
      print('Number of teachers: ${teacherLanguages.length}');
      
      // Load ratings for each teacher
      final ratings = <String, Map<String, dynamic>>{};
      for (var teacherData in teacherLanguages) {
        final teacher = teacherData['teachers'] ?? teacherData['teacher'] ?? teacherData;
        if (teacher != null && teacher['id'] != null) {
          final ratingStats = await _ratingService.getTeacherRatingStats(teacher['id']);
          if (ratingStats != null) {
            ratings[teacher['id']] = ratingStats;
          }
        }
      }
      
      setState(() {
        _teachers = teacherLanguages;
        _teacherRatings = ratings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading teachers: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.languageName} Teachers'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teachers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Teachers Available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No teachers found for ${widget.languageName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeachers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _teachers.length,
                    itemBuilder: (context, index) {
                      final teacherData = _teachers[index];
                      print('Teacher data at index $index: $teacherData');
                      
                      // Handle both possible data structures
                      final teacher = teacherData['teachers'] ?? teacherData['teacher'] ?? teacherData;
                      
                      if (teacher == null || teacher['full_name'] == null) {
                        print('Skipping invalid teacher data');
                        return const SizedBox.shrink();
                      }
                      
                      return _buildTeacherCard(teacher);
                    },
                  ),
                ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
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
              builder: (context) => TeacherDetailScreen(
                teacherId: teacher['id'],
                languageId: widget.languageId,
                languageName: widget.languageName,
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
              Hero(
                tag: 'teacher_${teacher['id']}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.shade100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: teacher['avatar_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: teacher['avatar_url'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.deepPurple.shade100,
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.deepPurple,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.deepPurple.shade100,
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.deepPurple,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.deepPurple.shade700,
                          ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Teacher Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher['full_name'] ?? 'Teacher',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (teacher['specialization'] != null)
                      Text(
                        teacher['specialization'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Rating Display
                    if (_teacherRatings.containsKey(teacher['id']))
                      RatingDisplay(
                        averageRating: (_teacherRatings[teacher['id']]!['average_rating'] as num?)?.toDouble() ?? 0.0,
                        totalRatings: (_teacherRatings[teacher['id']]!['total_ratings'] as int?) ?? 0,
                        compact: true,
                      ),
                    if (teacher['bio'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        teacher['bio'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

