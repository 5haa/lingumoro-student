import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/services/photo_service.dart';
import 'package:student/services/blocking_service.dart';
import 'package:student/l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final fullName = widget.studentData['full_name'] ?? l.user;
    final shouldBlock = !_isBlocked;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          shouldBlock ? l.blockUser : l.unblockUser,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          shouldBlock
              ? l.blockUserMessage
              : l.unblockUserMessage.replaceAll('{name}', fullName),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: const TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: shouldBlock ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(shouldBlock ? l.block : l.unblock),
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
              content: Text(
                shouldBlock
                    ? l.userBlocked
                    : l.userHasBeenUnblocked.replaceAll('{name}', fullName),
              ),
              backgroundColor: shouldBlock ? Colors.red : Colors.green,
            ),
          );
          
          if (shouldBlock) {
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shouldBlock
                    ? l.failedToBlockUserTryAgain
                    : l.failedToUnblockUser,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final languages = widget.studentData['languages'] as List<Map<String, dynamic>>? ?? [];
    final province = widget.studentData['province'] as Map<String, dynamic>?;
    final bio = widget.studentData['bio'] as String?;
    final fullName = widget.studentData['full_name'] ?? l.studentPlaceholder;
    final email = widget.studentData['email'] ?? '';
    final level = languages.isNotEmpty ? languages.length : 1;
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'ST';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Photo Carousel Section (full screen, Telegram-style)
            _buildPhotoCarouselSection(initials, fullName),
            
            const SizedBox(height: 20),
            
            // Profile Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Name and Level
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.redGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const FaIcon(
                                        FontAwesomeIcons.trophy,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${l.level} $level',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Email & Province Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
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
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const FaIcon(
                                      FontAwesomeIcons.envelope,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (province != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const FaIcon(
                                        FontAwesomeIcons.locationDot,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${province['name']} (${province['name_ar']})',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Bio Section
                  if (bio != null && bio.isNotEmpty)
                    _buildInfoCard(
                      icon: FontAwesomeIcons.circleInfo,
                      title: l.about,
                      child: Text(
                        bio,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  if (bio != null && bio.isNotEmpty) const SizedBox(height: 20),

                  // Languages Section
                  if (languages.isNotEmpty)
                    _buildInfoCard(
                      icon: FontAwesomeIcons.language,
                      title: l.languages,
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
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholderFadeInDuration: Duration.zero,
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

                  if (languages.isNotEmpty) const SizedBox(height: 32),
                ],
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

  Widget _buildPhotoCarouselSection(String initials, String fullName) {
    return Container(
      height: 450,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Photo Carousel
          if (_isLoadingPhotos)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else if (_photos.isEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _showFullScreenPhoto(),
              child: PageView.builder(
                onPageChanged: (index) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                },
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return CachedNetworkImage(
                    key: ValueKey(photo['photo_url']),
                    imageUrl: photo['photo_url'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.redGradient,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.redGradient,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Menu Button (Block/Unblock)
          if (!_isCheckingBlock)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 10,
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'block') {
                    _toggleBlock();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          FaIcon(
                            _isBlocked ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.ban,
                            color: _isBlocked ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(_isBlocked ? 'Unblock User' : 'Block User'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ),
          
          // Photo Indicators
          if (_photos.isNotEmpty && _photos.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 15,
              left: 70,
              right: 70,
              child: Row(
                children: List.generate(
                  _photos.length,
                  (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      height: 3,
                      decoration: BoxDecoration(
                        color: _currentPhotoIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreenPhoto() {
    if (_photos.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoViewer(
          photos: _photos,
          initialIndex: _currentPhotoIndex,
          studentName: widget.studentData['full_name'] ?? AppLocalizations.of(context).studentPlaceholder,
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
