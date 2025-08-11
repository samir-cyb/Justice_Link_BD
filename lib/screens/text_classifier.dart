import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'dart:math';

class TextClassifier {
  Interpreter? _interpreter;
  List<String>? _vocabulary;
  static const int _vocabSize = 3000;
  static const int _sequenceLength = 100;
  static const List<String> _labels = ['dangerous', 'suspicious', 'normal', 'fake'];

  Future<void> initialize() async {
    try {
      // Load the TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/crime_classifier.tflite');

      // Load the vocabulary
      final vocabJson = await rootBundle.loadString('assets/vectorizer/vocab.json');
      _vocabulary = List<String>.from(json.decode(vocabJson));

      // Verify vocabulary size
      if (_vocabulary!.length > _vocabSize + 1) {
        _vocabulary = _vocabulary!.sublist(0, _vocabSize + 1);
      }
    } catch (e) {
      print("Error loading model or vocabulary: $e");
      throw Exception("Failed to initialize classifier: $e");
    }
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (_interpreter == null || _vocabulary == null) {
      throw Exception("Classifier not initialized");
    }

    try {
      // Preprocess text and create input tensor
      final input = _preprocessText(text);
      final inputTensor = [input];
      final output = List.filled(1 * 4, 0.0).reshape([1, 4]);

      // Run inference
      _interpreter!.run(inputTensor, output);

      // Process output
      final confidences = output[0] as List<double>;
      final predictedIndex = confidences.indexOf(confidences.reduce(max));
      final confidence = confidences[predictedIndex];

      return {
        'label': _labels[predictedIndex],
        'confidence': confidence
      };
    } catch (e) {
      print("Error during classification: $e");
      throw Exception("Classification failed: $e");
    }
  }

  List<int> _preprocessText(String text) {
    // Step 1: Clean text (lowercase, remove punctuation)
    String cleanedText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    // Step 2: Tokenize (split into words)
    List<String> tokens = cleanedText.split(RegExp(r'\s+'));

    // Step 3: Convert tokens to indices using vocabulary
    List<int> indices = tokens.map((token) {
      int index = _vocabulary!.indexOf(token);
      // Use 0 for OOV (out-of-vocabulary) tokens
      return index >= 0 && index < _vocabSize ? index : 0;
    }).toList();

    // Step 4: Pad or truncate to sequence_length
    if (indices.length > _sequenceLength) {
      indices = indices.sublist(0, _sequenceLength);
    } else {
      indices = indices + List.filled(_sequenceLength - indices.length, 0);
    }

    return indices;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _vocabulary = null;
  }
}