import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_store.dart';
import 'vibration_service.dart';

class ForegroundLocationService {
  static final ForegroundLocationService _instance = ForegroundLocationService._internal();
  factory ForegroundLocationService() => _instance;
  ForegroundLocationService._internal();

  static const String _emergencyIdKey = 'emergency_id';
  static const String _userIdKey = 'user_id';
  static const String _emergencyTypeKey = 'emergency_type';

  bool _isRunning = false;
  String? _emergencyId;
  String? _userId;

  bool get isRunning => _isRunning;

  // 🔴 FIXED: Removed trailing space
  static const String _supabaseUrl = 'https://nlzepbocfljoreltzzup.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5semVwYm9jZmxqb3JlbHR6enVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2OTc3NzAsImV4cCI6MjA2NjI3Mzc3MH0.WdUlvCpG4D2L3CANvdNAENlOm1K0feKIi-zT5vNFyZw';

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    developer.log('🔧 [FGS] Initializing foreground service...');

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_persistent_channel',
      'Emergency Alert Service',
      description: 'Keeps app running to detect nearby emergencies',

      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onServiceStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'emergency_persistent_channel',
        initialNotificationTitle: 'Justice Link - Emergency Ready',
        initialNotificationContent: 'Running to detect nearby emergencies',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onServiceStart,
        onBackground: onIosBackground,
      ),
    );

    developer.log('✅ [FGS] Foreground service initialized');
  }

  Future<void> startEmergencyService({
    required String emergencyId,
    required String userId,
    required LatLng initialLocation,
    required String emergencyType,
  }) async {
    if (!Platform.isAndroid) {
      _isRunning = true;
      return;
    }

    if (_isRunning) {
      developer.log('⚠️ [FGS] Service already running, stopping first...');
      await stopService();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    developer.log('🚨 [FGS] STARTING EMERGENCY FOREGROUND SERVICE');
    developer.log('   - Emergency ID: $emergencyId');
    developer.log('   - User ID: $userId');
    developer.log('   - Initial Location: ${initialLocation.latitude}, ${initialLocation.longitude}');
    developer.log('   - Type: $emergencyType');

    _emergencyId = emergencyId;
    _userId = userId;

    final service = FlutterBackgroundService();

    final started = await service.startService();
    developer.log('   - Service start result: $started');

    await Future.delayed(const Duration(milliseconds: 500));

    const supabaseUrl = _supabaseUrl;
    const supabaseKey = _supabaseKey;

    service.invoke('startEmergency', {
      _emergencyIdKey: emergencyId,
      _userIdKey: userId,
      'lat': initialLocation.latitude,
      'lng': initialLocation.longitude,
      _emergencyTypeKey: emergencyType,
      'supabase_url': supabaseUrl,
      'supabase_key': supabaseKey,
    });

    _isRunning = true;
    developer.log('✅ [FGS] Emergency foreground service started');
  }

  Future<void> stopService() async {
    if (!Platform.isAndroid) {
      _isRunning = false;
      return;
    }

    if (!_isRunning) return;

    developer.log('🛑 [FGS] STOPPING EMERGENCY FOREGROUND SERVICE');

    final service = FlutterBackgroundService();
    service.invoke('stopEmergency');

    _isRunning = false;
    _emergencyId = null;
    _userId = null;

    developer.log('✅ [FGS] Emergency foreground service stopped');
  }

  static void updateNotification(String title, String content) {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {


  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('🔔 [FGS] Foreground service isolate started');
  developer.log('   - Service type: ${service.runtimeType}');

  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Must call setAsForegroundService IMMEDIATELY (within 5 seconds)
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    developer.log('   - ✅ Set as foreground service immediately');
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      developer.log('[FGS] Received setAsForeground');
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      developer.log('[FGS] Received setAsBackground');
      service.setAsBackgroundService();
    });
  }

  // Handle service restart
  service.on('startEmergency').listen((event) async {
    developer.log('[FGS] Received startEmergency event: $event');
    await _handleEmergencyStart(service, event);
  });

  // Check if we have pending emergency data (from restart)
  final prefs = await SharedPreferences.getInstance();
  final pendingEmergencyId = prefs.getString('pending_emergency_id');

  if (pendingEmergencyId != null) {
    developer.log('🔄 [FGS] Service restarted with pending emergency: $pendingEmergencyId');

    final userId = prefs.getString('pending_user_id') ?? '';
    final lat = prefs.getDouble('pending_lat') ?? 0;
    final lng = prefs.getDouble('pending_lng') ?? 0;
    final type = prefs.getString('pending_type') ?? 'General';

    developer.log('   - Restored location: $lat, $lng');
    developer.log('   - Restored type: $type');

    await _handleEmergencyStart(service, {
      'emergency_id': pendingEmergencyId,
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'emergency_type': type,
      'supabase_url': ForegroundLocationService._supabaseUrl,
      'supabase_key': ForegroundLocationService._supabaseKey,
    });
  } else {
    developer.log('[FGS] No pending emergency found in prefs');
  }

  // Keep alive heartbeat
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        developer.log('💓 [FGS] Service heartbeat - still alive');

        // 🔴 DEBUG: Check location store status
        final location = await EmergencyStore.getLastLocation();
        developer.log('   - EmergencyStore location: $location');
      } else {
        developer.log('⚠️ [FGS] Service is NOT in foreground mode!');
      }
    }
  });
}

Future<void> _handleEmergencyStart(ServiceInstance service, Map<String, dynamic>? event) async {
  developer.log('📥 [FGS] Handling emergency start');
  developer.log('   - Event data: $event');

  if (event == null) {
    developer.log('❌ [FGS] Error: event is null');
    return;
  }

  final emergencyId = event['emergency_id'] as String?;
  final userId = event['user_id'] as String?;
  final lat = event['lat'] as double?;
  final lng = event['lng'] as double?;
  final emergencyType = event['emergency_type'] as String?;
  final supabaseUrl = event['supabase_url'] as String?;
  final supabaseKey = event['supabase_key'] as String?;

  developer.log('   - Parsed: ID=$emergencyId, User=$userId, Lat=$lat, Lng=$lng');

  if (emergencyId == null || userId == null || lat == null || lng == null) {
    developer.log('❌ [FGS] Error: Missing required data');
    return;
  }

  // Save to prefs for restart persistence
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_emergency_id', emergencyId);
  await prefs.setString('pending_user_id', userId);
  await prefs.setDouble('pending_lat', lat);
  await prefs.setDouble('pending_lng', lng);
  await prefs.setString('pending_type', emergencyType ?? 'General');
  developer.log('   - ✅ Saved to prefs for persistence');

  // 🔴 CRITICAL: Save initial location to EmergencyStore immediately
  final initialLocation = LatLng(lat, lng);
  await EmergencyStore.saveLastLocation(initialLocation);
  developer.log('   - ✅ Initial location saved to EmergencyStore: $lat, $lng');

  // Ensure still foreground
  if (service is AndroidServiceInstance) {
    if (!await service.isForegroundService()) {
      developer.log('   - Setting as foreground service...');
      await service.setAsForegroundService();
    }
  }

  // Initialize Supabase
  try {
    if (supabaseUrl != null && supabaseKey != null) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      developer.log('   - ✅ Supabase initialized');
    }
  } catch (e) {
    developer.log('❌ [FGS] Supabase init error: $e');
  }

  Timer? emergencyCheckTimer;
  bool isCheckingEmergencies = false;
  String? lastNotifiedEmergencyId;

  // Location settings
  final locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 5,
    intervalDuration: const Duration(seconds: 3),
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationText: 'Emergency active: $emergencyType',
      notificationTitle: 'Justice Link SOS',
      enableWakeLock: true,
    ),
  );

  developer.log('   - Starting position stream...');

  StreamSubscription<Position>? positionStream;
  positionStream = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position position) async {
    final location = LatLng(position.latitude, position.longitude);

    developer.log('📍 [FGS] Location update: ${position.latitude}, ${position.longitude}');

    // 🔴 CRITICAL: Save to EmergencyStore for background access
    await EmergencyStore.saveLastLocation(location);
    developer.log('   - ✅ Saved to EmergencyStore');

    // Update notification
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'Justice Link SOS - $emergencyType',
          content: 'Loc: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        );
      }
    }

    // Update database
    try {
      final supabaseClient = Supabase.instance.client;
      if (supabaseClient.auth.currentUser != null) {
        await supabaseClient.from('emergencies').update({
          'location': 'POINT(${location.longitude} ${location.latitude})',
          'location_geo': 'SRID=4326;POINT(${location.longitude} ${location.latitude})',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', emergencyId);
        developer.log('   - ✅ Location updated in DB');
      }
    } catch (e) {
      developer.log('   - ❌ DB update failed: $e');
    }
  }, onError: (e) {
    developer.log('❌ [FGS] Position stream error: $e');
  });

  developer.log('   - ✅ Position stream started');

  // 🔴 EMERGENCY CHECK TIMER - Every 5 seconds
  developer.log('   - Starting emergency check timer (5 sec interval)...');

  emergencyCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (isCheckingEmergencies) {
      developer.log('⏳ [FGS] Emergency check already in progress, skipping');
      return;
    }

    isCheckingEmergencies = true;
    developer.log('🔍 [FGS] === EMERGENCY CHECK START ===');

    try {
      // 🔴 DEBUG: Check Supabase
      final supabaseClient = Supabase.instance.client;
      final currentUser = supabaseClient.auth.currentUser;

      if (currentUser == null) {
        developer.log('   - ❌ No user logged in, skipping check');
        isCheckingEmergencies = false;
        return;
      }
      developer.log('   - User: ${currentUser.id}');

      // 🔴 DEBUG: Check location from store
      final location = await EmergencyStore.getLastLocation();
      developer.log('   - Location from store: $location');

      if (location == null) {
        developer.log('   - ❌ No location available, skipping check');

        // 🔴 TRY TO GET FRESH LOCATION
        developer.log('   - Attempting fresh location...');
        try {
          final freshPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 3),
          );
          final freshLocation = LatLng(freshPosition.latitude, freshPosition.longitude);
          await EmergencyStore.saveLastLocation(freshLocation);
          developer.log('   - ✅ Fresh location obtained: $freshLocation');
          // Continue with fresh location...
        } catch (e) {
          developer.log('   - ❌ Fresh location failed: $e');
          isCheckingEmergencies = false;
          return;
        }
      }

      developer.log('   - Checking 500m radius around: ${location!.latitude}, ${location.longitude}');

      final response = await supabaseClient.rpc(
        'get_nearby_emergencies_except_self',
        params: {
          'user_lat': location.latitude,
          'user_lng': location.longitude,
          'self_user_id': currentUser.id,
          'radius_meters': 500,
        },
      );

      developer.log('   - RPC response: $response');

      if (response != null && (response as List).isNotEmpty) {
        final emergencies = response as List;
        developer.log('   - ✅ Found ${emergencies.length} emergencies');

        final latest = emergencies.first;
        final createdAt = DateTime.tryParse(latest['created_at'] ?? '') ?? DateTime.now();
        final secondsSinceCreated = DateTime.now().difference(createdAt).inSeconds;
        final distance = latest['distance'] as double?;

        developer.log('   - Latest: ID=${latest['id']}, Type=${latest['type']}, Distance=${distance}m, Age=${secondsSinceCreated}s');

        // Alert if within 5 minutes
        if (secondsSinceCreated < 300) {
          final currentEmergencyId = latest['id'].toString();

          if (lastNotifiedEmergencyId != currentEmergencyId) {
            lastNotifiedEmergencyId = currentEmergencyId;
            developer.log('🚨 [FGS] >>> NEW EMERGENCY DETECTED <<<');
            developer.log('   - Notifying user...');
            await _showBackgroundNotification(latest);
            developer.log('   - ✅ Notification shown');
          } else {
            developer.log('   - Already notified for this emergency');
          }
        } else {
          developer.log('   - Emergency too old ($secondsSinceCreated seconds), ignoring');
        }
      } else {
        developer.log('   - No emergencies found in radius');
      }
    } catch (e, stack) {
      developer.log('❌ [FGS] Emergency check error: $e');
      developer.log('Stack: $stack');
    } finally {
      isCheckingEmergencies = false;
      developer.log('🔍 [FGS] === EMERGENCY CHECK END ===');
    }
  });

  // Handle stop
  service.on('stopEmergency').listen((event) async {
    developer.log('📥 [FGS] Received stopEmergency');

    await prefs.remove('pending_emergency_id');
    await prefs.remove('pending_user_id');
    await prefs.remove('pending_lat');
    await prefs.remove('pending_lng');
    await prefs.remove('pending_type');

    emergencyCheckTimer?.cancel();
    await positionStream?.cancel();

    developer.log('   - ✅ Cleaned up, stopping service');
    service.stopSelf();
  });

  // Handle notification update
  service.on('updateNotification').listen((event) async {
    developer.log('[FGS] Received updateNotification: $event');
    if (event != null && service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: event['title'] ?? 'Justice Link',
          content: event['content'] ?? '',
        );
      }
    }
  });

  developer.log('✅ [FGS] _handleEmergencyStart completed');
}

@pragma('vm:entry-point')
Future<void> _showBackgroundNotification(Map<String, dynamic> emergency) async {
  developer.log('🔔 [FGS] Showing background notification');
  developer.log('   - Emergency: ${emergency['id']}, Type: ${emergency['type']}');

  final notifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: androidSettings));

  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'emergency_service_channel',
    'Emergency Service Alerts',
    description: 'Alerts from background service',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  );

  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final androidDetails = AndroidNotificationDetails(
    'emergency_service_channel',
    'Emergency Service Alerts',
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

  final notificationId = emergency['id'].hashCode;
  final title = '🚨 EMERGENCY NEARBY';
  final body = '${emergency['type'] ?? 'General'} emergency within 500m! Tap to respond.';

  await notifications.show(
    notificationId,
    title,
    body,
    details,
    payload: emergency['id'].toString(),
  );

  await VibrationService().startEmergencyVibration();

  Future.delayed(const Duration(seconds: 30), () {
    VibrationService().stopVibration();
  });

  developer.log('   - ✅ Notification shown: ID=$notificationId');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}