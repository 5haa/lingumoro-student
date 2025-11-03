import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/config/supabase_config.dart';
import 'package:student/screens/splash_screen.dart';
import 'package:student/screens/teachers/teachers_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lingumoro Student',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
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
      },
    );
  }
}
