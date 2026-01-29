import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../services/auth_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Tabs state
  int _selectedMainTab = 0; // 0: Offline, 1: Online
  int _selectedOfflineCategory = 0; // 0: All, 1: Killing, 2: Theft, etc.
  int _selectedOnlineCategory = 0; // 0: All, 1: Hacking, 2: Harassment, etc.

  // Category lists - using final instead of const for colors with shades
  final List<Map<String, dynamic>> _offlineCategories = [
    {'id': 0, 'name': 'All', 'icon': Icons.all_inclusive, 'color': Colors.white},
    {'id': 1, 'name': 'Killing', 'icon': Icons.warning, 'color': Colors.red},
    {'id': 2, 'name': 'Theft', 'icon': Icons.money_off, 'color': Colors.orange},
    {'id': 3, 'name': 'Bribery', 'icon': Icons.account_balance, 'color': Colors.yellow},
    {'id': 4, 'name': 'Assault', 'icon': Icons.gavel, 'color': Colors.blue},
    {'id': 5, 'name': 'Vandalism', 'icon': Icons.broken_image, 'color': Colors.purple},
    {'id': 6, 'name': 'Robbery', 'icon': Icons.security, 'color': Colors.cyan},
    {'id': 7, 'name': 'Kidnapping', 'icon': Icons.person_off, 'color': Colors.pink},
  ];

  final List<Map<String, dynamic>> _onlineCategories = [
    {'id': 0, 'name': 'All', 'icon': Icons.all_inclusive, 'color': Colors.white},
    {'id': 1, 'name': 'Hacking', 'icon': Icons.code, 'color': Colors.green},
    {'id': 2, 'name': 'Harassment', 'icon': Icons.block, 'color': Colors.red},
    {'id': 3, 'name': 'Fraud', 'icon': Icons.money, 'color': Colors.orange},
    {'id': 4, 'name': 'Scams', 'icon': Icons.warning, 'color': Colors.yellow},
    {'id': 5, 'name': 'Phishing', 'icon': Icons.link, 'color': Colors.blue},
    {'id': 6, 'name': 'Cyberbullying', 'icon': Icons.psychology, 'color': Colors.purple},
    {'id': 7, 'name': 'Identity Theft', 'icon': Icons.badge, 'color': Colors.cyan},
  ];

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<FlipCardState>> _cardKeys = {};
  final Map<String, AnimationController> _hoverControllers = {};
  final Map<String, bool> _isHovering = {};

  // NEW: Track sensitive content state
  final Map<String, bool> _sensitiveContentRevealed = {};
  final Map<String, bool> _showSensitiveWarning = {};

  StreamSubscription<List<Map<String, dynamic>>>? _reportsSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _loadReports();
    _startRealtimeSubscription();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _reportsSubscription?.cancel();
    for (var controller in _hoverControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startRealtimeSubscription() {
    _reportsSubscription = _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .listen((List<Map<String, dynamic>> reports) {
      if (mounted) {
        _updateReportsList(reports);
      }
    }, onError: (error) {
      debugPrint('Realtime subscription error: $error');
      // Retry after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _startRealtimeSubscription();
      });
    });
  }

  void _updateReportsList(List<Map<String, dynamic>> newReports) {
    setState(() {
      _reports = newReports;
      _isLoading = false;

      for (var report in _reports) {
        final id = report['id'].toString();
        if (!_cardKeys.containsKey(id)) {
          _cardKeys[id] = GlobalKey<FlipCardState>();
        }
        if (!_hoverControllers.containsKey(id)) {
          _hoverControllers[id] = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          _isHovering[id] = false;
        }
        // Initialize sensitive content tracking
        if (!_sensitiveContentRevealed.containsKey(id)) {
          _sensitiveContentRevealed[id] = false;
        }
        if (!_showSensitiveWarning.containsKey(id)) {
          _showSensitiveWarning[id] = false;
        }
      }
    });
  }

  Future<void> _loadReports() async {
    try {
      final response = await _supabase
          .from('reports')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;

      _updateReportsList(List<Map<String, dynamic>>.from(response ?? []));
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showSnackBar('Failed to load reports. Please try again.', Colors.red);
    }
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    List<Map<String, dynamic>> filteredReports = _reports.where((report) {
      // Filter by main tab (Online/Offline)
      final crimeType = (report['crime_type'] as String? ?? 'unknown').toLowerCase();
      final isOffline = _isOfflineCrime(crimeType);

      if (_selectedMainTab == 0 && !isOffline) return false; // Offline tab
      if (_selectedMainTab == 1 && isOffline) return false; // Online tab

      // Filter by category
      if (_selectedMainTab == 0) { // Offline categories
        if (_selectedOfflineCategory == 0) return true; // All
        final selectedCategory = _offlineCategories[_selectedOfflineCategory];
        final categoryName = selectedCategory['name'].toString().toLowerCase();

        // For "All" category in offline, we show all offline crimes
        if (categoryName == 'all') return true;

        // Check if crime type matches the selected category
        return crimeType.contains(categoryName);
      } else { // Online categories
        if (_selectedOnlineCategory == 0) return true; // All
        final selectedCategory = _onlineCategories[_selectedOnlineCategory];
        final categoryName = selectedCategory['name'].toString().toLowerCase();

        // For "All" category in online, we show all online crimes
        if (categoryName == 'all') return true;

        // Check if crime type matches the selected category
        return crimeType.contains(categoryName);
      }
    }).toList();

    return filteredReports;
  }

  bool _isOfflineCrime(String crimeType) {
    // List of online crimes (you can customize this)
    final onlineCrimes = ['hacking', 'harassment', 'fraud', 'scams', 'phishing',
      'cyberbullying', 'identity theft', 'online'];

    // If crime type contains any online crime keyword, treat as online
    for (var onlineCrime in onlineCrimes) {
      if (crimeType.contains(onlineCrime)) {
        return false;
      }
    }

    return true; // Default to offline if no match
  }

  // NEW: Check if crime is sensitive
  bool _isSensitiveCrime(String crimeType) {
    final lowerType = crimeType.toLowerCase();
    final sensitiveKeywords = ['killing', 'murder', 'homicide', 'dead', 'body', 'corpse'];
    return sensitiveKeywords.any((keyword) => lowerType.contains(keyword));
  }

  // NEW: Handle sensitive content tap
  void _handleSensitiveContentTap(String reportId, String crimeType) {
    final isSensitive = _isSensitiveCrime(crimeType);

    if (isSensitive && !_sensitiveContentRevealed[reportId]!) {
      _showSensitiveContentDialog(reportId, crimeType);
    }
  }

  // NEW: Show sensitive content dialog
  void _showSensitiveContentDialog(String reportId, String crimeType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.red, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 60,
              ),
              const SizedBox(height: 15),
              const Text(
                "⚠️ SENSITIVE CONTENT WARNING",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                crimeType.toUpperCase(),
                style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "This image may contain graphic violence or disturbing content. Viewer discretion is advised.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _sensitiveContentRevealed[reportId] = true;
                        _showSensitiveWarning[reportId] = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "VIEW ANYWAY",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                "This action will be logged",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateVote(String reportId, String voteType) async {
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      _showSnackBar('Please login to vote', Colors.orange);
      return;
    }

    int currentReportIndex = -1;
    try {
      currentReportIndex = _reports.indexWhere((report) => report['id'].toString() == reportId);
      if (currentReportIndex == -1) return;

      final currentReport = Map<String, dynamic>.from(_reports[currentReportIndex]);
      final currentVotes = Map<String, dynamic>.from(
          (currentReport['votes'] as Map<String, dynamic>?) ??
              {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0}
      );
      final currentUserVotes = Map<String, String>.from(
          (currentReport['user_votes'] as Map<String, dynamic>? ?? {})
              .map((key, value) => MapEntry(key, value.toString())));

      final previousVote = currentUserVotes[userId];

      if (previousVote == voteType) {
        setState(() {
          currentVotes[voteType] = (currentVotes[voteType] as int? ?? 0) - 1;
          currentUserVotes.remove(userId);
          _reports[currentReportIndex] = {
            ...currentReport,
            'votes': currentVotes,
            'user_votes': currentUserVotes,
          };
        });

        await _supabase.from('reports').update({
          'votes': currentVotes,
          'user_votes': currentUserVotes,
        }).eq('id', reportId);

        debugPrint('🗳️ Vote removed: $voteType from report $reportId');
        return;
      }

      if (previousVote != null) {
        currentVotes[previousVote] = (currentVotes[previousVote] as int? ?? 0) - 1;
      }

      currentVotes[voteType] = (currentVotes[voteType] as int? ?? 0) + 1;
      currentUserVotes[userId] = voteType;

      setState(() {
        _reports[currentReportIndex] = {
          ...currentReport,
          'votes': currentVotes,
          'user_votes': currentUserVotes,
        };
      });

      // 🎨 Debug logging for color calculation
      final dangerousVotes = currentVotes['dangerous'] as int? ?? 0;
      final suspiciousVotes = currentVotes['suspicious'] as int? ?? 0;
      final fakeVotes = currentVotes['fake'] as int? ?? 0;
      final normalVotes = currentVotes['normal'] as int? ?? 0;
      final totalVotes = dangerousVotes + suspiciousVotes + fakeVotes + normalVotes;

      debugPrint('''
🎨 COLOR CALCULATION AFTER VOTE:
  Report: $reportId
  Vote Type: $voteType
  Total Votes: $totalVotes
  Dangerous: $dangerousVotes
  Suspicious: $suspiciousVotes
  Fake: $fakeVotes
  Normal: $normalVotes
  Color will be: ${_getCardColor(_reports[currentReportIndex])}
''');

      await _supabase.from('reports').update({
        'votes': currentVotes,
        'user_votes': currentUserVotes,
      }).eq('id', reportId);

    } catch (e) {
      debugPrint('Error updating vote: $e');
      _showSnackBar('Failed to update vote. Please try again.', Colors.red);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM dd, yyyy').format(date);
  }

  // 🎨 UPDATED: Gradual Color Voting System
  Color _getCardColor(Map<String, dynamic> report) {
    final votes = (report['votes'] as Map<String, dynamic>?) ??
        {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0};

    final dangerousVotes = votes['dangerous'] as int? ?? 0;
    final suspiciousVotes = votes['suspicious'] as int? ?? 0;
    final fakeVotes = votes['fake'] as int? ?? 0;
    final normalVotes = votes['normal'] as int? ?? 0;

    final totalVotes = dangerousVotes + suspiciousVotes + fakeVotes + normalVotes;

    // 🔥 CRITICAL FIX: Prioritize AI prediction over risk score when no votes exist
    if (totalVotes == 0) {
      final predictedLabel = report['predicted_label'] as String?;

      // 🎯 Use the AI label directly for initial color
      switch (predictedLabel) {
        case 'dangerous':
          return Colors.red[800]!; // Strong red for dangerous
        case 'suspicious':
          return Colors.orange[800]!; // Strong orange for suspicious
        case 'fake':
          return Colors.purple[700]!; // Strong purple for fake (THIS WAS MISSING)
        case 'normal':
          return Colors.green[800]!; // Strong green for normal
        default:
        // Only fall back to risk score if no label exists (shouldn't happen)
          double riskScore;
          final dynamic riskScoreValue = report['risk_score'];
          if (riskScoreValue is int) {
            riskScore = riskScoreValue.toDouble();
          } else if (riskScoreValue is double) {
            riskScore = riskScoreValue;
          } else {
            riskScore = 0.0;
          }

          // Risk-based fallback (kept for safety but rarely used)
          if (riskScore > 70) return Colors.red[900]!;
          if (riskScore > 50) return Colors.red[700]!;
          if (riskScore > 30) return Colors.orange[700]!;
          return Colors.grey[800]!; // Neutral gray for truly unknown
      }
    }

    // 🌟 GRADUAL COLOR SYSTEM (Based on community votes)
    // This section remains unchanged - it's your solid voting logic

    // 1️⃣ With just 1 vote, show very light color (community is just starting)
    if (totalVotes < 2) {
      if (dangerousVotes == 1) return Colors.red[300]!; // Very light red
      if (suspiciousVotes == 1) return Colors.orange[300]!; // Very light orange
      if (fakeVotes == 1) return Colors.purple[300]!; // Very light purple
      if (normalVotes == 1) return Colors.green[300]!; // Very light green
      return Colors.grey[700]!;
    }

    // 2️⃣ FAKE consensus (highest priority - misinformation is critical)
    if (fakeVotes >= 3) {
      final fakePercent = (fakeVotes / totalVotes) * 100;
      if (fakePercent >= 70) return Colors.purple[900]!; // Strong fake consensus
      if (fakePercent >= 50) return Colors.purple[700]!; // Clear fake trend
      return Colors.purple[500]!; // Multiple fake votes
    }

    // 3️⃣ DANGEROUS consensus (second highest priority - safety first)
    if (dangerousVotes >= 3) {
      final dangerPercent = (dangerousVotes / totalVotes) * 100;
      if (dangerPercent >= 80) return Colors.red[900]!; // Very strong danger
      if (dangerPercent >= 60) return Colors.red[700]!; // Strong danger
      return Colors.red[500]!; // Moderate danger
    }

    // 4️⃣ Handle 2 dangerous votes (emerging consensus)
    if (dangerousVotes == 2) {
      if (totalVotes <= 4) return Colors.orange[700]!; // Strong emerging danger
      return Colors.orange[500]!; // Moderate emerging danger
    }

    // 5️⃣ Handle 1 dangerous vote (potential concern)
    if (dangerousVotes == 1) {
      if (totalVotes <= 3) return Colors.yellow[700]!; // Highlight in small pool
      return Colors.yellow[500]!; // Subtle indicator in large pool
    }

    // 6️⃣ SUSPICIOUS consensus
    if (suspiciousVotes >= 3) {
      final suspiciousPercent = (suspiciousVotes / totalVotes) * 100;
      if (suspiciousPercent >= 70) return Colors.orange[900]!; // Strong suspicious
      return Colors.orange[700]!; // Clear suspicious
    }

    // 7️⃣ Handle 2 suspicious votes
    if (suspiciousVotes == 2) return Colors.amber[700]!; // Amber for emerging suspicion

    // 8️⃣ Handle 1 suspicious vote
    if (suspiciousVotes == 1) return Colors.amber[300]!; // Light amber

    // 9️⃣ NORMAL consensus
    if (normalVotes >= 3) {
      final normalPercent = (normalVotes / totalVotes) * 100;
      if (normalPercent >= 80) return Colors.green[900]!; // Very normal
      if (normalPercent >= 60) return Colors.green[700]!; // Normal
      return Colors.green[500]!; // Somewhat normal
    }

    // 🔟 Handle 2 normal votes
    if (normalVotes == 2) return Colors.lightGreen[700]!; // Light green

    // 1️⃣1️⃣ Handle 1 normal vote
    if (normalVotes == 1) return Colors.lightGreen[300]!; // Very light green

    // 1️⃣2️⃣ Mixed votes with no clear winner
    final maxVotes = [dangerousVotes, suspiciousVotes, fakeVotes, normalVotes].reduce((a, b) => a > b ? a : b);
    final voteTypesWithVotes = [
      dangerousVotes > 0,
      suspiciousVotes > 0,
      fakeVotes > 0,
      normalVotes > 0
    ].where((hasVotes) => hasVotes).length;

    if (voteTypesWithVotes >= 2) {
      // Community is divided
      if (dangerousVotes > 0 && dangerousVotes == maxVotes) {
        return Colors.deepOrange[700]!; // Dangerous leading
      }
      if (suspiciousVotes > 0 && suspiciousVotes == maxVotes) {
        return Colors.amber[800]!; // Suspicious leading
      }
      return Colors.blueGrey[700]!; // Truly mixed
    }

    // 1️⃣3️⃣ DEFAULT: Neutral color when truly undetermined
    return Colors.grey[700]!;
  }

  List<double>? _parseCoordinates(String? location) {
    if (location == null || !location.startsWith('POINT(')) return null;
    final coordsStr = location.replaceAll('POINT(', '').replaceAll(')', '').trim();
    final coords = coordsStr.split(' ').map((s) => double.tryParse(s)).whereType<double>().toList();
    return coords.length == 2 ? coords : null;
  }

  String _getLocationText(Map<String, dynamic> report) {
    // Check if it's online crime
    final crimeType = (report['crime_type'] as String? ?? '').toLowerCase();
    if (!_isOfflineCrime(crimeType)) {
      return 'Online Incident';
    }

    // Get coordinates from location field
    final coords = _parseCoordinates(report['location'] as String?);
    if (coords != null) {
      return 'Area: ${coords[1].toStringAsFixed(5)}, ${coords[0].toStringAsFixed(5)}';
    }

    // Fallback to city field
    final city = report['city'] as String?;
    if (city != null && city.isNotEmpty) {
      return 'Area: $city';
    }

    return 'Location: Not Specified';
  }

  // UPDATED: Image preview with sensitive content blur
  Widget _buildImagePreview({
    required List<dynamic> images,
    required String reportId,
    required String crimeType,
  }) {
    if (images.isEmpty) return const SizedBox();

    final imageUrl = images[0] as String;
    final isSensitive = _isSensitiveCrime(crimeType) && !_sensitiveContentRevealed[reportId]!;

    return GestureDetector(
      onTap: () => _handleSensitiveContentTap(reportId, crimeType),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[800],
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: Colors.grey[600],
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                ),
                imageBuilder: (context, imageProvider) {
                  return isSensitive
                      ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.7),
                      BlendMode.srcOver,
                    ),
                    child: ImageFiltered(
                      imageFilter: const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      : Image(image: imageProvider, fit: BoxFit.cover);
                },
              ),
            ),
          ),

          if (isSensitive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.yellowAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SENSITIVE CONTENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        crimeType.toUpperCase(),
                        style: TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to view',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Warning badge (always shown for sensitive content after reveal)
          if (_showSensitiveWarning[reportId]! && _isSensitiveCrime(crimeType))
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.redAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'SENSITIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required int count,
    required Color color,
    required bool isSelected,
    required String reportId,
  }) {
    return MouseRegion(
      onEnter: (_) => _handleHover(reportId, true),
      onExit: (_) => _handleHover(reportId, false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(isSelected ? 0.3 : 0.1),
                    color.withOpacity(isSelected ? 0.1 : 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [],
              ),
              child: Transform.scale(
                scale: isSelected ? 1.1 : 1.0,
                child: IconButton(
                  icon: Icon(icon, color: isSelected ? color : Colors.white70, size: 24),
                  onPressed: onPressed,
                  splashRadius: 24,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                '$count',
                key: ValueKey<int>(count),
                style: TextStyle(
                  color: isSelected ? color : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleHover(String reportId, bool isHovering) {
    if (_hoverControllers[reportId] == null) return;

    setState(() {
      _isHovering[reportId] = isHovering;
    });

    if (isHovering) {
      _hoverControllers[reportId]!.forward();
    } else {
      _hoverControllers[reportId]!.reverse();
    }
  }

  Widget _buildMainTabBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildMainTabButton('OFFLINE', 0),
          _buildMainTabButton('ONLINE', 1),
        ],
      ),
    );
  }

  Widget _buildMainTabButton(String label, int index) {
    final isSelected = _selectedMainTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMainTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
              colors: index == 0
                  ? [Colors.red, Colors.redAccent]
                  : [Colors.blue, Colors.blueAccent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
                : null,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                index == 0 ? Icons.location_on : Icons.wifi,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Category chips with better overflow handling
  Widget _buildCategoryChips() {
    final categories = _selectedMainTab == 0 ? _offlineCategories : _onlineCategories;
    final selectedCategory = _selectedMainTab == 0
        ? _selectedOfflineCategory
        : _selectedOnlineCategory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Wrap(
        spacing: 8.0, // Horizontal space between chips
        runSpacing: 8.0, // Vertical space between rows
        children: List.generate(categories.length, (index) {
          final category = categories[index];
          final categoryColor = category['color'] as Color;
          final isSelected = selectedCategory == index;

          return Container(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : categoryColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      category['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (_selectedMainTab == 0) {
                    _selectedOfflineCategory = selected ? index : 0;
                  } else {
                    _selectedOnlineCategory = selected ? index : 0;
                  }
                });
              },
              selectedColor: categoryColor,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: categoryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              backgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final reportId = report['id'].toString();
    final reportText = report['description'] ?? 'No description provided';
    final crimeType = report['crime_type'] as String? ?? 'Unknown';
    final isOffline = _isOfflineCrime(crimeType.toLowerCase());
    final locationText = _getLocationText(report);
    final images = (report['images'] as List<dynamic>?) ?? [];
    final audioUrl = report['audio_url'] as String?;
    final timestamp = (report['created_at'] as String?)?.isNotEmpty == true
        ? DateTime.parse(report['created_at'])
        : DateTime.now();
    final votes = (report['votes'] as Map<String, dynamic>?) ??
        {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0};
    final userVotes = (report['user_votes'] as Map<String, dynamic>?) ?? <String, String>{};
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final userVote = currentUserId != null ? userVotes[currentUserId] as String? : null;
    final isEmergency = report['is_emergency'] as bool? ?? false;
    final cardColor = _getCardColor(report);
    final isDarkBackground = cardColor.computeLuminance() < 0.3;
    final textColor = isDarkBackground ? Colors.white : Colors.black87;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: FlipCard(
              key: _cardKeys[reportId],
              flipOnTouch: false,
              front: _buildCardFront(
                reportId: reportId,
                reportText: reportText,
                crimeType: crimeType,
                isOffline: isOffline,
                locationText: locationText,
                images: images,
                audioUrl: audioUrl,
                timestamp: timestamp,
                votes: votes,
                isEmergency: isEmergency,
                cardColor: cardColor,
                textColor: textColor,
              ),
              back: _buildCardBack(
                reportId: reportId,
                votes: votes,
                userVote: userVote,
                textColor: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront({
    required String reportId,
    required String reportText,
    required String crimeType,
    required bool isOffline,
    required String locationText,
    required List<dynamic> images,
    required String? audioUrl,
    required DateTime timestamp,
    required Map<String, dynamic> votes,
    required bool isEmergency,
    required Color cardColor,
    required Color textColor,
  }) {
    return AnimatedBuilder(
      animation: _hoverControllers[reportId]!,
      builder: (context, child) {
        final hoverValue = _hoverControllers[reportId]!.value;
        final scale = 1.0 + hoverValue * 0.05;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scale(scale),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cardColor,
                  cardColor.darken(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cardColor.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _cardKeys[reportId]?.currentState?.toggleCard(),
                  splashColor: Colors.white10,
                  highlightColor: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Crime type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOffline ? Icons.location_on : Icons.wifi,
                                size: 14,
                                color: textColor.withOpacity(0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                crimeType.toUpperCase(),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Report description
                        Text(
                          reportText,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Location and emergency status
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: textColor.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locationText,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEmergency)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'EMERGENCY',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Image preview
                        if (images.isNotEmpty)
                          Column(
                            children: [
                              _buildImagePreview(
                                images: images,
                                reportId: reportId,
                                crimeType: crimeType,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),

                        // Audio indicator
                        if (audioUrl != null)
                          Row(
                            children: [
                              Icon(Icons.audiotrack,
                                  color: textColor.withOpacity(0.8),
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Audio evidence available',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                        // Time and flip indicator
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(timestamp),
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.flip_to_front,
                                  color: textColor.withOpacity(0.6),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to vote',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBack({
    required String reportId,
    required Map<String, dynamic> votes,
    required String? userVote,
    required Color textColor,
  }) {
    return AnimatedBuilder(
      animation: _hoverControllers[reportId]!,
      builder: (context, child) {
        final hoverValue = _hoverControllers[reportId]!.value;
        final scale = 1.0 + hoverValue * 0.05;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scale(scale),
          alignment: Alignment.center,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey, Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _cardKeys[reportId]?.currentState?.toggleCard(),
                  splashColor: Colors.white10,
                  highlightColor: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'VOTE ON THIS REPORT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildVoteButton(
                              icon: Icons.local_fire_department,
                              tooltip: 'Dangerous',
                              onPressed: () => _updateVote(reportId, 'dangerous'),
                              count: votes['dangerous'] as int? ?? 0,
                              color: Colors.red,
                              isSelected: userVote == 'dangerous',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.warning_amber_rounded,
                              tooltip: 'Suspicious',
                              onPressed: () => _updateVote(reportId, 'suspicious'),
                              count: votes['suspicious'] as int? ?? 0,
                              color: Colors.orange,
                              isSelected: userVote == 'suspicious',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.check_circle_outline,
                              tooltip: 'Normal',
                              onPressed: () => _updateVote(reportId, 'normal'),
                              count: votes['normal'] as int? ?? 0,
                              color: Colors.green,
                              isSelected: userVote == 'normal',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.block,
                              tooltip: 'Fake',
                              onPressed: () => _updateVote(reportId, 'fake'),
                              count: votes['fake'] as int? ?? 0,
                              color: Colors.purple,
                              isSelected: userVote == 'fake',
                              reportId: reportId,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flip_to_back,
                              color: textColor.withOpacity(0.6),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to return',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Card(
                  color: Colors.grey[850],
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  child: const SizedBox(
                    height: 200,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final categories = _selectedMainTab == 0 ? _offlineCategories : _onlineCategories;
    final selectedCategory = _selectedMainTab == 0
        ? _selectedOfflineCategory
        : _selectedOnlineCategory;
    final categoryName = categories[selectedCategory]['name'] as String;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 20),
          const Text(
            'No reports found',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            categoryName == 'All'
                ? 'No ${_selectedMainTab == 0 ? 'offline' : 'online'} reports yet'
                : 'No reports in "$categoryName" category',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text(
                'Community Watch',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 24),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadReports();
                    });
                  },
                  tooltip: 'Refresh',
                  color: Colors.white70,
                ),
              ],
            ),
            body: Column(
              children: [
                // Main tabs (Offline/Online)
                _buildMainTabBar(),

                // Category chips
                _buildCategoryChips(),

                // Reports list
                Expanded(
                  child: Stack(
                    children: [
                      if (_isLoading) _buildShimmerLoading(),

                      if (!_isLoading && _getFilteredReports().isEmpty)
                        _buildEmptyState(),

                      if (!_isLoading && _getFilteredReports().isNotEmpty)
                        RefreshIndicator(
                          onRefresh: _loadReports,
                          color: Colors.red,
                          backgroundColor: Colors.grey[900],
                          child: AnimationLimiter(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              itemCount: _getFilteredReports().length,
                              itemBuilder: (context, index) {
                                final report = _getFilteredReports()[index];
                                return _buildReportCard(report, index);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Extension to darken/lighten colors
extension ColorExtension on Color {
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkenedHsl = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkenedHsl.toColor();
  }

  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightenedHsl = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightenedHsl.toColor();
  }
}