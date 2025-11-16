import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/language_service.dart';
import 'package:student/services/rating_service.dart';
import 'package:student/screens/teachers/teacher_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  const Text(
                    'TEACHERS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Teachers Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : _teachers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 80,
                                color: AppColors.grey.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Teachers Available',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No teachers found for ${widget.languageName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTeachers,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.1,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _teachers.length,
                              itemBuilder: (context, index) {
                                final teacherData = _teachers[index];
                                final teacher = teacherData['teachers'] ?? teacherData['teacher'] ?? teacherData;
                                
                                if (teacher == null || teacher['full_name'] == null) {
                                  return const SizedBox.shrink();
                                }
                                
                                return _buildTeacherCard(teacher);
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final teacherId = teacher['id'] as String?;
    final ratingStats = teacherId != null ? _teacherRatings[teacherId] : null;
    final averageRating = (ratingStats?['average_rating'] as num?)?.toDouble() ?? 0.0;
    
    return GestureDetector(
      onTap: () {
        if (teacherId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeacherDetailScreen(
                teacherId: teacherId,
                languageId: widget.languageId,
                languageName: widget.languageName,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Teacher Image - Left Side (Full Height)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                ),
                child: teacher['avatar_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: teacher['avatar_url'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.lightGrey,
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: AppColors.grey,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.lightGrey,
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: AppColors.grey,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 30,
                        color: AppColors.grey,
                      ),
              ),
            ),
            
            // Right Side Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Teacher Name
                    Text(
                      teacher['full_name'] ?? 'Teacher',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Star Rating
                    if (averageRating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (starIndex) {
                          if (starIndex < averageRating.floor()) {
                            return const Icon(Icons.star, color: Colors.amber, size: 14);
                          } else if (starIndex < averageRating) {
                            return const Icon(Icons.star_half, color: Colors.amber, size: 14);
                          } else {
                            return Icon(Icons.star_border, color: Colors.grey.shade300, size: 14);
                          }
                        }),
                      )
                    else
                      const SizedBox(height: 14),
                    
                    const SizedBox(height: 8),
                    
                    // Arrow Button - Centered
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.arrowRight,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
