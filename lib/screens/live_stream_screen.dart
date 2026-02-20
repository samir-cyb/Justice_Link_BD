import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:justice_link_user/services/webrtc_stream_service.dart';
import 'package:justice_link_user/services/nirbacon_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamScreen extends StatefulWidget {
  final String crimeType;
  final String? description;
  final LatLng? location;
  final String? staticArea;
  final String? dynamicArea;

  const LiveStreamScreen({
    super.key,
    required this.crimeType,
    this.description,
    this.location,
    this.staticArea,
    this.dynamicArea,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with WidgetsBindingObserver {

  final WebRTCStreamService _streamService = WebRTCStreamService();
  final NirbaconService _nirbaconService = NirbaconService();
  final SupabaseClient _supabase = Supabase.instance.client;

  RTCVideoRenderer? _localRenderer;
  bool _isStreaming = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _streamUrl;
  String? _roomId;
  DateTime? _startTime;
  Timer? _durationTimer;
  Duration _streamDuration = Duration.zero;
  String? _uploadedVideoUrl;

  // Recording quality
  bool _saveRecording = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _localRenderer = await _streamService.initializeCamera();
    if (mounted) setState(() {});
  }

  Future<void> _startStream() async {
    try {
      final result = await _streamService.startStream(
        crimeType: widget.crimeType,
        description: widget.description,
        enableRecording: _saveRecording,
      );

      if (result == null) {
        _showError('Failed to start stream');
        return;
      }

      setState(() {
        _isStreaming = true;
        _isRecording = result['isRecording'] as bool;
        _streamUrl = result['streamUrl'] as String;
        _roomId = result['roomId'] as String;
        _startTime = DateTime.parse(result['startTime'] as String);
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _streamDuration = DateTime.now().difference(_startTime!);
        });
      });

      // Save to database as "live stream in progress"
      await _saveToDatabase(isActive: true);

      _showSuccess('Live stream started!');

    } catch (e) {
      _showError('Stream error: $e');
    }
  }

  // In live_stream_screen.dart, update the result handling:

  Future<void> _stopStream() async {
    setState(() => _isUploading = true);
    _durationTimer?.cancel();

    final result = await _streamService.stopStream(saveRecording: _saveRecording);

    // Get the HLS URL from result
    _uploadedVideoUrl = result?['videoUrl'] as String?;  // HLS .m3u8 URL

    // Save to database with ACTUAL video URL
    await _saveToDatabase(
      isActive: false,
      duration: result?['duration'] as int?,
      videoUrl: _uploadedVideoUrl,  // This is now a real Cloudinary HLS URL!
    );

    setState(() {
      _isStreaming = false;
      _isRecording = false;
      _isUploading = false;
    });

    if (mounted) {
      Navigator.pop(context, {
        'streamed': true,
        'videoUrl': _uploadedVideoUrl,  // Real URL ending in .m3u8
        'duration': _streamDuration.inSeconds,
      });
    }
  }

  Future<void> _saveToDatabase({
    required bool isActive,
    int? duration,
    String? videoUrl,
  }) async {
    try {
      if (widget.location == null) return;

      final result = await _nirbaconService.submitCrimeReport(
        crimeType: widget.crimeType,
        description: widget.description?.isNotEmpty == true
            ? widget.description!
            : 'Live stream recording',
        location: widget.location!,
        staticArea: widget.staticArea,
        dynamicArea: widget.dynamicArea,
        isLiveStream: isActive, // true = currently live, false = ended
        liveStreamUrl: isActive ? _streamUrl : null,
        videoUrls: videoUrl != null ? [videoUrl] : null,
      );

      if (!result['success']) {
        developer.log('❌ Database save failed: ${result['error']}');
      }

    } catch (e) {
      developer.log('❌ Database error: $e');
    }
  }

  void _switchCamera() async {
    await _streamService.switchCamera();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isStreaming) {
      // Continue streaming in background (recording keeps going)
      developer.log('App paused, stream continues in background');
    } else if (state == AppLifecycleState.detached) {
      // App killed - stop and save
      _stopStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    if (_isStreaming) {
      _streamService.stopStream(saveRecording: _saveRecording);
    }
    _localRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_localRenderer != null)
            RTCVideoView(
              _localRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: true,
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Live/Recording Indicator
                      if (_isStreaming)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing dot
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 800),
                                builder: (context, value, child) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3 + (0.7 * value)),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Recording indicator
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('REC', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),

                      // Duration
                      if (_isStreaming)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_streamDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Crime Type Badge
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    widget.crimeType,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),

                // Save recording toggle
                if (!_isStreaming)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Save recording to cloud',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _saveRecording,
                          onChanged: (v) => setState(() => _saveRecording = v),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Bottom Controls
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Switch camera
                      if (_isStreaming)
                        IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                      else
                        const SizedBox(width: 48),

                      // Start/Stop button
                      GestureDetector(
                        onTap: _isUploading
                            ? null
                            : (_isStreaming ? _stopStream : _startStream),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isStreaming ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: (_isStreaming ? Colors.red : Colors.green)
                                    .withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: _isUploading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Icon(
                            _isStreaming ? Icons.stop : Icons.videocam,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),

                      // Placeholder for symmetry
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Uploading overlay
          if (_isUploading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'Saving recording...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}