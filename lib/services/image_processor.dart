import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as path_lib;
import 'package:image_picker/image_picker.dart';

class ImageProcessor {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Performance metrics
  final Map<String, int> _processingTimes = {};
  final Stopwatch _globalStopwatch = Stopwatch();

  // Debug mode with levels
  int debugLevel = 2; // 0=none, 1=errors, 2=info, 3=verbose
  String? _reportDescription;

  void _log(String message, {int level = 2, String tag = '🔍'}) {
    if (debugLevel >= level) {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      debugPrint('$timestamp $tag [L$level] $message');
    }
  }

  void _logTime(String step, int ms) {
    _processingTimes[step] = ms;
    _log('$step took ${ms}ms', level: 3, tag: '⏱️');
  }

  void setReportDescription(String description) {
    _reportDescription = description.toLowerCase();
    _log('Report context set: ${_reportDescription?.substring(0, min(50, _reportDescription!.length))}...', tag: '📝');
  }

  // OPTIMIZED: Read image once and reuse bytes
  Future<Uint8List> _readImageBytes(XFile imageFile) async {
    final stopwatch = Stopwatch()..start();
    try {
      final bytes = await imageFile.readAsBytes();
      _logTime('read_bytes', stopwatch.elapsedMilliseconds);
      return bytes;
    } catch (e) {
      _log('Failed to read image: $e', level: 1, tag: '❌');
      rethrow;
    }
  }

  // OPTIMIZED: Quick metadata extraction (only essential fields)
  Future<Map<String, dynamic>> _quickMetadataCheck(Uint8List bytes, String fileName) async {
    final stopwatch = Stopwatch()..start();
    try {
      final exifData = await readExifFromBytes(bytes);

      final Map<String, dynamic> result = {
        'file_name': fileName,
        'file_size': bytes.length,
        'has_gps': exifData.containsKey('GPS GPSLatitude') && exifData.containsKey('GPS GPSLongitude'),
        'has_date': exifData.containsKey('Image DateTime'),
        'date_string': exifData['Image DateTime']?.toString(),
        'gps_lat': exifData['GPS GPSLatitude']?.toString(),
        'gps_lon': exifData['GPS GPSLongitude']?.toString(),
      };

      _logTime('quick_metadata', stopwatch.elapsedMilliseconds);
      return result;
    } catch (e) {
      _log('Metadata extraction failed: $e', level: 1, tag: '⚠️');
      return {
        'file_name': fileName,
        'file_size': bytes.length,
        'has_gps': false,
        'has_date': false,
      };
    }
  }

  // OPTIMIZED: Fast hash generation (only SHA256 for verification)
  Future<Map<String, dynamic>> _generateQuickHash(Uint8List bytes) async {
    final stopwatch = Stopwatch()..start();
    try {
      final sha256Hash = sha256.convert(bytes).toString();

      final result = {
        'sha256': sha256Hash,
        'file_size': bytes.length,
      };

      _logTime('quick_hash', stopwatch.elapsedMilliseconds);
      return result;
    } catch (e) {
      _log('Hash generation failed: $e', level: 1, tag: '⚠️');
      return {
        'sha256': null,
        'file_size': bytes.length,
      };
    }
  }

  // OPTIMIZED: Check hash against fake database
  Future<Map<String, dynamic>> _checkHashQuick(Map<String, dynamic> hashResult) async {
    final stopwatch = Stopwatch()..start();
    try {
      final sha256Hash = hashResult['sha256'] as String?;

      if (sha256Hash == null) {
        _log('No hash generated, skipping DB check', level: 2, tag: '⚠️');
        return {
          'passed': true,
          'reasons': ['Could not generate hash for verification'],
        };
      }

      _log('Checking hash: ${sha256Hash.substring(0, 16)}...', level: 3, tag: '🔍');

      final response = await _supabase
          .from('fake_image_hashes')
          .select('id, reason, report_count')
          .eq('image_hash', sha256Hash)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response != null && response.isNotEmpty) {
        _log('❌ MATCH FOUND: Known fake image', level: 1, tag: '🚨');
        return {
          'passed': false,
          'reasons': ['Image matches known fake content (${response['reason']})'],
          'details': response,
        };
      }

      _logTime('hash_check', stopwatch.elapsedMilliseconds);
      return {
        'passed': true,
        'reasons': [],
      };
    } catch (e) {
      _log('Hash check error: $e', level: 1, tag: '⚠️');
      return {
        'passed': true, // Don't reject on network errors
        'reasons': ['Hash check inconclusive: $e'],
      };
    }
  }

  // FIXED: Resize image for faster processing - Now returns Uint8List properly
  Future<Uint8List> _resizeForML(Uint8List originalBytes, {int maxSize = 800}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final image = img.decodeImage(originalBytes);
      if (image == null) return originalBytes;

      // Don't resize if already small enough
      if (image.width <= maxSize && image.height <= maxSize) {
        _log('Image already small enough: ${image.width}x${image.height}', level: 3, tag: '📏');
        return originalBytes;
      }

      // Calculate new dimensions maintaining aspect ratio
      final double ratio = image.width / image.height;
      int newWidth, newHeight;

      if (ratio > 1) {
        newWidth = maxSize;
        newHeight = (maxSize / ratio).round();
      } else {
        newHeight = maxSize;
        newWidth = (maxSize * ratio).round();
      }

      // Ensure minimum size
      newWidth = max(newWidth, 100);
      newHeight = max(newHeight, 100);

      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear, // Fastest
      );

      // FIXED: Convert to JPEG with reduced quality and properly return Uint8List
      final compressed = img.encodeJpg(resized, quality: 70);

      if (compressed == null) {
        _log('Compression failed, returning original', level: 1, tag: '⚠️');
        return originalBytes;
      }

      _log('Resized ${image.width}x${image.height} → ${resized.width}x${resized.height}', level: 3, tag: '📏');
      _logTime('resize_image', stopwatch.elapsedMilliseconds);

      return Uint8List.fromList(compressed);
    } catch (e) {
      _log('Resize failed: $e', level: 1, tag: '⚠️');
      return originalBytes;
    }
  }

  // CRITICAL FIX: Better dead body detection
  bool _isLikelyDeadBody(Map<String, dynamic> mlResult, Map<String, dynamic> imageAnalysis) {
    _log('Checking if likely dead body...', level: 3, tag: '⚰️');

    final hasBody = mlResult['has_body'] == true;
    final hasBlood = mlResult['has_blood'] == true || (imageAnalysis['has_possible_blood'] == true);
    final hasWeapon = mlResult['has_weapon'] == true;
    final hasViolence = mlResult['has_violence'] == true;

    // Dead body indicators (combined)
    final deadBodyIndicators = [
      hasBlood && hasBody,                    // Body with blood
      hasWeapon && hasBody,                   // Body with weapon
      hasViolence && hasBody,                 // Body with violence context
      mlResult['has_emergency_context'] == true, // Emergency services in image
    ];

    final likelyDeadBody = deadBodyIndicators.where((indicator) => indicator).length >= 2;

    _log('Dead body check: body=$hasBody, blood=$hasBlood, weapon=$hasWeapon, violence=$hasViolence → likely=$likelyDeadBody',
        level: 2, tag: '⚰️');

    return likelyDeadBody;
  }

  // OPTIMIZED: Fast visual analysis (only for killing reports)
  Future<Map<String, dynamic>> _quickVisualAnalysis(Uint8List bytes) async {
    final stopwatch = Stopwatch()..start();

    // Skip if not needed (for non-killing reports)
    if (_reportDescription == null ||
        !_reportDescription!.contains(RegExp(r'dead|killing|murder|homicide|corpse', caseSensitive: false))) {
      return {
        'skipped': true,
        'reason': 'Not a killing report',
      };
    }

    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return {'error': 'Failed to decode image'};
      }

      // Quick sample analysis (every 10th pixel for speed)
      int redPixels = 0;
      int darkPixels = 0;
      int totalSampled = 0;

      // DEBUG: Check first few pixels
      bool debugPrinted = false;

      for (int y = 0; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixel(x, y);

          // DEBUG: Print pixel info for first few pixels only
          if (!debugPrinted && totalSampled < 3) {
            print('=== DEBUG PIXEL INFO ===');
            print('Pixel type: ${pixel.runtimeType}');
            print('Pixel toString: $pixel');
            print('Pixel value: ${pixel.r}, ${pixel.g}, ${pixel.b}');
            print('Pixel has r property: ${pixel.r}');
            print('Pixel has g property: ${pixel.g}');
            print('Pixel has b property: ${pixel.b}');
            print('Image format: ${image.format}');
            print('=======================');
            debugPrinted = true;
          }

          final r = pixel.r;   // Red (0-255)
          final g = pixel.g;   // Green (0-255)
          final b = pixel.b;   // Blue (0-255)

          // Blood detection (high red, low green/blue)
          if (r > 150 && g < 100 && b < 100 && r > g * 2 && r > b * 2) {
            redPixels++;
          }

          // Dark areas
          if (r < 50 && g < 50 && b < 50) {
            darkPixels++;
          }

          totalSampled++;
        }
      }

      final bloodRatio = totalSampled > 0 ? redPixels / totalSampled : 0;
      final darkRatio = totalSampled > 0 ? darkPixels / totalSampled : 0;

      final result = {
        'width': image.width,
        'height': image.height,
        'blood_ratio': bloodRatio,
        'dark_ratio': darkRatio,
        'has_possible_blood': bloodRatio > 0.01, // 1% threshold
        'has_dark_areas': darkRatio > 0.2, // 20% dark areas
        'pixels_sampled': totalSampled,
        // Add debug info
        'debug_sample_rgb': debugPrinted ? 'Printed to console' : 'Not printed',
      };

      _logTime('visual_analysis', stopwatch.elapsedMilliseconds);
      return result;
    } catch (e) {
      _log('Visual analysis failed: $e', level: 1, tag: '⚠️');
      return {'error': 'Visual analysis failed'};
    }
  }

  // OPTIMIZED: Mobile ML Kit detection with emergency logic fix
  Future<Map<String, dynamic>> _runMobileMLDetection(File file, Uint8List resizedBytes) async {
    final stopwatch = Stopwatch()..start();
    _log('Starting mobile ML detection...', level: 2, tag: '📱');

    try {
      final inputImage = InputImage.fromFilePath(file.path);

      // Use only ObjectDetector (faster than ImageLabeler)
      final objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

      final objects = await objectDetector.processImage(inputImage);
      await objectDetector.close();

      final detectedObjects = <String>[];
      final objectConfidences = <String, double>{};
      bool hasWeapon = false;
      bool hasBody = false;
      bool hasBlood = false;
      bool hasViolence = false;

      for (final obj in objects) {
        for (final label in obj.labels) {
          final labelText = label.text.toLowerCase().trim();
          final confidence = label.confidence;

          if (confidence < 0.5) continue; // Higher threshold for accuracy

          detectedObjects.add('$labelText (${(confidence * 100).toStringAsFixed(0)}%)');
          objectConfidences[labelText] = confidence;

          // Categorize detection
          if (_isWeaponRelated(labelText) && confidence > 0.7) {
            hasWeapon = true;
            _log('WEAPON DETECTED: $labelText (${(confidence * 100).toStringAsFixed(1)}%)', level: 1, tag: '🔫');
          }

          if (_isBodyRelated(labelText) && confidence > 0.6) {
            hasBody = true;
            _log('BODY DETECTED: $labelText (${(confidence * 100).toStringAsFixed(1)}%)', level: 2, tag: '👤');
          }

          if (_isBloodRelated(labelText) && confidence > 0.7) {
            hasBlood = true;
            _log('BLOOD DETECTED: $labelText (${(confidence * 100).toStringAsFixed(1)}%)', level: 1, tag: '🩸');
          }

          if (_isViolenceRelated(labelText) && confidence > 0.7) {
            hasViolence = true;
            _log('VIOLENCE DETECTED: $labelText (${(confidence * 100).toStringAsFixed(1)}%)', level: 1, tag: '🔥');
          }
        }
      }

      // CRITICAL FIX: Emergency override logic
      bool shouldReject = false;
      List<String> rejectionReasons = [];
      bool hasEmergencyContext = false;

      // Only apply emergency logic for killing reports
      final isKillingReport = _reportDescription != null &&
          _reportDescription!.contains(RegExp(r'dead|killing|murder|homicide|corpse', caseSensitive: false));

      if (isKillingReport) {
        if (!hasBody) {
          // Report says dead body but NO body detected = SUSPICIOUS
          shouldReject = true;
          rejectionReasons.add('MISMATCH: Report claims dead body but no human detected in image');
          _log('REJECT: No body detected for killing report', level: 1, tag: '❌');
        } else if (hasBody && !hasBlood && !hasWeapon && !hasViolence) {
          // Body detected but no signs of death = POTENTIALLY FAKE
          shouldReject = true;
          rejectionReasons.add('SUSPICIOUS: Human detected but no signs of violence/blood for killing report');
          _log('REJECT: Body without violence indicators for killing report', level: 1, tag: '❌');
        } else if (hasBody && (hasBlood || hasWeapon || hasViolence)) {
          // Body with signs of violence = POSSIBLE REAL CASE (needs review)
          hasEmergencyContext = true;
          rejectionReasons.add('URGENT: Possible deceased person with supporting evidence');
          _log('EMERGENCY: Body with violence indicators - needs human review', level: 1, tag: '🚨');
        }
      }

      // Non-killing reports: Standard weapon/violence check
      if (!isKillingReport) {
        if (hasWeapon) {
          shouldReject = true;
          rejectionReasons.add('Weapon detected - content restricted');
        }
        if (hasViolence && detectedObjects.length > 2) {
          shouldReject = true;
          rejectionReasons.add('Violent content detected');
        }
      }

      final result = {
        'passed': !shouldReject,
        'reasons': rejectionReasons,
        'detected_objects': detectedObjects,
        'has_weapon': hasWeapon,
        'has_body': hasBody,
        'has_blood': hasBlood,
        'has_violence': hasViolence,
        'has_emergency_context': hasEmergencyContext,
        'object_count': detectedObjects.length,
        'ml_kit_used': true,
        'detection_type': 'mobile_fast',
      };

      _logTime('ml_detection', stopwatch.elapsedMilliseconds);
      return result;

    } catch (e) {
      _log('Mobile ML failed: $e', level: 1, tag: '⚠️');
      return _runFallbackDetection();
    }
  }

  // Fallback detection when ML fails
  Future<Map<String, dynamic>> _runFallbackDetection() async {
    _log('Using fallback detection', level: 2, tag: '🆘');

    final isKillingReport = _reportDescription != null &&
        _reportDescription!.contains(RegExp(r'dead|killing|murder|homicide|corpse', caseSensitive: false));

    // For killing reports, be conservative: reject without ML verification
    if (isKillingReport) {
      return {
        'passed': false,
        'reasons': ['Cannot verify killing report - AI detection failed'],
        'detected_objects': [],
        'has_weapon': false,
        'has_body': false,
        'has_blood': false,
        'has_violence': false,
        'has_emergency_context': false,
        'ml_kit_used': false,
        'detection_type': 'fallback_reject',
      };
    }

    // For non-killing reports, allow with warning
    return {
      'passed': true,
      'reasons': ['Basic check passed - advanced analysis unavailable'],
      'detected_objects': ['generic content (fallback)'],
      'has_weapon': false,
      'has_body': false,
      'has_blood': false,
      'has_violence': false,
      'has_emergency_context': false,
      'ml_kit_used': false,
      'detection_type': 'fallback_pass',
    };
  }

  // MAIN OPTIMIZED PROCESSING PIPELINE
  Future<Map<String, dynamic>> processImage({
    required XFile imageFile,
    required LatLng userLocation,
    required String reportId,
    String? reportDescription,
  }) async {
    _globalStopwatch.reset();
    _globalStopwatch.start();
    _processingTimes.clear();

    _log('\n' + '='*60, level: 2, tag: '🚀');
    _log('STARTING OPTIMIZED IMAGE PROCESSING', level: 2, tag: '🚀');
    _log('Image: ${imageFile.name}', level: 2, tag: '📸');
    _log('Report ID: $reportId', level: 3, tag: '🆔');

    if (reportDescription != null) {
      setReportDescription(reportDescription);
    }

    try {
      // STEP 1: Read image once
      _log('Step 1: Reading image...', level: 2, tag: '1️⃣');
      final originalBytes = await _readImageBytes(imageFile);
      _log('Image size: ${originalBytes.length ~/ 1024}KB', level: 2, tag: '💾');

      // STEP 2: Parallel metadata and hash checks
      _log('Step 2: Parallel checks...', level: 2, tag: '2️⃣');
      final metadataFuture = _quickMetadataCheck(originalBytes, imageFile.name);
      final hashFuture = _generateQuickHash(originalBytes);

      final metadata = await metadataFuture;
      final hashResult = await hashFuture;

      // STEP 3: Quick hash database check
      _log('Step 3: Hash verification...', level: 2, tag: '3️⃣');
      final hashCheck = await _checkHashQuick(hashResult);

      if (!hashCheck['passed']) {
        _log('❌ HASH CHECK FAILED: ${hashCheck['reasons']}', level: 1, tag: '🚨');
        return _buildRejectResult(
          step: 'hash',
          reasons: hashCheck['reasons'],
          details: hashCheck,
          imageName: imageFile.name,
          totalTime: _globalStopwatch.elapsedMilliseconds,
        );
      }

      // STEP 4: Quick metadata validation
      _log('Step 4: Metadata validation...', level: 2, tag: '4️⃣');
      final metadataValid = await _validateMetadata(metadata, userLocation);

      if (!metadataValid['passed']) {
        _log('❌ METADATA CHECK FAILED: ${metadataValid['reasons']}', level: 1, tag: '🚨');
        return _buildRejectResult(
          step: 'metadata',
          reasons: metadataValid['reasons'],
          details: metadataValid['details'],
          imageName: imageFile.name,
          totalTime: _globalStopwatch.elapsedMilliseconds,
        );
      }

      // STEP 5: Resize for ML (if needed)
      _log('Step 5: Preparing for ML...', level: 2, tag: '5️⃣');
      final mlBytes = await _resizeForML(originalBytes);

      // STEP 6: Visual analysis (only for killing reports)
      Map<String, dynamic> visualAnalysis = {};
      if (_reportDescription != null &&
          _reportDescription!.contains(RegExp(r'dead|killing|murder|homicide|corpse', caseSensitive: false))) {
        _log('Step 6a: Quick visual analysis (killing report)...', level: 2, tag: '🔍');
        visualAnalysis = await _quickVisualAnalysis(originalBytes);
      }

      // STEP 7: ML Detection
      _log('Step 6b: AI Detection...', level: 2, tag: '🤖');
      Map<String, dynamic> mlResult;

      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
        _log('Platform: Web/Unsupported - using fallback', level: 2, tag: '🌐');
        mlResult = await _runFallbackDetection();
      } else {
        try {
          final tempFile = await _createTempFile(mlBytes, imageFile.name);
          mlResult = await _runMobileMLDetection(tempFile, mlBytes);
          await tempFile.delete();
        } catch (e) {
          _log('Mobile ML failed: $e', level: 1, tag: '⚠️');
          mlResult = await _runFallbackDetection();
        }
      }

      if (!mlResult['passed']) {
        _log('❌ AI CHECK FAILED: ${mlResult['reasons']}', level: 1, tag: '🚨');
        return _buildRejectResult(
          step: 'ai_detection',
          reasons: mlResult['reasons'],
          details: mlResult,
          imageName: imageFile.name,
          totalTime: _globalStopwatch.elapsedMilliseconds,
          emergencyContext: mlResult['has_emergency_context'] == true,
        );
      }

      // STEP 8: Final decision
      final totalTime = _globalStopwatch.elapsedMilliseconds;
      final hasEmergency = mlResult['has_emergency_context'] == true;

      _log('\n' + '='*60, level: 2, tag: '📊');
      _log('PROCESSING COMPLETE', level: 2, tag: '✅');
      _log('Total time: ${totalTime}ms', level: 2, tag: '⏱️');
      _log('Status: ${hasEmergency ? 'NEEDS_REVIEW' : 'APPROVED'}', level: 2, tag: hasEmergency ? '⚠️' : '✅');

      // Log performance breakdown
      _log('\nPERFORMANCE BREAKDOWN:', level: 3, tag: '📈');
      _processingTimes.forEach((step, time) {
        _log('  $step: ${time}ms (${(time/totalTime*100).toStringAsFixed(1)}%)', level: 3, tag: '  ⏱️');
      });

      return {
        'status': hasEmergency ? 'needs_review' : 'approved',
        'step': 'client_checks_complete',
        'reasons': hasEmergency ? ['Emergency context detected - needs human review'] : [],
        'details': {
          'metadata_check': metadataValid,
          'hash_check': hashCheck,
          'ml_detection': mlResult,
          'visual_analysis': visualAnalysis,
        },
        'processing_time_ms': totalTime,
        'image_name': imageFile.name,
        'next_step': hasEmergency ? 'human_moderation' : 'upload_to_storage',
        'emergency_context': hasEmergency,
        'debug_info': {
          'detection_type': mlResult['detection_type'] ?? 'unknown',
          'detected_objects_count': mlResult['detected_objects']?.length ?? 0,
          'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown')),
          'performance_times': _processingTimes,
        },
      };

    } catch (e) {
      _log('\n❌ PROCESSING ERROR: $e', level: 1, tag: '🚨');
      return _buildRejectResult(
        step: 'error',
        reasons: ['Processing error: $e'],
        details: {},
        imageName: imageFile.name,
        totalTime: _globalStopwatch.elapsedMilliseconds,
      );
    } finally {
      _globalStopwatch.stop();
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _validateMetadata(Map<String, dynamic> metadata, LatLng userLocation) async {
    final reasons = <String>[];
    final details = <String, dynamic>{};

    // Date check
    if (metadata['has_date']) {
      try {
        final dateStr = metadata['date_string'];
        if (dateStr != null) {
          final cleaned = dateStr.replaceFirst(':', '-').replaceFirst(':', '-').replaceFirst(' ', 'T');
          final imageDate = DateTime.parse(cleaned);
          final now = DateTime.now();
          final diffDays = now.difference(imageDate).inDays;

          details['image_date'] = imageDate.toIso8601String();
          details['days_old'] = diffDays;

          if (diffDays > 365) {
            reasons.add('Image too old ($diffDays days)');
          } else if (imageDate.isAfter(now.add(const Duration(days: 1)))) {
            reasons.add('Image date is in future');
          }
        }
      } catch (e) {
        _log('Date parsing error: $e', level: 2, tag: '⚠️');
      }
    }

    // GPS check (if available)
    if (metadata['has_gps']) {
      try {
        final lat = _parseGPSCoordinate(metadata['gps_lat']);
        final lon = _parseGPSCoordinate(metadata['gps_lon']);

        if (lat != null && lon != null) {
          final distance = Geolocator.distanceBetween(
            userLocation.latitude, userLocation.longitude,
            lat, lon,
          );

          details['distance_km'] = distance / 1000;

          if (distance > 100000) { // 100km
            reasons.add('Location mismatch (${(distance/1000).toStringAsFixed(1)}km away)');
          }
        }
      } catch (e) {
        _log('GPS parsing error: $e', level: 2, tag: '⚠️');
      }
    }

    return {
      'passed': reasons.isEmpty,
      'reasons': reasons,
      'details': details,
    };
  }

  Map<String, dynamic> _buildRejectResult({
    required String step,
    required List<dynamic> reasons,
    required Map<String, dynamic> details,
    required String imageName,
    required int totalTime,
    bool emergencyContext = false,
  }) {
    _log('\n❌ IMAGE REJECTED at step: $step', level: 1, tag: '🚨');
    _log('Reasons: $reasons', level: 1, tag: '📋');
    _log('Total time: ${totalTime}ms', level: 2, tag: '⏱️');

    return {
      'status': 'rejected',
      'step': step,
      'reasons': List<String>.from(reasons),
      'details': details,
      'processing_time_ms': totalTime,
      'image_name': imageName,
      'emergency_context': emergencyContext,
      'should_upload': false, // CRITICAL: DO NOT UPLOAD!
    };
  }

  Future<File> _createTempFile(Uint8List bytes, String originalName) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${path_lib.basename(originalName)}');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  // Original helper methods (unchanged but kept for compatibility)
  double? _parseGPSCoordinate(String? coordinate) {
    if (coordinate == null) return null;
    try {
      final cleaned = coordinate.replaceAll('[', '').replaceAll(']', '').trim();
      final parts = cleaned.split(',').map((s) => s.trim()).toList();
      if (parts.length != 3) return null;

      final degrees = double.parse(parts[0]);
      final minutes = double.parse(parts[1]);
      final secondsStr = parts[2];
      double seconds;

      if (secondsStr.contains('/')) {
        final fractionParts = secondsStr.split('/');
        final numerator = double.parse(fractionParts[0]);
        final denominator = double.parse(fractionParts[1]);
        seconds = numerator / denominator;
      } else {
        seconds = double.parse(secondsStr);
      }

      return degrees + (minutes / 60) + (seconds / 3600);
    } catch (e) {
      return null;
    }
  }

  bool _isWeaponRelated(String label) {
    final weaponKeywords = ['gun', 'pistol', 'rifle', 'knife', 'weapon', 'bullet'];
    return weaponKeywords.any((keyword) => label.contains(keyword));
  }

  bool _isBodyRelated(String label) {
    final bodyKeywords = ['person', 'human', 'man', 'woman', 'child', 'body', 'face', 'head'];
    return bodyKeywords.any((keyword) => label.contains(keyword));
  }

  bool _isBloodRelated(String label) {
    final bloodKeywords = ['blood', 'bleeding', 'wound', 'injury'];
    return bloodKeywords.any((keyword) => label.contains(keyword));
  }

  bool _isViolenceRelated(String label) {
    final violenceKeywords = ['fight', 'fighting', 'assault', 'violence'];
    return violenceKeywords.any((keyword) => label.contains(keyword));
  }

  // Upload method (unchanged)
  Future<String> uploadImageToStorage({
    required XFile imageFile,
    required String reportId,
    required String userId,
  }) async {
    _log('Uploading image to storage...', level: 2, tag: '☁️');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = path_lib.extension(imageFile.name);
      final fileName = '${reportId}_${userId}_$timestamp$fileExt';
      final filePath = 'reports/$reportId/$fileName';

      _log('Path: $filePath', level: 3, tag: '📁');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      String publicUrl;

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        await _supabase.storage
            .from('crime-images')
            .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
      } else {
        final file = File(imageFile.path);
        await _supabase.storage
            .from('crime-images')
            .upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      }

      publicUrl = _supabase.storage
          .from('crime-images')
          .getPublicUrl(filePath);

      _log('✅ Upload successful: $publicUrl', level: 2, tag: '✅');
      return publicUrl;
    } catch (e) {
      _log('❌ Upload failed: $e', level: 1, tag: '❌');
      rethrow;
    }
  }

  // Test method with detailed logging
  Future<void> testPipeline(XFile testImage, {String? testDescription}) async {
    _log('\n' + '='*60, level: 2, tag: '🧪');
    _log('TESTING OPTIMIZED PIPELINE', level: 2, tag: '🧪');
    _log('Image: ${testImage.name}', level: 2, tag: '📸');

    if (testDescription != null) {
      setReportDescription(testDescription);
    }

    debugLevel = 3; // Set to verbose for testing

    try {
      final result = await processImage(
        imageFile: testImage,
        userLocation: LatLng(23.8103, 90.4125),
        reportId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        reportDescription: testDescription,
      );

      _log('\n' + '='*60, level: 2, tag: '🎯');
      _log('TEST RESULTS:', level: 2, tag: '🎯');
      _log('Status: ${result['status']}', level: 2, tag: result['status'] == 'approved' ? '✅' : '⚠️');
      _log('Step: ${result['step']}', level: 2, tag: '📍');
      _log('Time: ${result['processing_time_ms']}ms', level: 2, tag: '⏱️');
      _log('Emergency: ${result['emergency_context']}', level: 2, tag: '🚨');

      if (result['status'] == 'rejected') {
        _log('❌ REJECTED: ${result['reasons']}', level: 1, tag: '❌');
      } else if (result['status'] == 'needs_review') {
        _log('⚠️ FLAGGED for review: ${result['reasons']}', level: 2, tag: '⚠️');
      } else {
        _log('✅ APPROVED for upload', level: 2, tag: '✅');
      }

    } catch (e) {
      _log('❌ TEST ERROR: $e', level: 1, tag: '❌');
    } finally {
      debugLevel = 2; // Reset to normal
    }
  }
}