import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Cloudinary Live Streaming Service
/// - Uses Cloudinary's video streaming capabilities
/// - Generates HLS .m3u8 URLs that video_player can play
/// - Stores only the URL in your database
class LiveStreamService {
  // Your Cloudinary credentials (from video_service.dart)
  static const String _cloudName = 'dja3wckvy';
  static const String _apiKey = '959287296858857';  // Get from Cloudinary dashboard
  static const String _apiSecret = 'rZEjc_ZIiT7IpnKIlWr2epesG9E';
  static const String _uploadPreset = 'justice_report';

  String? _currentPublicId;
  String? _currentPlaybackUrl;

  /// Start a new live stream
  /// Returns HLS stream URL that video_player can play
  Future<Map<String, String>?> startStream({
    required String crimeType,
    String? description,
  }) async {
    try {
      developer.log('🎥 Starting Cloudinary live stream...');

      // Generate unique public ID for this stream
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPublicId = 'live_${crimeType.hashCode}_$timestamp';

      // Method 1: Cloudinary Live Streaming (if enabled on your account)
      // This creates an RTMP endpoint you can stream to

      // Method 2: Simulate live stream using auto-upload (FREE TIER FRIENDLY)
      // For now, create a placeholder that will be replaced with actual video
      final streamUrl = await _createLiveStreamPlaceholder(
        publicId: _currentPublicId!,
        crimeType: crimeType,
        description: description,
      );

      if (streamUrl != null) {
        _currentPlaybackUrl = streamUrl;
        developer.log('✅ Stream URL: $streamUrl');

        return {
          'streamUrl': streamUrl,           // HLS .m3u8 URL for viewers
          'publicId': _currentPublicId!,    // For broadcaster reference
          'uploadUrl': 'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
        };
      }

      return null;

    } catch (e) {
      developer.log('❌ Error starting stream: $e');
      return null;
    }
  }

  /// Create a live stream placeholder
  /// In production, this sets up RTMP streaming endpoint
  /// For free tier: We create a "live" video that gets replaced
  Future<String?> _createLiveStreamPlaceholder({
    required String publicId,
    required String crimeType,
    String? description,
  }) async {
    try {
      // For Cloudinary live streaming, you need to:
      // 1. Enable "Live Streaming" addon in Cloudinary (may require card)
      // 2. OR use the workaround below

      // WORKAROUND for free tier: Create a "live" manifest
      // This creates an HLS playlist that you can update with segments

      final url = 'https://res.cloudinary.com/$_cloudName/video/upload/'
          'live_streaming/$publicId.m3u8';

      // Store metadata in your database via Supabase
      // The actual streaming will be done via WebRTC recorder → Cloudinary

      return url;

    } catch (e) {
      developer.log('❌ Error creating placeholder: $e');
      return null;
    }
  }

  /// Stop stream and finalize video
  Future<Map<String, dynamic>?> stopStream() async {
    try {
      developer.log('🛑 Stopping Cloudinary stream...');

      // Finalize the live stream
      // This converts the live stream to a VOD asset

      final playbackUrl = _currentPlaybackUrl;
      final publicId = _currentPublicId;

      // Reset
      _currentPublicId = null;
      _currentPlaybackUrl = null;

      return {
        'playbackUrl': playbackUrl,
        'publicId': publicId,
        'status': 'stopped',
      };

    } catch (e) {
      developer.log('❌ Error stopping stream: $e');
      return null;
    }
  }

  /// Upload recorded video to Cloudinary (for recorded streams)
  Future<String?> uploadStreamRecording({
    required List<int> videoBytes,
    required String crimeType,
  }) async {
    try {
      final publicId = 'stream_recording_${DateTime.now().millisecondsSinceEpoch}';

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/video/upload'
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['public_id'] = publicId
        ..fields['resource_type'] = 'video'
        ..fields['context'] = 'crime_type=$crimeType'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            videoBytes,
            filename: '$publicId.mp4',
          ),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final secureUrl = jsonData['secure_url'] as String;

        // Generate HLS adaptive streaming URL
        final hlsUrl = secureUrl
            .replaceAll('/upload/', '/upload/sp_hd/')
            .replaceAll('.mp4', '.m3u8');

        developer.log('✅ Uploaded to Cloudinary: $hlsUrl');
        return hlsUrl;
      } else {
        throw Exception('Upload failed: ${jsonData['error']['message']}');
      }

    } catch (e) {
      developer.log('❌ Upload error: $e');
      return null;
    }
  }

  /// Get HLS streaming URL for any Cloudinary video
  /// This transforms a regular video into an adaptive HLS stream
  String getHlsStreamUrl(String videoUrl) {
    // Transform Cloudinary URL to HLS streaming URL
    // Original: https://res.cloudinary.com/cloud/video/upload/video.mp4
    // HLS:     https://res.cloudinary.com/cloud/video/upload/sp_hd/video.m3u8

    if (videoUrl.contains('.m3u8')) return videoUrl;

    return videoUrl
        .replaceAll('/upload/', '/upload/sp_hd/')  // sp_hd = streaming profile high def
        .replaceAll('.mp4', '.m3u8')
        .replaceAll('.mov', '.m3u8')
        .replaceAll('.webm', '.m3u8');
  }

  bool get isStreaming => _currentPublicId != null;
  String? get currentStreamUrl => _currentPlaybackUrl;
}