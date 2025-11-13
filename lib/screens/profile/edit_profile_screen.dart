import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/photo_service.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_back_button.dart';

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
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['full_name'] ?? '');
    _emailController = TextEditingController(text: widget.profile['email'] ?? '');
    _bioController = TextEditingController(text: widget.profile['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      setState(() => _isUploadingPhoto = true);

      final file = await _photoService.pickImage(source: ImageSource.gallery);
      if (file == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      setState(() {
        _selectedImage = file;
        _isUploadingPhoto = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final studentId = _authService.currentUser?.id;
      if (studentId == null) throw Exception('Not logged in');

      String? avatarUrl;
      
      // Upload avatar if selected
      if (_selectedImage != null) {
        // Upload as main photo and get URL
        final photo = await _photoService.uploadAndAddPhoto(
          _selectedImage!,
          studentId,
          setAsMain: true,
        );
        if (photo != null) {
          avatarUrl = photo['photo_url'] as String?;
        }
      }

      // Update profile
      await _authService.updateProfile(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
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
    final avatarUrl = widget.profile['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'EDIT PROFILE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 45),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Picture
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: AppColors.redGradient,
                              shape: BoxShape.circle,
                            ),
                            child: _selectedImage != null
                                ? ClipOval(
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : avatarUrl != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Center(
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppColors.redGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.white, width: 3),
                                ),
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Full Name
                      CustomTextField(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        controller: _nameController,
                        prefixIcon: const Icon(
                          FontAwesomeIcons.user,
                          size: 18,
                          color: AppColors.grey,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email
                      CustomTextField(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: false, // Email is usually not editable
                        prefixIcon: const Icon(
                          FontAwesomeIcons.envelope,
                          size: 18,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 20, bottom: 8),
                            child: Text(
                              'Bio',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _bioController,
                              maxLines: 4,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tell us about yourself...',
                                hintStyle: const TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.white,
                                contentPadding: const EdgeInsets.all(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Save Button
                      CustomButton(
                        text: 'SAVE CHANGES',
                        onPressed: _isLoading ? () {} : _saveProfile,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
