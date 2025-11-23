import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/auth/auth_screen.dart';
import 'package:student/screens/main_navigation.dart';
import 'package:student/screens/onboarding_screen.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/firebase_notification_service.dart';
import 'package:student/services/preload_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _checkAuthStatus();
  }
  
  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Start with minimum splash duration and preloading in parallel
    final minimumSplashDuration = Future.delayed(const Duration(seconds: 3));
    
    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // If onboarding not completed, show onboarding screen
    if (!onboardingCompleted) {
      await minimumSplashDuration; // Wait for minimum splash time
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
      );
      return;
    }

    // Check authentication status
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    
    Widget nextScreen;
    
    if (isLoggedIn) {
      // Check if user is suspended
      final authService = AuthService();
      final isSuspended = await authService.checkIfSuspended();
      
      if (isSuspended) {
        // User is suspended, show login screen with message
        await minimumSplashDuration; // Wait for minimum splash time
        nextScreen = const AuthScreen();
        if (mounted) {
          // Show suspension message after navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your account has been suspended. Please contact support.'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        }
      } else {
        // Preload data and initialize Firebase notifications in parallel
        await Future.wait([
          minimumSplashDuration,
          _preloadAppData(isLoggedIn: true),
          _initializeFirebaseNotifications(),
        ]);
        
        nextScreen = const MainNavigation();
      }
    } else {
      // Not logged in - preload public data only
      await Future.wait([
        minimumSplashDuration,
        _preloadAppData(isLoggedIn: false),
      ]);
      
      nextScreen = const AuthScreen();
    }

    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => nextScreen,
      ),
    );
  }

  Future<void> _preloadAppData({required bool isLoggedIn}) async {
    try {
      final preloadService = PreloadService();
      await preloadService.preloadData(
        isLoggedIn: isLoggedIn,
        context: mounted ? context : null,
      );
    } catch (e) {
      print('❌ Error preloading data: $e');
      // Don't block app from loading even if preload fails
    }
  }

  Future<void> _initializeFirebaseNotifications() async {
    try {
      final firebaseNotificationService = FirebaseNotificationService();
      await firebaseNotificationService.initialize();
      print('✅ Firebase notifications initialized on app startup');
    } catch (e) {
      print('❌ Failed to initialize Firebase notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

