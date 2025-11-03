import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/payment_service.dart';

class PaymentSubmissionScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String packageId;
  final String packageName;
  final String languageId;
  final String languageName;
  final double amount;

  const PaymentSubmissionScreen({
    Key? key,
    required this.teacherId,
    required this.teacherName,
    required this.packageId,
    required this.packageName,
    required this.languageId,
    required this.languageName,
    required this.amount,
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

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
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
        appBar: AppBar(title: const Text('Payment Submission')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedMethod = _paymentMethods.firstWhere(
      (m) => m['id'] == _selectedPaymentMethodId,
      orElse: () => {},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Payment'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subscription Details Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      _buildDetailRow('Teacher', widget.teacherName),
                      _buildDetailRow('Language', widget.languageName),
                      _buildDetailRow('Package', widget.packageName),
                      _buildDetailRow(
                        'Amount',
                        '\$${widget.amount.toStringAsFixed(2)}',
                        isAmount: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Payment Method Selection
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._paymentMethods.map((method) => _buildPaymentMethodCard(method)).toList(),
              const SizedBox(height: 20),

              // Payment Instructions
              if (selectedMethod.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Payment Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (selectedMethod['account_name'] != null)
                          Text('Account Name: ${selectedMethod['account_name']}',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (selectedMethod['account_number'] != null)
                          Text('Account Number: ${selectedMethod['account_number']}',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (selectedMethod['phone_number'] != null)
                          Text('Phone: ${selectedMethod['phone_number']}',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (selectedMethod['instructions'] != null) ...[
                          const SizedBox(height: 10),
                          Text(selectedMethod['instructions']),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Upload Payment Proof
              const Text(
                'Upload Payment Proof *',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_paymentProofImage != null) ...[
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_paymentProofImage!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notes (Optional)
              const Text(
                'Additional Notes (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any additional information here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Payment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isAmount ? 20 : 16,
              color: isAmount ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = method['id'] == _selectedPaymentMethodId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethodId = method['id']),
      child: Card(
        elevation: isSelected ? 5 : 2,
        color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(
                _getPaymentIcon(method['type']),
                color: isSelected ? Colors.deepPurple : Colors.grey,
                size: 30,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.deepPurple : Colors.black,
                      ),
                    ),
                    Text(
                      method['type'],
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.deepPurple, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'bank_transfer':
        return Icons.account_balance;
      case 'mobile_money':
        return Icons.phone_android;
      case 'cash':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

