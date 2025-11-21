import 'package:flutter/material.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/l10n/app_localizations.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignIn = true;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Tab selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton(AppLocalizations.of(context).login.toUpperCase(), _isSignIn, () {
                    setState(() {
                      _isSignIn = true;
                    });
                  }),
                  Container(
                    width: 2,
                    height: 30,
                    color: AppColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  _buildTabButton(AppLocalizations.of(context).signup.toUpperCase(), !_isSignIn, () {
                    setState(() {
                      _isSignIn = false;
                    });
                  }),
                ],
              ),
              
              const SizedBox(height: 115),
              
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _isSignIn ? const SignInContent() : const SignUpContent(),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (isActive)
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

