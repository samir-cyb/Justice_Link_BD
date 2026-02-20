import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_store.dart';
import 'vibration_service.dart';

// 🔴 Alarm IDs
const int aggressiveAlarmId = 100;
const int normalAlarmId = 101;
const int fallbackAlarmId = 102;

/// 🔴 HIGH-FREQUENCY BACKGROUND SERVICE using AlarmManager
/// Replaces WorkManager for better Flutter 3.38 compatibility
class AggressiveBackgroundService {
  static final AggressiveBackgroundService _instance = AggressiveBackgroundService._internal();
  factory AggressiveBackgroundService() => _instance;
  AggressiveBackgroundService._internal();

  bool _isInitialized = false;
  bool _isAggressiveMode = false;
  Timer? _foregroundTimer;

  static const String _supabaseUrl = 'https://nlzepbocfljoreltzzup.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw';

  Future<void> initialize() async {
    if (_isInitialized) return;
    developer.log('🔧 AggressiveBackgroundService: Initializing...');

    // AlarmManager is already initialized in main.dart
    _isInitialized = true;
    developer.log('✅ AggressiveBackgroundService: Initialized');
  }

  /// Start NORMAL mode (15 min intervals) using AlarmManager
  Future<void> startNormalMonitoring() async {
    developer.log('📡 Starting NORMAL monitoring (15 min) - AlarmManager');
    _isAggressiveMode = false;
    _foregroundTimer?.cancel();

    try {
      // Cancel existing alarms
      await AndroidAlarmManager.cancel(aggressiveAlarmId);
      await AndroidAlarmManager.cancel(fallbackAlarmId);

      // Schedule periodic alarm (15 minutes)
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        normalAlarmId,
        _alarmCallback,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      developer.log('✅ Normal monitoring scheduled with AlarmManager');
    } catch (e) {
      developer.log('❌ Error scheduling normal monitoring: $e');
    }
  }

  /// Start AGGRESSIVE mode (15-30 second intervals when app is active)
  /// Falls back to 15-min AlarmManager when app is killed
  Future<void> startAggressiveMonitoring() async {
    if (_isAggressiveMode) return;

    developer.log('🚨 STARTING AGGRESSIVE MONITORING');
    _isAggressiveMode = true;

    try {
      // Cancel normal alarm
      await AndroidAlarmManager.cancel(normalAlarmId);

      // For active app: Use foreground timer (15-30 seconds)
      if (Platform.isAndroid) {
        _startForegroundAggressivePolling();
      }

      // 🔴 CRITICAL: Fallback alarm every 15 min when app is killed
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        fallbackAlarmId,
        _alarmCallback,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      developer.log('✅ Aggressive monitoring started with AlarmManager fallback');
    } catch (e) {
      developer.log('❌ Error in aggressive monitoring: $e');
    }
  }

  /// Stop aggressive mode, return to normal
  Future<void> stopAggressiveMonitoring() async {
    developer.log('🛑 Stopping aggressive monitoring');
    _isAggressiveMode = false;
    _foregroundTimer?.cancel();

    try {
      await AndroidAlarmManager.cancel(aggressiveAlarmId);
      await AndroidAlarmManager.cancel(fallbackAlarmId);
      await startNormalMonitoring();
    } catch (e) {
      developer.log('❌ Error stopping aggressive monitoring: $e');
    }
  }

  void _startForegroundAggressivePolling() {
    _foregroundTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isAggressiveMode) {
        timer.cancel();
        return;
      }
      await _checkForEmergencies(isAggressive: true);
    });
    developer.log('✅ Foreground aggressive polling started (15s interval)');
  }

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseKey => _supabaseKey;
}

/// 🔴 TOP-LEVEL CALLBACK for AlarmManager (must be static or top-level)
@pragma('vm:entry-point')
void _alarmCallback() async {
  // CRITICAL: Initialize Flutter bindings for background isolate
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('🔔 AlarmManager triggered at ${DateTime.now()}');

  // Re-initialize Supabase in this isolate with CORRECT URL
  try {
    await Supabase.initialize(
      url: 'https://nlzepbocfljoreltzzup.supabase.co', // NO TRAILING SPACE
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw',
    );
    // 🔴 FIX: Try to get fresh location first, fallback to stored
    LatLng? location;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      location = LatLng(position.latitude, position.longitude);
      await EmergencyStore.saveLastLocation(location);
      developer.log('   - Got fresh location: $location');
    } catch (e) {
      location = await EmergencyStore.getLastLocation();
      developer.log('   - Using stored location: $location');
    }

    if (location == null) {
      developer.log('❌ No location available for background check');
      return;
    }
    await _checkForEmergencies(isAggressive: false);
  } catch (e) {
    developer.log('❌ Supabase init failed in alarm: $e');
  }
}

/// Check for emergencies
Future<void> _checkForEmergencies({bool isAggressive = false}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_check_time', DateTime.now().toIso8601String());

  final checkType = isAggressive ? 'AGGRESSIVE' : 'NORMAL';
  developer.log('🔍 [$checkType] Checking for emergencies...');

  try {
    await Supabase.initialize(
      url: AggressiveBackgroundService.supabaseUrl,
      anonKey: AggressiveBackgroundService.supabaseKey,
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

    developer.log('   - Checking 500m radius around $location');

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

      final maxAgeSeconds = isAggressive ? 600 : 300;

      if (secondsSinceCreated < maxAgeSeconds) {
        developer.log('🚨 EMERGENCY FOUND! Age: ${secondsSinceCreated}s');
        await _showEmergencyNotification(latest);

        await prefs.setInt('aggressive_mode_until',
            DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch);
      } else {
        developer.log('   - Emergency too old ($secondsSinceCreated s), ignoring');
      }
    } else {
      developer.log('   - No emergencies found');
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

  await VibrationService().startEmergencyVibration();

  Future.delayed(const Duration(seconds: 30), () {
    VibrationService().stopVibration();
  });

  developer.log('✅ Background notification shown');
}