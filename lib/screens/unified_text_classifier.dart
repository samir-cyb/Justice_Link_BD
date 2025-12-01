import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;

// Conditional imports
import 'package:flutter/services.dart' if (dart.library.io) 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart' if (dart.library.io) '';

// Import web classifier conditionally
import 'text_classifier_web.dart' if (dart.library.html) '';

class UnifiedTextClassifier {
  dynamic _classifier;
  bool _isInitialized = false;
  bool _usingFallback = false;
  String? _initializationError;

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        developer.log("Using web classifier implementation");
        _classifier = _createWebClassifier();
        await _classifier.initialize();
        _usingFallback = false;
      } else {
        // Try mobile TFLite implementation first
        try {
          developer.log("Trying mobile TFLite classifier...");
          _classifier = await _createMobileClassifier();
          await _classifier.initialize();
          _usingFallback = false;
          developer.log("Mobile TFLite classifier initialized successfully");
        } catch (mobileError) {
          developer.log("Mobile TFLite failed: $mobileError");
          developer.log("Falling back to regex-based classifier");

          // Fallback to regex-based classifier
          _classifier = _createFallbackClassifier();
          await _classifier.initialize();
          _usingFallback = true;
          developer.log("Fallback regex classifier initialized");
        }
      }

      _isInitialized = true;
      developer.log("UnifiedTextClassifier initialized successfully (fallback: $_usingFallback)");

    } catch (e) {
      _initializationError = e.toString();
      developer.log("All classifier initialization attempts failed: $e");

      // Last resort: create a simple classifier that always returns normal
      _classifier = _createBasicClassifier();
      await _classifier.initialize();
      _isInitialized = true;
      _usingFallback = true;
      developer.log("Using basic classifier as last resort");
    }
  }

  dynamic _createWebClassifier() {
    if (kIsWeb) {
      // This will only be compiled for web
      return TextClassifier();
    }
    return _createFallbackClassifier();
  }

  Future<dynamic> _createMobileClassifier() async {
    try {
      if (!kIsWeb) {
        // Try to import TFLite
        developer.log("Attempting to load TFLite model...");

        // Create a mobile classifier instance
        return _MobileTextClassifier();
      }
    } catch (e) {
      developer.log("Failed to create mobile classifier: $e");
    }
    throw Exception("Mobile classifier not available");
  }

  dynamic _createFallbackClassifier() {
    return _RegexBasedClassifier();
  }

  dynamic _createBasicClassifier() {
    return _BasicClassifier();
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      developer.log("Classifier not initialized, initializing now...");
      await initialize();
    }

    try {
      final result = await _classifier.classify(text);
      developer.log("Classification result: ${result['label']} (${result['confidence']})");
      return result;
    } catch (e) {
      developer.log("Classification error: $e");

      // Return a safe default classification
      return {
        'label': 'normal',
        'confidence': 0.5,
        'scores': {},
        'crime_types': {},
        'pattern_matches': {},
      };
    }
  }

  void dispose() {
    try {
      if (_classifier != null && _classifier.dispose is Function) {
        _classifier.dispose();
      }
    } catch (e) {
      developer.log("Error disposing classifier: $e");
    }
  }
}

// Mobile TFLite classifier (only for non-web platforms)
class _MobileTextClassifier {
  Interpreter? _interpreter;
  List<String>? _vocabulary;
  bool _isInitialized = false;

  static const int _vocabSize = 3000;
  static const int _sequenceLength = 100;
  static const List<String> _labels = ['dangerous', 'suspicious', 'normal', 'fake'];

  Future<void> initialize() async {
    try {
      developer.log("Loading TFLite model...");

      // Note: This will only work if the model files are in assets
      // For now, we'll simulate loading and always fail
      // In a real implementation, you'd load the actual model

      // Simulate model loading delay
      await Future.delayed(const Duration(milliseconds: 100));

      throw Exception("TFLite model not found in assets");

    } catch (e) {
      developer.log("TFLite initialization error: $e");
      throw Exception("Failed to initialize TFLite model: $e");
    }
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      throw Exception("Mobile classifier not initialized");
    }

    // This is a placeholder - in real app, you'd use the TFLite model
    throw Exception("TFLite classifier not implemented");
  }

  void dispose() {
    _interpreter?.close();
  }
}

// Regex-based fallback classifier (same as web)
class _RegexBasedClassifier {
  bool _isInitialized = false;

  // Sentence-level crime patterns (from text_classifier_web.dart)
  final Map<String, List<String>> _sentencePatterns = {
    'dangerous': [
      r"(attack|assault|murder|kill|shot|stab).*?(happening|now|immediately|urgent)",
      r"(gun|knife|weapon).*?(threat|pointing|firing)",
      r"(bomb|explosion|blast).*?(found|located|threat)",
      r"(hostage|kidnap).*?(taken|held|captive)",
      r"(riot|mob).*?(violent|breaking|destroying)",
      r"(rape|sexual assault).*?(victim|happened)",
      r"(danger|emergency).*?(immediate|urgent|now)",
      r"(right now|currently|at this moment).*?(danger|attack|emergency)",
      r"(just happened|occurred).*?(crime|incident|attack)",
    ],
    'suspicious': [
      r"(suspicious|strange|unusual).*?(behavior|activity|person)",
      r"(follow|stalk).*?(me|someone|person)",
      r"(threat|warning).*?(received|made|sent)",
      r"(steal|rob|burglary).*?(attempt|planned|occurred)",
      r"(drug|narcotics).*?(deal|sell|trade)",
      r"(fraud|scam).*?(money|bank|account)",
      r"(corruption|bribe).*?(official|officer|government)",
      r"(should check|need to investigate|look into).*?(situation|matter)",
    ],
    'fake': [
      r"(fake|prank|joke).*?(just kidding|not real|lol)",
      r"(test|testing).*?(system|app|nothing real)",
      r"(money|tk|dollar).*?(give|payment|reward)",
      r"(tomorrow|future|will happen).*?(crime|incident)",
      r"(not real|false).*?(report|incident|situation)",
    ]
  };

  // Enhanced crime categories with contextual weights
  final Map<String, List<Map<String, dynamic>>> _crimePatterns = {
    'dangerous': [
      {'keyword': 'murder', 'weight': 2.5},
      {'keyword': 'attack', 'weight': 2.2},
      {'keyword': 'gun', 'weight': 2.0},
      {'keyword': 'knife', 'weight': 1.8},
      {'keyword': 'bomb', 'weight': 3.0},
      {'keyword': 'hostage', 'weight': 2.8},
      {'keyword': 'rape', 'weight': 2.7},
      {'keyword': 'shoot', 'weight': 2.3},
      {'keyword': 'explosion', 'weight': 2.6},
      {'keyword': 'kill', 'weight': 2.4},
      {'keyword': 'violent', 'weight': 2.1},
      {'keyword': 'emergency', 'weight': 1.9},
    ],
    'suspicious': [
      {'keyword': 'threat', 'weight': 1.8},
      {'keyword': 'follow', 'weight': 1.6},
      {'keyword': 'steal', 'weight': 1.7},
      {'keyword': 'fraud', 'weight': 1.6},
      {'keyword': 'drug', 'weight': 1.9},
      {'keyword': 'fight', 'weight': 1.5},
      {'keyword': 'suspect', 'weight': 1.4},
      {'keyword': 'suspicious', 'weight': 1.7},
      {'keyword': 'strange', 'weight': 1.3},
    ],
    'fake': [
      {'keyword': 'fake', 'weight': 2.0},
      {'keyword': 'prank', 'weight': 1.8},
      {'keyword': 'joke', 'weight': 1.7},
      {'keyword': 'test', 'weight': 1.5},
      {'keyword': 'lol', 'weight': 1.9},
      {'keyword': 'tk', 'weight': 1.3},
      {'keyword': 'tomorrow', 'weight': 1.2},
    ]
  };

  Future<void> initialize() async {
    await Future.delayed(Duration.zero);
    _isInitialized = true;
    developer.log("Regex classifier initialized");
  }

  Map<String, dynamic> _advancedTextClassification(String text) {
    final lowerText = text.toLowerCase();
    final Map<String, double> scores = {};

    // Initialize all categories
    for (final category in ['dangerous', 'suspicious', 'fake', 'normal']) {
      scores[category] = 0.0;
    }

    // Check sentence patterns
    for (final category in _sentencePatterns.keys) {
      double categoryScore = 0.0;

      for (final pattern in _sentencePatterns[category]!) {
        try {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(lowerText);

          if (matches.isNotEmpty) {
            final patternComplexity = pattern.split('.*?').length;
            categoryScore += patternComplexity * 0.5;
          }
        } catch (e) {
          continue;
        }
      }

      if (categoryScore > 0) {
        scores[category] = categoryScore;
      }
    }

    // Check keyword patterns
    for (final category in _crimePatterns.keys) {
      double categoryScore = scores[category] ?? 0.0;

      for (final keywordData in _crimePatterns[category]!) {
        final word = keywordData['keyword'] as String;
        final weight = keywordData['weight'] as double;

        // Check for whole word matches
        if (_containsWord(lowerText, word)) {
          categoryScore += weight;
        }
      }

      scores[category] = categoryScore;
    }

    // Determine primary label
    String primaryLabel = 'normal';
    double maxScore = 0.0;

    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        primaryLabel = entry.key;
      }
    }

    // Apply minimum threshold
    if (maxScore < 0.5) {
      primaryLabel = 'normal';
      maxScore = 0.5;
    }

    // Calculate confidence (normalize to 0-1)
    final confidence = (maxScore / 5.0).clamp(0.1, 0.95);

    return {
      'label': primaryLabel,
      'confidence': confidence,
      'scores': scores,
      'pattern_matches': {},
    };
  }

  bool _containsWord(String text, String word) {
    final pattern = r'\b' + _escapeRegExp(word) + r'\b';
    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  String _escapeRegExp(String string) {
    return string.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) {
      return '\\${match.group(0)}';
    });
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    final result = _advancedTextClassification(text);

    return {
      'label': result['label'],
      'confidence': result['confidence'],
      'scores': result['scores'],
      'crime_types': {},
      'pattern_matches': result['pattern_matches'],
    };
  }

  void dispose() {
    // Nothing to dispose
  }
}

// Basic classifier that always returns normal (last resort)
class _BasicClassifier {
  Future<void> initialize() async {
    await Future.delayed(Duration.zero);
  }

  Future<Map<String, dynamic>> classify(String text) async {
    return {
      'label': 'normal',
      'confidence': 0.5,
      'scores': {'normal': 0.5},
      'crime_types': {},
      'pattern_matches': {},
    };
  }

  void dispose() {}
}