import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class NirbaconService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Submit a crime report to nirbacon_crime table
  Future<Map<String, dynamic>> submitCrimeReport({
    required String crimeType,
    required String description,
    required LatLng location,
    String? staticArea,
    String? dynamicArea,
    List<String>? imageUrls,
    List<String>? videoUrls,
    bool isLiveStream = false,
    String? liveStreamUrl,
  }) async {
    try {
      debugPrint('📝 Submitting Nirbacon crime report...');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ User not logged in');
        return {'success': false, 'error': 'User not logged in'};
      }

      debugPrint('🔍 User ID: $userId');
      debugPrint('🔍 Crime Type: $crimeType');
      debugPrint('🔍 Location: ${location.latitude}, ${location.longitude}');
      debugPrint('🔍 Static Area: $staticArea');
      debugPrint('🔍 Dynamic Area: $dynamicArea');
      debugPrint('🔍 Is Live Stream: $isLiveStream');

      final reportData = {
        'user_id': userId,
        'crime_type': crimeType,
        'description': description,
        'location': 'POINT(${location.longitude} ${location.latitude})',
        'area_static': staticArea,
        'area_dynamic': dynamicArea,
        'images': imageUrls ?? [],
        'videos': videoUrls ?? [],
        'is_live_stream': isLiveStream,
        'live_stream_url': liveStreamUrl,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'active',  // ✅ FIXED: Was 'streaming'/'reported', must be 'active', 'resolved', or 'under_review'
      };

      // 🔥🔥🔥 CRITICAL DEBUG PRINTS
      debugPrint('🔥🔥🔥 ====================================');
      debugPrint('🔥🔥🔥 FINAL REPORT DATA: $reportData');
      debugPrint('🔥🔥🔥 STATUS VALUE: "${reportData['status']}"');
      debugPrint('🔥🔥🔥 STATUS TYPE: ${reportData['status'].runtimeType}');
      debugPrint('🔥🔥🔥 ====================================');

      final response = await _supabase
          .from('nirbacon_crime')
          .insert(reportData)
          .select()
          .single();

      debugPrint('✅ Crime report submitted: ${response['id']}');

      return {
        'success': true,
        'report_id': response['id'],
        'data': response,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error submitting crime report: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Upload media file to Supabase Storage
  Future<String?> uploadMedia(XFile file, String folder) async {
    try {
      final fileExt = path.extension(file.name);
      final fileName = '${_uuid.v4()}$fileExt';
      final filePath = 'nirbacon/$folder/$fileName';

      debugPrint('🔍 Uploading media: $fileName to $folder');

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await _supabase.storage
            .from('reports')
            .uploadBinary(filePath, bytes);
      } else {
        await _supabase.storage
            .from('reports')
            .upload(filePath, File(file.path));
      }

      final url = _supabase.storage
          .from('reports')
          .getPublicUrl(filePath);

      debugPrint('✅ Media uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading media: $e');
      return null;
    }
  }

  /// Get all crime reports
  Future<List<Map<String, dynamic>>> getCrimeReports({
    String? crimeType,
    int limit = 100,
  }) async {
    try {
      debugPrint('🔍 Fetching crime reports...');

      PostgrestFilterBuilder query = _supabase
          .from('nirbacon_crime')
          .select('*');

      if (crimeType != null && crimeType != 'All') {
        query = query.eq('crime_type', crimeType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('✅ Fetched ${response.length} reports');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching crime reports: $e');
      return [];
    }
  }

  /// Get crime reports by area
  Future<List<Map<String, dynamic>>> getCrimeReportsByArea(String area) async {
    try {
      debugPrint('🔍 Fetching reports for area: $area');

      final response = await _supabase
          .from('nirbacon_crime')
          .select('*')
          .or('area_static.eq.$area,area_dynamic.eq.$area')
          .order('created_at', ascending: false);

      debugPrint('✅ Fetched ${response.length} area reports');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching area reports: $e');
      return [];
    }
  }

  /// Update live stream status
  Future<bool> updateLiveStreamStatus(String reportId, String status) async {
    try {
      debugPrint('🔍 Updating stream status for $reportId to: $status');

      await _supabase
          .from('nirbacon_crime')
          .update({'live_stream_status': status})
          .eq('id', reportId);

      debugPrint('✅ Stream status updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating stream status: $e');
      return false;
    }
  }
}