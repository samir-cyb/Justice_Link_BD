import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:justice_link_user/screens/emergency_location_card_style.dart';
import 'package:intl/intl.dart';
import 'package:hex/hex.dart';
import 'package:audioplayers/audioplayers.dart';

class EmergencySupportScreen extends StatefulWidget {
  final String currentUserId;

  const EmergencySupportScreen({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<EmergencySupportScreen> createState() => _EmergencySupportScreenState();
}

class _EmergencySupportScreenState extends State<EmergencySupportScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmergencyService _emergencyService = EmergencyService();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAlarm = false;
  List<Map<String, dynamic>> _activeEmergencies = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
    _fetchActiveEmergencies();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> _playEmergencyAlarm() async {
    if (_isPlayingAlarm) return;

    setState(() => _isPlayingAlarm = true);

    try {
      await _audioPlayer.play(AssetSource('sounds/emergency_alarm.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      print('Error playing alarm: $e');
      setState(() => _isPlayingAlarm = false);
    }
  }

  Future<void> _stopEmergencyAlarm() async {
    if (!_isPlayingAlarm) return;

    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping alarm: $e');
    } finally {
      setState(() => _isPlayingAlarm = false);
    }
  }

  Future<void> _fetchActiveEmergencies() async {
    try {
      final emergencies = await _emergencyService.getActiveEmergencies();
      setState(() {
        _activeEmergencies = List<Map<String, dynamic>>.from(emergencies);
        _isLoading = false;

        print('Fetched ${_activeEmergencies.length} emergencies:');
        for (var emergency in _activeEmergencies) {
          print('Emergency ID: ${emergency['id']}');
          print('Location data: ${emergency['location']}');
          print('Type: ${emergency['location'].runtimeType}');
        }
      });

      for (final emergency in _activeEmergencies) {
        if (emergency['user_id'] != widget.currentUserId &&
            emergency['status'] == 'active') {
          _showEmergencyNotification();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching emergencies: $e');
    }
  }

  void _setupRealtimeUpdates() {
    _channel = _supabase.channel('emergency_updates');

    _channel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'emergencies',
      callback: (payload) {
        _handleRealtimeUpdate(payload);
      },
    ).subscribe();
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          final newRecord = payload.newRecord;
          if (newRecord != null &&
              newRecord['user_id'] != widget.currentUserId &&
              newRecord['status'] == 'active') {
            _showEmergencyNotification();
            setState(() {
              _activeEmergencies.add(newRecord);
            });
          }
          break;

        case PostgresChangeEvent.update:
          final newRecord = payload.newRecord;
          if (newRecord != null) {
            final index = _activeEmergencies
                .indexWhere((e) => e['id'] == newRecord['id']);
            if (index != -1) {
              setState(() {
                _activeEmergencies[index] = newRecord;
              });
            }
          }
          break;

        case PostgresChangeEvent.delete:
          final oldRecord = payload.oldRecord;
          if (oldRecord != null) {
            setState(() {
              _activeEmergencies.removeWhere((e) => e['id'] == oldRecord['id']);
            });
          }
          break;

        default:
          break;
      }
    } catch (e) {
      print('Error handling realtime update: $e');
    }
  }

  Future<void> _showEmergencyNotification() async {
    await _playEmergencyAlarm();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'Emergency Alert!',
      'Someone nearby needs help!',
      platformChannelSpecifics,
    );
  }

  Future<void> _respondToEmergency(String emergencyId) async {
    try {
      await _emergencyService.respondToEmergency(
        emergencyId,
        widget.currentUserId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are responding to this emergency')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to respond: ${e.toString()}')),
      );
    }
  }

  LatLng _parseWkbLocation(String wkb) {
    try {
      print('Parsing WKB location: $wkb');
      final bytes = HEX.decode(wkb);
      final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);

      final endian = byteData.getUint8(0) == 1 ? Endian.little : Endian.big;
      final type = byteData.getUint32(1, endian);
      final hasSrid = (type & 0x20000000) != 0;

      int offset = 5;

      if (hasSrid) {
        final srid = byteData.getUint32(offset, endian);
        print('SRID: $srid');
        offset += 4;
      }

      final longitude = byteData.getFloat64(offset, endian);
      offset += 8;
      final latitude = byteData.getFloat64(offset, endian);

      print('Parsed WKB: Latitude=$latitude, Longitude=$longitude');
      return LatLng(latitude, longitude);
    } catch (e) {
      print('Error parsing WKB location: $e');
      return const LatLng(0, 0);
    }
  }

  LatLng _parseLocation(dynamic location) {
    try {
      print('Parsing location: $location (type: ${location.runtimeType})');

      if (location is String) {
        if (location.startsWith('010100')) {
          return _parseWkbLocation(location);
        }
      }

      print('Unhandled location format');
      return const LatLng(0, 0);
    } catch (e) {
      print('Error parsing location: $e');
      return const LatLng(0, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.5,
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          padding: const EdgeInsets.only(top: 80),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activeEmergencies.isEmpty
              ? const Center(
            child: Text(
              'No active emergencies',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _activeEmergencies.length,
            itemBuilder: (context, index) {
              final emergency = _activeEmergencies[index];
              final location = emergency['location'];
              final parsedLocation = _parseLocation(location);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EmergencyLocationCard(
                  location: parsedLocation,
                  timestamp: DateTime.tryParse(
                      emergency['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                  userId: emergency['user_id']?.toString() ?? 'Unknown',
                  onRespond: () => _respondToEmergency(
                      emergency['id']?.toString() ?? ''),
                  isOwnEmergency:
                  emergency['user_id'] == widget.currentUserId,
                ),
              );
            },
          ),
        ),
        if (_isPlayingAlarm)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _stopEmergencyAlarm,
              backgroundColor: Colors.red,
              child: const Icon(Icons.notifications_off),
            ),
          ),
      ],
    );
  }
}