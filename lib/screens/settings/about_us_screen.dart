import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
                      'ABOUT US',
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo/Brand Section
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                gradient: AppColors.redGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'LM',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'LinguMoro',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Your Gateway to Language Mastery',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Mission Section
                    _buildInfoCard(
                      icon: FontAwesomeIcons.bullseye,
                      title: 'Our Mission',
                      description:
                          'To make language learning accessible, effective, and enjoyable for everyone around the world. We believe that breaking language barriers opens doors to endless opportunities.',
                    ),

                    // Vision Section
                    _buildInfoCard(
                      icon: FontAwesomeIcons.eye,
                      title: 'Our Vision',
                      description:
                          'To become the world\'s leading platform for connecting language learners with expert teachers, fostering a global community of multilingual communicators.',
                    ),

                    // What We Offer
                    _buildInfoCard(
                      icon: FontAwesomeIcons.star,
                      title: 'What We Offer',
                      description:
                          '• One-on-one live classes with expert teachers\n'
                          '• Flexible scheduling to fit your lifestyle\n'
                          '• Personalized learning paths\n'
                          '• Interactive practice exercises\n'
                          '• Progress tracking and feedback\n'
                          '• Affordable subscription packages',
                    ),

                    // Why Choose Us
                    _buildInfoCard(
                      icon: FontAwesomeIcons.heart,
                      title: 'Why Choose LinguMoro',
                      description:
                          '• Verified and experienced teachers\n'
                          '• Multiple language options\n'
                          '• Safe and secure platform\n'
                          '• 24/7 customer support\n'
                          '• Regular progress assessments\n'
                          '• Money-back guarantee',
                    ),

                    const SizedBox(height: 40),

                    // Contact Info
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Get In Touch',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildContactItem(
                            icon: FontAwesomeIcons.envelope,
                            text: 'lingumoro.institute@gmail.com',
                          ),
                          const SizedBox(height: 12),
                          _buildContactItem(
                            icon: FontAwesomeIcons.phone,
                            text: '+964 781 620 3894',
                          ),
                          const SizedBox(height: 12),
                          _buildContactItem(
                            icon: FontAwesomeIcons.locationDot,
                            text: 'Baghdad, Iraq',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Developer Info
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Developer Info',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildContactItem(
                            icon: FontAwesomeIcons.user,
                            text: 'Shakar Mustafa',
                          ),
                          const SizedBox(height: 12),
                          _buildContactItem(
                            icon: FontAwesomeIcons.phone,
                            text: '+964 750 837 6087',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Social Media
                    const Text(
                      'Follow Us',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(FontAwesomeIcons.instagram, 'https://instagram.com/lingumoro'),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Version Info
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '© 2025 LinguMoro. All rights reserved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            description,
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

  Widget _buildContactItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        FaIcon(
          icon,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, String url) {
    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          // Handle error silently
        }
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppColors.redGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

