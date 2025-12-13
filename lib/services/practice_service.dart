import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/daily_limit_service.dart';
import 'package:student/services/level_service.dart';

class PracticeService {
  final _supabase = Supabase.instance.client;
  final _dailyLimitService = DailyLimitService();
  final _levelService = LevelService();

  /// Get all practice videos for a specific language and difficulty level
  Future<List<Map<String, dynamic>>> getPracticeVideos(
      String? languageId, {int? difficultyLevel}) async {
    try {
      PostgrestFilterBuilder query = _supabase
          .from('practice_videos')
          .select()
          .eq('is_active', true);

      if (languageId != null) {
        query = query.eq('language_id', languageId);
      }

      if (difficultyLevel != null) {
        query = query.eq('difficulty_level', difficultyLevel);
      }

      final response = await query.order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching practice videos: $e');
      rethrow;
    }
  }

  /// Get videos for a specific difficulty level
  Future<List<Map<String, dynamic>>> getVideosForDifficulty(
      int difficultyLevel) async {
    return getPracticeVideos(null, difficultyLevel: difficultyLevel);
  }

  /// Get student's video progress
  Future<List<Map<String, dynamic>>> getStudentProgress(String studentId) async {
    try {
      final response = await _supabase
          .from('student_video_progress')
          .select('*, practice_videos(*)')
          .eq('student_id', studentId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching video progress: $e');
      rethrow;
    }
  }

  /// Check if a specific video is watched
  Future<bool> isVideoWatched(String studentId, String videoId) async {
    try {
      final response = await _supabase
          .from('student_video_progress')
          .select('watched')
          .eq('student_id', studentId)
          .eq('video_id', videoId)
          .maybeSingle();

      if (response == null) return false;
      return response['watched'] == true;
    } catch (e) {
      print('Error checking video watched status: $e');
      return false;
    }
  }

  /// BATCH: Get watched status for multiple videos at once
  Future<Map<String, bool>> getWatchedStatusBatch(String studentId, List<String> videoIds) async {
    try {
      if (videoIds.isEmpty) return {};
      
      final response = await _supabase
          .from('student_video_progress')
          .select('video_id, watched')
          .eq('student_id', studentId)
          .inFilter('video_id', videoIds);

      final watchedMap = <String, bool>{};
      for (var item in response) {
        watchedMap[item['video_id'] as String] = item['watched'] == true;
      }
      
      // Fill in missing videos as not watched
      for (var videoId in videoIds) {
        watchedMap.putIfAbsent(videoId, () => false);
      }
      
      return watchedMap;
    } catch (e) {
      print('Error fetching batch watched status: $e');
      return {};
    }
  }

  /// Check if student can watch a video today (daily limit)
  Future<bool> canWatchVideoToday(String studentId) async {
    return await _dailyLimitService.checkDailyLimit(
        studentId, DailyLimitService.practiceTypeVideo);
  }

  /// Mark video as watched and record daily limit
  Future<void> markVideoAsWatched(String studentId, String videoId,
      {int? pointsReward}) async {
    try {
      final existing = await _supabase
          .from('student_video_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('video_id', videoId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabase
            .from('student_video_progress')
            .update({
              'watched': true,
              'watch_percentage': 100,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('student_id', studentId)
            .eq('video_id', videoId);
      } else {
        // Insert new record
        await _supabase.from('student_video_progress').insert({
          'student_id': studentId,
          'video_id': videoId,
          'watched': true,
          'watch_percentage': 100,
          'completed_at': DateTime.now().toIso8601String(),
        });

        // Award points on first completion
        if (pointsReward != null && pointsReward > 0) {
          await _levelService.awardPoints(studentId, pointsReward);
        }
      }

      // Record daily limit
      await _dailyLimitService.recordPracticeCompletion(
          studentId, DailyLimitService.practiceTypeVideo);
    } catch (e) {
      print('Error marking video as watched: $e');
      rethrow;
    }
  }

  /// Update watch percentage
  Future<void> updateWatchPercentage(
    String studentId,
    String videoId,
    int percentage,
  ) async {
    try {
      final existing = await _supabase
          .from('student_video_progress')
          .select('id')
          .eq('student_id', studentId)
          .eq('video_id', videoId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabase
            .from('student_video_progress')
            .update({
              'watch_percentage': percentage,
            })
            .eq('student_id', studentId)
            .eq('video_id', videoId);
      } else {
        // Insert new record
        await _supabase.from('student_video_progress').insert({
          'student_id': studentId,
          'video_id': videoId,
          'watched': false,
          'watch_percentage': percentage,
        });
      }
    } catch (e) {
      print('Error updating watch percentage: $e');
      rethrow;
    }
  }

  /// Get the next unwatched video
  Future<Map<String, dynamic>?> getNextUnwatchedVideo(
    String studentId,
    String? languageId,
  ) async {
    try {
      // Get all videos
      final videos = await getPracticeVideos(languageId);
      
      if (videos.isEmpty) return null;

      // Check each video in order
      for (final video in videos) {
        final isWatched = await isVideoWatched(studentId, video['id']);
        if (!isWatched) {
          return video;
        }
      }

      // All videos watched
      return null;
    } catch (e) {
      print('Error getting next unwatched video: $e');
      rethrow;
    }
  }

  /// Check if previous video is watched (for sequential watching)
  Future<bool> canWatchVideo(
    String studentId,
    String videoId,
    List<Map<String, dynamic>> allVideos,
  ) async {
    try {
      // Find the index of the current video
      final currentIndex = allVideos.indexWhere((v) => v['id'] == videoId);
      
      if (currentIndex == -1) return false;
      if (currentIndex == 0) return true; // First video can always be watched

      // Check if previous video is watched
      final previousVideo = allVideos[currentIndex - 1];
      return await isVideoWatched(studentId, previousVideo['id']);
    } catch (e) {
      print('Error checking if can watch video: $e');
      return false;
    }
  }

  /// Get video progress for a difficulty level
  Future<Map<String, int>> getVideoProgressForLevel(
      String studentId, int difficultyLevel) async {
    try {
      final videos = await getVideosForDifficulty(difficultyLevel);
      final totalVideos = videos.length;

      if (totalVideos == 0) {
        return {'total': 0, 'completed': 0};
      }

      final videoIds = videos.map((v) => v['id'] as String).toList();
      final watchedMap =
          await getWatchedStatusBatch(studentId, videoIds);

      final completedCount =
          watchedMap.values.where((watched) => watched).length;

      return {'total': totalVideos, 'completed': completedCount};
    } catch (e) {
      print('Error getting video progress for level: $e');
      return {'total': 0, 'completed': 0};
    }
  }

  /// Check if student can unlock next difficulty level for videos
  Future<bool> canUnlockNextLevel(String studentId, int currentLevel) async {
    if (currentLevel >= 4) return false; // Already at max level

    final progress = await getVideoProgressForLevel(studentId, currentLevel);
    return progress['completed'] == progress['total'] &&
        progress['total']! > 0;
  }
}

