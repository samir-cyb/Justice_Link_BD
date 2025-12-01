import 'dart:math';

class TextClassifier {
  bool _isInitialized = false;

  // Sentence-level crime patterns (from your create_dataset.py)
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
    'theft': [
      r"(stolen|robbed|theft).*?(phone|wallet|money|item)",
      r"(break in|burglary).*?(house|home|apartment|car)",
      r"(missing|disappeared).*?(belongings|items|property)",
      r"(snatch|grab).*?(purse|bag|phone)",
      r"(pickpocket).*?(market|crowd|public)",
    ],
    'assault': [
      r"(hit|punch|beat).*?(person|victim|someone)",
      r"(physical|violent).*?(attack|assault|conflict)",
      r"(hurt|injured).*?(hospital|medical|treatment)",
      r"(abuse|domestic violence).*?(family|partner|spouse)",
    ],
    'vandalism': [
      r"(damage|destroy).*?(property|car|building)",
      r"(graffiti|spray paint).*?(wall|property|public)",
      r"(break|shatter).*?(window|glass|door)",
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
  final Map<String, List<CrimeKeyword>> _crimePatterns = {
    'dangerous': [
      CrimeKeyword('murder', weight: 2.5, context: 'violent_crime'),
      CrimeKeyword('attack', weight: 2.2, context: 'violent_crime'),
      CrimeKeyword('gun', weight: 2.0, context: 'weapon'),
      CrimeKeyword('knife', weight: 1.8, context: 'weapon'),
      CrimeKeyword('bomb', weight: 3.0, context: 'explosive'),
      CrimeKeyword('hostage', weight: 2.8, context: 'kidnapping'),
      CrimeKeyword('rape', weight: 2.7, context: 'sexual_crime'),
      CrimeKeyword('shoot', weight: 2.3, context: 'violent_crime'),
      CrimeKeyword('explosion', weight: 2.6, context: 'explosive'),
      CrimeKeyword('kill', weight: 2.4, context: 'violent_crime'),
      CrimeKeyword('violent', weight: 2.1, context: 'violent_crime'),
      CrimeKeyword('emergency', weight: 1.9, context: 'urgency'),
    ],
    'suspicious': [
      CrimeKeyword('threat', weight: 1.8, context: 'intimidation'),
      CrimeKeyword('follow', weight: 1.6, context: 'stalking'),
      CrimeKeyword('steal', weight: 1.7, context: 'theft'),
      CrimeKeyword('fraud', weight: 1.6, context: 'financial_crime'),
      CrimeKeyword('drug', weight: 1.9, context: 'narcotics'),
      CrimeKeyword('fight', weight: 1.5, context: 'conflict'),
      CrimeKeyword('suspect', weight: 1.4, context: 'suspicion'),
      CrimeKeyword('suspicious', weight: 1.7, context: 'suspicion'),
      CrimeKeyword('strange', weight: 1.3, context: 'suspicion'),
    ],
    'theft': [
      CrimeKeyword('theft', weight: 1.8, context: 'property_crime'),
      CrimeKeyword('rob', weight: 1.9, context: 'property_crime'),
      CrimeKeyword('stolen', weight: 1.7, context: 'property_crime'),
      CrimeKeyword('burglary', weight: 1.8, context: 'property_crime'),
      CrimeKeyword('missing', weight: 1.3, context: 'property_crime'),
      CrimeKeyword('snatch', weight: 1.6, context: 'property_crime'),
      CrimeKeyword('pickpocket', weight: 1.5, context: 'property_crime'),
    ],
    'assault': [
      CrimeKeyword('assault', weight: 2.0, context: 'violent_crime'),
      CrimeKeyword('hit', weight: 1.7, context: 'violent_crime'),
      CrimeKeyword('punch', weight: 1.8, context: 'violent_crime'),
      CrimeKeyword('hurt', weight: 1.5, context: 'violent_crime'),
      CrimeKeyword('abuse', weight: 1.9, context: 'violent_crime'),
      CrimeKeyword('beat', weight: 1.8, context: 'violent_crime'),
    ],
    'vandalism': [
      CrimeKeyword('vandalism', weight: 1.6, context: 'property_damage'),
      CrimeKeyword('damage', weight: 1.5, context: 'property_damage'),
      CrimeKeyword('destroy', weight: 1.7, context: 'property_damage'),
      CrimeKeyword('graffiti', weight: 1.4, context: 'property_damage'),
      CrimeKeyword('break', weight: 1.5, context: 'property_damage'),
    ],
    'fake': [
      CrimeKeyword('fake', weight: 2.0, context: 'false_report'),
      CrimeKeyword('prank', weight: 1.8, context: 'false_report'),
      CrimeKeyword('joke', weight: 1.7, context: 'false_report'),
      CrimeKeyword('test', weight: 1.5, context: 'false_report'),
      CrimeKeyword('lol', weight: 1.9, context: 'false_report'),
      CrimeKeyword('tk', weight: 1.3, context: 'false_report'),
      CrimeKeyword('tomorrow', weight: 1.2, context: 'false_report'),
    ]
  };

  // Context modifiers for sentence-level analysis
  final Map<String, List<String>> _contextModifiers = {
    'urgency_boosters': ['now', 'immediately', 'urgent', 'emergency', 'asap', 'right now', 'help', 'quickly'],
    'time_reducers': ['tomorrow', 'next week', 'later', 'will happen', 'planning', 'future', 'soon'],
    'credibility_boosters': ['witness', 'saw', 'seen', 'observed', 'heard', 'reported', 'noticed'],
    'fake_indicators': ['just kidding', 'lol', 'haha', 'not real', 'prank', 'testing', 'test', 'jk']
  };

  Future<void> initialize() async {
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Use the advanced sentence-level classification
    final result = _advancedTextClassification(text);

    return {
      'label': result['label'],
      'confidence': result['confidence'],
      'scores': result['scores'],
      'crime_types': _getDetectedCrimeTypes(result['scores']),
      'pattern_matches': result['pattern_matches'],
    };
  }

  Map<String, dynamic> _advancedTextClassification(String text) {
    final lowerText = text.toLowerCase();

    // Step 1: Sentence pattern analysis
    final patternAnalysis = _analyzeSentencePatterns(text);
    final patternScores = patternAnalysis['scores'];
    final patternMatches = patternAnalysis['matches'];

    // Step 2: Context analysis
    final contextModifier = _analyzeContext(lowerText);

    // Step 3: Sentence complexity
    final complexityModifier = _calculateSentenceComplexity(text);

    // Step 4: Word-level analysis
    final wordScores = _calculateWordScores(lowerText);

    // Step 5: Combine all scores
    final Map<String, double> finalScores = {};

    final allCategories = {...patternScores.keys, ...wordScores.keys};

    for (final category in allCategories) {
      final patternScore = patternScores[category] ?? 0.0;
      final wordScore = wordScores[category] ?? 0.0;

      // Weighted combination (pattern matching is more valuable - 70%)
      final combinedScore = (patternScore * 0.7) + (wordScore * 0.3);

      // Apply context and complexity modifiers
      finalScores[category] = combinedScore * contextModifier * complexityModifier;
    }

    // Step 6: Determine primary label
    final primaryLabel = _determinePrimaryLabel(finalScores);

    // Step 7: Calculate confidence
    final confidence = _calculateConfidence(finalScores, primaryLabel, text);

    return {
      'label': primaryLabel,
      'confidence': confidence,
      'scores': finalScores,
      'pattern_matches': patternMatches,
    };
  }

  Map<String, dynamic> _analyzeSentencePatterns(String text) {
    final lowerText = text.toLowerCase();
    final Map<String, double> patternScores = {};
    final Map<String, List<String>> patternMatches = {};

    for (final category in _sentencePatterns.keys) {
      double categoryScore = 0.0;
      int matchesFound = 0;
      final List<String> categoryMatches = [];

      for (final pattern in _sentencePatterns[category]!) {
        try {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(lowerText);

          if (matches.isNotEmpty) {
            matchesFound += matches.length;

            // Higher score for more specific patterns
            final patternComplexity = pattern.split('.*?').length;
            categoryScore += patternComplexity * 0.5;

            // Store what was matched
            for (final match in matches) {
              categoryMatches.add(match.group(0)!);
            }
          }
        } catch (e) {
          // Skip invalid regex patterns
          continue;
        }
      }

      if (matchesFound > 0) {
        // Normalize by text length
        final wordCount = text.split(' ').length;
        final densityBonus = (matchesFound / wordCount * 10).clamp(0.0, 2.0);
        categoryScore *= (1 + densityBonus);

        patternMatches[category] = categoryMatches;
      }

      patternScores[category] = categoryScore;
    }

    return {
      'scores': patternScores,
      'matches': patternMatches,
    };
  }

  Map<String, double> _calculateWordScores(String lowerText) {
    final Map<String, double> wordScores = {};

    for (final category in _crimePatterns.keys) {
      double categoryScore = 0.0;

      for (final keywordData in _crimePatterns[category]!) {
        final word = keywordData.keyword;
        final weight = keywordData.weight;

        // Check for whole word matches
        if (_containsWord(lowerText, word)) {
          categoryScore += weight;

          // Check for context boosters
          if (category == 'dangerous' || category == 'suspicious') {
            for (final booster in _contextModifiers['urgency_boosters']!) {
              if (_containsWord(lowerText, booster)) {
                categoryScore += 0.5; // Context bonus
              }
            }
          }
        }
      }

      wordScores[category] = categoryScore;
    }

    return wordScores;
  }

  double _analyzeContext(String lowerText) {
    double contextScore = 1.0;

    // Urgency boost
    int urgencyWords = 0;
    for (final word in _contextModifiers['urgency_boosters']!) {
      if (_containsWord(lowerText, word)) {
        urgencyWords++;
      }
    }
    if (urgencyWords > 0) {
      contextScore *= (1 + urgencyWords * 0.3);
    }

    // Time-based reduction (future events are less credible for emergencies)
    int futureWords = 0;
    for (final word in _contextModifiers['time_reducers']!) {
      if (_containsWord(lowerText, word)) {
        futureWords++;
      }
    }
    if (futureWords > 0) {
      contextScore *= (1 - futureWords * 0.4);
    }

    // Credibility boost
    int credibilityWords = 0;
    for (final word in _contextModifiers['credibility_boosters']!) {
      if (_containsWord(lowerText, word)) {
        credibilityWords++;
      }
    }
    if (credibilityWords > 0) {
      contextScore *= (1 + credibilityWords * 0.2);
    }

    // Fake indicators reduction
    int fakeIndicators = 0;
    for (final word in _contextModifiers['fake_indicators']!) {
      if (_containsWord(lowerText, word)) {
        fakeIndicators++;
      }
    }
    if (fakeIndicators > 0) {
      contextScore *= (1 - fakeIndicators * 0.5);
    }

    return contextScore.clamp(0.1, 3.0);
  }

  double _calculateSentenceComplexity(String text) {
    final words = text.split(' ');
    final wordCount = words.length;
    double complexity = 0.0;

    // Sentence length bonus (longer descriptions are more credible)
    if (wordCount > 20) {
      complexity += 1.0;
    } else if (wordCount > 10) {
      complexity += 0.5;
    } else if (wordCount < 5) {
      complexity -= 1.0;
    }

    // Specificity bonus (numbers, locations, details)
    final hasNumbers = RegExp(r'\d+').hasMatch(text);
    final hasLocationTerms = RegExp(r'\b(street|road|avenue|lane|area|location|near|at)\b', caseSensitive: false).hasMatch(text);
    final hasTimeReferences = RegExp(r'\b(\d+:\d+|am|pm|morning|evening|night|today|yesterday)\b', caseSensitive: false).hasMatch(text);

    if (hasNumbers) complexity += 0.3;
    if (hasLocationTerms) complexity += 0.3;
    if (hasTimeReferences) complexity += 0.3;

    return (1.0 + complexity).clamp(0.5, 2.5);
  }

  String _determinePrimaryLabel(Map<String, double> scores) {
    // Remove regular crime types from primary label consideration
    final mainCategories = ['dangerous', 'suspicious', 'fake', 'normal'];
    final mainScores = <String, double>{};

    for (final entry in scores.entries) {
      if (mainCategories.contains(entry.key)) {
        mainScores[entry.key] = entry.value;
      }
    }

    if (mainScores.isEmpty) return 'normal';

    // Find the entry with maximum value
    String primaryLabel = 'normal';
    double maxScore = 0.0;
    for (final entry in mainScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        primaryLabel = entry.key;
      }
    }

    // Apply minimum threshold
    if (maxScore < 0.5) return 'normal';

    return primaryLabel;
  }

  double _calculateConfidence(Map<String, double> scores, String primaryLabel, String text) {
    double baseConfidence = scores[primaryLabel] ?? 0.0;

    // Normalize to 0-1 range
    baseConfidence = (baseConfidence / 5.0).clamp(0.0, 0.9);

    // Text length factor
    final wordCount = text.split(' ').length;
    if (wordCount < 5) {
      baseConfidence *= 0.4; // Very short texts get low confidence
    } else if (wordCount < 10) {
      baseConfidence *= 0.7;
    } else if (wordCount > 50) {
      baseConfidence *= 1.1; // Detailed reports get confidence boost
    }

    // Score gap factor (difference between top and second score)
    final sortedScores = scores.values.toList();
    sortedScores.sort((a, b) => b.compareTo(a));
    if (sortedScores.length > 1) {
      final scoreGap = sortedScores[0] - sortedScores[1];
      final gapBonus = (scoreGap * 0.5).clamp(0.0, 0.3);
      baseConfidence += gapBonus;
    }

    // Multiple evidence factor - FIXED: Use explicit type annotation
    final highConfidenceCategories = scores.values.where((double score) => score > 1.0).length;
    if (highConfidenceCategories > 1) {
      baseConfidence *= 0.8; // Multiple strong signals might indicate confusion
    }

    // Pattern match bonus
    final patternAnalysis = _analyzeSentencePatterns(text);
    final patternScores = patternAnalysis['scores'] as Map<String, double>;
    final hasPatternMatches = patternScores.values.any((double score) => score > 0);
    if (hasPatternMatches) {
      baseConfidence *= 1.2; // Sentence patterns are reliable
    }

    return baseConfidence.clamp(0.1, 0.95);
  }

  // Helper method to check whole word matches (not partial)
  bool _containsWord(String text, String word) {
    final pattern = r'\b' + _escapeRegExp(word) + r'\b';
    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  // Helper function to escape regex characters
  String _escapeRegExp(String string) {
    return string.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) {
      return '\\${match.group(0)}';
    });
  }

  Map<String, double> _getDetectedCrimeTypes(Map<String, double> scores) {
    final crimeTypes = ['theft', 'assault', 'vandalism'];
    final crimeTypeScores = <String, double>{};

    for (final entry in scores.entries) {
      if (crimeTypes.contains(entry.key)) {
        crimeTypeScores[entry.key] = entry.value;
      }
    }

    return crimeTypeScores;
  }

  void dispose() {}
}

// Helper class for weighted keywords
class CrimeKeyword {
  final String keyword;
  final double weight;
  final String context;

  CrimeKeyword(this.keyword, {required this.weight, required this.context});
}