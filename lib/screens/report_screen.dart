import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

// Import your existing screens
import 'package:justice_link_user/screens/timeline_screen.dart';
import 'package:justice_link_user/screens/profile_screen.dart';
import 'package:justice_link_user/screens/emergency_support_screen.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:justice_link_user/screens/text_classifier.dart';
import 'package:justice_link_user/data/location_data.dart';
// Import the new ReportService
import 'package:justice_link_user/services/report_service.dart';


class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // --- 1. GLOBAL NOTIFICATION SYSTEM ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _globalAudioPlayer = AudioPlayer();
  StreamSubscription? _globalEmergencySubscription;
  late TabController _tabController;

  // Add this right after the above declarations:
  final MethodChannel _platformChannel =
  const MethodChannel('justice_link/notification');

  // Logic to prevent duplicate popups
  bool _isDialogVisible = false;
  final Set<String> _handledEmergencyIds = {};

  // --- 2. REPORT FORM CONTROLLERS ---
  final TextEditingController _reportController = TextEditingController();

  // Form Selections
  String? _selectedEnvironment;
  String? _selectedCrimeCategory;  // Changed from _selectedCrimeType
  String? _selectedCity;
  String? _selectedArea;

  // --- 3. EMERGENCY UI STATE ---
  String _selectedEmergencyType = 'General';
  final List<Map<String, dynamic>> _emergencyTypes = [
    {'label': 'General', 'icon': Icons.warning_amber_rounded, 'color': Colors.grey},
    {'label': 'Police', 'icon': Icons.local_police, 'color': Colors.blue},
    {'label': 'Medical', 'icon': Icons.medical_services, 'color': Colors.red},
    {'label': 'Fire', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'label': 'Harassment', 'icon': Icons.do_not_touch, 'color': Colors.purple},
  ];

  // --- 4. LOGIC VARIABLES ---
  bool _isRecording = false;
  bool _isLocationSharing = false;
  List<XFile> _images = [];
  XFile? _audioFile;
  final ImagePicker _picker = ImagePicker();

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Emergency Button Logic
  double _holdProgress = 0.0;
  bool _isHolding = false;

  // Data Logic
  LatLng? _currentLocation;
  bool _isUploading = false;
  String? _recordingTime = '00:00';
  DateTime? _recordingStartTime;
  final EmergencyService _emergencyService = EmergencyService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // NEW: Report Service
  final ReportService _reportService = ReportService();

  // Location & AI State
  StreamSubscription<Position>? _positionStream;
  bool _locationError = false;
  bool _locationLoading = true;
  double? _predictionConfidence;
  late TextClassifier _textClassifier;
  bool _classifierInitialized = false;
  Map<String, dynamic>? _prediction;
  String _deviceId = 'unknown_device';

  // NEW: Crime Categories
  List<Map<String, dynamic>> _onlineCrimeCategories = [];
  List<Map<String, dynamic>> _offlineCrimeCategories = [];
  bool _loadingCategories = false;

  // NEW: Image processing variables
  bool _isProcessingImage = false;
  bool _imageVerificationRequired = false;
  final List<Map<String, dynamic>> _imageVerificationResults = [];

  // Request notification permission (Android 13+)
  Future<void> _requestNotificationPermission() async {
    if (!kIsWeb) {
      try {
        await _platformChannel.invokeMethod('requestNotificationPermission');
        developer.log("Notification permission requested");
      } catch (e) {
        developer.log("Permission request error: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 4, vsync: this);

    _initAnimations();
    _requestLocationPermission();
    _initializeClassifier();
    _getDeviceId();
    _loadCrimeCategories();  // NEW: Load crime categories

    _initLocalNotifications();
    _startGlobalEmergencyListener();
    _requestNotificationPermission();


// Open notification settings
    Future<void> _openNotificationSettings() async {
      if (!kIsWeb) {
        try {
          await _platformChannel.invokeMethod('openNotificationSettings');
        } catch (e) {
          developer.log("Open settings error: $e");
        }
      }
    }
  }

  // NEW: Load crime categories from database
  Future<void> _loadCrimeCategories() async {
    if (!mounted) return;

    setState(() => _loadingCategories = true);
    try {
      final categories = await _reportService.getAllCategories();

      if (mounted) {
        setState(() {
          _onlineCrimeCategories = categories['online'] ?? [];
          _offlineCrimeCategories = categories['offline'] ?? [];
          _loadingCategories = false;
        });
      }
    } catch (e) {
      developer.log("Error loading crime categories: $e");
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  // NEW: Check if selected category requires image verification
  bool _requiresImageVerification(String? category) {
    if (category == null) return false;

    final killingKeywords = [
      'killing', 'murder', 'homicide', 'dead body', 'corpse',
      'killing / murders', 'killing/murders'
    ];

    return killingKeywords.any((keyword) =>
        category.toLowerCase().contains(keyword.toLowerCase()));
  }

  // --- NOTIFICATION SETUP ---
  Future<void> _initLocalNotifications() async {
    // Only init notifications on mobile to avoid web errors
    if (kIsWeb) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Create channel for high priority alerts
    // Note: Can't be const because of vibrationPattern
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_channel_high', // id
      'Emergency Alerts', // title
      description: 'High priority alerts for SOS', // description
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _tabController.animateTo(1);
      },
    );
  }

  // --- GLOBAL LISTENER ---
  void _startGlobalEmergencyListener() {
    _globalEmergencySubscription = _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {

      final myId = _supabase.auth.currentUser?.id;

      final othersEmergencies = data.where((e) {
        return e['status'] == 'active' &&
            e['user_id'] != myId;
      }).toList();

      if (othersEmergencies.isNotEmpty) {
        final latest = othersEmergencies.last;
        String emergencyId = latest['id'].toString();

        if (!_isDialogVisible && !_handledEmergencyIds.contains(emergencyId)) {
          _triggerSystemNotification(latest);
        }
      }
    });
  }

  void _triggerSystemNotification(Map<String, dynamic> emergency) async {
    _isDialogVisible = true;
    String emergencyId = emergency['id'].toString();

    // 1. Play Sound - USE NETWORK FOR BOTH TO AVOID ASSET ISSUES
    try {
      // Always use network audio for reliability
      await _globalAudioPlayer.play(
          UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3')
      );
      _globalAudioPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      developer.log("Audio Error: $e");

      // Fallback to a simpler alarm sound
      try {
        await _globalAudioPlayer.play(
            UrlSource('https://assets.mixkit.co/sfx/preview/mixkit-alarm-digital-clock-beep-989.mp3')
        );
        _globalAudioPlayer.setReleaseMode(ReleaseMode.loop);
      } catch (e2) {
        developer.log("Fallback audio also failed: $e2");
      }
    }

    // 2. SHOW SYSTEM NOTIFICATION (Mobile Only) - WITH FULL-SCREEN INTENT
    if (!kIsWeb) {
      // Enhanced notification details for full-screen popup
      final androidDetails = AndroidNotificationDetails(
        'emergency_channel_high',
        'Emergency Alerts',
        channelDescription: 'High priority emergency alerts',
        importance: Importance.max,
        priority: Priority.high,

        // CRITICAL: Enable full-screen intent for popup over other apps
        fullScreenIntent: true,

        // Make it appear as an alarm/emergency
        category: AndroidNotificationCategory.alarm,
        autoCancel: false, // Don't auto-dismiss
        ongoing: true, // Ongoing notification

        // Visual effects
        ticker: '🚨 SOS EMERGENCY 🚨',
        visibility: NotificationVisibility.public, // Show on lock screen

        // Sound and vibration
        sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),

        // LED (if device has it)
        ledColor: Colors.red,
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,

        // Style for better appearance
        styleInformation: BigTextStyleInformation(
          'Someone nearby needs immediate assistance!\n'
              'Emergency Type: ${emergency['type']?.toString().toUpperCase() ?? 'GENERAL'}\n'
              'Tap to open the emergency map.',
          htmlFormatBigText: true,
          contentTitle: '🚨 URGENT: SOS EMERGENCY 🚨',
          summaryText: 'Immediate action required',
          htmlFormatContentTitle: true,
        ),

        // Additional settings for reliability
        timeoutAfter: 60000, // Auto-dismiss after 1 minute if not interacted
        groupKey: 'emergency_group',
        setAsGroupSummary: true,
        color: Colors.red,
        colorized: true,
      );

      final details = NotificationDetails(android: androidDetails);

      try {
        await _notificationsPlugin.show(
          emergency['id'].hashCode,
          '🚨 SOS: ${emergency['type']?.toString().toUpperCase() ?? 'GENERAL'}',
          'Someone nearby needs immediate help! Tap to open map.',
          details,
          payload: 'emergency://${emergency['id']}', // Payload for deep linking
        );
        developer.log("✅ Full-screen notification sent");
      } catch (e) {
        developer.log("❌ Notification error: $e");
      }
    }

    if (!mounted) return;

    // 3. Check if app is in foreground before showing dialog
    final isAppInForeground = WidgetsBinding.instance.lifecycleState ==
        AppLifecycleState.resumed;

    if (isAppInForeground) {
      // SHOW UPGRADED IN-APP DIALOG (only when app is in foreground)
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.8),
        useSafeArea: true,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async => false, // Prevent back button from dismissing
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.red[900]!.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                        blurStyle: BlurStyle.outer,
                      )
                    ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flashing Icon with animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.2 * _animationController.value),
                          child: child,
                        );
                      },
                      child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 60,
                          color: Colors.yellow
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Title with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: const Text(
                        "EMERGENCY ALERT",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white54),
                    const SizedBox(height: 10),

                    Text(
                      "TYPE: ${emergency['type']?.toString().toUpperCase() ?? 'GENERAL'}",
                      style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      "Someone nearby needs immediate assistance.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 25),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // IGNORE button
                        TextButton(
                          onPressed: () {
                            _stopGlobalAlert(emergencyId);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10
                            ),
                          ),
                          child: const Text("IGNORE"),
                        ),

                        // GO TO MAP button (primary action)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red[900],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)
                            ),
                            elevation: 5,
                            shadowColor: Colors.white.withOpacity(0.5),
                          ),
                          onPressed: () {
                            _stopGlobalAlert(emergencyId);
                            Navigator.pop(context);
                            // Switch to Emergency Tab immediately
                            _tabController.animateTo(1);
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on),
                              SizedBox(width: 8),
                              Text(
                                  "GO TO MAP",
                                  style: TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Small note about full-screen notification
                    if (!kIsWeb)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          "⚠️ A full-screen alert was also sent to your notification panel",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      // App is in background - rely on full-screen notification
      developer.log("App is in background, showing full-screen notification only");
    }
  }

  void _stopGlobalAlert(String id) {
    try {
      _globalAudioPlayer.stop();
      if (!kIsWeb) {
        _notificationsPlugin.cancelAll();
      }
    } catch (e) {
      developer.log("Error stopping alert: $e");
    }
    _isDialogVisible = false;
    _handledEmergencyIds.add(id);
  }

  // --- STANDARD METHODS (Unchanged) ---

  Future<void> _getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        _deviceId = 'web_${webInfo.userAgent?.hashCode ?? 'unknown'}';
      } else {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          _deviceId = 'android_${androidInfo.id}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _deviceId = 'ios_${iosInfo.identifierForVendor}';
        }
      }
    } catch (e) {
      _deviceId = 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_isLocationSharing) _positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _positionStream?.resume();
    }
  }

  Future<void> _initializeClassifier() async {
    try {
      _textClassifier = TextClassifier();
      await _textClassifier.initialize();
      setState(() => _classifierInitialized = true);
    } catch (e) {
      setState(() => _classifierInitialized = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    if (_isLocationSharing) {
      _emergencyService.endEmergency(_supabase.auth.currentUser?.id ?? '');
    }
    _globalEmergencySubscription?.cancel();
    _globalAudioPlayer.dispose();
    _animationController.dispose();
    _reportController.dispose();
    _tabController.dispose();
    _textClassifier.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 1.0),
    ]).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

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
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
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
    }
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
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
    });
  }

  void _stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _stopLocationSharing() async {
    _stopLocationUpdates();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('emergencies')
            .update({'status': 'resolved'})
            .eq('user_id', userId)
            .eq('status', 'active');
      }
    } catch (e) {
      developer.log("Error stopping emergency: $e");
    }

    if(mounted) {
      setState(() => _isLocationSharing = false);
      _showInfo('Location sharing stopped & SOS resolved');
    }
  }

  void _startHold() {
    setState(() => _isHolding = true);
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
    setState(() {
      _isLocationSharing = true;
      _isHolding = false;
    });
    _startLocationUpdates();

    try {
      final userId = _supabase.auth.currentUser?.id ?? '';
      await _supabase.from('emergencies').insert({
        'user_id': userId,
        'location': 'POINT(${_currentLocation!.longitude} ${_currentLocation!.latitude})',
        'status': 'active',
        'type': _selectedEmergencyType,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('$_selectedEmergencyType Alert Sent! Sharing Location...');
    } catch (e) {
      _showError('Failed to send emergency alert');
      _stopLocationSharing();
    }
  }

  // --- MEDIA & SUBMIT LOGIC ---

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() => _images.add(image));
        _showSuccess('Photo added');
      }
    } catch (e) {
      _showError('Error taking photo');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() => _images.addAll(images));
        _showSuccess('${images.length} photos added');
      }
    } catch (e) {
      _showError('Error selecting images');
    }
  }

  void _removeImage(int index) {
    if (!mounted) return;
    setState(() => _images.removeAt(index));
  }

  void _updateRecordingTime() {
    if (_recordingStartTime != null && mounted) {
      final elapsed = DateTime.now().difference(_recordingStartTime!);
      final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _recordingTime = '$minutes:$seconds');
      Future.delayed(const Duration(seconds: 1), _updateRecordingTime);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final dir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      final filePath = path.join(dir.path, fileName);
      try {
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
      } catch (e) {
        _showError('Error saving recording');
      }
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

  // NEW: Show loading dialog for image processing
  void _showImageProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  strokeWidth: 5,
                ),
                const SizedBox(height: 20),
                const Text(
                  "🔍 ANALYZING IMAGE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedCrimeCategory ?? 'Killing/Homicide',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 15),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Running AI verification to ensure image authenticity...\nThis may take a few seconds.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${_images.length} image${_images.length > 1 ? 's' : ''} being analyzed",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Process images with verification for killing/homicide
  Future<bool> _processImagesForVerification() async {
    if (!_requiresImageVerification(_selectedCrimeCategory)) {
      return true; // Skip verification for non-killing categories
    }

    if (_images.isEmpty) {
      _showError('Image required for killing/homicide reports');
      return false;
    }

    _imageVerificationResults.clear();
    bool allImagesPassed = true;

    // Show processing dialog
    _showImageProcessingDialog();

    try {
      for (final image in _images) {
        developer.log("🔍 Processing image: ${image.name}");

        // Run image verification
        final result = await _reportService.verifyImageBeforeUpload(
          imageFile: image,
          userLocation: _currentLocation!,
          reportDescription: _reportController.text,
        );

        _imageVerificationResults.add(result);

        if (result['status'] == 'rejected') {
          developer.log("❌ Image rejected: ${result['reasons']}");
          allImagesPassed = false;

          // Close dialog and show error
          Navigator.pop(context);
          _showError('Image verification failed: ${result['reasons'].join(', ')}');
          break;
        } else if (result['status'] == 'needs_review') {
          developer.log("⚠️ Image needs review: ${result['reasons']}");
          // Continue but flag for review
        } else {
          developer.log("✅ Image approved");
        }
      }

      // Close dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      return allImagesPassed;

    } catch (e) {
      developer.log("❌ Image processing error: $e");

      // Close dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showError('Image processing failed. Please try again.');
      return false;
    }
  }

  // UPDATED: SUBMIT REPORT WITH ENHANCED VERIFICATION
  Future<void> _submitReport() async {
    if (_supabase.auth.currentUser == null) {
      _showError("Log in to submit report");
      return;
    }
    if (_selectedEnvironment == null) {
      _showError("Select Environment");
      return;
    }
    if (_selectedCrimeCategory == null) {
      _showError("Select Crime Category");
      return;
    }
    if (_reportController.text.isEmpty) {
      _showError("Describe incident");
      return;
    }
    if (_currentLocation == null) {
      _showError("Location is required");
      return;
    }

    // NEW: Check if killing/homicide requires image
    if (_requiresImageVerification(_selectedCrimeCategory) && _images.isEmpty) {
      _showError('Image evidence is required for killing/homicide reports');
      return;
    }

    // NEW: Process images first if required
    if (_requiresImageVerification(_selectedCrimeCategory)) {
      setState(() => _isProcessingImage = true);

      final imagesPassed = await _processImagesForVerification();

      setState(() => _isProcessingImage = false);

      if (!imagesPassed) {
        _showError('Report blocked: Fake or inappropriate image detected');
        return; // Stop here, don't upload to Supabase
      }
    }

    setState(() => _isUploading = true);

    try {
      // 1. Run text classification
      _prediction = await _textClassifier.classify(_reportController.text);
      _predictionConfidence = _prediction?['confidence'];
      final isDangerous = _prediction?['label'] == 'dangerous';

      // 2. Upload audio file if exists
      String? audioUrl;
      if (_audioFile != null) {
        final folder = 'audio';
        final fileExt = path.extension(_audioFile!.name);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
        final filePath = '$folder/$fileName';

        if (kIsWeb) {
          final bytes = await _audioFile!.readAsBytes();
          await _supabase.storage.from('reports').uploadBinary(filePath, bytes,
              fileOptions: const FileOptions(upsert: true));
        } else {
          await _supabase.storage.from('reports').upload(filePath, File(_audioFile!.path),
              fileOptions: const FileOptions(upsert: true));
        }
        audioUrl = _supabase.storage.from('reports').getPublicUrl(filePath);
      }

      // 3. Submit report WITH or WITHOUT image verification
      final areaText = _selectedEnvironment == 'Offline'
          ? '${_selectedCity ?? ''}, ${_selectedArea ?? ''}'
          : 'Online';

      final result = await _reportService.submitReportWithVerification(
        description: _reportController.text,
        location: _currentLocation!,
        area: areaText,
        crimeCategory: _selectedCrimeCategory!,
        images: _images,
        userId: _supabase.auth.currentUser!.id,
        audioUrl: audioUrl,
        isEmergency: _isLocationSharing && !isDangerous,
        runImageVerification: _requiresImageVerification(_selectedCrimeCategory),
      );

      if (result['success'] == false) {
        // Check if image verification failed
        if (result['blocked_reason'] != null) {
          _showError('Report blocked: ${result['blocked_reason']}');
          return;
        }
        throw Exception(result['error']);
      }

      // 4. Update report with AI prediction data
      final reportId = result['report_id'];
      await _supabase.from('reports').update({
        'predicted_label': _prediction?['label'],
        'predicted_confidence': _predictionConfidence,
        'risk_score': _calculateRiskScore(isDangerous),
        'device_id': _deviceId,
        'environment': _selectedEnvironment,
        'city': _selectedCity,
        'area': _selectedArea,
      }).eq('id', reportId);

      _showSuccess("Report Submitted Successfully!");
      _resetForm();

    } catch(e) {
      developer.log("Submit report error: $e");
      _showError("Failed to submit report: ${e.toString()}");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  double _calculateRiskScore(bool isDangerous) {
    double score = 0;
    switch (_prediction?['label']) {
      case 'dangerous': score = 80 + ((_predictionConfidence ?? 0) * 30); break;
      default: score = 15;
    }
    if (_isLocationSharing) score += 15;
    if (_selectedEnvironment == 'Offline') score += 5;
    return score.clamp(0, 100).toDouble();
  }

  void _resetForm() {
    _reportController.clear();
    setState(() {
      _images.clear();
      _audioFile = null;
      _selectedEnvironment = null;
      _selectedCrimeCategory = null;
      _selectedCity = null;
      _selectedArea = null;
      _imageVerificationResults.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    ));
  }

  // --- UI WIDGETS ---

  Widget _buildStepIndicator() {
    int currentStep = 0;
    if (_selectedEnvironment != null) currentStep = 1;
    if (_selectedCrimeCategory != null) currentStep = 2;
    if (_selectedEnvironment == 'Offline') {
      if (_selectedCity != null && _selectedArea != null) currentStep = 3;
    } else if (_selectedEnvironment == 'Online' && _selectedCrimeCategory != null) {
      currentStep = 3;
    }
    int totalSteps = 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          bool isActive = index < currentStep;
          bool isCurrent = index == currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isCurrent ? 30 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive || isCurrent ? Colors.blueAccent : Colors.grey[700],
              borderRadius: BorderRadius.circular(5),
              boxShadow: (isActive || isCurrent)
                  ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 8)]
                  : [],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmergencyKeywordsSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _emergencyTypes.map((type) {
          bool isSelected = _selectedEmergencyType == type['label'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedEmergencyType = type['label']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (type['color'] as Color).withOpacity(0.8) : Colors.black45,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: isSelected ? Colors.white : (type['color'] as Color).withOpacity(0.5),
                      width: 1.5
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: (type['color'] as Color).withOpacity(0.6), blurRadius: 8)] : [],
                ),
                child: Row(
                  children: [
                    Icon(type['icon'], color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(type['label'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isHolding ? [Colors.redAccent, Colors.red] : [Colors.blueAccent, Colors.blue],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: _isHolding ? Colors.red.withOpacity(0.5) : Colors.blue.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
            ),
          ),
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
          ),
          Icon(_isLocationSharing ? Icons.stop : Icons.touch_app, size: 50, color: Colors.white),
          if (_isHolding)
            CircularProgressIndicator(value: _holdProgress, strokeWidth: 8, backgroundColor: Colors.white.withOpacity(0.3), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
          if (_isLocationSharing)
            Positioned(
              bottom: 10,
              child: GestureDetector(
                onTap: _stopLocationSharing,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Stop Sharing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(String title, IconData icon, String subtitle, String value, Color accentColor) {
    bool isSelected = _selectedEnvironment == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedEnvironment = value;
            _selectedCrimeCategory = null; // Reset category when environment changes
            _selectedCity = null;
            _selectedArea = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.15) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? accentColor : Colors.white12, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 1)] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: isSelected ? accentColor : Colors.white54),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: isSelected ? accentColor : Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Crime category dropdown with image requirement indicator
  Widget _buildCrimeCategoryDropdown() {
    final currentCategories = _selectedEnvironment == 'Online'
        ? _onlineCrimeCategories
        : _offlineCrimeCategories;

    if (_loadingCategories) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24)
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
            const SizedBox(width: 12),
            Text(
              'Loading crime categories...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (currentCategories.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24)
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No crime categories available. Please check your connection.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white24)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCrimeCategory,
              hint: Row(
                  children: [
                    Icon(Icons.category, color: Colors.white54, size: 20),
                    SizedBox(width: 12),
                    Text('Select Crime Category', style: TextStyle(color: Colors.white54)),
                  ]
              ),
              isExpanded: true,
              dropdownColor: Color(0xFF1E2A38),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              style: TextStyle(color: Colors.white),
              items: currentCategories.map((category) {
                final requiresImage = _requiresImageVerification(category['name']);
                return DropdownMenuItem<String>(
                  value: category['name'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(category['name']),
                      ),
                      if (requiresImage)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.yellow,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() => _selectedCrimeCategory = value);
              },
            ),
          ),
        ),

        // NEW: Show warning for killing/homicide
        if (_requiresImageVerification(_selectedCrimeCategory))
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ IMAGE REQUIRED',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'For killing/homicide reports, you must upload clear photo evidence. AI will verify authenticity.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStyledDropdown({required String label, required String? value, required List<String> items, required Function(String?) onChanged, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [Icon(icon, color: Colors.white54, size: 20), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white54))]),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2A38),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white),
          items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
      child: TextFormField(
        controller: _reportController,
        maxLines: 6,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Describe incident details...',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
          prefixIcon: Padding(padding: EdgeInsets.only(bottom: 100), child: Icon(Icons.description, color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5))),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NEW: Show warning for killing/homicide
        if (_requiresImageVerification(_selectedCrimeCategory) && _images.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Photo evidence is REQUIRED for killing/homicide reports',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Image preview grid
        if (_images.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: kIsWeb ? NetworkImage(_images[index].path) : FileImage(File(_images[index].path)) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Verification status badge
                    if (_imageVerificationResults.length > index)
                      Positioned(
                        top: 5,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _imageVerificationResults[index]['status'] == 'approved'
                                ? Colors.green.withOpacity(0.8)
                                : _imageVerificationResults[index]['status'] == 'needs_review'
                                ? Colors.orange.withOpacity(0.8)
                                : Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _imageVerificationResults[index]['status'] == 'approved' ? '✓' : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Remove button
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPredictionBadge() {
    if (_prediction == null) return const SizedBox();
    final label = _prediction!['label'];
    Color c = label == 'dangerous' ? Colors.red : (label == 'suspicious' ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: c)),
      child: Text('${label.toUpperCase()} (${(_prediction!['confidence'] * 100).toStringAsFixed(0)}%)', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildReportTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight, radius: 1.5,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], stops: [0.0, 0.5, 1.0],
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
                  _buildEmergencyKeywordsSelector(),
                  const SizedBox(height: 20),
                  Text(
                    _isLocationSharing ? 'SOS ACTIVE: $_selectedEmergencyType' : 'HOLD FOR SOS',
                    style: TextStyle(color: _isLocationSharing ? Colors.red : Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: _locationLoading
                        ? const Text('Locating...', style: TextStyle(color: Colors.blueAccent))
                        : Text(
                      _isLocationSharing ? 'Broadcasting: ${_currentLocation?.latitude.toStringAsFixed(4)}...' : 'Secure Location Ready',
                      style: TextStyle(color: _isLocationSharing ? Colors.green : Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Card(
              elevation: 10,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: const Color(0xFF1E2A38).withOpacity(0.8),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FILE A REPORT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    const SizedBox(height: 20),
                    _buildStepIndicator(),
                    Row(
                      children: [
                        _buildEnvironmentCard('Online', Icons.wifi, 'Cyber Crime', 'Online', Colors.cyanAccent),
                        const SizedBox(width: 12),
                        _buildEnvironmentCard('Offline', Icons.place, 'Physical Incident', 'Offline', Colors.greenAccent),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(height: 0, width: double.infinity),
                      secondChild: _buildCrimeCategoryDropdown(),
                      crossFadeState: _selectedEnvironment != null ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                    if (_selectedEnvironment == 'Offline' && _selectedCrimeCategory != null) ...[
                      _buildStyledDropdown(
                        label: 'Select City',
                        value: _selectedCity,
                        items: LocationData.bangladeshLocationData.keys.toList(),
                        icon: Icons.location_city,
                        onChanged: (val) => setState(() {
                          _selectedCity = val;
                          _selectedArea = null;
                        }),
                      ),
                      if (_selectedCity != null)
                        _buildStyledDropdown(
                          label: 'Select Area',
                          value: _selectedArea,
                          items: LocationData.bangladeshLocationData[_selectedCity] ?? [],
                          icon: Icons.map,
                          onChanged: (val) => setState(() => _selectedArea = val),
                        ),
                    ],
                    if (_selectedCrimeCategory != null && (_selectedEnvironment == 'Online' || _selectedArea != null)) ...[
                      const SizedBox(height: 10),
                      _buildTextInput(),
                      if (_prediction != null) Padding(padding: const EdgeInsets.only(top: 10), child: _buildPredictionBadge()),

                      const SizedBox(height: 20),
                      const Text("Evidence", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _buildMediaButton(Icons.camera_alt, "Photo", Colors.purpleAccent, _pickImageFromCamera),
                        _buildMediaButton(Icons.image, "Gallery", Colors.blueAccent, _pickImageFromGallery),
                        _buildMediaButton(_isRecording ? Icons.stop : Icons.mic, _isRecording ? "Stop" : "Audio", Colors.redAccent, _toggleRecording),
                      ]),
                      const SizedBox(height: 15),
                      _buildImagePreview(),
                      if (_audioFile != null)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check, color: Colors.green), SizedBox(width: 5), Text("Audio Attached", style: TextStyle(color: Colors.green))]),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                bool isReady = (_selectedCrimeCategory != null && _reportController.text.isNotEmpty &&
                    (_selectedEnvironment == 'Online' || _selectedArea != null));

                // NEW: Additional check for killing/homicide - must have images
                if (_requiresImageVerification(_selectedCrimeCategory)) {
                  isReady = isReady && _images.isNotEmpty;
                }

                return Transform.scale(
                  scale: isReady ? _scaleAnimation.value : 1.0,
                  child: ElevatedButton(
                    onPressed: (isReady && !_isUploading && !_isProcessingImage) ? _submitReport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: isReady ? 10 : 0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: isReady
                            ? const LinearGradient(colors: [Color(0xFF00b09b), Color(0xFF96c93d)])
                            : LinearGradient(colors: [Colors.grey[800]!, Colors.grey[700]!]),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: _isUploading || _isProcessingImage
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              _isProcessingImage ? 'VERIFYING IMAGE...' : 'UPLOADING...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                            : Text(
                          isReady
                              ? (_requiresImageVerification(_selectedCrimeCategory)
                              ? 'SUBMIT WITH AI VERIFICATION'
                              : 'SUBMIT REPORT')
                              : 'COMPLETE FORM',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: isReady ? Colors.white : Colors.white38
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // NEW: Test Image Verification Button (only in debug mode)
            if (!kReleaseMode) ...[
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _images.isNotEmpty ? () async {
                  if (_requiresImageVerification(_selectedCrimeCategory)) {
                    setState(() => _isProcessingImage = true);
                    final passed = await _processImagesForVerification();
                    setState(() => _isProcessingImage = false);

                    if (passed) {
                      _showSuccess('Image verification passed!');
                    } else {
                      _showError('Image verification failed');
                    }
                  } else {
                    _showInfo('Image verification not required for this category');
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, size: 20),
                    SizedBox(width: 8),
                    Text('TEST IMAGE VERIFICATION', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],

            if (!kReleaseMode) Padding(padding: const EdgeInsets.only(top: 20), child: Text("Debug Mode: ${widget.key}", textAlign: TextAlign.center, style: TextStyle(color: Colors.white10))),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'REPORT PORTAL';
      case 1: return 'EMERGENCY SUPPORT';
      case 2: return 'TIMELINE';
      case 3: return 'PROFILE';
      default: return 'REPORT PORTAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => Text(_getAppBarTitle(_tabController.index), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildReportTab(),
          EmergencySupportScreen(currentUserId: _supabase.auth.currentUser?.id ?? ''),
          const TimelineScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (index != 0 && index != 1) { _positionStream?.pause(); } else if (_isLocationSharing) { _positionStream?.resume(); }
          },
          tabs: const [Tab(icon: Icon(Icons.report), text: 'Report'), Tab(icon: Icon(Icons.emergency), text: 'Emergency'), Tab(icon: Icon(Icons.timeline), text: 'Timeline'), Tab(icon: Icon(Icons.person), text: 'Profile')],
          labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.green, indicatorWeight: 3.0,
        ),
      ),
    );
  }
}

// LOCATION DATA
class LocationData {
  static const List<String> onlineCrimeTypes = [
    'Financial Fraud (MFS)', 'E-Commerce Scam', 'Cyberbullying / Harassment',
    'Blackmail / Sextortion', 'Identity Theft / Impersonation', 'Hacking',
    'Phishing Links', 'Rumor / Hate Speech'
  ];

  static const List<String> offlineCrimeTypes = [
    'killing / murders','Theft / Mugging', 'Bribery / Corruption', 'Physical Assault / Fighting',
    'Sexual Harassment / Stalking', 'Drug Dealing / Usage', 'Robbery / Dacoity',
    'Vandalism / Property Damage', 'Domestic Violence', 'Kidnapping / Missing Person'
  ];

  static const Map<String, List<String>> bangladeshLocationData = {
    'Dhaka': ['Mirpur', 'Uttara', 'Dhanmondi', 'Gulshan', 'Banani', 'Motijheel', 'Shahbagh', 'Farmgate', 'Mohakhali', 'Tejgaon', 'Khilgaon', 'Shyamoli', 'Mohammadpur', 'Lalbagh', 'Old Dhaka', 'Jatrabari', 'Demra', 'Sabujbagh'],
    'Chittagong': ['Agrabad', 'GEC', 'Kotwali', 'Chandgaon', 'Halishahar', 'Panchlaish', 'Khulshi', 'Pahartali', 'Bakalia', 'Double Mooring', 'Bayezid', 'Patenga'],
    'Sylhet': ['Sylhet City', 'Zindabazar', 'Mirabazar', 'Kumarpara', 'Bandarbazar', 'Subhanighat', 'Mogalbazar', 'Pathantula', 'Tilagor', 'Mazar Road'],
    'Rajshahi': ['Rajshahi City', 'Shaheb Bazar', 'Kazla', 'Binodpur', 'New Market', 'Motinagar', 'Horagram', 'Boroigram', 'Shapura', 'Budhpara'],
    'Khulna': ['Khulna City', 'Sonadanga', 'Daulatpur', 'Khalishpur', 'Boyra', 'Labanchara', 'Rupsha', 'Siramani', 'Moylapota', 'Tootpara'],
    'Barisal': ['Barisal City', 'Nattullabad', 'Alekkanda', 'Kawnia', 'Chandmari', 'Rupatali', 'Sadar Road', 'Natun Bazar', 'Guthia', 'Kashipur'],
    'Rangpur': ['Rangpur City', 'Lalbag', 'Haridebpur', 'Mithapukur', 'Pirgachha', 'Badarganj', 'Kawran Bazar', 'Station Road', 'College Para', 'Shapla Chatwar'],
    'Gazipur': ['Gazipur City', 'Konabari', 'Kaliakoir', 'Kapasia', 'Sreepur', 'Boro Bari', 'Chandana', 'Bhawal', 'Joydebpur', 'Rajendrapur'],
    'Narayanganj': ['Narayanganj City', 'Fatullah', 'Bandar', 'Rupganj', 'Araihazar', 'Sonargaon', 'Madanganj', 'Chashara', 'Signboard', 'Kachpur'],
    'Comilla': ['Comilla City', 'Kandirpar', 'Shashongachha', 'Dhormoshoshor', 'Cantonment', 'Boro Para', 'Chawk Bazar', 'Tomsom Bridge', 'Bibir Bazar', 'Sholoshahar'],
  };
}