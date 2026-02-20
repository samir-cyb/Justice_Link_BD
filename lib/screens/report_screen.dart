import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
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
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

// Import your existing screens
import 'package:justice_link_user/screens/timeline_screen.dart';
import 'package:justice_link_user/screens/profile_screen.dart';
import 'package:justice_link_user/screens/emergency_support_screen.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:justice_link_user/screens/text_classifier.dart';
import 'package:justice_link_user/screens/dashboard_screen.dart';
import 'package:justice_link_user/services/report_service.dart';
import 'package:justice_link_user/services/vibration_service.dart';
import 'package:justice_link_user/services/background_service.dart';
import 'package:justice_link_user/services/emergency_store.dart';
import 'package:justice_link_user/services/foreground_location_service.dart';
import 'package:justice_link_user/services/video_service.dart';
import 'package:justice_link_user/services/aggressive_background_service.dart';
import 'package:justice_link_user/services/nirbacon_service.dart';
import 'package:justice_link_user/providers/emergency_provider.dart';

// ==================== LOCATION DATA ====================

class LocationData {
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

  static const Map<String, String> cityToDivision = {
    'Dhaka': 'Dhaka',
    'Chittagong': 'Chittagong',
    'Sylhet': 'Sylhet',
    'Rajshahi': 'Rajshahi',
    'Khulna': 'Khulna',
    'Barisal': 'Barisal',
    'Rangpur': 'Rangpur',
    'Gazipur': 'Dhaka',
    'Narayanganj': 'Dhaka',
    'Comilla': 'Chittagong',
  };

  // City coordinates for database location field
  static const Map<String, Map<String, double>> cityCoordinates = {
    'Dhaka': {'lat': 23.8103, 'lng': 90.4125},
    'Chittagong': {'lat': 22.3569, 'lng': 91.7832},
    'Sylhet': {'lat': 24.8949, 'lng': 91.8687},
    'Rajshahi': {'lat': 24.3745, 'lng': 88.6042},
    'Khulna': {'lat': 22.8456, 'lng': 89.5403},
    'Barisal': {'lat': 22.7010, 'lng': 90.3535},
    'Rangpur': {'lat': 25.7466, 'lng': 89.2517},
    'Gazipur': {'lat': 23.9999, 'lng': 90.4203},
    'Narayanganj': {'lat': 23.6238, 'lng': 90.5000},
    'Comilla': {'lat': 23.4607, 'lng': 91.1809},
  };
}

// ==================== MODELS ====================

class AsonArea {
  final int id;
  final String areaName;
  final String areaNameEn;
  final String division;
  final String divisionEn;
  final double? lat;
  final double? lng;

  AsonArea({
    required this.id,
    required this.areaName,
    required this.areaNameEn,
    required this.division,
    required this.divisionEn,
    this.lat,
    this.lng,
  });

  factory AsonArea.fromJson(Map<String, dynamic> json) {
    return AsonArea(
      id: json['id'],
      areaName: json['area_name'],
      areaNameEn: json['area_name_en'],
      division: json['division'],
      divisionEn: json['division_en'],
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'AsonArea(id: $id, areaNameEn: $areaNameEn, divisionEn: $divisionEn)';
  }
}

// ==================== EMERGENCY ALARM SERVICE ====================

class EmergencyAlarmService {
  static const MethodChannel _platform = MethodChannel('justice_link/notification');

  static Future<bool> canScheduleExactAlarms() async {
    try {
      return await _platform.invokeMethod('canScheduleExactAlarms') ?? false;
    } catch (e) {
      developer.log('Error checking exact alarm permission: $e');
      return false;
    }
  }

  static Future<void> requestExactAlarmPermission() async {
    try {
      await _platform.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      developer.log('Error requesting exact alarm permission: $e');
    }
  }

  static Future<void> scheduleEmergencyAlarm({int delaySeconds = 15}) async {
    try {
      await _platform.invokeMethod('scheduleEmergencyAlarm', {
        'delaySeconds': delaySeconds,
      });
      developer.log('✅ Emergency alarm scheduled');
    } catch (e) {
      developer.log('❌ Error scheduling emergency alarm: $e');
    }
  }

  static Future<void> cancelEmergencyAlarm() async {
    try {
      await _platform.invokeMethod('cancelEmergencyAlarm');
      developer.log('✅ Emergency alarm cancelled');
    } catch (e) {
      developer.log('❌ Error cancelling emergency alarm: $e');
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      developer.log('Error opening battery settings: $e');
    }
  }

  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      return await _platform.invokeMethod('isBatteryOptimizationDisabled') ?? false;
    } catch (e) {
      developer.log('Error checking battery optimization: $e');
      return false;
    }
  }
}

// ==================== MAIN REPORT SCREEN ====================

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ==================== EMERGENCY SECTION (100% PRESERVED) ====================
  StreamSubscription? _emergencyStatusSubscription;
  String? _currentEmergencyId;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _globalAudioPlayer = AudioPlayer();
  StreamSubscription? _globalEmergencySubscription;
  late TabController _tabController;

  final AggressiveBackgroundService _aggressiveService = AggressiveBackgroundService();
  final NirbaconService _nirbaconService = NirbaconService();

  final MethodChannel _platformChannel = const MethodChannel('justice_link/notification');

  bool _isDialogVisible = false;
  final Set<String> _handledEmergencyIds = {};
  bool _listenerStarted = false;

  String _selectedEmergencyType = 'General';
  final List<Map<String, dynamic>> _emergencyTypes = [
    {'label': 'General', 'icon': Icons.warning_amber_rounded, 'color': Colors.grey},
    {'label': 'Police', 'icon': Icons.local_police, 'color': Colors.blue},
    {'label': 'Medical', 'icon': Icons.medical_services, 'color': Colors.red},
    {'label': 'Fire', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'label': 'Harassment', 'icon': Icons.do_not_touch, 'color': Colors.purple},
  ];

  // ==================== REPORT SECTION ====================

  int _currentStep = 0;
  final int _totalSteps = 4;

  String? _selectedEnvironment;
  String? _selectedCrimeCategory;
  String? _selectedCity;
  String? _selectedAson;
  String? _selectedArea;

  final TextEditingController _reportController = TextEditingController();

  List<XFile> _images = [];
  List<XFile> _videos = [];
  List<XFile> _audioFiles = [];
  bool _isRecording = false;
  String? _recordingTime = '00:00';
  DateTime? _recordingStartTime;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ImagePicker _picker = ImagePicker();

  late TextClassifier _textClassifier;
  bool _classifierInitialized = false;
  Map<String, dynamic>? _prediction;
  double? _predictionConfidence;
  bool _isProcessingImage = false;
  final List<Map<String, dynamic>> _imageVerificationResults = [];

  // Ason data from database
  List<AsonArea> _asonAreas = [];
  List<AsonArea> _filteredAsonAreas = [];
  bool _asonLoading = false;
  String? _asonError;

  final SupabaseClient _supabase = Supabase.instance.client;
  final EmergencyService _emergencyService = EmergencyService();
  final ReportService _reportService = ReportService();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _deviceId = 'unknown_device';

  late AnimationController _animationController;
  late AnimationController _stepAnimationController;
  late Animation<double> _scaleAnimation;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  bool _isLocationSharing = false;

  // ==================== CRIME CATEGORIES ====================

  final List<Map<String, dynamic>> _onlineCrimeCategories = [
    {'name': 'Financial Fraud (MFS)', 'icon': Icons.account_balance_wallet, 'color': Colors.red},
    {'name': 'E-Commerce Scam', 'icon': Icons.shopping_cart, 'color': Colors.orange},
    {'name': 'Cyberbullying / Harassment', 'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.purple},
    {'name': 'Blackmail / Sextortion', 'icon': Icons.monetization_on, 'color': Colors.deepOrange},
    {'name': 'Identity Theft / Impersonation', 'icon': Icons.person_outline, 'color': Colors.blue},
    {'name': 'Hacking', 'icon': Icons.computer, 'color': Colors.green},
    {'name': 'Phishing Links', 'icon': Icons.link, 'color': Colors.teal},
    {'name': 'Rumor / Hate Speech', 'icon': Icons.record_voice_over, 'color': Colors.indigo},
  ];

  final List<Map<String, dynamic>> _offlineCrimeCategories = [
    {'name': 'Killing / Murders', 'icon': Icons.warning, 'color': Colors.red, 'requiresImage': true},
    {'name': 'Theft / Mugging', 'icon': Icons.money_off, 'color': Colors.orange},
    {'name': 'Bribery / Corruption', 'icon': Icons.attach_money, 'color': Colors.amber},
    {'name': 'Physical Assault / Fighting', 'icon': Icons.sports_kabaddi, 'color': Colors.deepPurple},
    {'name': 'Sexual Harassment / Stalking', 'icon': Icons.accessibility_new, 'color': Colors.pink},
    {'name': 'Drug Dealing / Usage', 'icon': Icons.medication, 'color': Colors.green},
    {'name': 'Robbery / Dacoity', 'icon': Icons.local_atm, 'color': Colors.redAccent},
    {'name': 'Vandalism / Property Damage', 'icon': Icons.construction, 'color': Colors.brown},
    {'name': 'Domestic Violence', 'icon': Icons.home, 'color': Colors.deepOrange},
    {'name': 'Kidnapping / Missing Person', 'icon': Icons.person_search, 'color': Colors.blueGrey},
  ];

  // ==================== INIT & DISPOSE ====================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 5, vsync: this);
    _initAnimations();
    _initializeClassifier();
    _getDeviceId();
    _loadAsonAreas();
    _initBackgroundService();
    _initLocalNotifications();

    // FIXED: Request GPS permission FIRST (before notifications), then start emergency services
    _requestLocationPermissionAndStartTracking().then((_) {
      // After location permission, request other permissions
      _requestNotificationPermission();
      if (Platform.isAndroid) {
        EmergencyAlarmService.canScheduleExactAlarms().then((canSchedule) {
          if (!canSchedule) {
            EmergencyAlarmService.requestExactAlarmPermission();
          }
        });
      }
    });

    _checkBatteryOptimizationStatus();
    _initializeAggressiveService();

    BackgroundService().startEmergencyMonitoring();

    developer.log('🚀 ReportScreen initialized with GPS-first permission flow');
  }

  Future<void> _loadAsonAreas() async {
    developer.log('📥 Loading Ason areas from database...');
    setState(() => _asonLoading = true);

    try {
      final response = await _supabase.from('ason').select();
      developer.log('📊 Raw Ason response: ${response.length} records');

      if (response.isEmpty) {
        developer.log('⚠️ WARNING: No Ason areas found in database!');
        setState(() {
          _asonError = 'No Ason areas found';
          _asonLoading = false;
        });
        return;
      }

      setState(() {
        _asonAreas = response.map((json) => AsonArea.fromJson(json)).toList();
        _filteredAsonAreas = List.from(_asonAreas);
        _asonLoading = false;
      });

      developer.log('✅ Loaded ${_asonAreas.length} Ason areas');

    } catch (e, stackTrace) {
      developer.log('❌ Error loading Ason areas: $e');
      developer.log('📚 Stack trace: $stackTrace');
      setState(() {
        _asonError = 'Failed to load Ason areas: $e';
        _asonLoading = false;
      });
    }
  }

  void _filterAsonByCity(String city) {
    final division = LocationData.cityToDivision[city];
    developer.log('🔍 Filtering Ason for city: $city, division: $division');

    if (division == null) {
      developer.log('⚠️ No division mapping found for city: $city');
      setState(() => _filteredAsonAreas = List.from(_asonAreas));
      return;
    }

    setState(() {
      _filteredAsonAreas = _asonAreas.where((ason) {
        final match = ason.divisionEn.toLowerCase() == division.toLowerCase();
        return match;
      }).toList();

      _selectedAson = null;
    });

    developer.log('📊 Filtered to ${_filteredAsonAreas.length} Ason areas for $city');
  }

  // ==================== GPS PERMISSION (FIXED - EMERGENCY FIRST) ====================

  Future<void> _requestLocationPermissionAndStartTracking() async {
    developer.log('📍 === REQUESTING GPS PERMISSION FOR EMERGENCY ===');

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      developer.log('❌ Location services disabled');
      // Show dialog to enable location
      _showLocationEnableDialog();
      return;
    }

    // Request permission
    LocationPermission permission = await Geolocator.checkPermission();
    developer.log('🔐 Current permission status: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      developer.log('📝 Permission after request: $permission');

      if (permission == LocationPermission.denied) {
        developer.log('❌ Location permission denied');
        _showLocationPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      developer.log('❌ Location permission denied forever');
      _showLocationSettingsDialog();
      return;
    }

    // Permission granted - start tracking for emergency
    developer.log('✅ Location permission granted, starting emergency tracking');
    _startEmergencyLocationTracking();
  }

  void _startEmergencyLocationTracking() async {
    try {
      // Get initial location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      final location = latlong.LatLng(position.latitude, position.longitude);
      await EmergencyStore.saveLastLocation(location);

      developer.log('✅ Emergency location saved: ${location.latitude}, ${location.longitude}');

      // Start continuous tracking for emergency
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );

      Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) async {
          final newLocation = latlong.LatLng(position.latitude, position.longitude);
          await EmergencyStore.saveLastLocation(newLocation);

          if (_isLocationSharing) {
            _emergencyService.updateEmergencyLocation(
              newLocation,
              _supabase.auth.currentUser?.id ?? '',
            );
          }
        },
        onError: (e) {
          developer.log('❌ Location stream error: $e');
        },
      );

      // Start emergency listener if we have location
      if (!_listenerStarted) {
        _startNearbyEmergencyListener();
      }

    } catch (e) {
      developer.log('❌ Error starting emergency location tracking: $e');
    }
  }

  void _showLocationEnableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Location Required',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Emergency SOS requires location services to be enabled.\n\n'
              'Please enable GPS to use the emergency features.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Permission Required',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Location permission is required for Emergency SOS features.\n\n'
              'Without this, you cannot send emergency alerts with your location.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.requestPermission();
            },
            child: const Text('Request Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) return;
    try {
      developer.log('📍 Requesting notification permission...');
      await _platformChannel.invokeMethod('requestNotificationPermission');
      developer.log("✅ Notification permission requested");
    } catch (e) {
      developer.log("Notification permission error: $e");
    }
  }

  // ==================== AI & CLASSIFICATION ====================

  Future<void> _initializeClassifier() async {
    try {
      _textClassifier = TextClassifier();
      await _textClassifier.initialize();
      setState(() => _classifierInitialized = true);
      developer.log('✅ Text classifier initialized');
    } catch (e) {
      developer.log('⚠️ Text classifier init error: $e');
      setState(() => _classifierInitialized = true);
    }
  }

  Future<void> _analyzeText() async {
    if (_reportController.text.isEmpty || !_classifierInitialized) return;

    try {
      _prediction = await _textClassifier.classify(_reportController.text);
      _predictionConfidence = _prediction?['confidence'];
      setState(() {});
      developer.log('🤖 Text prediction: $_prediction');
    } catch (e) {
      developer.log('Text classification error: $e');
    }
  }

  bool _requiresImageVerification(String? category) {
    if (category == null) return false;
    final killingKeywords = [
      'killing', 'murder', 'homicide', 'dead body', 'corpse',
      'killing / murders', 'killing/murders'
    ];
    return killingKeywords.any((keyword) =>
        category.toLowerCase().contains(keyword.toLowerCase()));
  }

  // ==================== IMAGE VERIFICATION ====================

  Future<bool> _processImagesForVerification() async {
    if (!_requiresImageVerification(_selectedCrimeCategory)) return true;
    if (_images.isEmpty) {
      _showError('Image required for killing/homicide reports');
      return false;
    }

    _imageVerificationResults.clear();
    bool allImagesPassed = true;

    _showImageProcessingDialog();

    try {
      // Use city coordinates for image verification
      final cityLocation = _getCityCoordinates(_selectedCity);
      developer.log("📍 Using city coordinates for image verification: $cityLocation");

      for (final image in _images) {
        developer.log("🔍 Processing image: ${image.name}");

        final result = await _reportService.verifyImageBeforeUpload(
          imageFile: image,
          userLocation: cityLocation,
          reportDescription: _reportController.text,
        );

        _imageVerificationResults.add(result);

        if (result['status'] == 'rejected') {
          developer.log("❌ Image rejected: ${result['reasons']}");
          allImagesPassed = false;
          Navigator.pop(context);
          _showError('Image verification failed: ${result['reasons'].join(', ')}');
          break;
        }
      }

      if (Navigator.canPop(context)) Navigator.pop(context);
      return allImagesPassed;

    } catch (e) {
      developer.log("❌ Image processing error: $e");
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError('Image processing failed. Please try again.');
      return false;
    }
  }

  // Helper method to get city coordinates
  latlong.LatLng _getCityCoordinates(String? city) {
    final coords = LocationData.cityCoordinates[city] ??
        LocationData.cityCoordinates['Dhaka']!;
    final location = latlong.LatLng(coords['lat']!, coords['lng']!);
    developer.log("🗺️ City coordinates for $city: $location");
    return location;
  }

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

  // ==================== MEDIA HANDLING ====================

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

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null && mounted) {
        setState(() => _videos.add(video));
        _showSuccess('Video added');
      }
    } catch (e) {
      _showError('Error recording video');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        setState(() => _videos.add(video));
        _showSuccess('Video added');
      }
    } catch (e) {
      _showError('Error selecting video');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null && mounted) {
          setState(() {
            _isRecording = false;
            _audioFiles.add(XFile(path));
            _recordingTime = '00:00';
            _recordingStartTime = null;
          });
          _showSuccess('Recording saved');
        }
      } catch (e) {
        _showError('Error saving recording');
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getTemporaryDirectory();
          final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final filePath = path.join(dir.path, fileName);

          await _audioRecorder.start(const RecordConfig(), path: filePath);

          if (mounted) {
            setState(() {
              _isRecording = true;
              _recordingStartTime = DateTime.now();
            });
            _updateRecordingTime();
            _showInfo('Recording started');
          }
        }
      } catch (e) {
        _showError('Error starting recording');
      }
    }
  }

  void _updateRecordingTime() {
    if (_recordingStartTime != null && mounted && _isRecording) {
      final elapsed = DateTime.now().difference(_recordingStartTime!);
      final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _recordingTime = '$minutes:$seconds');
      Future.delayed(const Duration(seconds: 1), _updateRecordingTime);
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));
  void _removeVideo(int index) => setState(() => _videos.removeAt(index));
  void _removeAudio(int index) => setState(() => _audioFiles.removeAt(index));

  // ==================== REPORT SUBMISSION (FIXED WITH LOCATION) ====================

  Future<void> _submitReport() async {
    developer.log('📤 Starting report submission...');

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
    if (_selectedCity == null) {
      _showError("Select City");
      return;
    }
    if (_selectedAson == null) {
      _showError("Select Ason (Area)");
      return;
    }

    if (_requiresImageVerification(_selectedCrimeCategory) && _images.isEmpty) {
      _showError('Image evidence is required for killing/homicide reports');
      return;
    }

    if (_requiresImageVerification(_selectedCrimeCategory)) {
      setState(() => _isProcessingImage = true);
      final imagesPassed = await _processImagesForVerification();
      setState(() => _isProcessingImage = false);
      if (!imagesPassed) {
        _showError('Report blocked: Fake or inappropriate image detected');
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      await _analyzeText();
      final isDangerous = _prediction?['label'] == 'dangerous';

      final List<String> imageUrls = [];
      final List<String> videoUrls = [];
      final List<String> audioUrls = [];
      final userId = _supabase.auth.currentUser!.id;

      // Upload media files
      developer.log('📁 Uploading media files...');
      for (final image in _images) {
        final url = await VideoService.uploadImage(File(image.path), userId);
        if (url != null) imageUrls.add(url);
      }

      for (final video in _videos) {
        final url = await VideoService.processAndUploadVideo(video.path, userId);
        if (url != null) videoUrls.add(url);
      }

      for (final audio in _audioFiles) {
        final file = File(audio.path);
        final fileExt = path.extension(audio.path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
        final storagePath = 'audio/$userId/$fileName';

        await _supabase.storage.from('crime-audio').upload(storagePath, file);
        final url = _supabase.storage.from('crime-audio').getPublicUrl(storagePath);
        audioUrls.add(url);
      }

      // FIXED: Get city coordinates for location field (required by database)
      final cityCoords = LocationData.cityCoordinates[_selectedCity] ??
          LocationData.cityCoordinates['Dhaka']!;
      final locationLng = cityCoords['lng']!;
      final locationLat = cityCoords['lat']!;

      final reportData = {
        'user_id': userId,
        'description': _reportController.text,
        'location': 'POINT($locationLng $locationLat)', // FIXED: Added required location
        'images': imageUrls,
        'videos': videoUrls,
        'audio_url': audioUrls.isNotEmpty ? audioUrls : null,
        'is_emergency': false,
        'predicted_label': _prediction?['label'],
        'predicted_confidence': _predictionConfidence,
        'risk_score': _calculateRiskScore(isDangerous),
        'device_id': _deviceId,
        'environment': _selectedEnvironment,
        'crime_type': _selectedCrimeCategory,
        'city': _selectedCity,
        'area': _selectedAson,
        'detailed_area': _selectedArea,
        'is_sensitive': _requiresImageVerification(_selectedCrimeCategory),
        'image_verified': _imageVerificationResults.isNotEmpty
            ? _imageVerificationResults.every((r) => r['status'] == 'approved')
            : null,
        'verification_status': _imageVerificationResults.isNotEmpty ? 'verified' : 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      developer.log('📝 Report data prepared: ${reportData.keys.toList()}');
      developer.log('   - City: $_selectedCity');
      developer.log('   - Ason (Area): $_selectedAson');
      developer.log('   - Detailed Area: $_selectedArea');
      developer.log('   - Location: POINT($locationLng $locationLat)');

      final response = await _supabase.from('reports').insert(reportData).select();

      if (response != null && response.isNotEmpty) {
        developer.log('✅ Report submitted successfully! ID: ${response[0]['id']}');
        _showSuccess("Report Submitted Successfully!");
        _resetForm();
      } else {
        throw Exception('Failed to insert report - no response');
      }

    } catch (e, stackTrace) {
      developer.log("❌ Submit report error: $e");
      developer.log("📚 Stack trace: $stackTrace");
      _showError("Failed to submit report: ${e.toString()}");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  double _calculateRiskScore(bool isDangerous) {
    double score = 0;
    switch (_prediction?['label']) {
      case 'dangerous': score = 80 + ((_predictionConfidence ?? 0) * 30); break;
      case 'suspicious': score = 50 + ((_predictionConfidence ?? 0) * 20); break;
      default: score = 15;
    }
    if (_isLocationSharing) score += 15;
    if (_selectedEnvironment == 'Offline') score += 5;
    return score.clamp(0, 100).toDouble();
  }

  void _resetForm() {
    _reportController.clear();
    setState(() {
      _currentStep = 0;
      _images.clear();
      _videos.clear();
      _audioFiles.clear();
      _selectedEnvironment = null;
      _selectedCrimeCategory = null;
      _selectedCity = null;
      _selectedAson = null;
      _selectedArea = null;
      _prediction = null;
      _imageVerificationResults.clear();
      _filteredAsonAreas = List.from(_asonAreas);
    });
    developer.log('🔄 Form reset completed');
  }

  // ==================== UI BUILDERS ====================

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          bool isActive = index <= _currentStep;
          bool isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blueAccent : Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.blueAccent : Colors.grey[800],
                    border: isCurrent
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isCurrent
                        ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 10)]
                        : null,
                  ),
                  child: Center(
                    child: isActive && index < _currentStep
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: index < _currentStep ? Colors.blueAccent : Colors.grey[800],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEnvironmentStep();
      case 1:
        return _buildCrimeTypeStep();
      case 2:
        return _buildLocationStep();
      case 3:
        return _buildDetailsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildEnvironmentStep() {
    return Column(
      children: [
        const Text(
          'SELECT ENVIRONMENT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Is this an online or offline incident?',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _buildEnvironmentCard(
                'Online',
                Icons.wifi_tethering,
                'Cyber Crime & Digital Issues',
                Colors.cyanAccent,
                Icons.computer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnvironmentCard(
                'Offline',
                Icons.location_on,
                'Physical Crime & Incidents',
                Colors.greenAccent,
                Icons.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnvironmentCard(
      String title,
      IconData icon,
      String subtitle,
      Color accentColor,
      IconData detailIcon,
      ) {
    bool isSelected = _selectedEnvironment == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEnvironment = title;
          _selectedCrimeCategory = null;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _currentStep = 1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 200,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [accentColor.withOpacity(0.3), accentColor.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.2),
                border: Border.all(color: accentColor.withOpacity(0.5)),
              ),
              child: Icon(icon, size: 40, color: accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrimeTypeStep() {
    final categories = _selectedEnvironment == 'Online'
        ? _onlineCrimeCategories
        : _offlineCrimeCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
            ),
            const Expanded(
              child: Text(
                'SELECT CRIME TYPE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'What type of incident occurred?',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 20),

        if (_selectedEnvironment == 'Offline')
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Killing/Murder reports require photo evidence with AI verification',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCrimeCategory == category['name'];
            final requiresImage = category['requiresImage'] == true;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedCrimeCategory = category['name']);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _currentStep = 2);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      (category['color'] as Color).withOpacity(0.4),
                      (category['color'] as Color).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isSelected ? null : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (category['color'] as Color)
                        : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            color: isSelected
                                ? (category['color'] as Color)
                                : Colors.white54,
                            size: 28,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              category['name'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (requiresImage)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==================== FIXED LOCATION STEP (OVERFLOW FIXED) ====================

  Widget _buildLocationStep() {
    developer.log('🏗️ Building location step - City: $_selectedCity, Ason: $_selectedAson, Area: $_selectedArea');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
            ),
            const Expanded(
              child: Text(
                'SELECT LOCATION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the incident location',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 20),

        // Debug info in development mode
        if (!kReleaseMode) ...[
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔧 DEBUG:', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Ason loaded: ${_asonAreas.length}', style: TextStyle(color: Colors.orange, fontSize: 10)),
                Text('Filtered: ${_filteredAsonAreas.length}', style: TextStyle(color: Colors.orange, fontSize: 10)),
                Text('Loading: $_asonLoading', style: TextStyle(color: Colors.orange, fontSize: 10)),
                if (_asonError != null) Text('Error: $_asonError', style: TextStyle(color: Colors.red, fontSize: 10)),
              ],
            ),
          ),
        ],

        // 1. CITY SELECTION
        _buildStyledDropdown(
          label: 'Select City',
          value: _selectedCity,
          items: LocationData.bangladeshLocationData.keys.toList(),
          icon: Icons.location_city,
          onChanged: (val) {
            developer.log('🏙️ City selected: $val');
            setState(() {
              _selectedCity = val;
              _selectedAson = null;
              _selectedArea = null;
            });
            if (val != null) {
              _filterAsonByCity(val);
            }
          },
        ),

        const SizedBox(height: 16),

        // 2. ASON SELECTION (Searchable) - FIXED OVERFLOW
        if (_asonLoading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
                SizedBox(width: 12),
                Text('Loading Ason areas...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          )
        else if (_asonError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: $_asonError\nPull down to retry',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.redAccent),
                  onPressed: _loadAsonAreas,
                ),
              ],
            ),
          )
        else if (_selectedCity == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select a city first',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (_filteredAsonAreas.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No Ason areas found for $_selectedCity',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildSearchableAsonDropdown(),

        const SizedBox(height: 16),

        // 3. AREA SELECTION (City Areas)
        if (_selectedCity != null)
          _buildStyledDropdown(
            label: 'Select Specific Area (Optional)',
            value: _selectedArea,
            items: LocationData.bangladeshLocationData[_selectedCity] ?? [],
            icon: Icons.map,
            onChanged: (val) {
              developer.log('📍 Area selected: $val');
              setState(() => _selectedArea = val);
            },
          ),

        const SizedBox(height: 24),

        // Location Summary
        if (_selectedAson != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOCATION SUMMARY',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLocationRow('City:', _selectedCity!),
                _buildLocationRow('Ason (Area):', _selectedAson!),
                if (_selectedArea != null)
                  _buildLocationRow('Specific Area:', _selectedArea!),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_selectedCity != null && _selectedAson != null)
                ? () {
              developer.log('✅ Location confirmed, moving to step 3');
              setState(() => _currentStep = 3);
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'CONFIRM LOCATION',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: Searchable Ason Dropdown with overflow protection
  Widget _buildSearchableAsonDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _selectedAson != null ? Colors.blueAccent : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Ason area...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (query) {
                setState(() {
                  if (query.isEmpty) {
                    final division = LocationData.cityToDivision[_selectedCity];
                    _filteredAsonAreas = _asonAreas.where((ason) {
                      return ason.divisionEn.toLowerCase() == division?.toLowerCase();
                    }).toList();
                  } else {
                    final division = LocationData.cityToDivision[_selectedCity];
                    _filteredAsonAreas = _asonAreas.where((ason) {
                      final matchesDivision = ason.divisionEn.toLowerCase() == division?.toLowerCase();
                      final matchesQuery = ason.areaNameEn.toLowerCase().contains(query.toLowerCase()) ||
                          ason.areaName.toLowerCase().contains(query.toLowerCase());
                      return matchesDivision && matchesQuery;
                    }).toList();
                  }
                });
                developer.log('🔍 Search query: "$query", results: ${_filteredAsonAreas.length}');
              },
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          // Selected value display
          if (_selectedAson != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blueAccent.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected: $_selectedAson',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () {
                      setState(() => _selectedAson = null);
                      developer.log('🔄 Ason selection cleared');
                    },
                  ),
                ],
              ),
            ),

          // Dropdown list - FIXED HEIGHT to prevent overflow
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredAsonAreas.length,
              itemBuilder: (context, index) {
                final ason = _filteredAsonAreas[index];
                final isSelected = _selectedAson == ason.areaNameEn;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: Colors.blueAccent.withOpacity(0.2),
                  leading: Icon(
                    Icons.location_on,
                    color: isSelected ? Colors.blueAccent : Colors.white54,
                    size: 20,
                  ),
                  title: Text(
                    ason.areaNameEn,
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    ason.areaName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAson = ason.areaNameEn;
                    });
                    developer.log('✅ Ason selected: ${ason.areaNameEn} (ID: ${ason.id})');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
            ),
            const Expanded(
              child: Text(
                'INCIDENT DETAILS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Provide details and evidence',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: TextField(
            controller: _reportController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => _analyzeText(),
            decoration: InputDecoration(
              hintText: 'Describe what happened in detail...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: const Icon(Icons.description, color: Colors.white54),
            ),
          ),
        ),

        if (_prediction != null) ...[
          const SizedBox(height: 12),
          _buildPredictionBadge(),
        ],

        const SizedBox(height: 24),

        Text(
          'EVIDENCE',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMediaButton(Icons.camera_alt, 'Camera', Colors.purpleAccent, _pickImageFromCamera),
            _buildMediaButton(Icons.image, 'Photos', Colors.blueAccent, _pickImageFromGallery),
            _buildMediaButton(Icons.videocam, 'Video', Colors.redAccent, _pickVideo),
            _buildMediaButton(Icons.mic, _isRecording ? 'Stop' : 'Audio', Colors.orangeAccent, _toggleRecording),
          ],
        ),

        if (_isRecording) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _recordingTime ?? '00:00',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        if (_images.isNotEmpty) _buildImagePreview(),
        if (_videos.isNotEmpty) _buildVideoPreview(),
        if (_audioFiles.isNotEmpty) _buildAudioPreview(),

        if (_requiresImageVerification(_selectedCrimeCategory) && _images.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photo evidence REQUIRED for ${_selectedCrimeCategory}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              bool canSubmit = _reportController.text.isNotEmpty &&
                  (_images.isNotEmpty || !_requiresImageVerification(_selectedCrimeCategory));

              return Transform.scale(
                scale: canSubmit ? _scaleAnimation.value : 1.0,
                child: ElevatedButton(
                  onPressed: (canSubmit && !_isUploading && !_isProcessingImage) ? _submitReport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: canSubmit
                          ? const LinearGradient(
                        colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                          : LinearGradient(
                        colors: [Colors.grey[800]!, Colors.grey[700]!],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: _isUploading || _isProcessingImage
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          const SizedBox(width: 12),
                          Text(
                            _isProcessingImage ? 'VERIFYING...' : 'SUBMITTING...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        _requiresImageVerification(_selectedCrimeCategory)
                            ? 'SUBMIT WITH AI VERIFICATION'
                            : 'SUBMIT REPORT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value != null ? Colors.blueAccent : Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2A38),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: kIsWeb
                        ? NetworkImage(_images[index].path)
                        : FileImage(File(_images[index].path)) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (_imageVerificationResults.length > index)
                Positioned(
                  top: 4,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _imageVerificationResults[index]['status'] == 'approved'
                          ? Colors.green
                          : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _imageVerificationResults[index]['status'] == 'approved'
                          ? Icons.check
                          : Icons.pending,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: const Center(
                  child: Icon(Icons.videocam, color: Colors.redAccent),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () => _removeVideo(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: _audioFiles.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.audiotrack, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Audio ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeAudio(index),
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPredictionBadge() {
    final label = _prediction!['label'];
    Color c = label == 'dangerous'
        ? Colors.red
        : (label == 'suspicious' ? Colors.orange : Colors.green);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'dangerous' ? Icons.warning : Icons.info,
            color: c,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '${label.toUpperCase()} (${(_prediction!['confidence'] * 100).toStringAsFixed(0)}%)',
            style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==================== EMERGENCY METHODS (100% PRESERVED) ====================

  Future<void> _initBackgroundService() async {
    try {
      await BackgroundService().initialize();
      developer.log('✅ Background service initialized');
    } catch (e) {
      developer.log('❌ Background service init error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_channel_high',
      'Emergency Alerts',
      description: 'High priority alerts for SOS',
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
        if (_handledEmergencyIds.isNotEmpty) {
          _stopGlobalAlert(_handledEmergencyIds.last);
        }
      },
    );
  }

  void _startNearbyEmergencyListener() async {
    developer.log('🔍 Starting emergency listener...');

    if (_listenerStarted) {
      developer.log('⚠️ Listener already started, skipping');
      return;
    }

    latlong.LatLng? emergencyLocation = await EmergencyStore.getLastLocation();

    if (emergencyLocation == null) {
      developer.log('⚠️ No emergency location available, trying to get current...');
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 5),
        );
        emergencyLocation = latlong.LatLng(position.latitude, position.longitude);
        await EmergencyStore.saveLastLocation(emergencyLocation);
      } catch (e) {
        developer.log('❌ Could not get emergency location: $e');
        return;
      }
    }

    final myId = _supabase.auth.currentUser?.id ?? '';
    if (myId.isEmpty) {
      developer.log('❌ No user ID');
      return;
    }

    _globalEmergencySubscription?.cancel();
    _emergencyStatusSubscription?.cancel();

    developer.log('📡 Starting Realtime subscription for 500m radius');
    developer.log('   - User ID: $myId');
    developer.log('   - Location: ${emergencyLocation.latitude}, ${emergencyLocation.longitude}');

    _globalEmergencySubscription = _emergencyService
        .subscribeToNearbyEmergencies(emergencyLocation, myId)
        .listen(
          (List<Map<String, dynamic>> emergencies) {
        if (emergencies.isEmpty) {
          developer.log('📭 No nearby emergencies');
          return;
        }

        developer.log('📋 Checking ${emergencies.length} emergencies...');

        for (final emergency in emergencies) {
          final String emergencyId = emergency['id'].toString();

          if (_handledEmergencyIds.contains(emergencyId)) {
            developer.log('   - Skipping handled: $emergencyId');
            continue;
          }

          if (_isDialogVisible) {
            developer.log('   - Dialog busy, queueing: $emergencyId');
            continue;
          }

          if (emergency['user_id'] == myId) {
            developer.log('   - Skipping self-emergency: $emergencyId');
            continue;
          }

          final createdAt = DateTime.tryParse(emergency['created_at'] ?? '') ?? DateTime.now();
          final minutesSinceCreated = DateTime.now().difference(createdAt).inMinutes;

          if (minutesSinceCreated > 10) {
            developer.log('   - Too old ($minutesSinceCreated min), skipping: $emergencyId');
            _handledEmergencyIds.add(emergencyId);
            continue;
          }

          developer.log('🚨 TRIGGERING ALERT for: $emergencyId at ${emergency['distance']}m');
          _currentEmergencyId = emergencyId;

          _triggerSystemNotification(emergency);
          _listenForEmergencyResolution(emergencyId);

          break;
        }
      },
      onError: (error) {
        developer.log('❌ Stream error: $error');
        _listenerStarted = false;
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _retryStartListener();
        });
      },
    );

    _listenerStarted = true;
    developer.log('✅ Emergency listener started successfully');
  }

  void _retryStartListener() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _startNearbyEmergencyListener();
    });
  }

  void _listenForEmergencyResolution(String emergencyId) {
    _emergencyStatusSubscription?.cancel();

    _emergencyStatusSubscription = _emergencyService
        .subscribeToEmergencyStatus(emergencyId)
        .listen((emergency) {
      if (emergency == null) return;
      if (_handledEmergencyIds.contains(emergencyId)) {
        developer.log('⏭️ Skipping status update for handled emergency: $emergencyId');
        return;
      }

      final status = emergency['status'] as String?;
      if (status == 'resolved') {
        developer.log('✅ Emergency $emergencyId resolved by sender. Stopping alarm.');
        _stopGlobalAlert(emergencyId);
      }
    });
  }

  void _triggerSystemNotification(Map<String, dynamic> emergency) async {
    String emergencyId = emergency['id'].toString();

    final myId = _supabase.auth.currentUser?.id ?? '';
    if (emergency['user_id'] == myId) {
      developer.log('⏭️ Skipping own emergency: $emergencyId');
      return;
    }

    if (_isDialogVisible) {
      developer.log('⏭️ Dialog already visible, queueing: $emergencyId');
      return;
    }

    _isDialogVisible = true;

    await VibrationService().startEmergencyVibration();
    await WakelockPlus.enable();

    try {
      await _globalAudioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
      );
      _globalAudioPlayer.setReleaseMode(ReleaseMode.loop);
      developer.log('🔊 Audio started successfully');
    } catch (e) {
      developer.log("Audio Error: $e");
      try {
        await _globalAudioPlayer.play(
          UrlSource('https://assets.mixkit.co/sfx/preview/mixkit-alarm-digital-clock-beep-989.mp3'),
        );
        _globalAudioPlayer.setReleaseMode(ReleaseMode.loop);
        developer.log('🔊 Fallback audio started');
      } catch (e2) {
        developer.log("Fallback audio also failed: $e2");
      }
    }

    if (!kIsWeb) {
      final androidDetails = AndroidNotificationDetails(
        'emergency_channel_high',
        'Emergency Alerts',
        channelDescription: 'High priority emergency alerts',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        autoCancel: false,
        ongoing: true,
        ticker: '🚨 SOS EMERGENCY 🚨',
        visibility: NotificationVisibility.public,
        sound: const RawResourceAndroidNotificationSound('emergency_alarm'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        ledColor: Colors.red,
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,
        styleInformation: BigTextStyleInformation(
          'Someone nearby needs immediate assistance!\n'
              'Emergency Type: ${emergency['type']?.toString().toUpperCase() ?? 'GENERAL'}\n'
              'Tap to open the emergency map.',
          htmlFormatBigText: true,
          contentTitle: '🚨 URGENT: SOS EMERGENCY 🚨',
          summaryText: 'Immediate action required',
          htmlFormatContentTitle: true,
        ),
        timeoutAfter: 60000,
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
          payload: emergencyId,
        );
        developer.log("✅ Full-screen notification sent");
      } catch (e) {
        developer.log("❌ Notification error: $e");
      }
    }

    if (!mounted) {
      _isDialogVisible = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showEmergencyDialog(emergency, emergencyId);
      } else {
        _isDialogVisible = false;
      }
    });
  }

  void _showEmergencyDialog(Map<String, dynamic> emergency, String emergencyId) {
    developer.log('🚨 Showing emergency dialog for: $emergencyId');

    if (!mounted) {
      _isDialogVisible = false;
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      useSafeArea: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[900]!.withOpacity(0.98),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.8),
                    blurRadius: 30,
                    spreadRadius: 10,
                    blurStyle: BlurStyle.outer,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (0.3 * _animationController.value),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Colors.yellow,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "🚨 EMERGENCY ALERT 🚨",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Divider(color: Colors.white54, thickness: 2),
                  const SizedBox(height: 15),
                  Text(
                    "TYPE: ${emergency['type']?.toString().toUpperCase() ?? 'GENERAL'}",
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Someone within 500m needs immediate assistance!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (emergency['distance'] != null)
                    Text(
                      "Distance: ${(emergency['distance'] as double).toStringAsFixed(0)}m away",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            if (!_isDialogVisible) return;
                            _stopGlobalAlert(emergencyId);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: const Text("IGNORE", style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red[900],
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 10,
                          ),
                          onPressed: () {
                            if (!_isDialogVisible) return;

                            developer.log('🗺️ GO TO MAP pressed for: $emergencyId');

                            final emergencyState = Provider.of<EmergencyState>(context, listen: false);
                            emergencyState.setEmergency(emergency, emergencyId);
                            developer.log('   - Emergency set in provider');

                            _stopAlarmForNavigation(emergencyId);
                            developer.log('   - Alarm stopped, provider preserved');

                            Navigator.of(dialogContext).pop();
                            _isDialogVisible = false;
                            developer.log('   - Dialog closed');

                            _tabController.animateTo(1);
                            developer.log('✅ Switched to Emergency tab with active emergency');
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 20),
                                SizedBox(width: 6),
                                Text("GO TO MAP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Tap IGNORE to stop alarm\nTap GO TO MAP to respond",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _stopAlarmForNavigation(String id) {
    developer.log('🔇 Stopping alarm for navigation (keeping provider): $id');

    _isDialogVisible = false;
    VibrationService().stopVibration();
    WakelockPlus.disable();

    try {
      _globalAudioPlayer.stop();
      developer.log('   - Audio stopped');
    } catch (e) {
      developer.log('   - Audio stop error: $e');
    }

    try {
      if (!kIsWeb) {
        _notificationsPlugin.cancel(id.hashCode);
      }
      developer.log('   - Notification cancelled');
    } catch (e) {
      developer.log('   - Notification cancel error: $e');
    }
  }

  void _stopGlobalAlert(String id) {
    if (_handledEmergencyIds.contains(id) && !_isDialogVisible) {
      developer.log('🛑 Alert already stopped for: $id');
      final emergencyState = Provider.of<EmergencyState>(context, listen: false);
      emergencyState.clearEmergency();
      return;
    }
    developer.log('🛑 Stopping global alert for: $id');

    final wasDialogVisible = _isDialogVisible;
    _isDialogVisible = false;

    if (wasDialogVisible && mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
        developer.log('   - Dialog popped successfully');
      } catch (e) {
        developer.log('   - Error popping dialog (already closed): $e');
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isDialogVisible && !_listenerStarted) {
          developer.log('🔄 Restarting emergency listener after delay...');
          _startNearbyEmergencyListener();
        }
      });
    }

    VibrationService().stopVibration();
    WakelockPlus.disable();

    try {
      _globalAudioPlayer.stop();
      developer.log('   - Audio stopped');
    } catch (e) {
      developer.log('   - Audio stop error (ignoring): $e');
    }

    try {
      if (!kIsWeb) {
        _notificationsPlugin.cancel(id.hashCode);
      }
    } catch (e) {
      developer.log('   - Notification cancel error: $e');
    }

    _handledEmergencyIds.add(id);
    if (_currentEmergencyId == id) {
      _currentEmergencyId = null;
    }
    developer.log('✅ Alert stopped completely');
  }

  // ==================== EMERGENCY BUTTON (100% PRESERVED) ====================

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
    developer.log('🚨 SOS Button: Hold completed, starting emergency...');

    latlong.LatLng? emergencyLocation;
    int locationRetries = 0;
    const maxRetries = 3;

    while (emergencyLocation == null && locationRetries < maxRetries) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 5),
        );
        emergencyLocation = latlong.LatLng(position.latitude, position.longitude);
        await EmergencyStore.saveLastLocation(emergencyLocation);
      } catch (e) {
        locationRetries++;
        if (locationRetries < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    if (emergencyLocation == null) {
      emergencyLocation = await EmergencyStore.getLastLocation();
      developer.log('   - Using last known location: $emergencyLocation');
    }

    if (emergencyLocation == null) {
      _showError('Cannot start emergency: Location unavailable. Please enable GPS and try again.');
      _showLocationSettingsDialog();
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLocationSharing = true;
      _isHolding = false;
      _holdProgress = 0.0;
    });

    String? tempEmergencyId;
    String? realEmergencyId;

    try {
      final userId = _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _showError('User not logged in');
        _safeResetEmergencyState();
        return;
      }

      try {
        developer.log('   - Starting aggressive background monitoring...');
        await _aggressiveService.startAggressiveMonitoring();

        try {
          final canSchedule = await EmergencyAlarmService.canScheduleExactAlarms();
          if (canSchedule) {
            await EmergencyAlarmService.scheduleEmergencyAlarm(delaySeconds: 15);
            developer.log('   - ✅ Exact alarm scheduled');
          } else {
            developer.log('   - ⚠️ Cannot schedule exact alarm, requesting permission...');
            EmergencyAlarmService.requestExactAlarmPermission();
          }
        } catch (e) {
          developer.log('   - ⚠️ Failed to schedule exact alarm: $e');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_in_emergency_mode', true);
        await prefs.setInt('aggressive_mode_until',
            DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch);
        developer.log('   - ✅ Aggressive monitoring active');
      } catch (e) {
        developer.log('   - ⚠️ Aggressive service failed (non-critical): $e');
      }

      tempEmergencyId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      try {
        developer.log('   - Starting foreground service with temp ID: $tempEmergencyId');
        await ForegroundLocationService().startEmergencyService(
          emergencyId: tempEmergencyId,
          userId: userId,
          initialLocation: emergencyLocation,
          emergencyType: _selectedEmergencyType,
        );
        developer.log('   - ✅ Foreground service started');
      } catch (e) {
        developer.log('❌ CRITICAL: Failed to start foreground service: $e');
        _showError('Failed to start emergency service. Please try again.');
        _safeResetEmergencyState();
        return;
      }

      try {
        developer.log('   - Inserting emergency to database...');
        final response = await _supabase.from('emergencies').insert({
          'user_id': userId,
          'location': 'POINT(${emergencyLocation.longitude} ${emergencyLocation.latitude})',
          'location_geo': 'SRID=4326;POINT(${emergencyLocation.longitude} ${emergencyLocation.latitude})',
          'status': 'active',
          'type': _selectedEmergencyType,
          'created_at': DateTime.now().toIso8601String(),
        }).select();

        if (response == null || response.isEmpty) {
          throw Exception('No response from database insert');
        }

        realEmergencyId = response[0]['id'].toString();
        developer.log('   - ✅ Emergency inserted with ID: $realEmergencyId');

      } catch (e) {
        developer.log('❌ Database insert failed: $e');
        realEmergencyId = tempEmergencyId;
        _showError('Warning: Could not save to database, but location sharing is active.');
      }

      if (realEmergencyId != null && realEmergencyId != tempEmergencyId) {
        try {
          developer.log('   - Restarting foreground service with real ID: $realEmergencyId');
          await ForegroundLocationService().stopService();
          await Future.delayed(const Duration(milliseconds: 300));

          await ForegroundLocationService().startEmergencyService(
            emergencyId: realEmergencyId,
            userId: userId,
            initialLocation: emergencyLocation,
            emergencyType: _selectedEmergencyType,
          );
          developer.log('   - ✅ Foreground service restarted with real ID');
        } catch (e) {
          developer.log('   - ⚠️ Failed to restart with real ID, continuing with temp ID: $e');
        }
      }

      await EmergencyStore.setActiveEmergency(realEmergencyId ?? tempEmergencyId);
      _startNearbyEmergencyListener();

      if (mounted) {
        _showSuccess('$_selectedEmergencyType Alert Sent! Location sharing active even when phone is locked.');
      }

    } catch (e, stackTrace) {
      developer.log('❌ UNEXPECTED ERROR in emergency flow: $e\n$stackTrace');
      await _emergencyCleanup();

      if (mounted) {
        _showError('Failed to send emergency alert: ${e.toString()}');
      }
      _safeResetEmergencyState();
    }
  }

  void _safeResetEmergencyState() {
    if (!mounted) return;
    setState(() {
      _isLocationSharing = false;
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _emergencyCleanup() async {
    developer.log('🧹 Starting emergency cleanup...');

    try {
      await EmergencyAlarmService.cancelEmergencyAlarm();
      developer.log('   - Alarm cancelled');
    } catch (e) {
      developer.log('   - Alarm cancel error (ignoring): $e');
    }

    try {
      await _aggressiveService.stopAggressiveMonitoring();
      developer.log('   - Aggressive monitoring stopped');
    } catch (e) {
      developer.log('   - Aggressive service stop error (ignoring): $e');
    }

    try {
      await ForegroundLocationService().stopService();
      developer.log('   - Foreground service stopped');
    } catch (e) {
      developer.log('   - Foreground service stop error (ignoring): $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_in_emergency_mode', false);
      await prefs.remove('aggressive_mode_until');
      developer.log('   - Shared preferences cleared');
    } catch (e) {
      developer.log('   - Prefs clear error (ignoring): $e');
    }

    try {
      await EmergencyStore.setActiveEmergency(null);
      developer.log('   - Emergency store cleared');
    } catch (e) {
      developer.log('   - Store clear error (ignoring): $e');
    }

    developer.log('✅ Cleanup completed');
  }

  void _showLocationSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Location Required',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Emergency alerts require location services to be enabled.\n\n'
              'Please enable:\n'
              '1. GPS/Location in phone settings\n'
              '2. Allow "Precise Location" for this app',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _stopLocationSharing() async {
    developer.log('🛑 Stopping location sharing and emergency services...');

    try {
      await _aggressiveService.stopAggressiveMonitoring();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_in_emergency_mode', false);
      await prefs.remove('aggressive_mode_until');
    } catch (e) {
      developer.log('   - Error stopping aggressive monitoring: $e');
    }

    try {
      await ForegroundLocationService().stopService();
    } catch (e) {
      developer.log('   - Error stopping foreground service: $e');
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('emergencies')
            .update({'status': 'resolved'})
            .eq('user_id', userId)
            .eq('status', 'active');
      }
    } catch (e) {
      developer.log("   - Error updating database: $e");
    }

    if(mounted) {
      setState(() => _isLocationSharing = false);
      _showInfo('Location sharing stopped & SOS resolved');
    }
  }

  // ==================== UTILITY METHODS ====================

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
      developer.log('📱 Device ID: $_deviceId');
    } catch (e) {
      _deviceId = 'error_${DateTime.now().millisecondsSinceEpoch}';
      developer.log('⚠️ Device ID error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _initializeAggressiveService() async {
    developer.log('🔧 Initializing aggressive background service...');

    await _aggressiveService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final isEmergencyMode = prefs.getBool('is_in_emergency_mode') ?? false;
    final aggressiveUntil = prefs.getInt('aggressive_mode_until') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (isEmergencyMode || now < aggressiveUntil) {
      developer.log('🚨 Resuming aggressive monitoring mode');
      await _aggressiveService.startAggressiveMonitoring();
    } else {
      developer.log('📡 Starting normal monitoring mode');
      await _aggressiveService.startNormalMonitoring();
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      final isDisabled = await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      developer.log('🔋 Battery optimization status: ${isDisabled == true ? "DISABLED (Good)" : "ENABLED (Bad)"}');
    } catch (e) {
      developer.log('Error checking battery status: $e');
    }
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _stepAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 1.0),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 1.05, end: 1.0), weight: 1.0),
    ]).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.repeat(reverse: true);
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

  // ==================== BUILD METHODS ====================

  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isHolding ? [Colors.redAccent, Colors.red] : [Colors.blueAccent, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHolding ? Colors.red.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Icon(
            _isLocationSharing ? Icons.stop : Icons.touch_app,
            size: 50,
            color: Colors.white,
          ),
          if (_isHolding)
            CircularProgressIndicator(
              value: _holdProgress,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          if (_isLocationSharing)
            Positioned(
              bottom: 10,
              child: GestureDetector(
                onTap: _stopLocationSharing,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Stop Sharing',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
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
              onTap: () => setState(() => _selectedEmergencyType = type['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (type['color'] as Color).withOpacity(0.8) : Colors.black45,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? Colors.white : (type['color'] as Color).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: (type['color'] as Color).withOpacity(0.6), blurRadius: 8)]
                      : [],
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

  Widget _buildReportTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmergencyButtonSection(),
            const SizedBox(height: 40),

            Card(
              elevation: 20,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              color: const Color(0xFF1E2A38).withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'FILE A REPORT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Step ${_currentStep + 1} of $_totalSteps',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    _buildStepIndicator(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildStepContent(),
                    ),
                  ],
                ),
              ),
            ),

            if (!kReleaseMode) ...[
              const SizedBox(height: 20),
              _buildDebugControls(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButtonSection() {
    return Center(
      child: Column(
        children: [
          _buildEmergencyButton(),
          const SizedBox(height: 20),
          _buildEmergencyKeywordsSelector(),
          const SizedBox(height: 20),
          Text(
            _isLocationSharing ? 'SOS ACTIVE: $_selectedEmergencyType' : 'HOLD FOR SOS',
            style: TextStyle(
              color: _isLocationSharing ? Colors.red : Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _isLocationSharing
                ? Text(
              'Broadcasting location...',
              style: TextStyle(color: Colors.green),
            )
                : const Text(
              'Emergency Location Ready',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        children: [
          const Text(
            '🧪 DEBUG CONTROLS',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _triggerSystemNotification({
                    'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
                    'type': 'Medical',
                    'created_at': DateTime.now().toIso8601String(),
                    'distance': 250.5,
                    'user_id': 'test-user-id',
                    'location': '0101000020E61000007AA52C431C985640E72F99CF5EB83740',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.notification_add),
                label: const Text('TEST ALERT'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (_handledEmergencyIds.isNotEmpty) {
                    _stopGlobalAlert(_handledEmergencyIds.last);
                  } else {
                    _showInfo('No active alert to stop');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop),
                label: const Text('TEST STOP'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Listener: ${_listenerStarted ? "ACTIVE" : "OFF"} | Ason: ${_asonAreas.length} loaded',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'REPORT CRIME';
      case 1: return 'EMERGENCY SUPPORT';
      case 2: return 'DASHBOARD';
      case 3: return 'TIMELINE';
      case 4: return 'PROFILE';
      default: return 'REPORT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => Text(
            _getAppBarTitle(_tabController.index),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
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
          const DashboardScreen(),
          const TimelineScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildModern3DTabBar(),
    );
  }

  // ==================== MODERN 3D TAB BAR ====================

  Widget _buildModern3DTabBar() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _build3DTabItem(Icons.report, 'Report', 0),
                _build3DTabItem(Icons.emergency, 'SOS', 1),
                _build3DTabItem(Icons.dashboard, 'Stats', 2),
                _build3DTabItem(Icons.timeline, 'Timeline', 3),
                _build3DTabItem(Icons.person, 'Profile', 4),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _build3DTabItem(IconData icon, String label, int index) {
    final isSelected = _tabController.index == index;
    final isEmergency = index == 1;

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        if (index == 1 && !_listenerStarted) {
          _startNearbyEmergencyListener();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(isSelected ? -0.2 : 0)
          ..translate(0.0, isSelected ? -8.0 : 0.0, 0.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
              colors: isEmergency
                  ? [Colors.redAccent, Colors.red]
                  : [Colors.blueAccent, Colors.cyanAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: (isEmergency ? Colors.redAccent : Colors.blueAccent).withOpacity(0.6),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()
                  ..scale(isSelected ? 1.2 : 1.0),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : (isEmergency ? Colors.redAccent : Colors.white70),
                  size: isSelected ? 28 : 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: isSelected ? 12 : 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.5,
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('📱 App state: $state');

    if (state == AppLifecycleState.paused) {
      BackgroundService().triggerImmediateCheck();
    } else if (state == AppLifecycleState.resumed) {
      if (!_listenerStarted) {
        _startNearbyEmergencyListener();
      }
    }
  }

  @override
  void dispose() {
    developer.log('🔴 ReportScreen: dispose called');
    _emergencyStatusSubscription?.cancel();

    try {
      if (ForegroundLocationService().isRunning) {
        ForegroundLocationService().stopService();
      }
    } catch (e) {
      developer.log('Error stopping foreground service: $e');
    }

    VibrationService().stopVibration();
    WakelockPlus.disable();

    WidgetsBinding.instance.removeObserver(this);

    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty && !_isLocationSharing) {
      _emergencyService.endEmergency(userId);
    }

    _globalEmergencySubscription?.cancel();
    _emergencyService.dispose();

    _globalAudioPlayer.dispose();
    _animationController.dispose();
    _stepAnimationController.dispose();
    _reportController.dispose();
    _tabController.dispose();
    _textClassifier.dispose();
    _audioRecorder.dispose();

    _listenerStarted = false;

    super.dispose();
  }
}