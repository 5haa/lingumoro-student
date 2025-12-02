import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/photo_service.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _photoService = PhotoService();
  final PageController _pageController = PageController();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  
  bool _isLoading = false;
  bool _isLoadingPhotos = true;
  bool _isUploadingPhoto = false;
  List<Map<String, dynamic>> _photos = [];
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['full_name'] ?? '');
    _emailController = TextEditingController(text: widget.profile['email'] ?? '');
    _bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    _loadPhotos();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoService.getMyPhotos();
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

  /// Clear cached images for old photos
  Future<void> _clearOldPhotosCache() async {
    try {
      final cacheManager = DefaultCacheManager();
      
      // Clear all current photos from cache
      for (var photo in _photos) {
        final photoUrl = photo['photo_url'] as String?;
        if (photoUrl != null) {
          await cacheManager.removeFile(photoUrl);
        }
      }
      print('🗑️ Cleared ${_photos.length} cached photos');
    } catch (e) {
      print('⚠️ Error clearing photos cache: $e');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      setState(() => _isUploadingPhoto = true);

      final file = await _photoService.pickImage(source: ImageSource.gallery);
      if (file == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final studentId = _authService.currentUser?.id;
      if (studentId == null) throw Exception('Not logged in');

      // Upload the photo
      final photo = await _photoService.uploadAndAddPhoto(
        file,
        studentId,
        setAsMain: _photos.isEmpty, // Set as main if it's the first photo
      );

      if (photo != null && mounted) {
        // Clear image cache before reloading
        await _clearOldPhotosCache();
        await _loadPhotos(); // Reload photos
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photoAddedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      setState(() => _isUploadingPhoto = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).failedToUploadPhoto} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setAsMainPhoto(String photoId) async {
    try {
      final studentId = _authService.currentUser?.id;
      if (studentId == null) return;

      final success = await _photoService.setMainPhoto(studentId, photoId);
      if (success && mounted) {
        // Clear image cache before reloading
        await _clearOldPhotosCache();
        await _loadPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).mainPhotoUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).failedToSetMainPhoto} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePhoto(String photoId, String photoUrl) async {
    try {
      final studentId = _authService.currentUser?.id;
      if (studentId == null) return;

      // Clear the deleted photo from cache
      final cacheManager = DefaultCacheManager();
      await cacheManager.removeFile(photoUrl);

      final success = await _photoService.deletePhoto(studentId, photoId, photoUrl);
      if (success && mounted) {
        await _loadPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photoDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).failedToDeletePhoto} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      // Update profile info
      await _authService.updateProfile(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profileUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).failedToUpdateProfile} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.profile['full_name'] ?? 'Student';
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'ST';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Photo Carousel Section with Add Button
            Stack(
              clipBehavior: Clip.none, // Allow button to overflow
              children: [
                _buildPhotoCarouselSection(initials),
                
                // Add Photo Button (fixed position relative to carousel)
                Positioned(
                  bottom: -28, // Half of button height (56/2 = 28) extends below carousel
                  right: 20,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isUploadingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name
                    CustomTextField(
                      labelText: AppLocalizations.of(context).fullName,
                      hintText: AppLocalizations.of(context).enterFullName,
                      controller: _nameController,
                      prefixIcon: const Icon(
                        FontAwesomeIcons.user,
                        size: 18,
                        color: AppColors.grey,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context).pleaseEnterYourName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email
                    CustomTextField(
                      labelText: AppLocalizations.of(context).email,
                      hintText: AppLocalizations.of(context).enterEmail,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                      prefixIcon: const Icon(
                        FontAwesomeIcons.envelope,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bio
                    CustomTextField(
                      labelText: AppLocalizations.of(context).bio,
                      hintText: AppLocalizations.of(context).tellUsAboutYourself,
                      controller: _bioController,
                      maxLines: 4,
                      prefixIcon: const Icon(
                        FontAwesomeIcons.info,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    CustomButton(
                      text: AppLocalizations.of(context).save.toUpperCase(),
                      onPressed: _isLoading ? () {} : _saveProfile,
                      isLoading: _isLoading,
                    ),
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
  
  Widget _buildPhotoCarouselSection(String initials) {
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
              behavior: HitTestBehavior.opaque,
              child: PageView.builder(
                controller: _pageController,
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
          
          // Photo Indicators
          if (_photos.isNotEmpty)
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
          
          // Three Dots Menu
          if (_photos.isNotEmpty && _currentPhotoIndex < _photos.length)
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
                  final photo = _photos[_currentPhotoIndex];
                  if (value == 'set_main') {
                    _setAsMainPhoto(photo['id']);
                  } else if (value == 'delete') {
                    _deletePhoto(photo['id'], photo['photo_url']);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final photo = _photos[_currentPhotoIndex];
                  return [
                    if (!(photo['is_main'] ?? false))
                      PopupMenuItem<String>(
                        value: 'set_main',
                        child: Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.solidStar, color: AppColors.primary, size: 18),
                            const SizedBox(width: 12),
                            const Text('Set as Main Photo'),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          const Text('Delete Photo', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ),
          
          // Main Badge
          if (_photos.isNotEmpty && 
              _currentPhotoIndex < _photos.length && 
              (_photos[_currentPhotoIndex]['is_main'] ?? false))
            Positioned(
              bottom: 20,
              left: 20,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.solidStar, color: Colors.amber, size: 20),
                ),
              ),
            ),
          
        ],
      ),
    );
  }
}
