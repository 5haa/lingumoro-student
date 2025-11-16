import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/payment_service.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';
import '../../widgets/custom_button.dart';

class PaymentSubmissionScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String packageId;
  final String packageName;
  final String languageId;
  final String languageName;
  final double amount;
  final List<int>? selectedDays;
  final String? selectedStartTime;
  final String? selectedEndTime;

  const PaymentSubmissionScreen({
    Key? key,
    required this.teacherId,
    required this.teacherName,
    required this.packageId,
    required this.packageName,
    required this.languageId,
    required this.languageName,
    required this.amount,
    this.selectedDays,
    this.selectedStartTime,
    this.selectedEndTime,
  }) : super(key: key);

  @override
  _PaymentSubmissionScreenState createState() => _PaymentSubmissionScreenState();
}

class _PaymentSubmissionScreenState extends State<PaymentSubmissionScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedPaymentMethodId;
  File? _paymentProofImage;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _hasPendingPayment = false;

  @override
  void initState() {
    super.initState();
    _checkPendingPayment();
    _loadPaymentMethods();
  }

  Future<void> _checkPendingPayment() async {
    try {
      final pendingPayment = await _paymentService.getPendingPayment(
        teacherId: widget.teacherId,
        packageId: widget.packageId,
      );
      
      if (pendingPayment != null && mounted) {
        setState(() => _hasPendingPayment = true);
        
        // Show dialog and go back
        Future.delayed(Duration.zero, () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Payment Pending'),
              content: const Text(
                'You already have a pending payment for this course. '
                'Please wait for admin approval or rejection before submitting again.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      print('Error checking pending payment: $e');
    }
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final methods = await _paymentService.getPaymentMethods();
      setState(() {
        _paymentMethods = methods;
        if (methods.isNotEmpty) {
          _selectedPaymentMethodId = methods[0]['id'];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment methods: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _paymentProofImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _paymentProofImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    if (_paymentProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload image first
      final imageUrl = await _paymentService.uploadPaymentProof(_paymentProofImage!.path);

      // Submit payment
      await _paymentService.submitPayment(
        teacherId: widget.teacherId,
        packageId: widget.packageId,
        languageId: widget.languageId,
        paymentMethodId: _selectedPaymentMethodId!,
        amount: widget.amount,
        paymentProofUrl: imageUrl,
        studentNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        selectedDays: widget.selectedDays,
        selectedStartTime: widget.selectedStartTime,
        selectedEndTime: widget.selectedEndTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted successfully! Waiting for admin verification.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting payment: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    final selectedMethod = _paymentMethods.firstWhere(
      (m) => m['id'] == _selectedPaymentMethodId,
      orElse: () => {},
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: const [
                  CustomBackButton(),
                  Spacer(),
                  Text(
                    'PAYMENT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  Spacer(),
                  SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      // Subscription Summary Card
                      _buildSubscriptionSummary(),
                      
                      const SizedBox(height: 20),

                      // Payment Method Selection
                      _buildPaymentMethodSection(selectedMethod),
                      
                      const SizedBox(height: 20),

                      // Payment Instructions
                      if (selectedMethod.isNotEmpty) ...[
                        _buildPaymentInstructions(selectedMethod),
                        const SizedBox(height: 20),
                      ],

                      // Upload Payment Proof
                      _buildPaymentProofSection(),
                      
                      const SizedBox(height: 20),

                      // Notes
                      _buildNotesSection(),
                      
                      const SizedBox(height: 20),

                      // Submit Button
                      _buildSubmitButton(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSummary() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.grey.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildSummaryRow(
              icon: Icons.person_outline,
              label: 'Teacher',
              value: widget.teacherName,
            ),
            _buildSummaryRow(
              icon: Icons.language,
              label: 'Language',
              value: widget.languageName,
            ),
            _buildSummaryRow(
              icon: Icons.card_giftcard,
              label: 'Package',
              value: widget.packageName,
            ),
            
            if (widget.selectedDays != null && widget.selectedDays!.isNotEmpty) ...[
              _buildSummaryRow(
                icon: Icons.calendar_today,
                label: 'Days',
                value: _formatDays(widget.selectedDays!),
              ),
              if (widget.selectedStartTime != null && widget.selectedEndTime != null)
                _buildSummaryRow(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: '${_formatTime(widget.selectedStartTime!)} - ${_formatTime(widget.selectedEndTime!)}',
                ),
            ],
            
            const SizedBox(height: 8),
            Divider(color: AppColors.grey.withOpacity(0.3), thickness: 1),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '\$${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(Map<String, dynamic> selectedMethod) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_paymentMethods.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 48,
                    color: AppColors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Payment Methods Available',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._paymentMethods.map((method) => _buildPaymentMethodCard(method)).toList(),
      ],
    );
  }

  Widget _buildPaymentInstructions(Map<String, dynamic> selectedMethod) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (selectedMethod['account_name'] != null)
            _buildInstructionRow(
              'Account Name',
              selectedMethod['account_name'],
            ),
          if (selectedMethod['account_number'] != null)
            _buildInstructionRow(
              'Account Number',
              selectedMethod['account_number'],
            ),
          if (selectedMethod['phone_number'] != null)
            _buildInstructionRow(
              'Phone Number',
              selectedMethod['phone_number'],
            ),
          
          if (selectedMethod['instructions'] != null) ...[
            const SizedBox(height: 8),
            Text(
              selectedMethod['instructions'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Payment Proof',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Image Preview
        if (_paymentProofImage != null) ...[
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _paymentProofImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentProofImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Upload Buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _paymentProofImage != null 
                          ? AppColors.primary 
                          : AppColors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 20,
                        color: _paymentProofImage != null 
                            ? AppColors.primary 
                            : AppColors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gallery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _paymentProofImage != null 
                              ? AppColors.primary 
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: AppColors.grey,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Camera',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Additional Notes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '(Optional)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Add any additional information...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return CustomButton(
      text: _isSubmitting ? 'SUBMITTING...' : 'SUBMIT PAYMENT',
      onPressed: _isSubmitting ? () {} : _submitPayment,
      isLoading: _isSubmitting,
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = method['id'] == _selectedPaymentMethodId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethodId = method['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // Payment Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primary.withOpacity(0.1) 
                    : AppColors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                _getPaymentIcon(method['type']),
                color: isSelected ? AppColors.primary : AppColors.grey,
                size: 18,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'] ?? 'Payment Method',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPaymentType(method['type']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String? type) {
    switch (type) {
      case 'bank_transfer':
        return FontAwesomeIcons.buildingColumns;
      case 'mobile_money':
        return FontAwesomeIcons.mobileScreen;
      case 'cash':
        return FontAwesomeIcons.moneyBill;
      case 'credit_card':
        return FontAwesomeIcons.creditCard;
      default:
        return FontAwesomeIcons.wallet;
    }
  }

  String _formatPaymentType(String? type) {
    switch (type) {
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Cash';
      case 'credit_card':
        return 'Credit Card';
      default:
        return type ?? 'Payment';
    }
  }

  String _formatDays(List<int> days) {
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sortedDays = List<int>.from(days)..sort();
    return sortedDays.map((d) => dayNames[d]).join(', ');
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}


