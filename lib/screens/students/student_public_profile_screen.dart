import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/widgets/student_avatar_widget.dart';
import 'package:student/services/photo_service.dart';

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
  List<Map<String, dynamic>> _photos = [];
  bool _isLoadingPhotos = true;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
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

  @override
  Widget build(BuildContext context) {
    final languages = widget.studentData['languages'] as List<Map<String, dynamic>>? ?? [];
    final province = widget.studentData['province'] as Map<String, dynamic>?;
    final bio = widget.studentData['bio'] as String?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with student header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.teal,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade400,
                      Colors.teal.shade700,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Profile picture carousel
                      _buildPhotoCarousel(),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        widget.studentData['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Province
                      if (province != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${province['name']} (${province['name_ar']})',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Information Card
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.email,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Email',
                          widget.studentData['email'] ?? 'Not provided',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio Section
                  if (bio != null && bio.isNotEmpty)
                    _buildSectionCard(
                      title: 'About',
                      icon: Icons.person,
                      child: Text(
                        bio,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (bio != null && bio.isNotEmpty) const SizedBox(height: 16),

                  // Languages Section
                  if (languages.isNotEmpty)
                    _buildSectionCard(
                      title: 'Learning Languages',
                      icon: Icons.language,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: languages.map((language) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade50,
                                  Colors.teal.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.teal.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (language['flag_url'] != null)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: language['flag_url'],
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.language,
                                          size: 20,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.language,
                                    size: 20,
                                    color: Colors.teal,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  language['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Note about connecting
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You can connect with this student because you\'re both learning the same language!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.teal.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final initial = (widget.studentData['full_name']?.isNotEmpty ?? false)
        ? widget.studentData['full_name']![0].toUpperCase()
        : '?';

    return Container(
      color: Colors.teal.shade600,
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
        width: 120,
        height: 120,
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
      // Show default avatar if no photos
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: _buildDefaultAvatar(),
        ),
      );
    }

    return Column(
      children: [
        // Photo viewer with gestures
        GestureDetector(
          onTap: () => _showFullScreenPhoto(),
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              // Swiped right - previous photo
              _previousPhoto();
            } else if (details.primaryVelocity! < 0) {
              // Swiped left - next photo
              _nextPhoto();
            }
          },
          child: Hero(
            tag: 'student_${widget.studentData['id']}_photo_$_currentPhotoIndex',
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
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
        ),
        
        // Photo counter and navigation
        if (_photos.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              IconButton(
                onPressed: _previousPhoto,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                iconSize: 28,
              ),
              
              // Photo indicators
              ...List.generate(_photos.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPhotoIndex == index ? 10 : 6,
                  height: _currentPhotoIndex == index ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                );
              }),
              
              // Next button
              IconButton(
                onPressed: _nextPhoto,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
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
          studentId: widget.studentData['id'],
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
  final String studentId;

  const _FullScreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.studentName,
    required this.studentId,
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
          // Photo viewer
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
                return Hero(
                  tag: 'student_${widget.studentId}_photo_$index',
                  child: InteractiveViewer(
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
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Photo counter
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

