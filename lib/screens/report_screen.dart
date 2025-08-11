import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:justice_link_user/screens/timeline_screen.dart';
import 'package:justice_link_user/screens/profile_screen.dart';
import 'package:justice_link_user/screens/emergency_support_screen.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// Conditional import for classifier
import 'package:justice_link_user/screens/text_classifier.dart'
if (dart.library.html) 'package:justice_link_user/screens/text_classifier_web.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _reportController = TextEditingController();
  bool _isRecording = false;
  bool _isLocationSharing = false;
  List<XFile> _images = [];
  XFile? _audioFile;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  LatLng? _currentLocation;
  bool _isUploading = false;
  String? _recordingTime = '00:00';
  DateTime? _recordingStartTime;
  final EmergencyService _emergencyService = EmergencyService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ValueNotifier<int> _currentTabIndex = ValueNotifier<int>(0);
  StreamSubscription<Position>? _positionStream;
  bool _locationError = false;
  bool _locationLoading = true;
  double? _predictionConfidence;
  late TextClassifier _textClassifier;
  bool _classifierInitialized = false;
  Map<String, dynamic>? _prediction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _requestLocationPermission();
    _initializeClassifier();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocationSharing) {
        _positionStream?.resume();
      }
    }
  }

  Future<void> _initializeClassifier() async {
    try {
      _textClassifier = TextClassifier();
      await _textClassifier.initialize();
      setState(() {
        _classifierInitialized = true;
      });
    } catch (e) {
      debugPrint("Error initializing classifier: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    if (_isLocationSharing) {
      _emergencyService.endEmergency(_supabase.auth.currentUser?.id ?? '');
    }
    _animationController.dispose();
    _reportController.dispose();
    _currentTabIndex.dispose();
    _textClassifier.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.1),
        weight: 1.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 1.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() {
        _locationError = true;
        _locationLoading = false;
      });
      _showError('Location permission denied');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = true;
          _locationLoading = false;
        });
        _showError('Please enable location services');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationError = false;
        _locationLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationError = true;
        _locationLoading = false;
      });
      _showError('Error getting location: $e');
    }
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationError = false;
      });

      if (_isLocationSharing) {
        _emergencyService.updateEmergencyLocation(
          _currentLocation!,
          _supabase.auth.currentUser?.id ?? '',
        );
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _locationError = true);
      _showError('Location update error: $e');
    });
  }

  void _stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void _stopLocationSharing() {
    _stopLocationUpdates();
    setState(() {
      _isLocationSharing = false;
    });
    _emergencyService.endEmergency(_supabase.auth.currentUser?.id ?? '');
    _showInfo('Location sharing stopped');
  }

  void _startHold() {
    setState(() {
      _isHolding = true;
    });

    const holdDuration = Duration(seconds: 1);
    final startTime = DateTime.now();

    void updateProgress() {
      if (!_isHolding || !mounted) return;

      final elapsed = DateTime.now().difference(startTime);
      setState(() {
        _holdProgress = elapsed.inMilliseconds / holdDuration.inMilliseconds;
      });

      if (elapsed < holdDuration) {
        Future.delayed(const Duration(milliseconds: 16), updateProgress);
      } else {
        _onTapAndHoldCompleted();
      }
    }

    updateProgress();
  }

  void _endHold() {
    if (!mounted) return;
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  void _onTapAndHoldCompleted() async {
    await _getCurrentLocation();

    if (_locationError || _currentLocation == null) {
      _showError('Cannot start emergency without location');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLocationSharing = true;
      _isHolding = false;
    });

    _startLocationUpdates();

    await _emergencyService.sendEmergencyAlert(
      _currentLocation!,
      _supabase.auth.currentUser?.id ?? '',
    );

    _showSuccess('Emergency alert sent! Sharing your location...');
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() {
          _images.add(image);
        });
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(images);
        });
      }
    } catch (e) {
      _showError('Error selecting images: $e');
    }
  }

  void _removeImage(int index) {
    if (!mounted) return;
    setState(() {
      _images.removeAt(index);
    });
  }

  void _updateRecordingTime() {
    if (_recordingStartTime != null && mounted) {
      final elapsed = DateTime.now().difference(_recordingStartTime!);
      final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _recordingTime = '$minutes:$seconds';
      });
      Future.delayed(const Duration(seconds: 1), _updateRecordingTime);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final dir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      final filePath = path.join(dir.path, fileName);

      final file = File(filePath)..createSync();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _audioFile = XFile(filePath);
          _recordingTime = '00:00';
          _recordingStartTime = null;
        });
      }

      _showSuccess('Recording saved');
    } else {
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
        });
      }
      _updateRecordingTime();
      _showInfo('Recording started');
    }
  }

  Future<void> _submitReport() async {
    if (_reportController.text.isEmpty) {
      _showError('Please describe the incident');
      return;
    }

    if (_currentLocation == null) {
      _showError('Location not available');
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      _prediction = await _textClassifier.classify(_reportController.text);
      _predictionConfidence = _prediction?['confidence'];
      final isDangerous = _prediction?['label'] == 'dangerous';

      final imageUrls = await Future.wait(
        _images.map((image) => _uploadFile(image, 'images')).toList(),
      );

      String? audioUrl;
      if (_audioFile != null) {
        audioUrl = await _uploadFile(_audioFile!, 'audio');
      }

      final location = 'POINT(${_currentLocation!.longitude} ${_currentLocation!.latitude})';

      await _supabase.from('reports').insert({
        'description': _reportController.text,
        'location': location,
        'images': imageUrls,
        'audio_url': audioUrl,
        'is_emergency': _isLocationSharing && !isDangerous,
        'created_at': DateTime.now().toIso8601String(),
        'user_id': _supabase.auth.currentUser?.id,
        'votes': {'dangerous': 0, 'suspicious': 0, 'normal': 0, 'fake': 0},
        'user_votes': {},
        'predicted_label': _prediction?['label'],
        'predicted_confidence': _predictionConfidence,
        'risk_score': _calculateRiskScore(isDangerous),
      });

      if (isDangerous) {
        if (_isLocationSharing) {
          _stopLocationSharing();
        }
        _showInfo('Dangerous situation detected! Report submitted with high priority');
      }

      _showSuccess('Report submitted successfully!');
      _resetForm();
    } catch (e) {
      _showError('Failed to submit report: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  double _calculateRiskScore(bool isDangerous) {
    double score = 0;
    if (isDangerous) {
      score += (_predictionConfidence ?? 0) * 80;
    } else {
      score += (_predictionConfidence ?? 0) * 30;
    }
    if (_isLocationSharing) {
      score += 20;
    }
    return score.clamp(0, 100).toDouble();
  }

  Future<String> _uploadFile(XFile file, String folder) async {
    try {
      final fileExt = path.extension(file.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = '$folder/$fileName';

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await _supabase.storage
            .from('reports')
            .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
      } else {
        await _supabase.storage
            .from('reports')
            .upload(filePath, File(file.path), fileOptions: const FileOptions(upsert: true));
      }

      return _supabase.storage.from('reports').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  void _resetForm() {
    _reportController.clear();
    if (mounted) {
      setState(() {
        _images.clear();
        _audioFile = null;
        _isRecording = false;
        _recordingTime = '00:00';
        _recordingStartTime = null;
        _prediction = null;
        _predictionConfidence = null;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionBadge() {
    if (_prediction == null) return const SizedBox();

    final label = _prediction!['label'];
    final confidence = _prediction!['confidence'];

    Color getColor() {
      switch (label) {
        case 'dangerous':
          return Colors.redAccent;
        case 'suspicious':
          return Colors.orangeAccent;
        case 'fake':
          return Colors.purpleAccent;
        default:
          return Colors.greenAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: getColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: getColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            color: getColor(),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${label.toUpperCase()} (${(confidence * 100).toStringAsFixed(1)}%)',
            style: TextStyle(
              color: getColor(),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blueGrey[800]!, Colors.blueGrey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 40, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                'No photos added',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: 16, left: index == 0 ? 0 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: kIsWeb
                        ? Image.network(_images[index].path, fit: BoxFit.cover)
                        : Image.file(File(_images[index].path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioSection() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isRecording ? 100 : 80,
          height: _isRecording ? 100 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isRecording
                ? const RadialGradient(
              colors: [Colors.redAccent, Colors.red],
              stops: [0.5, 1.0],
            )
                : const RadialGradient(
              colors: [Colors.lightGreen, Colors.green],
              stops: [0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _isRecording ? Colors.redAccent : Colors.green,
                blurRadius: _isRecording ? 20 : 10,
                spreadRadius: _isRecording ? 2 : 1,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              size: 36,
              color: Colors.white,
            ),
            onPressed: _toggleRecording,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isRecording ? 'RECORDING' : 'PRESS TO RECORD',
          style: TextStyle(
            color: _isRecording ? Colors.redAccent : Colors.greenAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        if (_isRecording || _audioFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _isRecording ? _recordingTime! : 'Audio recorded',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D effect with shadows and gradients
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isHolding
                    ? [Colors.redAccent, Colors.red]
                    : [Colors.blueAccent, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHolding ? Colors.red.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          // Inner circle for depth
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          // Text or Icon
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLocationSharing ? Icons.stop : Icons.touch_app,
                size: 50,
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              Text(
                _isLocationSharing ? 'STOP' : 'HOLD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          // Progress indicator
          if (_isHolding)
            CircularProgressIndicator(
              value: _holdProgress,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          // Stop sharing button
          if (_isLocationSharing)
            Positioned(
              bottom: 10,
              child: GestureDetector(
                onTap: _stopLocationSharing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Stop Sharing',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  _buildEmergencyButton(),
                  const SizedBox(height: 20),
                  Text(
                    _isLocationSharing
                        ? 'EMERGENCY ACTIVE • LOCATION SHARING'
                        : 'TAP AND HOLD FOR EMERGENCY',
                    style: TextStyle(
                      color: _isLocationSharing ? Colors.red : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _locationLoading
                        ? const Text(
                      'Acquiring location...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : Text(
                      _isLocationSharing
                          ? 'Sharing location: ${_currentLocation?.latitude.toStringAsFixed(5) ?? 'N/A'}, ${_currentLocation?.longitude.toStringAsFixed(5) ?? 'N/A'}'
                          : 'Current location: ${_currentLocation?.latitude.toStringAsFixed(5) ?? 'N/A'}, ${_currentLocation?.longitude.toStringAsFixed(5) ?? 'N/A'}',
                      style: TextStyle(
                        color: _locationError
                            ? Colors.orange
                            : _isLocationSharing
                            ? Colors.green
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_locationError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Location services not available',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white.withOpacity(0.07),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic, color: Colors.redAccent, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'AUDIO RECORDING',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildAudioSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white.withOpacity(0.07),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.blueAccent, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'INCIDENT DETAILS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        if (_prediction != null) _buildPredictionBadge(),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: TextFormField(
                        controller: _reportController,
                        maxLines: 8,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(15),
                          hintText: 'Describe the incident in detail...',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white.withOpacity(0.07),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'ATTACH PHOTOS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildImagePreview(),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconButton(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          color: Colors.blueAccent,
                          onPressed: _pickImageFromCamera,
                        ),
                        _buildIconButton(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          color: Colors.purpleAccent,
                          onPressed: _pickImageFromGallery,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 10,
                      shadowColor: Colors.green.withOpacity(0.5),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isUploading
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'SUBMITTING...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        )
                            : const Text(
                          'SUBMIT REPORT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'REPORT PORTAL';
      case 1:
        return 'EMERGENCY SUPPORT';
      case 2:
        return 'TIMELINE';
      case 3:
        return 'PROFILE';
      default:
        return 'REPORT PORTAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<int>(
            valueListenable: _currentTabIndex,
            builder: (context, index, _) {
              return Text(
                _getAppBarTitle(index),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 18,
                ),
              );
            },
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: _currentTabIndex,
              builder: (context, index, _) {
                if (index == 0) {
                  return Row(
                    children: [
                      if (_prediction != null) _buildPredictionBadge(),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.send, size: 28),
                        onPressed: _isUploading ? null : _submitReport,
                        tooltip: 'Submit Report',
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildReportTab(),
            EmergencySupportScreen(
              currentUserId: _supabase.auth.currentUser?.id ?? '',
            ),
            const TimelineScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: TabBar(
            onTap: (index) {
              _currentTabIndex.value = index;
              if (index != 0 && index != 1) {
                _positionStream?.pause();
              } else if (_isLocationSharing) {
                _positionStream?.resume();
              }
            },
            tabs: const [
              Tab(icon: Icon(Icons.report), text: 'Report'),
              Tab(icon: Icon(Icons.emergency), text: 'Emergency'),
              Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
              Tab(icon: Icon(Icons.person), text: 'Profile'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.green,
            indicatorWeight: 3.0,
          ),
        ),
      ),
    );
  }
}