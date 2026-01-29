import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- SENDER METHODS ---

  Future<void> sendEmergencyAlert(LatLng location, String userId, String type) async {
    try {
      await _supabase.from('emergencies').insert({
        'user_id': userId,
        'location': 'POINT(${location.longitude} ${location.latitude})',
        'status': 'active',
        'type': type, // Saved keyword
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to send emergency alert: $e');
    }
  }

  Future<void> updateEmergencyLocation(LatLng location, String userId) async {
    await _supabase
        .from('emergencies')
        .update({
      'location': 'POINT(${location.longitude} ${location.latitude})',
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('user_id', userId)
        .eq('status', 'active');
  }

  Future<void> endEmergency(String userId) async {
    await _supabase
        .from('emergencies')
        .update({'status': 'resolved'})
        .eq('user_id', userId)
        .eq('status', 'active');
  }

  // --- RESPONDER METHODS (NEW) ---

  // 1. "I Am Coming"
  Future<void> sendResponse(String emergencyId, String responderId) async {
    await _supabase.from('emergency_responses').insert({
      'emergency_id': emergencyId,
      'responder_id': responderId,
      'status': 'coming',
      'responded_at': DateTime.now().toIso8601String(),
    });
  }

  // 2. "Help Done"
  Future<void> markAsResolved(String emergencyId) async {
    await _supabase.from('emergencies').update({
      'status': 'resolved'
    }).eq('id', emergencyId);
  }

  // 3. "Fake Report"
  Future<void> markAsFake(String emergencyId, String userId) async {
    // Flag the report
    await _supabase.from('emergencies').update({
      'status': 'fake'
    }).eq('id', emergencyId);

    // Optional: Log the fake vote against the user
    // await _supabase.rpc('penalize_user', params: {'user_id': userId});
  }

  // Get active alerts for listening
  Stream<List<Map<String, dynamic>>> streamActiveEmergencies() {
    return _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .eq('status', 'active');
  }
}