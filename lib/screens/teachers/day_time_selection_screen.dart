import 'package:flutter/material.dart';
import 'package:student/services/teacher_service.dart';

class DayTimeSelectionScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String languageId;
  final String languageName;
  final String packageId;
  final String packageName;
  final double amount;
  final int sessionsPerWeek;
  final int durationMinutes;

  const DayTimeSelectionScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.languageId,
    required this.languageName,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.sessionsPerWeek,
    required this.durationMinutes,
  });

  @override
  State<DayTimeSelectionScreen> createState() => _DayTimeSelectionScreenState();
}

class _DayTimeSelectionScreenState extends State<DayTimeSelectionScreen> {
  final _teacherService = TeacherService();
  
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  
  // Selected days (0 = Sunday, 6 = Saturday)
  Set<int> _selectedDays = {};
  
  // Available time slots grouped by day
  Map<int, List<Map<String, String>>> _availableTimeSlots = {};
  
  // Selected time slot
  String? _selectedStartTime;
  String? _selectedEndTime;
  
  int _currentStep = 0; // 0 = Select Days, 1 = Select Time

  final List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadTeacherSchedule();
  }

  Future<void> _loadTeacherSchedule() async {
    setState(() => _isLoading = true);
    
    try {
      final teacherData = await _teacherService.getTeacherWithSchedule(widget.teacherId);
      
      if (teacherData != null) {
        final schedules = teacherData['schedules'] as List<Map<String, dynamic>>? ?? [];
        
        // Process schedules and group by day
        _processSchedules(schedules);
        
        setState(() {
          _teacher = teacherData;
          _schedules = schedules;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schedule: $e')),
        );
      }
    }
  }

  void _processSchedules(List<Map<String, dynamic>> schedules) {
    _availableTimeSlots.clear();
    
    for (var schedule in schedules) {
      if (schedule['is_available'] == true) {
        final dayOfWeek = schedule['day_of_week'] as int;
        final startTime = schedule['start_time'] as String;
        final endTime = schedule['end_time'] as String;
        
        // Generate time slots based on package duration
        final slots = _generateTimeSlotsFromRange(startTime, endTime, widget.durationMinutes);
        
        if (!_availableTimeSlots.containsKey(dayOfWeek)) {
          _availableTimeSlots[dayOfWeek] = [];
        }
        
        _availableTimeSlots[dayOfWeek]!.addAll(slots);
      }
    }
  }

  List<Map<String, String>> _generateTimeSlotsFromRange(String startTime, String endTime, int durationMinutes) {
    final slots = <Map<String, String>>[];
    
    // Parse start and end times
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);
    
    // Convert to minutes since midnight
    var currentMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    
    // Generate slots
    while (currentMinutes + durationMinutes <= endMinutes) {
      final slotStartHour = currentMinutes ~/ 60;
      final slotStartMinute = currentMinutes % 60;
      
      final slotEndMinutes = currentMinutes + durationMinutes;
      final slotEndHour = slotEndMinutes ~/ 60;
      final slotEndMinute = slotEndMinutes % 60;
      
      slots.add({
        'start_time': '${slotStartHour.toString().padLeft(2, '0')}:${slotStartMinute.toString().padLeft(2, '0')}:00',
        'end_time': '${slotEndHour.toString().padLeft(2, '0')}:${slotEndMinute.toString().padLeft(2, '0')}:00',
      });
      
      // Move to next slot (30 min intervals for flexibility)
      currentMinutes += 30;
    }
    
    return slots;
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  bool _canProceedToTimeSelection() {
    return _selectedDays.length >= widget.sessionsPerWeek;
  }

  void _proceedToTimeSelection() {
    if (!_canProceedToTimeSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least ${widget.sessionsPerWeek} days'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _currentStep = 1;
    });
  }

  void _selectTimeSlot(String startTime, String endTime) {
    setState(() {
      _selectedStartTime = startTime;
      _selectedEndTime = endTime;
    });
  }

  void _proceedToPayment() {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to payment submission with selected days and time
    Navigator.pushNamed(
      context,
      '/payment-submission',
      arguments: {
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherName,
        'packageId': widget.packageId,
        'packageName': widget.packageName,
        'languageId': widget.languageId,
        'languageName': widget.languageName,
        'amount': widget.amount,
        'selectedDays': _selectedDays.toList(),
        'selectedStartTime': _selectedStartTime,
        'selectedEndTime': _selectedEndTime,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Schedule'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                
                // Content
                Expanded(
                  child: _currentStep == 0
                      ? _buildDaySelection()
                      : _buildTimeSelection(),
                ),
                
                // Bottom button
                _buildBottomButton(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.deepPurple.shade100,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildProgressStep(1, 'Select Days', _currentStep >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1 ? Colors.deepPurple : Colors.grey.shade300,
            ),
          ),
          _buildProgressStep(2, 'Select Time', _currentStep >= 1),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.deepPurple : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.deepPurple : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelection() {
    // Get available days from teacher's schedule
    final availableDays = _availableTimeSlots.keys.toList()..sort();
    
    if (availableDays.length < widget.sessionsPerWeek) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              Text(
                'Teacher needs at least ${widget.sessionsPerWeek} days available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This teacher only has ${availableDays.length} days available for this ${widget.sessionsPerWeek}x/week package.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select at least ${widget.sessionsPerWeek} days for your classes',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedDays.length}/7 days (need ${widget.sessionsPerWeek})',
            style: TextStyle(
              fontSize: 14,
              color: _selectedDays.length >= widget.sessionsPerWeek ? Colors.green : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Package: ${widget.sessionsPerWeek}x/week, ${widget.durationMinutes} min sessions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          ...availableDays.map((day) {
            final isSelected = _selectedDays.contains(day);
            final timeSlots = _availableTimeSlots[day]!;
            
            return Card(
              elevation: isSelected ? 4 : 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => _toggleDay(day),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                            width: 2,
                          ),
                          color: isSelected ? Colors.deepPurple : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayNames[day],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.deepPurple : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${timeSlots.length} time slot${timeSlots.length > 1 ? 's' : ''} available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeSelection() {
    // Get common time slots available for all selected days
    List<Map<String, String>> commonTimeSlots = [];
    
    if (_selectedDays.isNotEmpty) {
      // Start with first selected day's slots
      final firstDay = _selectedDays.first;
      commonTimeSlots = List.from(_availableTimeSlots[firstDay] ?? []);
      
      // Find intersection with other days
      for (var day in _selectedDays.skip(1)) {
        final daySlots = _availableTimeSlots[day] ?? [];
        commonTimeSlots.retainWhere((slot) {
          return daySlots.any((daySlot) =>
              daySlot['start_time'] == slot['start_time'] &&
              daySlot['end_time'] == slot['end_time']);
        });
      }
    }

    if (commonTimeSlots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text(
                'No common time slots',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The selected days don\'t have any overlapping time slots. Please go back and select different days.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Day Selection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your preferred time slot',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This ${widget.durationMinutes}-minute slot will be used for all selected days',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected days: ${_selectedDays.map((d) => _dayNames[d]).join(', ')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          ...commonTimeSlots.map((slot) {
            final startTime = slot['start_time']!;
            final endTime = slot['end_time']!;
            final isSelected = _selectedStartTime == startTime && _selectedEndTime == endTime;
            
            return Card(
              elevation: isSelected ? 4 : 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => _selectTimeSlot(startTime, endTime),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                            width: 2,
                          ),
                          color: isSelected ? Colors.deepPurple : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: isSelected ? Colors.deepPurple : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(startTime),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.deepPurple : Colors.black87,
                              ),
                            ),
                            Text(
                              ' - ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatTime(endTime),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.deepPurple : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep == 1)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.deepPurple),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep == 1) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _currentStep == 0
                  ? (_canProceedToTimeSelection() ? _proceedToTimeSelection : null)
                  : (_selectedStartTime != null ? _proceedToPayment : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                _currentStep == 0 ? 'Continue' : 'Proceed to Payment',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    // Format time from "HH:MM:SS" to "HH:MM AM/PM"
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    
    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }
}

