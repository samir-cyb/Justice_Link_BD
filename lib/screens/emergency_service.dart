import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> sendEmergencyAlert(LatLng location, String userId) async {
    try {
      // Use proper WKT format for PostGIS
      await _supabase.from('emergencies').insert({
        'user_id': userId,
        'location': 'POINT(${location.longitude} ${location.latitude})',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify nearby users (500m radius)
      await _supabase.rpc('notify_nearby_users', params: {
        'user_id': userId,
        'longitude': location.longitude,
        'latitude': location.latitude,
        'radius': 500, // meters
      });
    } catch (e) {
      throw Exception('Failed to send emergency alert: $e');
    }
  }

  Future<void> updateEmergencyLocation(LatLng location, String userId) async {
    try {
      // Use proper WKT format for PostGIS
      await _supabase
          .from('emergencies')
          .update({
        'location': 'POINT(${location.longitude} ${location.latitude})',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId)
          .eq('status', 'active');
    } catch (e) {
      throw Exception('Failed to update emergency location: $e');
    }
  }

  Future<void> endEmergency(String userId) async {
    try {
      await _supabase
          .from('emergencies')
          .update({'status': 'resolved'})
          .eq('user_id', userId)
          .eq('status', 'active');
    } catch (e) {
      throw Exception('Failed to end emergency: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveEmergencies() async {
    try {
      final response = await _supabase
          .from('emergencies')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      throw Exception('Failed to get active emergencies: $e');
    }
  }

  Future<void> respondToEmergency(String emergencyId, String responderId) async {
    try {
      await _supabase.from('emergency_responses').insert({
        'emergency_id': emergencyId,
        'responder_id': responderId,
        'responded_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to respond to emergency: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyEmergencies(
      LatLng location,
      double radius,
      ) async {
    try {
      final response = await _supabase.rpc('get_nearby_emergencies', params: {
        'longitude': location.longitude,
        'latitude': location.latitude,
        'radius': radius,
      });

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      throw Exception('Failed to get nearby emergencies: $e');
    }
  }
}