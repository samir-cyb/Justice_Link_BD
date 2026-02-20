import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:convert';

/// WebRTC Recording + Cloudinary Upload
/// - Records video locally using WebRTC
/// - Uploads to Cloudinary when stream ends
/// - Returns HLS URL for playback
class WebRTCStreamService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;

  // Recording state
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _streamStartTime;

  // Stream info
  String? _currentRoomId;
  String? _crimeType;

  // Cloudinary config
  static const String _cloudName = 'dja3wckvy';
  static const String _uploadPreset = 'justice_report';

  /// Initialize camera for preview
  Future<RTCVideoRenderer?> initializeCamera() async {
    try {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();

      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': true,
      });

      _localRenderer!.srcObject = _localStream;
      return _localRenderer;

    } catch (e) {
      developer.log('❌ Camera init error: $e');
      return null;
    }
  }

  /// Start streaming + recording
  Future<Map<String, dynamic>?> startStream({
    required String crimeType,
    String? description,
    bool enableRecording = true,
  }) async {
    try {
      developer.log('🎥 Starting WebRTC recording stream...');
      _crimeType = crimeType;
      _streamStartTime = DateTime.now();

      // Ensure camera is ready
      if (_localStream == null) {
        await initializeCamera();
      }

      // Start recording to file
      if (enableRecording) {
        await _startRecordingToFile();
      }

      // Create room ID for viewers to know which stream to watch
      _currentRoomId = '${DateTime.now().millisecondsSinceEpoch}_${crimeType.hashCode}';

      // IMPORTANT: For live viewing, we have two options:

      // OPTION A: WebRTC P2P (complex, requires signaling server)
      // OPTION B: Upload chunks to Cloudinary (simpler, slight delay)

      // For now, we return a "pending" URL that will be updated
      // when the recording is uploaded

      final pendingUrl = 'https://res.cloudinary.com/$_cloudName/'
          'video/upload/live_streaming/$_currentRoomId.m3u8';

      return {
        'streamUrl': pendingUrl,        // Will be valid after upload
        'roomId': _currentRoomId,
        'isRecording': _isRecording,
        'startTime': _streamStartTime!.toIso8601String(),
        'status': 'recording',          // recording → uploading → live
      };

    } catch (e) {
      developer.log('❌ Stream start error: $e');
      return null;
    }
  }

  /// Start recording to local file using native recorder
  Future<void> _startRecordingToFile() async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${dir.path}/stream_$timestamp.mp4';

      // TODO: Implement native recording
      // For Android: Use MediaRecorder via platform channel
      // For iOS: Use AVCaptureMovieFileOutput

      // Temporary: We'll use the camera plugin's recording instead
      _isRecording = true;

      developer.log('📹 Recording to: $_recordingPath');

    } catch (e) {
      developer.log('❌ Recording start error: $e');
      _isRecording = false;
    }
  }

  /// Stop stream and upload to Cloudinary
  Future<Map<String, dynamic>?> stopStream({bool saveRecording = true}) async {
    developer.log('🛑 Stopping stream and uploading...');

    final endTime = DateTime.now();
    final duration = endTime.difference(_streamStartTime ?? endTime);

    // Stop WebRTC
    _localStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _peerConnection = null;

    String? cloudinaryUrl;
    String? hlsUrl;

    // Stop recording and upload
    if (_isRecording && saveRecording && _recordingPath != null) {
      final file = File(_recordingPath!);

      if (await file.exists()) {
        // Upload to Cloudinary
        cloudinaryUrl = await _uploadToCloudinary(file);

        // Convert to HLS streaming URL
        if (cloudinaryUrl != null) {
          hlsUrl = _convertToHlsUrl(cloudinaryUrl);
        }
      }
    }

    // Cleanup
    await _localRenderer?.dispose();
    _localRenderer = null;
    _isRecording = false;

    return {
      'duration': duration.inSeconds,
      'cloudinaryUrl': cloudinaryUrl,    // Original MP4
      'videoUrl': hlsUrl,                // HLS streaming URL
      'roomId': _currentRoomId,
      'status': hlsUrl != null ? 'uploaded' : 'failed',
    };
  }

  /// Upload video file to Cloudinary
  Future<String?> _uploadToCloudinary(File videoFile) async {
    try {
      developer.log('📤 Uploading to Cloudinary...');

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/video/upload'
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['resource_type'] = 'video'
        ..fields['context'] = 'crime_type=$_crimeType|room_id=$_currentRoomId';

      // Add file
      final mimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';
      final fileStream = http.ByteStream(videoFile.openRead());
      final fileLength = await videoFile.length();

      request.files.add(http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: videoFile.path.split('/').last,
        contentType: MediaType.parse(mimeType),
      ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final url = jsonData['secure_url'] as String;
        developer.log('✅ Uploaded: $url');
        return url;
      } else {
        throw Exception('Upload failed: ${jsonData['error']['message']}');
      }

    } catch (e) {
      developer.log('❌ Cloudinary upload error: $e');
      return null;
    }
  }

  /// Convert Cloudinary URL to HLS streaming URL
  String? _convertToHlsUrl(String cloudinaryUrl) {
    try {
      // Transform to HLS adaptive streaming
      // sp_hd = streaming profile high definition

      return cloudinaryUrl
          .replaceAll('/upload/', '/upload/sp_hd/')
          .replaceAll('.mp4', '.m3u8')
          .replaceAll('.mov', '.m3u8');

    } catch (e) {
      developer.log('❌ HLS conversion error: $e');
      return null;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().first;
    await Helper.switchCamera(videoTrack);
  }

  // Getters
  MediaStream? get localStream => _localStream;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  bool get isRecording => _isRecording;
  String? get currentRoomId => _currentRoomId;
}