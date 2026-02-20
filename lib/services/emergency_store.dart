import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

class EmergencyStore {
  static const String _lastLocationKey = 'last_known_location';
  static const String _activeEmergencyIdKey = 'active_emergency_id';

  static Future<void> saveLastLocation(LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLocationKey, jsonEncode({
      'lat': location.latitude,
      'lng': location.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  static Future<LatLng?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastLocationKey);
    if (data == null) return null;

    try {
      final json = jsonDecode(data);
      return LatLng(json['lat'], json['lng']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setActiveEmergency(String? emergencyId) async {
    final prefs = await SharedPreferences.getInstance();
    if (emergencyId == null) {
      await prefs.remove(_activeEmergencyIdKey);
    } else {
      await prefs.setString(_activeEmergencyIdKey, emergencyId);
    }
  }

  static Future<String?> getActiveEmergency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeEmergencyIdKey);
  }
}