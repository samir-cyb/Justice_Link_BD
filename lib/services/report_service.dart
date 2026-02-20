import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'image_processor.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImageProcessor _imageProcessor = ImageProcessor();

  // Pre-upload image verification (client-side only)
  Future<Map<String, dynamic>> verifyImageBeforeUpload({
    required XFile imageFile,
    required LatLng userLocation,
    String? reportDescription,
  }) async {
    try {
      debugPrint('🔍 Starting pre-upload image verification...');

      final result = await _imageProcessor.processImage(
        imageFile: imageFile,
        userLocation: userLocation,
        reportId: 'pre_upload_${DateTime.now().millisecondsSinceEpoch}',
        reportDescription: reportDescription,
      );

      debugPrint('📊 Verification result: ${result['status']}');

      if (result['status'] == 'rejected') {
        return {
          'status': 'rejected',
          'reasons': result['reasons'] is List ? List<String>.from(result['reasons']) : ['Image verification failed'],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': false,
        };
      } else if (result['status'] == 'needs_review') {
        return {
          'status': 'needs_review',
          'reasons': result['reasons'] is List ? List<String>.from(result['reasons']) : ['Image needs human review'],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': true,
        };
      } else {
        return {
          'status': 'approved',
          'reasons': [],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': true,
        };
      }
    } catch (e) {
      debugPrint('❌ Pre-upload verification error: $e');
      return {
        'status': 'error',
        'reasons': ['Verification error: $e'],
        'should_upload': false,
      };
    }
  }

  // Submit report with verification - FIXED for your schema
  Future<Map<String, dynamic>> submitReportWithVerification({
    required String description,
    required LatLng location,
    required String area,
    required String crimeCategory,
    required List<XFile> images,
    List<String> videos = const [],
    required String userId,
    String? audioUrl,
    bool isEmergency = false,
    bool runImageVerification = true,
  }) async {
    try {
      debugPrint('📝 Starting report submission...');
      debugPrint('📹 Videos to attach: ${videos.length}');
      debugPrint('🔍 User ID: $userId');
      debugPrint('🔍 Crime Category: $crimeCategory');
      debugPrint('🔍 Area: $area');
      debugPrint('🔍 Location: ${location.latitude}, ${location.longitude}');

      List<Map<String, dynamic>> imageResults = [];
      List<String> imageUrls = [];

      if (runImageVerification && images.isNotEmpty) {
        for (final image in images) {
          debugPrint('🖼️ Processing image: ${image.name}');

          final verificationResult = await verifyImageBeforeUpload(
            imageFile: image,
            userLocation: location,
            reportDescription: description,
          );

          if (verificationResult['status'] == 'rejected') {
            return {
              'success': false,
              'error': 'Image verification failed',
              'details': {
                'step': 'image_verification',
                'reasons': verificationResult['reasons'] is List ? List<String>.from(verificationResult['reasons']) : [],
                'image_name': image.name,
              },
              'blocked_reason': 'Image failed verification checks',
            };
          }

          imageResults.add(verificationResult);
        }
      } else {
        debugPrint('⚠️ Skipping image verification');
      }

      // ✅ FIXED: Only include columns that exist in your table
      final locationText = 'POINT(${location.longitude} ${location.latitude})';

      final reportData = {
        'description': description,
        'location': locationText,
        'area_static': area,              // ✅ Fixed: was 'area'
        'crime_type': crimeCategory,
        'user_id': userId,
        'status': 'active',                // ✅ Fixed: required by CHECK constraint
        'created_at': DateTime.now().toIso8601String(),
        // REMOVED: is_emergency, audio_url, votes, user_votes,
        //          verification_status, image_verified, is_sensitive, sensitive_views
      };

      // 🔥🔥🔥 CRITICAL DEBUG PRINTS - Check exactly what's being sent
      debugPrint('🔥🔥🔥 ====================================');
      debugPrint('🔥🔥🔥 FINAL REPORT DATA MAP: $reportData');
      debugPrint('🔥🔥🔥 STATUS VALUE: "${reportData['status']}"');
      debugPrint('🔥🔥🔥 STATUS RUNTIME TYPE: ${reportData['status'].runtimeType}');
      debugPrint('🔥🔥🔥 ALL KEYS: ${reportData.keys.toList()}');
      debugPrint('🔥🔥🔥 JSON ENCODED: ${jsonEncode(reportData)}');
      debugPrint('🔥🔥🔥 ====================================');
      final allowedStatuses = ['active', 'resolved', 'under_review'];
      final currentStatus = reportData['status'] as String?;
      debugPrint('🔥🔥🔥 IS STATUS ALLOWED? ${allowedStatuses.contains(currentStatus)}');
      debugPrint('🔥🔥🔥 STATUS LENGTH: ${currentStatus?.length}');
      debugPrint('🔥🔥🔥 STATUS CODE UNITS: ${currentStatus?.codeUnits}');

      debugPrint('📊 About to insert to nirbacon_crime...');

      debugPrint('📊 Report data: $reportData');

      final reportResponse = await _supabase
          .from('nirbacon_crime')
          .insert(reportData)
          .select('id')
          .single();

      final reportId = reportResponse['id'] as String;

      debugPrint('📄 Report created with ID: $reportId');

      // Upload images
      for (int i = 0; i < images.length; i++) {
        final image = images[i];

        try {
          final imageUrl = await _imageProcessor.uploadImageToStorage(
            imageFile: image,
            reportId: reportId,
            userId: userId,
          );

          if (imageUrl.isNotEmpty) {
            imageUrls.add(imageUrl);

            if (runImageVerification) {
              final verificationData = i < imageResults.length
                  ? Map<String, dynamic>.from(imageResults[i])
                  : <String, dynamic>{};
              await _callVerificationEdgeFunction(
                reportId: reportId,
                imageUrl: imageUrl,
                verificationData: verificationData,
                userId: userId,
                crimeCategory: crimeCategory,
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Error uploading image ${image.name}: $e');
        }
      }

      // ✅ FIXED: Update correct table
      final updateData = <String, dynamic>{};
      if (imageUrls.isNotEmpty) {
        updateData['images'] = imageUrls;
      }
      if (videos.isNotEmpty) {
        updateData['videos'] = videos;
        debugPrint('📹 Attaching ${videos.length} videos to report');
      }

      if (updateData.isNotEmpty) {
        await _supabase
            .from('nirbacon_crime')           // ✅ Fixed: was 'reports'
            .update(updateData)
            .eq('id', reportId);
      }

      return {
        'success': true,
        'report_id': reportId,
        'message': 'Report submitted successfully',
        'image_count': images.length,
        'verified_images': imageUrls.length,
        'verification_performed': runImageVerification,
        'video_count': videos.length,
      };
    } catch (e) {
      debugPrint('❌ Report submission error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Call edge function for server-side verification
  Future<void> _callVerificationEdgeFunction({
    required String reportId,
    required String imageUrl,
    required Map<String, dynamic> verificationData,
    required String userId,
    required String crimeCategory,
  }) async {
    if (imageUrl.isEmpty) {
      debugPrint('❌ Cannot call verification without image URL');
      return;
    }

    try {
      final response = await _supabase.functions.invoke(
        'verify-image',
        body: {
          'reportId': reportId,
          'imageUrl': imageUrl,
          'verificationData': verificationData,
          'userId': userId,
          'crimeCategory': crimeCategory,
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Edge function result: ${response.data['overall_status']}');
      } else {
        debugPrint('❌ Edge function error: ${response.status} - ${response.data}');
      }
    } catch (e) {
      debugPrint('❌ Edge function call error: $e');
      await _storeBasicVerification(
        reportId: reportId,
        imageUrl: imageUrl,
        verificationData: verificationData,
        userId: userId,
        crimeCategory: crimeCategory,
      );
    }
  }

  // Store verification locally (fallback)
  Future<void> _storeBasicVerification({
    required String reportId,
    required String imageUrl,
    required Map<String, dynamic> verificationData,
    required String userId,
    required String crimeCategory,
  }) async {
    if (imageUrl.isEmpty) {
      debugPrint('⚠️ Cannot store verification without image URL');
      return;
    }

    try {
      await _supabase.from('image_verifications').upsert({
        'report_id': reportId,
        'image_url': imageUrl,
        'user_id': userId,
        'crime_category': crimeCategory,
        'client_check': verificationData,
        'overall_status': 'client_approved',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Stored basic verification locally');
    } catch (e) {
      debugPrint('⚠️ Could not store verification: $e');
    }
  }

  // Get crime categories
  Future<List<Map<String, dynamic>>> getCrimeCategories(String type) async {
    try {
      final response = await _supabase
          .from('crime_categories')
          .select('*')
          .eq('type', type)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching crime categories: $e');
      return [];
    }
  }

  // Get all categories
  Future<Map<String, List<Map<String, dynamic>>>> getAllCategories() async {
    try {
      final response = await _supabase
          .from('crime_categories')
          .select('*')
          .order('type', ascending: true)
          .order('name', ascending: true);

      final categories = List<Map<String, dynamic>>.from(response);

      final offline = categories.where((c) => c['type'] == 'offline').toList();
      final online = categories.where((c) => c['type'] == 'online').toList();

      return {
        'offline': offline,
        'online': online,
      };
    } catch (e) {
      debugPrint('Error fetching all categories: $e');
      return {'offline': [], 'online': []};
    }
  }

  // ✅ FIXED: Update location - correct table name
  Future<void> updateReportLocation(String reportId, LatLng location) async {
    try {
      final locationText = 'POINT(${location.longitude} ${location.latitude})';
      await _supabase
          .from('nirbacon_crime')              // ✅ Fixed: was 'reports'
          .update({
        'location': locationText,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', reportId);
    } catch (e) {
      debugPrint('Error updating report location: $e');
    }
  }

  // ✅ FIXED: Get location - correct table name
  Future<LatLng?> getReportLocation(String reportId) async {
    try {
      final response = await _supabase
          .from('nirbacon_crime')              // ✅ Fixed: was 'reports'
          .select('location')
          .eq('id', reportId)
          .single();

      final locationStr = response['location'] as String?;
      if (locationStr == null) return null;

      final match = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)').firstMatch(locationStr);
      if (match != null) {
        final lon = double.tryParse(match.group(1)!);
        final lat = double.tryParse(match.group(2)!);
        if (lat != null && lon != null) {
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting report location: $e');
      return null;
    }
  }

  // Check if image verification needed
  bool requiresImageVerification(String crimeCategory) {
    if (crimeCategory.isEmpty) return false;

    final killingKeywords = [
      'killing', 'murder', 'homicide', 'dead body', 'corpse',
      'killing / murders', 'killing/murders'
    ];

    return killingKeywords.any((keyword) =>
        crimeCategory.toLowerCase().contains(keyword.toLowerCase()));
  }

  // Bulk verify multiple images
  Future<List<Map<String, dynamic>>> verifyMultipleImages({
    required List<XFile> images,
    required LatLng userLocation,
    String? reportDescription,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (final image in images) {
      final result = await verifyImageBeforeUpload(
        imageFile: image,
        userLocation: userLocation,
        reportDescription: reportDescription,
      );
      results.add(result);
    }

    return results;
  }

  // ✅ FIXED: Simple report submission - matching your schema
  Future<Map<String, dynamic>> submitSimpleReport({
    required String description,
    required LatLng location,
    required String area,
    required String crimeCategory,
    required String userId,
    List<XFile> images = const [],
    List<String> videos = const [],
    String? audioUrl,
    bool isEmergency = false,
  }) async {
    try {
      debugPrint('📝 Starting simple report submission...');
      debugPrint('📹 Videos to attach: ${videos.length}');

      final locationText = 'POINT(${location.longitude} ${location.latitude})';

      // ✅ FIXED: Only include columns that exist in nirbacon_crime table
      final reportData = {
        'description': description,
        'location': locationText,
        'area_static': area,           // ✅ Fixed: was 'area'
        'crime_type': crimeCategory,
        'user_id': userId,
        'status': 'active',            // ✅ Fixed: required by CHECK constraint
        'created_at': DateTime.now().toIso8601String(),
        // REMOVED: is_emergency, audio_url, votes, user_votes,
        //          verification_status, image_verified
      };

      debugPrint('📊 Report data: $reportData');

      final reportResponse = await _supabase
          .from('nirbacon_crime')
          .insert(reportData)
          .select('id')
          .single();

      final reportId = reportResponse['id'] as String;
      debugPrint('📄 Report created with ID: $reportId');

      // Upload images
      final imageUrls = <String>[];
      for (final image in images) {
        try {
          final imageUrl = await _imageProcessor.uploadImageToStorage(
            imageFile: image,
            reportId: reportId,
            userId: userId,
          );
          if (imageUrl.isNotEmpty) {
            imageUrls.add(imageUrl);
          }
        } catch (e) {
          debugPrint('❌ Error uploading image ${image.name}: $e');
        }
      }

      // ✅ FIXED: Update correct table
      final updateData = <String, dynamic>{};
      if (imageUrls.isNotEmpty) {
        updateData['images'] = imageUrls;
      }
      if (videos.isNotEmpty) {
        updateData['videos'] = videos;
        debugPrint('📹 Attaching ${videos.length} videos to report');
      }

      if (updateData.isNotEmpty) {
        await _supabase
            .from('nirbacon_crime')           // ✅ Fixed: was 'reports'
            .update(updateData)
            .eq('id', reportId);
      }

      return {
        'success': true,
        'report_id': reportId,
        'message': 'Report submitted successfully',
        'image_count': images.length,
        'video_count': videos.length,
      };
    } catch (e) {
      debugPrint('❌ Simple report submission error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}