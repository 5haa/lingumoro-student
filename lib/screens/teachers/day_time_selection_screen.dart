import 'package:flutter/material.dart';
import 'package:student/services/timeslot_service.dart';
import 'package:student/screens/payment/payment_submission_screen.dart';

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
  final _timeslotService = TimeslotService();
  
  Map<int, List<Map<String, dynamic>>> _availableTimeslots = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  Set<int> _selectedDays = {};
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
    _loadAvailableTimeslots();
  }

  Future<void> _loadAvailableTimeslots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final slots = await _timeslotService.getAvailableTimeslots(
        teacherId: widget.teacherId,
      );
      
      setState(() {
        _availableTimeslots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading available timeslots: ${e.toString()}';
        _isLoading = false;
      });
    }
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSubmissionScreen(
          teacherId: widget.teacherId,
          teacherName: widget.teacherName,
          packageId: widget.packageId,
          packageName: widget.packageName,
          languageId: widget.languageId,
          languageName: widget.languageName,
          amount: widget.amount,
          selectedDays: _selectedDays.toList(),
          selectedStartTime: _selectedStartTime,
          selectedEndTime: _selectedEndTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Days & Time'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadAvailableTimeslots,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
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
                  ],
                ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Select Days', Icons.calendar_today),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1 ? Colors.deepPurple : Colors.grey.shade300,
            ),
          ),
          _buildStepIndicator(1, 'Select Time', Icons.access_time),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? Colors.deepPurple : Colors.grey.shade300,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive || isCompleted ? Colors.deepPurple : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelection() {
    final availableDays = _availableTimeslots.keys.toList()..sort();
    
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
            final timeSlots = _availableTimeslots[day]!;
            
            return Card(
              elevation: isSelected ? 4 : 1,
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
                            color: isSelected ? Colors.deepPurple : Colors.grey,
                            width: 2,
                          ),
                          color: isSelected ? Colors.deepPurple : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                              '${timeSlots.length} available 30-min slots',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: isSelected ? Colors.deepPurple : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceedToTimeSelection() ? _proceedToTimeSelection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Continue to Time Selection',
                style: TextStyle(
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

  Widget _buildTimeSelection() {
    return FutureBuilder<List<Map<String, String>>>(
      future: _timeslotService.getCommonTimeslots(
        teacherId: widget.teacherId,
        days: _selectedDays.toList(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading timeslots',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }
        
        final commonSlots = snapshot.data ?? [];
        
        if (commonSlots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.orange.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No common time slots available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The selected days don\'t have any matching available time slots. Please select different days.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentStep = 0);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Change Days'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return _buildTimeSelectionContent(commonSlots);
      },
    );
  }

  Widget _buildTimeSelectionContent(List<Map<String, String>> commonSlots) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your preferred time slot',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This 30-minute slot will be used for all selected days',
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
                    'Selected days: ${_selectedDays.map((d) => _dayNames[d]).join(", ")}',
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
          
          ...commonSlots.map((slot) {
            final startTime = slot['start_time']!;
            final endTime = slot['end_time']!;
            final isSelected = _selectedStartTime == startTime && _selectedEndTime == endTime;
            
            return Card(
              elevation: isSelected ? 4 : 1,
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: isSelected ? Colors.deepPurple : Colors.grey[600],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.deepPurple : Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple,
                          ),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _selectedStartTime = null;
                      _selectedEndTime = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Days',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedStartTime != null ? _proceedToPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    
    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }
}


