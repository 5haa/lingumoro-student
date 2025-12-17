import 'package:flutter/material.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/widgets/custom_button.dart';
import 'package:student/widgets/custom_text_field.dart';
import 'package:student/widgets/custom_back_button.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/utils/error_helper.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _handleSendCode() async {
    final l10n = AppLocalizations.of(context);
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterYourEmail),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Send password reset OTP
      await _authService.resetPassword(_emailController.text.trim());
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.verificationCodeSentToEmail),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to OTP verification screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              email: _emailController.text.trim(),
              fullName: '', // Not needed for password reset
              phone: null,
              provinceId: null,
              isPasswordReset: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getUserFriendlyError(e)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Back button
              const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CustomBackButton(),
                ),
              ),
              
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Title
                    Text(
                      l10n.forgotPasswordTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Description
                    Text(
                      l10n.forgotPasswordDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      hintText: l10n.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Send Code button
                    CustomButton(
                      text: l10n.sendCode,
                      onPressed: _handleSendCode,
                      isLoading: _isLoading,
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

