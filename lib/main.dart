import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:justice_link_user/screens/login_screen.dart';
import 'package:justice_link_user/screens/signup_screen.dart';
import 'package:justice_link_user/screens/report_screen.dart';
import 'package:justice_link_user/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://nlzepbocfljoreltzzup.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw',
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'Justice Link BD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/report': (context) => const ReportScreen(),
        },
      ),
    );
  }
}