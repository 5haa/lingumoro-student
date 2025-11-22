import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/services/photo_service.dart';
import 'package:student/services/blocking_service.dart';
import 'package:student/widgets/custom_back_button.dart';
import '../../config/app_colors.dart';

class StudentPublicProfileScreen extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> studentData;

  const StudentPublicProfileScreen({
    super.key,
    required this.studentId,
    required this.studentData,
  });

  @override
  State<StudentPublicProfileScreen> createState() => _StudentPublicProfileScreenState();
}

class _StudentPublicProfileScreenState extends State<StudentPublicProfileScreen> {
  final _photoService = PhotoService();
  final _blockingService = BlockingService();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoadingPhotos = true;
  int _currentPhotoIndex = 0;
  bool _isBlocked = false;
  bool _isCheckingBlock = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _checkIfBlocked();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoService.getStudentPhotos(widget.studentId);
      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoadingPhotos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPhotos = false);
      }
    }
  }

  Future<void> _checkIfBlocked() async {
    try {
      final isBlocked = await _blockingService.isUserBlocked(widget.studentId);
      if (mounted) {
        setState(() {
          _isBlocked = isBlocked;
          _isCheckingBlock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingBlock = false);
      }
    }
  }

  Future<void> _toggleBlock() async {
    final shouldBlock = !_isBlocked;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          shouldBlock ? 'Block User?' : 'Unblock User?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          shouldBlock
              ? 'Blocking this user will hide their profile and prevent them from contacting you.'
              : 'This user will be able to see your profile and contact you again.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: shouldBlock ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(shouldBlock ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = shouldBlock
          ? await _blockingService.blockUser(widget.studentId)
          : await _blockingService.unblockUser(widget.studentId);

      if (mounted) {
        if (success) {
          setState(() => _isBlocked = shouldBlock);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shouldBlock ? 'User blocked' : 'User unblocked'),
              backgroundColor: shouldBlock ? Colors.red : Colors.green,
            ),
          );
          
          if (shouldBlock) {
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to ${shouldBlock ? 'block' : 'unblock'} user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = widget.studentData['languages'] as List<Map<String, dynamic>>? ?? [];
    final province = widget.studentData['province'] as Map<String, dynamic>?;
    final bio = widget.studentData['bio'] as String?;
    final fullName = widget.studentData['full_name'] ?? 'Unknown';
    final email = widget.studentData['email'] ?? '';
    final level = languages.isNotEmpty ? languages.length : 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and menu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  if (!_isCheckingBlock)
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
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const FaIcon(
                          FontAwesomeIcons.ellipsisVertical,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'block') {
                            _toggleBlock();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                FaIcon(
                                  _isBlocked ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.ban,
                                  color: _isBlocked ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 12),
                                Text(_isBlocked ? 'Unblock User' : 'Block User'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    
                    // Profile Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppColors.redGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Photo carousel
                          _buildPhotoCarousel(),
                          const SizedBox(height: 20),
                          
                          // Name
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          // Email
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.envelope,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Province
                          if (province != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.locationDot,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${province['name']} (${province['name_ar']})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          
                          // Level badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.trophy,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Level $level',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bio Section
                    if (bio != null && bio.isNotEmpty)
                      _buildInfoCard(
                        icon: FontAwesomeIcons.circleInfo,
                        title: 'About',
                        child: Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    if (bio != null && bio.isNotEmpty) const SizedBox(height: 16),

                    // Languages Section
                    if (languages.isNotEmpty)
                      _buildInfoCard(
                        icon: FontAwesomeIcons.language,
                        title: 'Learning Languages',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: languages.map((language) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (language['flag_url'] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CachedNetworkImage(
                                        imageUrl: language['flag_url'],
                                        width: 24,
                                        height: 16,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            const FaIcon(
                                          FontAwesomeIcons.flag,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else
                                    const FaIcon(
                                      FontAwesomeIcons.flag,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    language['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.circleInfo,
                              color: Colors.blue.shade700,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'You can connect with this student because you\'re both learning the same language!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final initial = (widget.studentData['full_name']?.isNotEmpty ?? false)
        ? widget.studentData['full_name']![0].toUpperCase()
        : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    if (_isLoadingPhotos) {
      return Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(child: _buildDefaultAvatar()),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showFullScreenPhoto(),
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _previousPhoto();
            } else if (details.primaryVelocity! < 0) {
              _nextPhoto();
            }
          },
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: _photos[_currentPhotoIndex]['photo_url'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              ),
            ),
          ),
        ),
        
        if (_photos.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _previousPhoto,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.chevronLeft,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                iconSize: 28,
              ),
              
              ...List.generate(_photos.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPhotoIndex == index ? 10 : 7,
                  height: _currentPhotoIndex == index ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
              
              IconButton(
                onPressed: _nextPhoto,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                iconSize: 28,
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _previousPhoto() {
    if (_photos.isEmpty) return;
    setState(() {
      _currentPhotoIndex = (_currentPhotoIndex - 1 + _photos.length) % _photos.length;
    });
  }

  void _nextPhoto() {
    if (_photos.isEmpty) return;
    setState(() {
      _currentPhotoIndex = (_currentPhotoIndex + 1) % _photos.length;
    });
  }

  void _showFullScreenPhoto() {
    if (_photos.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoViewer(
          photos: _photos,
          initialIndex: _currentPhotoIndex,
          studentName: widget.studentData['full_name'] ?? 'Student',
        ),
      ),
    );
  }
}

// Full screen photo viewer
class _FullScreenPhotoViewer extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final String studentName;

  const _FullScreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.studentName,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.studentName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.photos[index]['photo_url'],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => const FaIcon(
                        FontAwesomeIcons.circleExclamation,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_currentIndex + 1} / ${widget.photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
