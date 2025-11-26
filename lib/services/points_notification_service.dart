import 'package:flutter/material.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service to handle points notifications and real-time updates
class PointsNotificationService {
  final _supabase = Supabase.instance.client;
  final _levelService = LevelService();
  final _preloadService = PreloadService();
  
  // Realtime subscription for points changes
  RealtimeChannel? _pointsChannel;
  
  // Stream controller for points updates
  final _pointsUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPointsUpdate => _pointsUpdateController.stream;
  
  // Singleton pattern
  static final PointsNotificationService _instance = PointsNotificationService._internal();
  factory PointsNotificationService() => _instance;
  PointsNotificationService._internal();

  /// Subscribe to real-time points updates for a student
  void subscribeToPointsUpdates(String studentId, BuildContext context) {
    // Unsubscribe from any existing channel
    _pointsChannel?.unsubscribe();
    
    // Subscribe to student table updates
    _pointsChannel = _supabase
        .channel('points_updates_$studentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'students',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: studentId,
          ),
          callback: (payload) {
            _handlePointsUpdate(payload, context);
          },
        )
        .subscribe();
  }

  /// Handle points update from realtime subscription
  void _handlePointsUpdate(PostgresChangePayload payload, BuildContext context) {
    try {
      final oldRecord = payload.oldRecord;
      final newRecord = payload.newRecord;
      
      if (oldRecord == null || newRecord == null) return;
      
      final oldPoints = oldRecord['points'] as int? ?? 0;
      final newPoints = newRecord['points'] as int? ?? 0;
      final oldLevel = oldRecord['level'] as int? ?? 1;
      final newLevel = newRecord['level'] as int? ?? 1;
      
      // Check if points actually changed
      if (newPoints > oldPoints) {
        final pointsGained = newPoints - oldPoints;
        final leveledUp = newLevel > oldLevel;
        
        // Emit update event
        _pointsUpdateController.add({
          'pointsGained': pointsGained,
          'newPoints': newPoints,
          'newLevel': newLevel,
          'leveledUp': leveledUp,
          'previousLevel': oldLevel,
        });
        
        // Show notification
        if (context.mounted) {
          _showPointsNotification(
            context: context,
            pointsGained: pointsGained,
            newPoints: newPoints,
            newLevel: newLevel,
            leveledUp: leveledUp,
          );
          
          // Refresh cached profile data
          _refreshProfileData();
        }
      }
    } catch (e) {
      print('Error handling points update: $e');
    }
  }

  /// Show points earned notification as a bottom sheet or snackbar
  void _showPointsNotification({
    required BuildContext context,
    required int pointsGained,
    required int newPoints,
    required int newLevel,
    required bool leveledUp,
  }) {
    if (!context.mounted) return;
    
    if (leveledUp) {
      // Show level up dialog
      _showLevelUpDialog(
        context: context,
        newLevel: newLevel,
        pointsGained: pointsGained,
        newPoints: newPoints,
      );
    } else {
      // Show points snackbar
      _showPointsSnackbar(
        context: context,
        pointsGained: pointsGained,
        newPoints: newPoints,
      );
    }
  }

  /// Show level up dialog
  void _showLevelUpDialog({
    required BuildContext context,
    required int newLevel,
    required int pointsGained,
    required int newPoints,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon with animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Level up text
              const Text(
                '🎉 LEVEL UP! 🎉',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // New level
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level $newLevel',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Points info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '+$pointsGained Points',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: $newPoints XP',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show points earned snackbar
  void _showPointsSnackbar({
    required BuildContext context,
    required int pointsGained,
    required int newPoints,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+$pointsGained Points Earned!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total: $newPoints XP',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  /// Manually show points notification (for immediate feedback after point-earning actions)
  void showPointsEarnedNotification({
    required BuildContext context,
    required int pointsGained,
    String? message,
  }) async {
    if (!context.mounted) return;
    
    // Get current student data
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    try {
      // Wait a bit for database to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      final student = await _supabase
          .from('students')
          .select('points, level')
          .eq('id', user.id)
          .single();
      
      final newPoints = student['points'] as int? ?? 0;
      final newLevel = student['level'] as int? ?? 1;
      
      // Get cached level to check if leveled up
      final cachedProgress = _preloadService.levelProgress;
      final oldLevel = cachedProgress?['level'] as int? ?? 1;
      final leveledUp = newLevel > oldLevel;
      
      print('🎯 Points notification: +$pointsGained, New total: $newPoints, Level: $oldLevel -> $newLevel, Leveled up: $leveledUp');
      
      if (leveledUp) {
        _showLevelUpDialog(
          context: context,
          newLevel: newLevel,
          pointsGained: pointsGained,
          newPoints: newPoints,
        );
      } else {
        _showPointsSnackbar(
          context: context,
          pointsGained: pointsGained,
          newPoints: newPoints,
        );
      }
      
      // Refresh profile data
      await _refreshProfileData();
    } catch (e) {
      print('Error showing points notification: $e');
      // Fallback to simple snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? '+$pointsGained Points Earned!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      
      // Still try to refresh
      await _refreshProfileData();
    }
  }

  /// Refresh profile data in cache
  Future<void> _refreshProfileData() async {
    try {
      await _preloadService.refreshUserData();
      print('✅ Profile data refreshed after points update');
    } catch (e) {
      print('Error refreshing profile data: $e');
    }
  }

  /// Unsubscribe from points updates
  void unsubscribe() {
    _pointsChannel?.unsubscribe();
    _pointsChannel = null;
  }

  /// Dispose the service
  void dispose() {
    unsubscribe();
    _pointsUpdateController.close();
  }
}

