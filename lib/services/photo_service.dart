import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class PhotoService {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Get all photos for a student
  Future<List<Map<String, dynamic>>> getStudentPhotos(String studentId) async {
    try {
      final photos = await _supabase
          .from('student_photos')
          .select()
          .eq('student_id', studentId)
          .order('is_main', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(photos);
    } catch (e) {
      print('Error fetching student photos: $e');
      return [];
    }
  }

  /// Upload and add photo (convenience method)
  Future<Map<String, dynamic>?> uploadAndAddPhoto(
    File photoFile,
    String studentId, {
    bool setAsMain = false,
  }) async {
    return await uploadPhoto(
      studentId: studentId,
      photoFile: photoFile,
      setAsMain: setAsMain,
    );
  }

  /// Upload a new photo
  Future<Map<String, dynamic>?> uploadPhoto({
    required String studentId,
    required File photoFile,
    bool setAsMain = false,
  }) async {
    try {
      // If setting as main, unset other photos first
      if (setAsMain) {
        await _supabase
            .from('student_photos')
            .update({'is_main': false})
            .eq('student_id', studentId);
      }

      // Upload to storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photoFile.path)}';
      final filePath = '$studentId/$fileName';

      await _supabase.storage
          .from('student-photos')
          .upload(filePath, photoFile);

      final photoUrl = _supabase.storage
          .from('student-photos')
          .getPublicUrl(filePath);

      // Create photo record
      final photo = await _supabase
          .from('student_photos')
          .insert({
            'student_id': studentId,
            'photo_url': photoUrl,
            'is_main': setAsMain,
          })
          .select()
          .single();

      return photo;
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  /// Set a photo as main (signature matches usage in edit_profile_screen)
  Future<bool> setMainPhoto(String studentId, String photoId) async {
    try {
      // Unset all other photos as main
      await _supabase
          .from('student_photos')
          .update({'is_main': false})
          .eq('student_id', studentId);

      // Set this photo as main
      await _supabase
          .from('student_photos')
          .update({'is_main': true})
          .eq('id', photoId);

      return true;
    } catch (e) {
      print('Error setting main photo: $e');
      return false;
    }
  }

  /// Delete a photo (signature matches usage in edit_profile_screen)
  Future<bool> deletePhoto(String studentId, String photoId, String photoUrl) async {
    try {
      // Delete from storage
      final storagePathMatch = RegExp(r'student-photos/(.+)').firstMatch(photoUrl);
      if (storagePathMatch != null) {
        final storagePath = storagePathMatch.group(1);
        if (storagePath != null) {
          await _supabase.storage
              .from('student-photos')
              .remove([storagePath]);
        }
      }

      // Delete record
      await _supabase
          .from('student_photos')
          .delete()
          .eq('id', photoId)
          .eq('student_id', studentId);

      return true;
    } catch (e) {
      print('Error deleting photo: $e');
      return false;
    }
  }

  /// Get current user's photos
  Future<List<Map<String, dynamic>>> getMyPhotos() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      return await getStudentPhotos(userId);
    } catch (e) {
      print('Error fetching my photos: $e');
      return [];
    }
  }

  /// Get main photo for a student
  Future<Map<String, dynamic>?> getMainPhoto(String studentId) async {
    try {
      final photos = await _supabase
          .from('student_photos')
          .select()
          .eq('student_id', studentId)
          .eq('is_main', true)
          .limit(1);

      if (photos.isNotEmpty) {
        return photos[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching main photo: $e');
      return null;
    }
  }
}

