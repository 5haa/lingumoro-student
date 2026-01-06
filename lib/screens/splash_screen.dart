import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/auth/auth_screen.dart';
import 'package:student/screens/main_navigation.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/firebase_notification_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:student/services/pro_subscription_service.dart';

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
    // Run after first frame so InheritedWidgets (e.g. MediaQuery) are available
    // for any preload work that depends on context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAuthStatus();
    });
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
    try {
      // Maximum timeout for entire splash initialization to prevent getting stuck
      await Future.any([
        _performAuthCheck(),
        Future.delayed(const Duration(seconds: 10)).then((_) {
          throw TimeoutException('Splash screen initialization timed out');
        }),
      ]);
    } catch (e) {
      print('❌ Splash screen error: $e');
      // If anything fails, navigate to auth screen as fallback
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    }
  }

  Future<void> _performAuthCheck() async {
    // Start with minimum splash duration and preloading in parallel
    final minimumSplashDuration = Future.delayed(const Duration(seconds: 3));

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
        // Preload data, initialize Firebase notifications, and validate device session in parallel
        // Add individual timeouts to prevent any single operation from blocking
        await Future.wait([
          minimumSplashDuration,
          _preloadAppData(isLoggedIn: true).timeout(const Duration(seconds: 5), onTimeout: () {}),
          _initializeFirebaseNotifications().timeout(const Duration(seconds: 5), onTimeout: () {}),
          _validateDeviceSession().timeout(const Duration(seconds: 5), onTimeout: () {}),
        ]);
        
        nextScreen = const MainNavigation();
      }
    } else {
      // Not logged in - preload public data only
      await Future.wait([
        minimumSplashDuration,
        _preloadAppData(isLoggedIn: false).timeout(const Duration(seconds: 5), onTimeout: () {}),
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

  Future<void> _validateDeviceSession() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final proService = ProSubscriptionService();
        final result = await proService.validateAndUpdateDeviceSession(userId);
        
        if (result['device_changed'] == true) {
          print('🔄 Pro subscription device session updated on app startup');
        }
        
        print('✅ Device session validated on app startup: ${result}');
      }
    } catch (e) {
      print('❌ Failed to validate device session on app startup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/splash.jpg'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

