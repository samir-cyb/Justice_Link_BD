import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:justice_link_user/screens/login_screen.dart';
import 'package:justice_link_user/screens/signup_screen.dart';
import 'package:justice_link_user/screens/report_screen.dart';
import 'package:justice_link_user/screens/about_app_screen.dart';
import 'package:justice_link_user/screens/police_info_screen.dart';
import 'package:justice_link_user/services/auth_service.dart';
import 'package:justice_link_user/services/foreground_location_service.dart';
import 'package:justice_link_user/services/background_service.dart';
import 'package:justice_link_user/services/aggressive_background_service.dart';
import 'package:justice_link_user/services/nirbacon_service.dart';
import 'package:justice_link_user/services/live_stream_service.dart';
import 'package:justice_link_user/providers/emergency_provider.dart'; // ADD THIS
import 'dart:developer' as developer;
import 'package:fvp/fvp.dart' as fvp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REGISTER FVP FIRST
  fvp.registerWith();
  developer.log('✅ FVP (video_player compatibility) registered');

  // INITIALIZE ANDROID ALARM MANAGER
  await AndroidAlarmManager.initialize();
  developer.log('✅ Android Alarm Manager initialized');

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  try {
    await Supabase.initialize(
      url: 'https://nlzepbocfljoreltzzup.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw',
    );
    developer.log('✅ Supabase initialized successfully');
  } catch (e) {
    developer.log('❌ Error initializing Supabase: $e');
  }

  // Check emergency mode
  final isEmergencyMode = prefs.getBool('is_in_emergency_mode') ?? false;
  final aggressiveUntil = prefs.getInt('aggressive_mode_until') ?? 0;
  final shouldBeAggressive = isEmergencyMode ||
      DateTime.now().millisecondsSinceEpoch < aggressiveUntil;

  developer.log('🔍 Emergency mode check:');
  developer.log('   - isEmergencyMode: $isEmergencyMode');
  developer.log('   - shouldBeAggressive: $shouldBeAggressive');

  // Initialize services only on Android
  if (!kIsWeb && Platform.isAndroid) {
    developer.log('🔧 Initializing Android-specific services...');
    try {
      await ForegroundLocationService.initialize();
      developer.log('✅ Foreground service initialized');

      await AggressiveBackgroundService().initialize();
      developer.log('✅ Aggressive background service initialized');

      if (shouldBeAggressive) {
        developer.log('🚨 App started in EMERGENCY MODE');
        await AggressiveBackgroundService().startAggressiveMonitoring();
      } else {
        developer.log('📡 App started in NORMAL MODE');
        await AggressiveBackgroundService().startNormalMonitoring();
      }

      await BackgroundService().initialize();
      await BackgroundService().startEmergencyMonitoring();
      developer.log('✅ Legacy background service initialized');

    } catch (e) {
      developer.log('❌ Error initializing Android services: $e');
    }
  } else {
    developer.log('⚠️ Skipping Android service initialization (not on Android)');
  }

  final initialRoute = await _determineInitialRoute();
  developer.log('🚀 Initial route: $initialRoute');

  runApp(MyApp(initialRoute: initialRoute));
}

Future<String> _determineInitialRoute() async {
  final authService = AuthService();
  await Future.delayed(const Duration(milliseconds: 100));
  final status = await authService.checkSessionValidity();
  developer.log('🔐 Session status: $status');

  switch (status) {
    case AuthStatus.valid:
      return '/report';
    case AuthStatus.expired:
    case AuthStatus.tooOld:
    case AuthStatus.noSession:
    case AuthStatus.invalid:
      return '/login';
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => EmergencyState()), // ADD THIS
        Provider(create: (_) => NirbaconService()),
        Provider(create: (_) => LiveStreamService()),
      ],
      child: MaterialApp(
        title: 'Justice Link BD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        initialRoute: initialRoute,
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/report': (context) => const ReportScreen(),
          '/about': (context) => const AboutAppScreen(),
          '/police-info': (context) => const PoliceInfoScreen(),
        },
      ),
    );
  }
}