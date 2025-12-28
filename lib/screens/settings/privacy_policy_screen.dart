import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PRIVACY POLICY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 45),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'Introduction',
                      'LinguMoro ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our language learning platform.',
                    ),
                    _buildSection(
                      '1. Information We Collect',
                      'We collect information that you provide directly to us, including:\n\n'
                      '• Personal identification information (name, email address, phone number)\n'
                      '• Account credentials\n'
                      '• Payment information\n'
                      '• Profile information\n'
                      '• Communication preferences\n'
                      '• Learning progress and performance data',
                    ),
                    _buildSection(
                      '2. How We Use Your Information',
                      'We use the information we collect to:\n\n'
                      '• Provide, maintain, and improve our services\n'
                      '• Process your transactions\n'
                      '• Send you updates and notifications\n'
                      '• Respond to your comments and questions\n'
                      '• Personalize your learning experience\n'
                      '• Analyze usage patterns and trends',
                    ),
                    _buildSection(
                      '3. Information Sharing',
                      'We do not sell your personal information. We may share your information with:\n\n'
                      '• Teachers you are enrolled with\n'
                      '• Service providers who assist our operations\n'
                      '• Law enforcement when required by law\n'
                      '• Third parties with your consent',
                    ),
                    _buildSection(
                      '4. Data Security',
                      'We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
                    ),
                    _buildSection(
                      '5. Your Rights',
                      'You have the right to:\n\n'
                      '• Access your personal information\n'
                      '• Correct inaccurate data\n'
                      '• Request deletion of your data\n'
                      '• Opt-out of marketing communications\n'
                      '• Export your data',
                    ),
                    _buildSection(
                      '6. Contact Us',
                      'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                      'Email: lingumoro.institute@gmail.com\n'
                      'Phone: +964 781 620 3894',
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Last updated: November 2025',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

