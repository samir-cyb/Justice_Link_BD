import 'dart:async';
import 'package:vibration/vibration.dart';
import 'dart:developer' as developer;

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  Timer? _vibrationTimer;
  bool _isVibrating = false;
  static const int _vibrationDuration = 2000; // 2 seconds on
  static const int _pauseDuration = 500;      // 0.5 seconds off

  /// Start continuous heavy vibration until stopped
  Future<void> startEmergencyVibration() async {
    if (_isVibrating) {
      developer.log('⚠️ Vibration already active');
      return;
    }

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) {
      developer.log('❌ Device has no vibrator');
      return;
    }

    // Check for amplitude control
    final hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

    _isVibrating = true;
    developer.log('🚨 Starting emergency vibration (amplitude: $hasAmplitudeControl)');

    if (hasAmplitudeControl) {
      _startAmplitudeVibration();
    } else {
      _startSimpleVibration();
    }
  }

  void _startAmplitudeVibration() {
    // Build pattern with max amplitude
    final pattern = <int>[];
    final intensities = <int>[];

    for (int i = 0; i < 50; i++) { // 50 cycles = ~2 minutes max
      pattern.add(_pauseDuration);   // wait
      pattern.add(_vibrationDuration); // vibrate
      intensities.add(0);
      intensities.add(255); // Max amplitude
    }

    // Ensure non-nullable lists
    final List<int> vibrationPattern = pattern;
    final List<int> vibrationIntensities = intensities;

    Vibration.vibrate(
      pattern: vibrationPattern,
      intensities: vibrationIntensities,
    );
  }

  void _startSimpleVibration() {
    // Fallback for older devices
    _vibrationTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
          (timer) {
        if (!_isVibrating) {
          timer.cancel();
          return;
        }
        Vibration.vibrate(duration: 2000);
      },
    );
    // Initial vibration
    Vibration.vibrate(duration: 2000);
  }

  /// Stop all vibration immediately
  void stopVibration() {
    if (!_isVibrating) return;

    developer.log('✋ Stopping emergency vibration');
    _isVibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    Vibration.cancel();
  }

  bool get isVibrating => _isVibrating;
}