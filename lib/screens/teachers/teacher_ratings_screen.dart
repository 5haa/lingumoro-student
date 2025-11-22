import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../services/rating_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_back_button.dart';

class TeacherRatingsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? teacherAvatar;

  const TeacherRatingsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.teacherAvatar,
  });

  @override
  State<TeacherRatingsScreen> createState() => _TeacherRatingsScreenState();
}

class _TeacherRatingsScreenState extends State<TeacherRatingsScreen> {
  final _ratingService = RatingService();
  final _authService = AuthService();
  
  Map<String, dynamic>? _ratingStats;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myRating;
  bool _canRate = false;
  bool _isLoading = true;
  
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _ratingService.getTeacherRatingStats(widget.teacherId),
        _ratingService.getTeacherRatings(widget.teacherId),
        _ratingService.canRateTeacher(currentUser.id, widget.teacherId),
      ]);

      final ratingStats = results[0] as Map<String, dynamic>?;
      final reviews = results[1] as List<Map<String, dynamic>>;
      final canRate = results[2] as bool;

      Map<String, dynamic>? myRating;
      if (canRate) {
        myRating = await _ratingService.getStudentRating(
          currentUser.id,
          widget.teacherId,
        );
      }

      setState(() {
        _ratingStats = ratingStats;
        _reviews = reviews;
        _canRate = canRate;
        _myRating = myRating;
        
        if (_myRating != null) {
          _selectedRating = _myRating!['rating'] as int;
          _commentController.text = _myRating!['comment'] as String? ?? '';
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await _ratingService.submitRating(
        studentId: currentUser.id,
        teacherId: widget.teacherId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty 
            ? null 
            : _commentController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Rating submitted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _loadData(); // Reload to show updated rating
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit rating. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          
                          // Rating Stats Summary
                          if (_ratingStats != null)
                            _buildRatingStatsSummary(),
                          
                          const SizedBox(height: 16),
                          
                          // Rate/Update Section (if can rate)
                          if (_canRate) ...[
                            _buildRatingInput(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Reviews List
                          _buildReviewsList(),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CustomBackButton(onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          
          // Teacher Avatar
          if (widget.teacherAvatar != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.teacherAvatar!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.lightGrey,
                    child: const Icon(Icons.person, size: 18, color: AppColors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.lightGrey,
                    child: const Icon(Icons.person, size: 18, color: AppColors.grey),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightGrey,
              ),
              child: const Icon(Icons.person, size: 18, color: AppColors.grey),
            ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacherName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStatsSummary() {
    final averageRating = (_ratingStats!['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalRatings = _ratingStats!['total_ratings'] as int? ?? 0;
    final fiveStarCount = _ratingStats!['five_star_count'] as int? ?? 0;
    final fourStarCount = _ratingStats!['four_star_count'] as int? ?? 0;
    final threeStarCount = _ratingStats!['three_star_count'] as int? ?? 0;
    final twoStarCount = _ratingStats!['two_star_count'] as int? ?? 0;
    final oneStarCount = _ratingStats!['one_star_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with rating
          Row(
            children: [
              // Large average rating
              Column(
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      if (index < averageRating.floor()) {
                        return const Icon(Icons.star, color: Colors.amber, size: 16);
                      } else if (index < averageRating) {
                        return const Icon(Icons.star_half, color: Colors.amber, size: 16);
                      } else {
                        return Icon(Icons.star_border, color: Colors.grey.shade300, size: 16);
                      }
                    }),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalRatings ${totalRatings == 1 ? 'Rating' : 'Ratings'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 20),
              
              // Star breakdown
              Expanded(
                child: Column(
                  children: [
                    _buildCompactStarBar(5, fiveStarCount, totalRatings),
                    const SizedBox(height: 4),
                    _buildCompactStarBar(4, fourStarCount, totalRatings),
                    const SizedBox(height: 4),
                    _buildCompactStarBar(3, threeStarCount, totalRatings),
                    const SizedBox(height: 4),
                    _buildCompactStarBar(2, twoStarCount, totalRatings),
                    const SizedBox(height: 4),
                    _buildCompactStarBar(1, oneStarCount, totalRatings),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStarBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            '$stars',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(
          Icons.star,
          size: 12,
          color: Colors.amber,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.lightGrey,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 20,
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _myRating != null ? 'Update Your Rating' : 'Rate This Teacher',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Star selector - more compact
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: _isSubmitting ? null : () {
                  setState(() => _selectedRating = starValue);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    _selectedRating >= starValue ? Icons.star : Icons.star_border,
                    color: _selectedRating >= starValue 
                        ? Colors.amber 
                        : AppColors.grey.withOpacity(0.3),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          
          if (_selectedRating > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getRatingText(_selectedRating),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Comment field - more compact
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 300,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Share your experience (optional)',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                counterStyle: TextStyle(fontSize: 11),
              ),
            ),
          ),
          
          const SizedBox(height: 14),
          
          // Submit button - more compact
          SizedBox(
            width: double.infinity,
            height: 46,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _myRating != null ? 'UPDATE RATING' : 'SUBMIT RATING',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rate_review,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Student Reviews',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        if (_reviews.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 40,
                    color: AppColors.grey.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to share your experience!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              return _buildReviewCard(_reviews[index]);
            },
          ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;
    final student = review['students'] as Map<String, dynamic>?;
    final studentName = student?['full_name'] as String? ?? 'Anonymous';
    final avatarUrl = student?['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarUrl == null ? AppColors.lightGrey : null,
                ),
                child: avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.lightGrey,
                            child: const Icon(Icons.person, color: AppColors.grey, size: 20),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.lightGrey,
                            child: const Icon(Icons.person, color: AppColors.grey, size: 20),
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: AppColors.grey, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: index < rating ? Colors.amber : AppColors.grey.withOpacity(0.3),
                    size: 15,
                  );
                }),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks}w ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '${months}mo ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '${years}y ago';
      }
    } catch (e) {
      return '';
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
