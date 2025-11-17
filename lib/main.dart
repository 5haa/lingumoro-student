import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/config/supabase_config.dart';
import 'package:student/screens/splash_screen.dart';
import 'package:student/screens/teachers/teachers_list_screen.dart';
import 'package:student/screens/payment/payment_submission_screen.dart';
import 'package:student/screens/students/students_list_screen.dart';
import 'package:student/services/presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePresence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.stopTracking();
    _presenceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        _presenceService.startTracking();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background
        _presenceService.stopTracking();
        break;
    }
  }

  Future<void> _initializePresence() async {
    // Wait for auth to be ready
    await Future.delayed(const Duration(seconds: 2));
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await _presenceService.startTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lingumoro Student',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/teachers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TeachersListScreen(
            languageId: args['languageId'],
            languageName: args['languageName'],
          );
        },
        '/students': (context) => const StudentsListScreen(),
        '/payment-submission': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PaymentSubmissionScreen(
            teacherId: args['teacherId'],
            teacherName: args['teacherName'],
            packageId: args['packageId'],
            packageName: args['packageName'],
            languageId: args['languageId'],
            languageName: args['languageName'],
            amount: args['amount'],
          );
        },
      },
    );
  }
}
