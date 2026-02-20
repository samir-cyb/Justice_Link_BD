import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/emergency_store.dart';

class EmergencyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Distance _distanceCalc = const Distance();

  RealtimeChannel? _emergencyChannel;
  RealtimeChannel? _statusChannel;

  // --- SENDER METHODS ---

  Future<void> sendEmergencyAlert(LatLng location, String userId, String type) async {
    try {
      final point = 'POINT(${location.longitude} ${location.latitude})';

      await _supabase.from('emergencies').insert({
        'user_id': userId,
        'location': point,
        'location_geo': 'SRID=4326;$point',
        'status': 'active',
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      });

      developer.log('🚨 Emergency alert sent: $type at $location');
    } catch (e) {
      developer.log('❌ Failed to send emergency alert: $e');
      throw Exception('Failed to send emergency alert: $e');
    }
  }

  Future<void> updateEmergencyLocation(LatLng location, String userId) async {
    try {
      final point = 'POINT(${location.longitude} ${location.latitude})';

      await _supabase
          .from('emergencies')
          .update({
        'location': point,
        'location_geo': 'SRID=4326;$point',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId)
          .eq('status', 'active');

      developer.log('📍 Emergency location updated: $location');
    } catch (e) {
      developer.log('❌ Failed to update emergency location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  Future<void> endEmergency(String userId) async {
    try {
      await _supabase
          .from('emergencies')
          .update({
        'status': 'resolved',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId)
          .eq('status', 'active');

      developer.log('✅ Emergency ended for user: $userId');
    } catch (e) {
      developer.log('❌ Failed to end emergency: $e');
      throw Exception('Failed to end emergency: $e');
    }
  }

  // --- REALTIME SUBSCRIPTIONS ---

  Stream<List<Map<String, dynamic>>> subscribeToNearbyEmergencies(
      LatLng? userLocation,
      String selfUserId,
      ) {
    developer.log('📡 Setting up Realtime subscription...');
    developer.log('   - User location: $userLocation');
    developer.log('   - Self ID: $selfUserId');

    _emergencyChannel?.unsubscribe();

    _emergencyChannel = _supabase
        .channel('emergencies_channel')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'emergencies',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'status',
        value: 'active',
      ),
      callback: (payload) {
        developer.log('🔔 Realtime: New emergency inserted');
      },
    )
        .subscribe();

    return _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .asyncMap((emergencies) async {
      developer.log('📊 Raw emergencies from DB: ${emergencies.length}');

      if (userLocation == null) {
        developer.log('⚠️ No location provided, trying to get last known...');
        final lastLoc = await EmergencyStore.getLastLocation();
        if (lastLoc != null) {
          developer.log('   - Using stored location: $lastLoc');
          return _filterByDistance(emergencies, lastLoc, selfUserId);
        } else {
          developer.log('   - No location available! Showing all emergencies (except self)');
          return emergencies.where((e) => e['user_id'] != selfUserId).toList();
        }
      }

      return _filterByDistance(emergencies, userLocation, selfUserId);
    });
  }

  List<Map<String, dynamic>> _filterByDistance(
      List<Map<String, dynamic>> emergencies,
      LatLng userLocation,
      String selfUserId,
      ) {
    developer.log('🔍 Filtering by distance from: $userLocation');

    final filtered = emergencies.where((emergency) {
      if (emergency['user_id'] == selfUserId) {
        developer.log('   - Skipping self: ${emergency['user_id']}');
        return false;
      }

      final locationStr = emergency['location']?.toString() ?? '';
      final coords = _parsePointString(locationStr);

      if (coords == null) {
        developer.log('   - Failed to parse location: $locationStr');
        return false;
      }

      final emergencyLoc = LatLng(coords['lat']!, coords['lng']!);
      final distance = _distanceCalc.as(LengthUnit.Meter, userLocation, emergencyLoc);

      emergency['distance'] = distance;
      developer.log('   - Emergency at $emergencyLoc, distance: ${distance.toStringAsFixed(0)}m');

      return distance <= 1500;
    }).toList();

    developer.log('✅ Filtered: ${filtered.length} within 1500m');
    return filtered;
  }

  Stream<Map<String, dynamic>?> subscribeToEmergencyStatus(String emergencyId) {
    developer.log('👂 Listening to status changes for emergency: $emergencyId');

    _statusChannel?.unsubscribe();

    _statusChannel = _supabase
        .channel('emergency_status_$emergencyId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'emergencies',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: emergencyId,
      ),
      callback: (payload) {
        developer.log('🔄 Emergency status changed: ${payload.newRecord}');
      },
    )
        .subscribe();

    return _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .eq('id', emergencyId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  // --- PARSING METHODS ---

  Map<String, double>? _parsePointString(String pointStr) {
    try {
      developer.log('   - Parsing location: $pointStr');

      if (pointStr.length > 16 && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(pointStr)) {
        return _parseWKBHex(pointStr);
      }

      final cleanStr = pointStr.replaceAll(RegExp(r'SRID=\d+;'), '');

      final match = RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(cleanStr);
      if (match != null) {
        return {
          'lng': double.parse(match.group(1)!),
          'lat': double.parse(match.group(2)!),
        };
      }

      if (pointStr.contains('"lat"') || pointStr.contains('"latitude"')) {
        final json = jsonDecode(pointStr);
        return {
          'lat': (json['lat'] ?? json['latitude']).toDouble(),
          'lng': (json['lng'] ?? json['longitude'] ?? json['lon']).toDouble(),
        };
      }

      return null;
    } catch (e) {
      developer.log('   - Parse error: $e');
      return null;
    }
  }

  Map<String, double>? _parseWKBHex(String hex) {
    try {
      if (hex.length < 34) return null;

      final xHex = hex.substring(18, 34);
      final xBytes = _hexToBytes(xHex);
      final lng = _bytesToDouble(xBytes);

      final yHex = hex.substring(34, 50);
      final yBytes = _hexToBytes(yHex);
      final lat = _bytesToDouble(yBytes);

      developer.log('   - WKB parsed: lat=$lat, lng=$lng');

      return {'lat': lat, 'lng': lng};
    } catch (e) {
      developer.log('   - WKB parse error: $e');
      return null;
    }
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  double _bytesToDouble(List<int> bytes) {
    final buffer = ByteData(8);
    for (var i = 0; i < 8; i++) {
      buffer.setUint8(i, bytes[i]);
    }
    return buffer.getFloat64(0, Endian.little);
  }

  // --- DISPOSE METHOD ---

  void dispose() {
    developer.log('🧹 Disposing EmergencyService');
    _emergencyChannel?.unsubscribe();
    _statusChannel?.unsubscribe();
    _emergencyChannel = null;
    _statusChannel = null;
  }
}