import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class PhotoService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Get all photos for a student
  Future<List<Map<String, dynamic>>> getStudentPhotos(String studentId) async {
    try {
      final response = await _supabase
          .from('student_photos')
          .select()
          .eq('student_id', studentId)
          .order('is_main', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student photos: $e');
      throw Exception('Failed to load photos');
    }
  }

  /// Get the main photo URL for a student
  Future<String?> getMainPhotoUrl(String studentId) async {
    try {
      final response = await _supabase
          .from('student_photos')
          .select('photo_url')
          .eq('student_id', studentId)
          .eq('is_main', true)
          .maybeSingle();

      return response?['photo_url'];
    } catch (e) {
      print('Error fetching main photo: $e');
      return null;
    }
  }

  /// Pick image from gallery or camera
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Compress the image
      final compressedFile = await _compressImage(File(image.path));
      return compressedFile;
    } catch (e) {
      print('Error picking image: $e');
      throw Exception('Failed to pick image');
    }
  }

  /// Compress image to reduce file size
  Future<File> _compressImage(File file) async {
    try {
      final dir = path.dirname(file.path);
      final filename = path.basenameWithoutExtension(file.path);
      final ext = path.extension(file.path);
      final targetPath = path.join(dir, '${filename}_compressed$ext');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 800,
        minHeight: 800,
      );

      return File(result?.path ?? file.path);
    } catch (e) {
      print('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  /// Upload photo to Supabase storage
  Future<String> uploadPhoto(File file, String studentId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = path.extension(file.path);
      final fileName = 'photo_$timestamp$ext';
      final filePath = '$studentId/$fileName';

      // Upload to Supabase storage
      await _supabase.storage
          .from('profiles')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: false));

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      throw Exception('Failed to upload photo');
    }
  }

  /// Add photo to student's photo collection
  Future<Map<String, dynamic>> addPhoto(String studentId, String photoUrl, {bool setAsMain = false}) async {
    try {
      // If setting as main, unset all other main photos first
      if (setAsMain) {
        await _supabase
            .from('student_photos')
            .update({'is_main': false})
            .eq('student_id', studentId);
      }

      // Insert new photo
      final response = await _supabase
          .from('student_photos')
          .insert({
            'student_id': studentId,
            'photo_url': photoUrl,
            'is_main': setAsMain,
          })
          .select()
          .single();

      // If this is the first photo or set as main, update the student's avatar_url
      if (setAsMain) {
        await _updateStudentAvatar(studentId, photoUrl);
      }

      return response;
    } catch (e) {
      print('Error adding photo: $e');
      throw Exception('Failed to add photo');
    }
  }

  /// Set a photo as the main profile photo
  Future<void> setMainPhoto(String studentId, String photoId) async {
    try {
      // Use database function to atomically set main photo
      // This avoids race conditions and constraint violations
      await _supabase.rpc('set_student_main_photo', params: {
        'p_student_id': studentId,
        'p_photo_id': photoId,
      });
    } catch (e) {
      print('Error setting main photo: $e');
      throw Exception('Failed to set main photo');
    }
  }

  /// Update student's avatar_url field
  Future<void> _updateStudentAvatar(String studentId, String photoUrl) async {
    await _supabase
        .from('students')
        .update({'avatar_url': photoUrl})
        .eq('id', studentId);
  }

  /// Delete a photo
  Future<void> deletePhoto(String studentId, String photoId, String photoUrl) async {
    try {
      // Check if this is the main photo
      final photo = await _supabase
          .from('student_photos')
          .select('is_main')
          .eq('id', photoId)
          .single();

      final wasMain = photo['is_main'] as bool;

      // Delete from database
      await _supabase
          .from('student_photos')
          .delete()
          .eq('id', photoId);

      // Delete from storage
      try {
        final uri = Uri.parse(photoUrl);
        final filePath = uri.path.split('/').skip(4).join('/'); // Extract path after bucket name
        await _supabase.storage.from('profiles').remove([filePath]);
      } catch (e) {
        print('Error deleting file from storage: $e');
        // Continue even if storage deletion fails
      }

      // If deleted photo was main, set another photo as main
      if (wasMain) {
        final remainingPhotos = await getStudentPhotos(studentId);
        if (remainingPhotos.isNotEmpty) {
          await setMainPhoto(studentId, remainingPhotos.first['id']);
        } else {
          // No photos left, clear avatar_url
          await _supabase
              .from('students')
              .update({'avatar_url': null})
              .eq('id', studentId);
        }
      }
    } catch (e) {
      print('Error deleting photo: $e');
      throw Exception('Failed to delete photo');
    }
  }

  /// Upload and add new photo in one step
  Future<Map<String, dynamic>> uploadAndAddPhoto(File file, String studentId, {bool setAsMain = false}) async {
    try {
      // Upload the photo
      final photoUrl = await uploadPhoto(file, studentId);
      
      // Add to database
      final photoData = await addPhoto(studentId, photoUrl, setAsMain: setAsMain);
      
      return photoData;
    } catch (e) {
      print('Error uploading and adding photo: $e');
      throw Exception('Failed to upload photo');
    }
  }
}

