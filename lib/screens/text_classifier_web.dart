class TextClassifier {
  bool _isInitialized = false;

  Future<void> initialize() async {
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Simple keyword-based fallback for web
    final lowerText = text.toLowerCase();

    // Dangerous keywords
    final dangerousKeywords = [
      'attack', 'kill', 'murder', 'shoot', 'gun', 'knife',
      'bomb', 'explosion', 'hostage', 'rape', 'assault'
    ];

    // Suspicious keywords
    final suspiciousKeywords = [
      'threat', 'danger', 'suspect', 'follow', 'steal',
      'rob', 'burglary', 'fraud', 'corruption', 'bribe'
    ];

    // Fake keywords
    final fakeKeywords = [
      'fake', 'prank', 'joke', 'not real', 'just kidding'
    ];

    // Count matches
    final dangerousCount = dangerousKeywords.where((k) => lowerText.contains(k)).length;
    final suspiciousCount = suspiciousKeywords.where((k) => lowerText.contains(k)).length;
    final fakeCount = fakeKeywords.where((k) => lowerText.contains(k)).length;

    // Determine label
    String label;
    double confidence;

    if (dangerousCount > 0) {
      label = 'dangerous';
      confidence = dangerousCount / dangerousKeywords.length;
    } else if (suspiciousCount > 0) {
      label = 'suspicious';
      confidence = suspiciousCount / suspiciousKeywords.length;
    } else if (fakeCount > 0) {
      label = 'fake';
      confidence = fakeCount / fakeKeywords.length;
    } else {
      label = 'normal';
      confidence = 0.8; // Default confidence for normal
    }

    return {
      'label': label,
      'confidence': confidence.clamp(0.0, 1.0),
      'scores': {
        'dangerous': dangerousCount / dangerousKeywords.length,
        'suspicious': suspiciousCount / suspiciousKeywords.length,
        'normal': 1.0 - (dangerousCount + suspiciousCount) / (dangerousKeywords.length + suspiciousKeywords.length),
        'fake': fakeCount / fakeKeywords.length,
      },
    };
  }

  void dispose() {}
}