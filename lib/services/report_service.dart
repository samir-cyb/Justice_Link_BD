import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'image_processor.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImageProcessor _imageProcessor = ImageProcessor();

  // NEW: Pre-upload image verification (client-side only)
  Future<Map<String, dynamic>> verifyImageBeforeUpload({
    required XFile imageFile,
    required LatLng userLocation,
    String? reportDescription,
  }) async {
    try {
      debugPrint('🔍 Starting pre-upload image verification...');

      // Run the image processor verification
      final result = await _imageProcessor.processImage(
        imageFile: imageFile,
        userLocation: userLocation,
        reportId: 'pre_upload_${DateTime.now().millisecondsSinceEpoch}',
        reportDescription: reportDescription,
      );

      debugPrint('📊 Verification result: ${result['status']}');

      // Check if image should be rejected
      if (result['status'] == 'rejected') {
        return {
          'status': 'rejected',
          'reasons': result['reasons'] is List ? List<String>.from(result['reasons']) : ['Image verification failed'],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': false, // DO NOT UPLOAD TO SUPABASE
        };
      } else if (result['status'] == 'needs_review') {
        return {
          'status': 'needs_review',
          'reasons': result['reasons'] is List ? List<String>.from(result['reasons']) : ['Image needs human review'],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': true, // Upload but flag for review
        };
      } else {
        return {
          'status': 'approved',
          'reasons': [],
          'details': result['details'] is Map<String, dynamic> ? Map<String, dynamic>.from(result['details']) : {},
          'should_upload': true, // Safe to upload
        };
      }

    } catch (e) {
      debugPrint('❌ Pre-upload verification error: $e');
      return {
        'status': 'error',
        'reasons': ['Verification error: $e'],
        'should_upload': false, // Don't upload on error
      };
    }
  }

  // UPDATED: Submit report with verification
  Future<Map<String, dynamic>> submitReportWithVerification({
    required String description,
    required LatLng location,
    required String area,
    required String crimeCategory,
    required List<XFile> images,
    required String userId,
    String? audioUrl,
    bool isEmergency = false,
    bool runImageVerification = true, // NEW: Parameter to control verification
  }) async {
    try {
      debugPrint('📝 Starting report submission...');

      // Step 1: Process each image locally first (only if verification is required)
      List<Map<String, dynamic>> imageResults = [];
      List<String> imageUrls = [];

      if (runImageVerification && images.isNotEmpty) {
        for (final image in images) {
          debugPrint('🖼️ Processing image: ${image.name}');

          // Run local verification pipeline
          final verificationResult = await verifyImageBeforeUpload(
            imageFile: image,
            userLocation: location,
            reportDescription: description,
          );

          if (verificationResult['status'] == 'rejected') {
            // Image failed local verification - reject immediately
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
        debugPrint('⚠️ Skipping image verification (not required or no images)');
      }

      debugPrint('✅ Images passed local verification or verification skipped');

      // Step 2: Create report entry in database
      final locationText = 'POINT(${location.longitude} ${location.latitude})';

      final reportData = {
        'description': description,
        'location': locationText,
        'area': area,
        'crime_type': crimeCategory,
        'is_emergency': isEmergency,
        'user_id': userId,
        'audio_url': audioUrl,
        'votes': {'dangerous': 0, 'suspicious': 0, 'normal': 0, 'fake': 0},
        'user_votes': {},
        'verification_status': runImageVerification ? 'pending' : 'not_required',
        'image_verified': runImageVerification && images.isNotEmpty,
        'is_sensitive': false,
        'sensitive_views': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final reportResponse = await _supabase
          .from('reports')
          .insert(reportData)
          .select('id')
          .single();

      final reportId = reportResponse['id'] as String;
      debugPrint('📄 Report created with ID: $reportId');

      // Step 3: Upload images to storage (only if verification passed or not required)
      for (int i = 0; i < images.length; i++) {
        final image = images[i];

        try {
          // Upload image
          final imageUrl = await _imageProcessor.uploadImageToStorage(
            imageFile: image,
            reportId: reportId,
            userId: userId,
          );

          imageUrls.add(imageUrl);

          // Call edge function for server-side verification (only if needed AND we have valid imageUrl)
          if (runImageVerification && imageUrl.isNotEmpty) {
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
          } else if (runImageVerification && imageUrl.isEmpty) {
            debugPrint('⚠️ Skipping verification for image ${image.name} - no valid URL');
          }

        } catch (e) {
          debugPrint('❌ Error uploading image ${image.name}: $e');
          // Continue with other images
        }
      }

      // Step 4: Update report with image URLs
      if (imageUrls.isNotEmpty) {
        await _supabase
            .from('reports')
            .update({
          'images': imageUrls,  // ← ONLY THIS, NO OTHER COLUMNS
        })
            .eq('id', reportId);
      }

      // Step 5: Get crime category details
      final categoryResponse = await _supabase
          .from('crime_categories')
          .select('requires_sensitive_filter')
          .eq('name', crimeCategory)
          .maybeSingle();

      final requiresSensitiveFilter = categoryResponse?['requires_sensitive_filter'] ?? false;

      return {
        'success': true,
        'report_id': reportId,
        'message': 'Report submitted successfully',
        'requires_sensitive_filter': requiresSensitiveFilter,
        'image_count': images.length,
        'verified_images': imageUrls.length,
        'verification_performed': runImageVerification,
      };

    } catch (e) {
      debugPrint('❌ Report submission error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // UPDATED: Call the edge function for server-side verification with null check
  Future<void> _callVerificationEdgeFunction({
    required String reportId,
    required String imageUrl,
    required Map<String, dynamic> verificationData,
    required String userId,
    required String crimeCategory,
  }) async {
    // Check for null or empty imageUrl before proceeding
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

      // Handle the response
      final status = response.status;
      final data = response.data;

      if (status == 200) {
        debugPrint('✅ Edge function result: ${data['overall_status']}');
      } else {
        debugPrint('❌ Edge function error: $status - $data');
      }
    } catch (e) {
      debugPrint('❌ Edge function call error: $e');

      // Fallback: Store basic verification locally (with imageUrl check)
      await _storeBasicVerification(
        reportId: reportId,
        imageUrl: imageUrl,
        verificationData: verificationData,
        userId: userId,
        crimeCategory: crimeCategory,
      );
    }
  }

  // UPDATED: Helper method to store verification locally with null check
  Future<void> _storeBasicVerification({
    required String reportId,
    required String imageUrl,
    required Map<String, dynamic> verificationData,
    required String userId,
    required String crimeCategory,
  }) async {
    // Check for null or empty imageUrl before storing
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

  // Get all categories (both online and offline)
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

  // Update location data in report
  Future<void> updateReportLocation(String reportId, LatLng location) async {
    try {
      final locationText = 'POINT(${location.longitude} ${location.latitude})';
      await _supabase
          .from('reports')
          .update({
        'location': locationText,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', reportId);
    } catch (e) {
      debugPrint('Error updating report location: $e');
    }
  }

  // Get location data from report
  Future<LatLng?> getReportLocation(String reportId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('location')
          .eq('id', reportId)
          .single();

      final locationStr = response['location'] as String?;
      if (locationStr == null) return null;

      // Parse POINT(lon lat) format
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

  // NEW: Quick check if image verification is needed for a category
  bool requiresImageVerification(String crimeCategory) {
    if (crimeCategory.isEmpty) return false;

    final killingKeywords = [
      'killing', 'murder', 'homicide', 'dead body', 'corpse',
      'killing / murders', 'killing/murders'
    ];

    return killingKeywords.any((keyword) =>
        crimeCategory.toLowerCase().contains(keyword.toLowerCase()));
  }

  // NEW: Bulk verify multiple images
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

  // FIXED: Simple report submission without image verification (for non-killing categories)
  Future<Map<String, dynamic>> submitSimpleReport({
    required String description,
    required LatLng location,
    required String area,
    required String crimeCategory,
    required String userId,
    List<XFile> images = const [],
    String? audioUrl,
    bool isEmergency = false,
  }) async {
    try {
      debugPrint('📝 Starting simple report submission (no image verification)...');

      final locationText = 'POINT(${location.longitude} ${location.latitude})';

      final reportData = {
        'description': description,
        'location': locationText,
        'area': area,
        'crime_type': crimeCategory,
        'is_emergency': isEmergency,
        'user_id': userId,
        'audio_url': audioUrl,
        'votes': {'dangerous': 0, 'suspicious': 0, 'normal': 0, 'fake': 0},
        'user_votes': {},
        'verification_status': 'not_required',
        'image_verified': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final reportResponse = await _supabase
          .from('reports')
          .insert(reportData)
          .select('id')
          .single();

      final reportId = reportResponse['id'] as String;

      // Upload images without verification
      final imageUrls = <String>[];
      for (final image in images) {
        try {
          final imageUrl = await _imageProcessor.uploadImageToStorage(
            imageFile: image,
            reportId: reportId,
            userId: userId,
          );
          imageUrls.add(imageUrl);
        } catch (e) {
          debugPrint('❌ Error uploading image: $e');
        }
      }

      // FIXED: Only update the 'images' column, no other columns
      if (imageUrls.isNotEmpty) {
        await _supabase
            .from('reports')
            .update({
          'images': imageUrls,  // ← THIS IS THE ONLY COLUMN THAT EXISTS
        })
            .eq('id', reportId);
      }

      return {
        'success': true,
        'report_id': reportId,
        'message': 'Report submitted successfully',
        'image_count': images.length,
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