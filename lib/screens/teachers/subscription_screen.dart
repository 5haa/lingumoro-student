import 'package:flutter/material.dart';
import 'package:student/services/package_service.dart';
import 'package:student/services/timeslot_service.dart';
import 'package:student/screens/vouchers/course_voucher_redemption_screen.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:student/widgets/custom_button.dart';
import 'package:student/config/app_colors.dart';
import 'dart:convert';

class SubscriptionScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String languageId;
  final String languageName;

  const SubscriptionScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.languageId,
    required this.languageName,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _packageService = PackageService();
  final _timeslotService = TimeslotService();

  // State variables
  List<Map<String, dynamic>> _packages = [];
  bool _isLoadingPackages = true;
  
  int _selectedPackageIndex = -1;
  Map<String, dynamic>? _selectedPackage;
  
  List<int> _selectedDays = [];
  Map<int, List<Map<String, dynamic>>> _availableTimeslots = {};
  bool _isLoadingTimeslots = false;
  
  String? _selectedStartTime;
  String? _selectedEndTime;
  List<Map<String, String>> _commonTimeslots = [];
  bool _isLoadingCommonSlots = false;

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
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoadingPackages = true);
    try {
      final packages = await _packageService.getActivePackages();
      setState(() {
        _packages = packages;
        _isLoadingPackages = false;
      });
    } catch (e) {
      setState(() => _isLoadingPackages = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading packages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAvailableTimeslots() async {
    setState(() => _isLoadingTimeslots = true);
    try {
      final slots = await _timeslotService.getAvailableTimeslots(
        teacherId: widget.teacherId,
      );
      setState(() {
        _availableTimeslots = slots;
        _isLoadingTimeslots = false;
      });
    } catch (e) {
      setState(() => _isLoadingTimeslots = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading timeslots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCommonTimeslots() async {
    if (_selectedDays.isEmpty) return;
    
    setState(() => _isLoadingCommonSlots = true);
    try {
      final commonSlots = await _timeslotService.getCommonTimeslots(
        teacherId: widget.teacherId,
        days: _selectedDays,
      );
      setState(() {
        _commonTimeslots = commonSlots;
        _isLoadingCommonSlots = false;
      });
    } catch (e) {
      setState(() => _isLoadingCommonSlots = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading time slots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePackageSelection(int index) {
    setState(() {
      _selectedPackageIndex = index;
      _selectedPackage = _packages[index];
      _selectedDays = [];
      _selectedStartTime = null;
      _selectedEndTime = null;
      _commonTimeslots = [];
    });
    
    // Load available timeslots when package is selected
    _loadAvailableTimeslots();
  }

  void _handleDaySelection(int day) {
    if (_selectedPackage == null) return;
    
    final sessionsPerWeek = _selectedPackage!['sessions_per_week'] as int? ?? 3;
    
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
        // Clear time selection if days change
        _selectedStartTime = null;
        _selectedEndTime = null;
        _commonTimeslots = [];
      } else if (_selectedDays.length < sessionsPerWeek) {
        _selectedDays.add(day);
        // Clear time selection if days change
        _selectedStartTime = null;
        _selectedEndTime = null;
      }
    });
    
    // Load common timeslots when required number of days is selected
    if (_selectedDays.length == sessionsPerWeek) {
      _loadCommonTimeslots();
    }
  }

  void _handleTimeSelection(String startTime, String endTime) {
    setState(() {
      _selectedStartTime = startTime;
      _selectedEndTime = endTime;
    });
  }

  void _proceedToVoucherRedemption() {
    if (_selectedPackage == null || 
        _selectedStartTime == null || 
        _selectedEndTime == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseVoucherRedemptionScreen(
          teacherId: widget.teacherId,
          teacherName: widget.teacherName,
          packageId: _selectedPackage!['id'],
          packageName: _selectedPackage!['name'],
          languageId: widget.languageId,
          languageName: widget.languageName,
          amount: (_selectedPackage!['price_monthly'] ?? 0).toDouble(),
          selectedDays: _selectedDays,
          selectedStartTime: _selectedStartTime!,
          selectedEndTime: _selectedEndTime!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  const Text(
                    'SUBSCRIPTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Teacher Info
                    _buildTeacherInfo(),
                    
                    const SizedBox(height: 20),

                    // Packages Section
                    _buildPackagesSection(),

                    const SizedBox(height: 30),

                    // Day Selection (only if package selected)
                    if (_selectedPackageIndex >= 0 && !_isLoadingTimeslots) ...[
                      _buildDaySelection(),
                      const SizedBox(height: 30),
                    ],

                    // Loading indicator for timeslots
                    if (_isLoadingTimeslots)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    // Time Selection (only if required days selected)
                    if (_selectedPackage != null &&
                        _selectedDays.length == (_selectedPackage!['sessions_per_week'] as int? ?? 3) &&
                        !_isLoadingTimeslots) ...[
                      _buildTimeSelection(),
                      const SizedBox(height: 30),
                    ],

                    // Confirm Button (only if time selected)
                    if (_selectedStartTime != null && _selectedEndTime != null) ...[
                      _buildConfirmButton(),
                      const SizedBox(height: 30),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.redGradient,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscribe to',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.teacherName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.languageName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesSection() {
    if (_isLoadingPackages) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.card_giftcard,
                size: 64,
                color: AppColors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Packages Available',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'CHOOSE PACKAGE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 15),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _packages.length,
          itemBuilder: (context, index) {
            final package = _packages[index];
            final isSelected = _selectedPackageIndex == index;
            final isFeatured = package['is_featured'] ?? false;

            return _buildPackageCard(package, index, isSelected, isFeatured);
          },
        ),
      ],
    );
  }

  Widget _buildPackageCard(
    Map<String, dynamic> package,
    int index,
    bool isSelected,
    bool isFeatured,
  ) {
    final features = package['features'] != null
        ? (package['features'] is List
            ? List<String>.from(package['features'])
            : List<String>.from(json.decode(package['features'])))
        : <String>[];

    return GestureDetector(
      onTap: () => _handlePackageSelection(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isFeatured ? Colors.amber : Colors.transparent),
            width: isSelected ? 2 : (isFeatured ? 2 : 0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Radio Button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.redGradient,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              package['name'] ?? 'Package',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'POPULAR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (package['description'] != null)
                        Text(
                          package['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Package Details
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetailChip(
                  Icons.access_time,
                  '${package['duration_minutes']} min',
                ),
                _buildDetailChip(
                  Icons.calendar_today,
                  '${package['sessions_per_week']}x/week',
                ),
                _buildDetailChip(
                  Icons.date_range,
                  '${package['total_weeks']} weeks',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Price
            if (package['price_monthly'] != null)
              Row(
                children: [
                  Text(
                    '\$${package['price_monthly'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    '/month',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

            // Features
            if (features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...features.take(3).map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelection() {
    final sessionsPerWeek = _selectedPackage!['sessions_per_week'] as int? ?? 3;
    final availableDays = _availableTimeslots.keys.toList()..sort();

    if (availableDays.length < sessionsPerWeek) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Teacher needs at least $sessionsPerWeek days available for this package.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'SELECT DAYS (${_selectedDays.length}/$sessionsPerWeek)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 15),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: availableDays.map((day) {
              final isSelected = _selectedDays.contains(day);

              return GestureDetector(
                onTap: () => _handleDaySelection(day),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.redGradient : null,
                    color: isSelected ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    _dayNames[day].substring(0, 3),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    if (_isLoadingCommonSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_commonTimeslots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No common time slots available for the selected days. Please select different days.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'SELECT TIME',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 15),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _commonTimeslots.length,
            itemBuilder: (context, index) {
              final slot = _commonTimeslots[index];
              final startTime = slot['start_time']!;
              final endTime = slot['end_time']!;
              final isSelected = _selectedStartTime == startTime && _selectedEndTime == endTime;

              return GestureDetector(
                onTap: () => _handleTimeSelection(startTime, endTime),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.redGradient : null,
                    color: isSelected ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _formatTime(startTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: 'REDEEM VOUCHER',
        onPressed: _proceedToVoucherRedemption,
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;

      return '$hour:$minute $period';
    } catch (e) {
      return time;
    }
  }
}

