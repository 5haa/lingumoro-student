import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:student/config/app_colors.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/screens/vouchers/course_voucher_redemption_screen.dart';
import 'package:student/services/package_service.dart';
import 'package:student/services/timeslot_service.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:student/widgets/custom_button.dart';

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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
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

  void _goToStep(int step) {
    setState(() {
      if (step == 0) {
        // Go back to package selection - reset everything
        _selectedPackageIndex = -1;
        _selectedPackage = null;
        _selectedDays = [];
        _selectedStartTime = null;
        _selectedEndTime = null;
        _commonTimeslots = [];
        _availableTimeslots = {};
      } else if (step == 1 && _selectedPackageIndex >= 0) {
        // Go back to day selection - reset days and time
        _selectedDays = [];
        _selectedStartTime = null;
        _selectedEndTime = null;
        _commonTimeslots = [];
      }
    });
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
    
    // Auto-scroll to bottom to show the redeem voucher button
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
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

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Determine current step
    int currentStep = 0;
    if (_selectedPackageIndex >= 0) {
      currentStep = 1;
      final sessionsPerWeek = _selectedPackage!['sessions_per_week'] as int? ?? 3;
      if (_selectedDays.length == sessionsPerWeek) {
        currentStep = 2;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button and Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  Text(
                    l10n.subscribe.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Teacher Info Banner (Full Width)
            _buildTeacherInfoBanner(),

            const SizedBox(height: 20),

            // Step Indicator
            _buildStepIndicator(currentStep),

            const SizedBox(height: 20),

            // Content based on current step
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // Show selected package summary on later steps
                    if (currentStep > 0 && _selectedPackage != null) ...[
                      _buildSelectedPackageSummary(),
                      const SizedBox(height: 20),
                    ],

                    // Show selected days summary on step 3
                    if (currentStep == 2 && _selectedDays.isNotEmpty) ...[
                      _buildSelectedDaysSummary(),
                      const SizedBox(height: 20),
                    ],

                    // Step 1: Package Selection
                    if (currentStep == 0) _buildPackagesSection(),

                    // Step 2: Day Selection
                    if (currentStep == 1) ...[
                      if (_isLoadingTimeslots)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        _buildDaySelection(),
                    ],

                    // Step 3: Time Selection
                    if (currentStep == 2) ...[
                      if (_isLoadingCommonSlots)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        _buildTimeSelection(),
                    ],

                    const SizedBox(height: 20),

                    // Confirm Button (only show at final step with time selected)
                    if (currentStep == 2 && _selectedStartTime != null && _selectedEndTime != null) ...[
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

  Widget _buildTeacherInfoBanner() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.redGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subscribeTo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.teacherName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.languageName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStepItem(0, currentStep, l10n.stepPackage),
          _buildStepLine(currentStep >= 1),
          _buildStepItem(1, currentStep, l10n.stepDays),
          _buildStepLine(currentStep >= 2),
          _buildStepItem(2, currentStep, l10n.stepTime),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, int currentStep, String label) {
    final isActive = currentStep >= step;
    final isCurrent = currentStep == step;
    final canNavigate = step < currentStep;

    return Expanded(
      child: GestureDetector(
        onTap: canNavigate ? () => _goToStep(step) : null,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.redGradient : null,
                color: isActive ? null : AppColors.lightGrey,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(
                        color: AppColors.primary,
                        width: 3,
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: canNavigate
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.redGradient : null,
          color: isActive ? null : AppColors.lightGrey,
        ),
      ),
    );
  }

  Widget _buildPackagesSection() {
    final l10n = AppLocalizations.of(context);
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
              Text(
                l10n.noPackagesAvailable,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectYourPackage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _packages.length,
            itemBuilder: (context, index) {
              final package = _packages[index];
              final isSelected = _selectedPackageIndex == index;
              final isFeatured = package['is_featured'] ?? false;

              return _buildPackageCard(
                package,
                index,
                isSelected,
                isFeatured,
                l10n,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    Map<String, dynamic> package,
    int index,
    bool isSelected,
    bool isFeatured,
    AppLocalizations l10n,
  ) {
    return GestureDetector(
      onTap: () => _handlePackageSelection(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isFeatured ? Colors.amber : Colors.grey.shade200),
            width: isSelected ? 2.5 : (isFeatured ? 2 : 1),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 20,
              height: 20,
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
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.redGradient,
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package['name'] ?? l10n.packages,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 10, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildCompactChip(Icons.access_time, '${package['duration_minutes']}m'),
                      const SizedBox(width: 6),
                      _buildCompactChip(Icons.calendar_today, '${package['sessions_per_week']}x/wk'),
                      const SizedBox(width: 6),
                      _buildCompactChip(Icons.date_range, '${package['total_weeks']}wks'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Price
            if (package['price_monthly'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  // Price and "/month" suffix; currency itself is not localized here
                  // but the amount comes from backend.
                  // If you localize currency later, adjust this block.
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelection() {
    final l10n = AppLocalizations.of(context);
    final sessionsPerWeek = _selectedPackage!['sessions_per_week'] as int? ?? 3;
    final availableDays = _availableTimeslots.keys.toList()..sort();

    if (availableDays.length < sessionsPerWeek) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.teacherNeedsDaysAvailable(sessionsPerWeek),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.selectDays,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedDays.length}/$sessionsPerWeek',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableDays.map((day) {
              final isSelected = _selectedDays.contains(day);

              return GestureDetector(
                onTap: () => _handleDaySelection(day),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.redGradient : null,
                    color: isSelected ? null : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _shortDayName(l10n, day),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelection() {
    final l10n = AppLocalizations.of(context);
    if (_commonTimeslots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.noCommonTimeSlots,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectTime,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _formatTime(startTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPackageSummary() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectedPackageLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedPackage!['name'] ?? l10n.packages,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _goToStep(0),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.change,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDaysSummary() {
    final l10n = AppLocalizations.of(context);
    final sessionsPerWeek = _selectedPackage!['sessions_per_week'] as int? ?? 3;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectedDaysLabel(sessionsPerWeek),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: _selectedDays.map((day) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.redGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _shortDayName(l10n, day),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _goToStep(1),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.change,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: AppLocalizations.of(context).redeemVoucher.toUpperCase(),
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

  String _shortDayName(AppLocalizations l10n, int day) {
    switch (day) {
      case 0:
        return l10n.sun.toUpperCase();
      case 1:
        return l10n.mon.toUpperCase();
      case 2:
        return l10n.tue.toUpperCase();
      case 3:
        return l10n.wed.toUpperCase();
      case 4:
        return l10n.thu.toUpperCase();
      case 5:
        return l10n.fri.toUpperCase();
      case 6:
      default:
        return l10n.sat.toUpperCase();
    }
  }
}

