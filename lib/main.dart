import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/config/supabase_config.dart';
import 'package:student/screens/splash_screen.dart';
import 'package:student/screens/teachers/teachers_list_screen.dart';
import 'package:student/screens/students/students_list_screen.dart';
import 'package:student/services/presence_service.dart';
import 'package:student/services/locale_service.dart';
import 'package:student/services/notification_badge_controller.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/providers/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  // Android works because Firebase auto-initializes via Gradle plugin
  // iOS needs explicit handling - crash here causes blank screen on iPad
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    // Continue anyway - Firebase might already be initialized or is not critical for launch
  }

  // Initialize Supabase with error handling
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Supabase initialization error: $e');
    // Continue anyway - app should at least show UI
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _presenceService = PresenceService();
  final _localeService = LocaleService();
  final _badgeController = NotificationBadgeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePresence();
    _localeService.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceService.stopTracking();
    _presenceService.dispose();
    _localeService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        _presenceService.startTracking();
        // Trigger notification badge refresh when app resumes
        _badgeController.triggerUpdate();
        print('🔄 App resumed - triggering notification refresh');
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
      
      // Localization
      locale: _localeService.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first;
      },
      
      // Builder for RTL support and LocaleProvider
      builder: (context, child) {
        return LocaleProvider(
          localeService: _localeService,
          child: Directionality(
            textDirection: _localeService.getTextDirection(),
            child: child!,
          ),
        );
      },
      
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: _localeService.locale.languageCode == 'ar' ? 'Arabic' : null,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: _localeService.locale.languageCode == 'ar' ? 'Arabic' : null,
          ),
          centerTitle: true,
        ),
        textTheme: _localeService.locale.languageCode == 'ar' 
          ? ThemeData.light().textTheme.apply(fontFamily: 'Arabic')
          : null,
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
      },
    );
  }
}
