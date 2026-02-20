import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_store.dart';
import 'vibration_service.dart';

// 🔴 Alarm IDs for AlarmManager
const int emergencyCheckAlarmId = 200;
const int highFrequencyAlarmId = 201;
const int immediateCheckAlarmId = 202;

/// 🟡 SMART POLLING BACKGROUND SERVICE using AlarmManager
/// Replaces WorkManager for Flutter 3.38+ compatibility
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  bool _isInitialized = false;
  bool _isHighFrequencyMode = false;
  Timer? _rapidCheckTimer;

  static const String _supabaseUrl = 'https://nlzepbocfljoreltzzup.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw';

  Future<void> initialize() async {
    if (_isInitialized) return;
    developer.log('🔧 BackgroundService: Initializing...');
    // AlarmManager is initialized in main.dart
    _isInitialized = true;
    developer.log('✅ BackgroundService initialized');
  }

  /// Normal monitoring - 15 min periodic using AlarmManager
  Future<void> startEmergencyMonitoring() async {
    developer.log('📡 Starting 15-min periodic monitoring (AlarmManager)');

    // Cancel any existing high frequency alarms
    await AndroidAlarmManager.cancel(highFrequencyAlarmId);
    await AndroidAlarmManager.cancel(immediateCheckAlarmId);
    _rapidCheckTimer?.cancel();

    // Schedule periodic alarm (15 minutes)
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 15),
      emergencyCheckAlarmId,
      _backgroundAlarmCallback,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    developer.log('✅ Normal monitoring scheduled');
  }

  /// 🔴 HIGH FREQUENCY MODE - Every 15 seconds when emergency nearby
  Future<void> startHighFrequencyMonitoring() async {
    if (_isHighFrequencyMode) return;

    developer.log('🚨 STARTING HIGH FREQUENCY MONITORING (15 sec)');
    _isHighFrequencyMode = true;

    // Cancel normal monitoring
    await AndroidAlarmManager.cancel(emergencyCheckAlarmId);

    // Schedule high frequency alarm (15 min minimum for AlarmManager)
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 15),
      highFrequencyAlarmId,
      _backgroundAlarmCallback,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    // Use Timer for rapid 15-second checks while app is running
    _startRapidChecks();
    developer.log('✅ High frequency monitoring started');
  }

  /// Start rapid timer-based checks (only works while app is alive)
  void _startRapidChecks() {
    _rapidCheckTimer?.cancel();
    _rapidCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isHighFrequencyMode) {
        timer.cancel();
        return;
      }
      developer.log('⚡ Rapid check triggered');
      await _checkForEmergenciesInBackground(normalMode: false);
    });
  }

  /// Stop high frequency, return to normal
  Future<void> stopHighFrequencyMonitoring() async {
    developer.log('✅ Stopping high frequency, returning to normal');
    _isHighFrequencyMode = false;
    _rapidCheckTimer?.cancel();
    await AndroidAlarmManager.cancel(highFrequencyAlarmId);
    await AndroidAlarmManager.cancel(immediateCheckAlarmId);
    await startEmergencyMonitoring();
  }

  /// Immediate check - runs within seconds using one-shot alarm
  Future<void> triggerImmediateCheck() async {
    developer.log('⚡ Triggering immediate check');
    await AndroidAlarmManager.oneShot(
      Duration.zero,
      immediateCheckAlarmId,
      _backgroundAlarmCallback,
      wakeup: true,
      exact: true,
      alarmClock: true,
    );
  }

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseKey => _supabaseKey;
}

/// 🔴 TOP-LEVEL CALLBACK for AlarmManager (must be static or top-level)
@pragma('vm:entry-point')
void _backgroundAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('🔔 AlarmManager triggered at ${DateTime.now()}');

  try {
    await Supabase.initialize(
      url: 'https://nlzepbocfljoreltzzup.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw',
    );
    await _checkForEmergenciesInBackground(normalMode: true);
  } catch (e) {
    developer.log('❌ Supabase init failed: $e');
  }
}

/// Check for emergencies with smart logic
Future<void> _checkForEmergenciesInBackground({bool normalMode = true}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_check_time', DateTime.now().toIso8601String());

  developer.log('🔍 ${normalMode ? "Normal" : "HIGH FREQ"} check at ${DateTime.now()}');

  try {
    await Supabase.initialize(
      url: BackgroundService.supabaseUrl,
      anonKey: BackgroundService.supabaseKey,
    );

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      developer.log('   - No user logged in');
      return;
    }

    final location = await EmergencyStore.getLastLocation();
    if (location == null) {
      developer.log('   - No location available');
      return;
    }

    developer.log('   - Checking 500m around $location');

    final emergencies = await supabase.rpc(
      'get_nearby_emergencies_except_self',
      params: {
        'user_lat': location.latitude,
        'user_lng': location.longitude,
        'self_user_id': user.id,
        'radius_meters': 500,
      },
    );

    if (emergencies != null && (emergencies as List).isNotEmpty) {
      final latest = (emergencies as List).first;
      final createdAt = DateTime.tryParse(latest['created_at'] ?? '') ?? DateTime.now();
      final secondsSinceCreated = DateTime.now().difference(createdAt).inSeconds;

      // Alert if within 10 minutes
      if (secondsSinceCreated < 600) {
        developer.log('🚨 EMERGENCY FOUND! Switching to high frequency mode');
        await _showEmergencyNotification(latest);

        // 🔴 Switch to high frequency mode
        if (normalMode) {
          await BackgroundService().startHighFrequencyMonitoring();
        }

        // Keep worker alive
        await Future.delayed(const Duration(seconds: 10));
      } else {
        developer.log('   - Old emergency, ignoring');
        // If in high freq mode and no recent emergencies, go back to normal
        if (!normalMode) {
          // Check if any emergencies are recent
          final hasRecent = (emergencies as List).any((e) {
            final created = DateTime.tryParse(e['created_at'] ?? '') ?? DateTime.now();
            return DateTime.now().difference(created).inSeconds < 600;
          });

          if (!hasRecent) {
            developer.log('   - No recent emergencies, returning to normal mode');
            await BackgroundService().stopHighFrequencyMonitoring();
          }
        }
      }
    } else {
      developer.log('   - No emergencies found');
      // Return to normal if in high freq mode
      if (!normalMode) {
        await BackgroundService().stopHighFrequencyMonitoring();
      }
    }
  } catch (e, stack) {
    developer.log('❌ Check error: $e\n$stack');
  }
}

/// Show notification from background
Future<void> _showEmergencyNotification(Map<String, dynamic> emergency) async {
  developer.log('🔔 ATTEMPTING TO SHOW NOTIFICATION: ${emergency['id']}');
  final notifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'emergency_channel_critical',
    'Emergency Alerts',
    description: 'Critical emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  );

  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final androidDetails = AndroidNotificationDetails(
    'emergency_channel_critical',
    'Emergency Alerts',
    channelDescription: 'Emergency detected near you',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
    autoCancel: false,
    ongoing: true,
    visibility: NotificationVisibility.public,
    timeoutAfter: 60000,
  );

  final details = NotificationDetails(android: androidDetails);

  await notifications.show(
    emergency['id'].hashCode,
    '🚨 EMERGENCY NEARBY',
    '${emergency['type'] ?? 'General'} emergency within 500m! Tap to respond.',
    details,
    payload: emergency['id'].toString(),
  );

  // Start vibration
  await VibrationService().startEmergencyVibration();

  // Stop after 30 seconds
  Future.delayed(const Duration(seconds: 30), () {
    VibrationService().stopVibration();
  });

  developer.log('✅ Background notification shown');
}