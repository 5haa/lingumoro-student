import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                      'TERMS & CONDITIONS',
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
                      'Agreement to Terms',
                      'By accessing and using LinguMoro, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use our services.',
                    ),
                    _buildSection(
                      '1. Service Usage',
                      'You agree to use LinguMoro services only for lawful purposes and in accordance with these Terms. You agree not to:\n\n'
                      '• Use the service in any way that violates applicable laws\n'
                      '• Impersonate or attempt to impersonate others\n'
                      '• Engage in any conduct that restricts others from using the service\n'
                      '• Use any robot, spider, or automated device\n'
                      '• Introduce viruses or malicious code',
                    ),
                    _buildSection(
                      '2. User Accounts',
                      'When you create an account with us, you must provide accurate and complete information. You are responsible for:\n\n'
                      '• Maintaining the security of your account\n'
                      '• All activities that occur under your account\n'
                      '• Notifying us of any unauthorized use\n'
                      '• Keeping your password confidential',
                    ),
                    _buildSection(
                      '3. Payment Terms',
                      'By purchasing services through LinguMoro:\n\n'
                      '• All fees are in USD unless otherwise stated\n'
                      '• Payments are processed securely\n'
                      '• Subscriptions renew automatically\n'
                      '• Refunds are subject to our refund policy\n'
                      '• You authorize us to charge your payment method',
                    ),
                    _buildSection(
                      '4. Classes and Scheduling',
                      'For live classes:\n\n'
                      '• You must attend classes at scheduled times\n'
                      '• Late cancellations may not be refunded\n'
                      '• Teachers reserve the right to reschedule\n'
                      '• Recording classes requires permission',
                    ),
                    _buildSection(
                      '5. Intellectual Property',
                      'All content on LinguMoro, including text, graphics, logos, and software, is protected by copyright and other intellectual property laws. You may not:\n\n'
                      '• Copy or distribute our content without permission\n'
                      '• Modify or create derivative works\n'
                      '• Use content for commercial purposes\n'
                      '• Remove copyright notices',
                    ),
                    _buildSection(
                      '6. Termination',
                      'We may terminate or suspend your account immediately, without prior notice, for any breach of these Terms. Upon termination:\n\n'
                      '• Your right to use the service will cease\n'
                      '• You remain liable for any outstanding fees\n'
                      '• We may delete your account data',
                    ),
                    _buildSection(
                      '7. Limitation of Liability',
                      'LinguMoro shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use or inability to use the service.',
                    ),
                    _buildSection(
                      '8. Changes to Terms',
                      'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.',
                    ),
                    _buildSection(
                      '9. Contact Information',
                      'For questions about these Terms, contact us at:\n\n'
                      'Email: legal@lingumoro.com\n'
                      'Phone: +964 123 456 7890\n'
                      'Address: Baghdad, Iraq',
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

