import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/course_voucher_service.dart';
import 'package:student/services/session_update_service.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:student/widgets/custom_button.dart';

class CourseVoucherRedemptionScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String packageId;
  final String packageName;
  final String languageId;
  final String languageName;
  final List<int> selectedDays;
  final String selectedStartTime;
  final String selectedEndTime;
  final double amount;

  const CourseVoucherRedemptionScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.packageId,
    required this.packageName,
    required this.languageId,
    required this.languageName,
    required this.selectedDays,
    required this.selectedStartTime,
    required this.selectedEndTime,
    required this.amount,
  });

  @override
  State<CourseVoucherRedemptionScreen> createState() =>
      _CourseVoucherRedemptionScreenState();
}

class _CourseVoucherRedemptionScreenState
    extends State<CourseVoucherRedemptionScreen> {
  final _voucherService = CourseVoucherService();
  final _authService = AuthService();
  final _voucherController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRedeeming = false;

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _redeemVoucher() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final studentId = _authService.currentUser?.id;
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userNotLoggedIn)),
      );
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final result = await _voucherService.redeemCourseVoucher(
        studentId: studentId,
        voucherCode: _voucherController.text.trim(),
        teacherId: widget.teacherId,
        languageId: widget.languageId,
        selectedDays: widget.selectedDays,
        startTime: widget.selectedStartTime,
        endTime: widget.selectedEndTime,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Notify listeners that sessions have been updated
        SessionUpdateService().notifySessionsUpdated();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.subscriptionActivatedSessions(result['total_sessions'] as int),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Navigate back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception(result['error'] ?? 'Failed to redeem voucher');
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      // ignore
    }
    return time;
  }

  String _fullDayName(AppLocalizations l10n, int day) {
    switch (day) {
      case 0:
        return l10n.sunday;
      case 1:
        return l10n.monday;
      case 2:
        return l10n.tuesday;
      case 3:
        return l10n.wednesday;
      case 4:
        return l10n.thursday;
      case 5:
        return l10n.friday;
      case 6:
      default:
        return l10n.saturday;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button and Title (matching subscription screen)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const Spacer(),
                  Text(
                    l10n.redeemVoucher.toUpperCase(),
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
            // Header section with gradient
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.subscribeTo,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.teacherName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          widget.languageName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          widget.packageName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Schedule Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.yourSchedule,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.selectedDays.map((day) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _fullDayName(l10n, day),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatTime(widget.selectedStartTime)} - ${_formatTime(widget.selectedEndTime)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Voucher Code Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 10),
                      child: Text(
                        l10n.voucherCode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    
                    TextFormField(
                      controller: _voucherController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'XXXXXXXXXXXXXXXX',
                        hintStyle: const TextStyle(
                          letterSpacing: 2,
                          color: AppColors.textHint,
                          fontSize: 18,
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.enterVoucherCode;
                        }
                        if (value.trim().length != 16) {
                          return l10n.voucherCodeMustBeLength(16);
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.voucherCodeValidForPackage,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Redeem button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomButton(
                text: _isRedeeming ? l10n.redeemingVoucher : l10n.redeemVoucher,
                onPressed: () {
                  _redeemVoucher();
                },
                isLoading: _isRedeeming,
              ),
            ),

            const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

