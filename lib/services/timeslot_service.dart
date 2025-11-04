import 'package:supabase_flutter/supabase_flutter.dart';

class TimeslotService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get available timeslots for a teacher on specific days
  /// Returns only slots that are available (enabled by teacher) and not occupied
  Future<Map<int, List<Map<String, dynamic>>>> getAvailableTimeslots({
    required String teacherId,
    List<int>? specificDays,
  }) async {
    try {
      var query = _supabase
          .from('teacher_timeslots')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_available', true)
          .eq('is_occupied', false);

      if (specificDays != null && specificDays.isNotEmpty) {
        query = query.inFilter('day_of_week', specificDays);
      }
      
      final response = await query.order('day_of_week').order('start_time');
      var slots = List<Map<String, dynamic>>.from(response);

      // Filter out reserved slots (unless reservation expired)
      final now = DateTime.now();
      slots = slots.where((slot) {
        if (slot['reserved_until'] == null) return true;
        final reservedUntil = DateTime.parse(slot['reserved_until']);
        return reservedUntil.isBefore(now); // Include if reservation expired
      }).toList();

      // Group by day_of_week
      final Map<int, List<Map<String, dynamic>>> groupedSlots = {};
      
      for (var slot in slots) {
        final day = slot['day_of_week'] as int;
        if (!groupedSlots.containsKey(day)) {
          groupedSlots[day] = [];
        }
        groupedSlots[day]!.add(slot);
      }

      return groupedSlots;
    } catch (e) {
      print('Error fetching available timeslots: $e');
      throw Exception('Failed to load available timeslots');
    }
  }

  /// Get common timeslots across multiple days
  /// Returns only slots that exist and are available on ALL specified days
  Future<List<Map<String, String>>> getCommonTimeslots({
    required String teacherId,
    required List<int> days,
  }) async {
    try {
      if (days.isEmpty) return [];

      final allSlots = await getAvailableTimeslots(
        teacherId: teacherId,
        specificDays: days,
      );

      if (allSlots.isEmpty) return [];

      // Find slots that appear on all selected days
      final commonSlots = <Map<String, String>>[];
      
      // Get slots from first day as baseline
      final firstDaySlots = allSlots[days.first] ?? [];
      
      for (var slot in firstDaySlots) {
        final startTime = slot['start_time'] as String;
        final endTime = slot['end_time'] as String;
        
        // Check if this time exists on all other days
        bool existsOnAllDays = true;
        
        for (var day in days.skip(1)) {
          final daySlots = allSlots[day] ?? [];
          final hasMatchingSlot = daySlots.any((s) =>
              s['start_time'] == startTime && s['end_time'] == endTime);
          
          if (!hasMatchingSlot) {
            existsOnAllDays = false;
            break;
          }
        }
        
        if (existsOnAllDays) {
          commonSlots.add({
            'start_time': startTime,
            'end_time': endTime,
          });
        }
      }

      return commonSlots;
    } catch (e) {
      print('Error finding common timeslots: $e');
      throw Exception('Failed to find common timeslots');
    }
  }

  /// Get days that have available timeslots for a teacher
  Future<List<int>> getDaysWithAvailableSlots(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_timeslots')
          .select('day_of_week')
          .eq('teacher_id', teacherId)
          .eq('is_available', true)
          .eq('is_occupied', false);

      final slots = List<Map<String, dynamic>>.from(response);
      final days = slots.map((s) => s['day_of_week'] as int).toSet().toList();
      days.sort();
      
      return days;
    } catch (e) {
      print('Error fetching days with available slots: $e');
      throw Exception('Failed to load available days');
    }
  }

  /// Check if a specific timeslot is available for booking
  Future<bool> isTimeslotAvailable({
    required String teacherId,
    required int dayOfWeek,
    required String startTime,
  }) async {
    try {
      final response = await _supabase
          .from('teacher_timeslots')
          .select()
          .eq('teacher_id', teacherId)
          .eq('day_of_week', dayOfWeek)
          .eq('start_time', startTime)
          .eq('is_available', true)
          .eq('is_occupied', false)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking timeslot availability: $e');
      return false;
    }
  }

  /// Mark timeslots as occupied when subscription is created
  /// This should be called from backend/admin, but added for reference
  Future<void> markTimeslotsOccupied({
    required String teacherId,
    required String subscriptionId,
    required List<int> days,
    required String startTime,
    required String endTime,
  }) async {
    try {
      // Call the database function
      await _supabase.rpc('mark_timeslots_occupied', params: {
        'p_teacher_id': teacherId,
        'p_subscription_id': subscriptionId,
        'p_days': days,
        'p_start_time': startTime,
        'p_end_time': endTime,
      });
    } catch (e) {
      print('Error marking timeslots as occupied: $e');
      throw Exception('Failed to mark timeslots as occupied');
    }
  }

  /// Release timeslots when subscription ends
  /// This should be called from backend/admin
  Future<void> releaseTimeslots(String subscriptionId) async {
    try {
      await _supabase.rpc('release_timeslots', params: {
        'p_subscription_id': subscriptionId,
      });
    } catch (e) {
      print('Error releasing timeslots: $e');
      throw Exception('Failed to release timeslots');
    }
  }

  /// Get timeslot statistics for a teacher (for admin/teacher app)
  Future<Map<String, dynamic>> getTimeslotStats(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_timeslots')
          .select()
          .eq('teacher_id', teacherId);

      final slots = List<Map<String, dynamic>>.from(response);
      
      return {
        'total': slots.length,
        'available': slots.where((s) => s['is_available'] == true && s['is_occupied'] == false).length,
        'disabled': slots.where((s) => s['is_available'] == false).length,
        'occupied': slots.where((s) => s['is_occupied'] == true).length,
      };
    } catch (e) {
      print('Error fetching timeslot stats: $e');
      throw Exception('Failed to load timeslot statistics');
    }
  }
}


