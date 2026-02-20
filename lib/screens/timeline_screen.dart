import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

import '../services/auth_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

// ==================== VIDEO PLAYER WIDGET ====================

class TimelineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool muted;

  const TimelineVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.muted = true,
  });

  @override
  State<TimelineVideoPlayer> createState() => _TimelineVideoPlayerState();
}

class _TimelineVideoPlayerState extends State<TimelineVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    developer.log('🎬 TimelineVideoPlayer init: ${widget.videoUrl}');

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _initializePlayer();
    });
  }

  Future<void> _initializePlayer() async {
    if (_isInitialized || _hasError) return;

    try {
      final cleanUrl = widget.videoUrl.trim();
      developer.log('   - Clean URL: $cleanUrl');

      if (cleanUrl.isEmpty) throw Exception('Empty video URL');

      developer.log('   - Creating VideoPlayerController...');

      if (cleanUrl.startsWith('/data') ||
          cleanUrl.startsWith('/storage') ||
          cleanUrl.startsWith('/mnt') ||
          File(cleanUrl).existsSync()) {

        developer.log('   - Detected LOCAL file path');
        final file = File(cleanUrl);

        if (!await file.exists()) {
          throw Exception('Local video file not found: $cleanUrl');
        }

        _videoController = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );

      } else {

        developer.log('   - Detected NETWORK URL');

        if (!cleanUrl.startsWith('http')) {
          throw Exception('Invalid URL scheme: $cleanUrl');
        }

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(cleanUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: const {
            'Accept': '*/*',
          },
        );
      }

      _videoController!.addListener(_onVideoControllerUpdate);

      developer.log('   - Initializing video...');
      await _videoController!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Video initialization timed out after 30s'),
      );

      developer.log('   - Video initialized successfully');

      await _videoController!.setVolume(widget.muted ? 0.0 : 1.0);
      await _videoController!.setLooping(true);

      developer.log('   - Creating ChewieController...');
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: true,
        showControls: true,
        showControlsOnInitialize: false,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        aspectRatio: _videoController!.value.aspectRatio,
        placeholder: widget.thumbnailUrl != null
            ? CachedNetworkImage(
          imageUrl: widget.thumbnailUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(color: Colors.black),
        )
            : Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 50),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          developer.log('   - Chewie error builder called: $errorMessage');
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Video error: $errorMessage',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _errorMessage = null;
                      });
                      _initializePlayer();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() => _isInitialized = true);
        developer.log('   - Player ready!');
      }

      if (widget.autoPlay) {
        developer.log('   - Auto-playing...');
        _videoController!.play();
      }

    } on TimeoutException catch (e) {
      developer.log('❌ Timeout error: $e');
      _setError('Loading timed out. Video may be too large or unavailable.');
    } catch (e, stackTrace) {
      developer.log('❌ Video player error: $e');
      developer.log('   - Stack trace: $stackTrace');
      _setError('Failed to load video: $e');
    }
  }

  void _onVideoControllerUpdate() {
    if (_videoController == null) return;
    final value = _videoController!.value;
    if (value.hasError && !_hasError) {
      developer.log('❌ Video controller error: ${value.errorDescription}');
      _setError('Playback error: ${value.errorDescription}');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isInitialized = false;
    });
  }

  @override
  void dispose() {
    developer.log('🗑️ Disposing video player...');
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Colors.red[400], size: 40),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage ?? 'Video unavailable',
                  style: TextStyle(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
              const SizedBox(height: 12),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}

// ==================== MAIN TIMELINE SCREEN ====================

class _TimelineScreenState extends State<TimelineScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Main tabs: 0 = Offline, 1 = Online
  int _selectedMainTab = 0;

  // Area tabs: 0 = All, 1 = My Area, 2 = Search Area
  late TabController _areaTabController;
  int _selectedAreaTab = 0;

  // Category selection
  int _selectedOfflineCategory = 0;
  int _selectedOnlineCategory = 0;

  // Crime categories from Code 1
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

  // Data
  List<Map<String, dynamic>> _allReports = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortMode = 'priority'; // 'priority' or 'time'

  // Area search
  List<Map<String, dynamic>> _allAreas = [];
  List<Map<String, dynamic>> _filteredAreas = [];
  String _searchQuery = '';
  String? _selectedSearchArea;
  final TextEditingController _areaSearchController = TextEditingController();
  final FocusNode _areaSearchFocusNode = FocusNode();
  bool _showAreaDropdown = false;

  // Controllers & Keys
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<FlipCardState>> _cardKeys = {};
  final Map<String, AnimationController> _hoverControllers = {};
  final Map<String, bool> _isHovering = {};

  // Sensitive content tracking
  final Map<String, bool> _sensitiveContentRevealed = {};
  final Map<String, bool> _showSensitiveWarning = {};

  // Download tracking
  final Map<String, bool> _downloadingFiles = {};

  StreamSubscription? _reportsSubscription;

  @override
  void initState() {
    super.initState();
    developer.log('📱 TimelineScreen initState');

    _areaTabController = TabController(length: 3, vsync: this);
    _areaTabController.addListener(() {
      setState(() {
        _selectedAreaTab = _areaTabController.index;
        developer.log('🏠 Area tab changed to: $_selectedAreaTab');
        if (_selectedAreaTab != 2) {
          _showAreaDropdown = false;
          _areaSearchFocusNode.unfocus();
        }
      });
    });

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

    _loadAreas();
    _loadReports();
    _startRealtimeSubscription();
    _animationController.forward();
  }

  @override
  void dispose() {
    developer.log('🗑️ TimelineScreen dispose');
    _animationController.dispose();
    _scrollController.dispose();
    _reportsSubscription?.cancel();
    _areaTabController.dispose();
    _areaSearchController.dispose();
    _areaSearchFocusNode.dispose();
    for (var controller in _hoverControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==================== AREA SEARCH METHODS ====================

  Future<void> _loadAreas() async {
    try {
      developer.log('📍 Loading areas from ason table...');
      final response = await _supabase
          .from('ason')
          .select('area_name, division, area_name_en, division_en')
          .order('area_name');
      setState(() {
        _allAreas = List<Map<String, dynamic>>.from(response);
      });
      developer.log('✅ Loaded ${_allAreas.length} areas');
    } catch (e) {
      developer.log('❌ Error loading areas: $e');
    }
  }

  void _filterAreas(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAreas = _allAreas;
      } else {
        final searchLower = query.toLowerCase();
        _filteredAreas = _allAreas.where((area) {
          final areaName = area['area_name'].toString().toLowerCase();
          final division = area['division'].toString().toLowerCase();
          final areaNameEn = (area['area_name_en'] ?? '').toString().toLowerCase();
          final divisionEn = (area['division_en'] ?? '').toString().toLowerCase();

          return areaName.contains(searchLower) ||
              division.contains(searchLower) ||
              areaNameEn.contains(searchLower) ||
              divisionEn.contains(searchLower) ||
              _matchBanglish(areaNameEn, searchLower);
        }).toList();
      }
      _showAreaDropdown = true;
    });
  }

  bool _matchBanglish(String englishName, String banglishQuery) {
    final banglishMap = {
      'panchagar': ['panchagar', 'panchagarh', 'ponchogor', 'panchogor'],
      'rangpur': ['rangpur', 'rongpur', 'rangpur'],
      'dhaka': ['dhaka', 'daka', 'dhaka'],
      'chittagong': ['chittagong', 'chattagram', 'chittagong', 'ctg'],
      'sylhet': ['sylhet', 'silet', 'sylhet'],
      'khulna': ['khulna', 'khulna'],
      'barisal': ['barisal', 'barishal', 'borishal'],
      'rajshahi': ['rajshahi', 'rajshahi', 'rajshahi'],
      'mymensingh': ['mymensingh', 'mymensingh', 'moymonsingho'],
      'comilla': ['comilla', 'cumilla', 'comilla'],
    };

    for (final entry in banglishMap.entries) {
      if (englishName.toLowerCase().contains(entry.key)) {
        if (entry.value.any((variant) => banglishQuery.contains(variant))) {
          return true;
        }
      }
    }
    return false;
  }

  void _selectSearchArea(Map<String, dynamic> area) {
    setState(() {
      _selectedSearchArea = area['area_name'];
      _areaSearchController.text = area['area_name'];
      _showAreaDropdown = false;
      _searchQuery = '';
    });
    _areaSearchFocusNode.unfocus();
    developer.log('📍 Selected search area: ${_selectedSearchArea}');
  }

  // ==================== REALTIME & DATA METHODS ====================

  void _startRealtimeSubscription() {
    developer.log('📡 Starting realtime subscription on reports table...');
    try {
      _reportsSubscription = _supabase
          .from('reports')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> reports) {
          developer.log('📥 Realtime update received: ${reports.length} reports');
          if (mounted) _processAndUpdateReports(reports);
        },
        onError: (error) {
          developer.log('❌ Realtime subscription error: $error');
          setState(() => _errorMessage = 'Realtime connection failed: $error');
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _startRealtimeSubscription();
          });
        },
      );
      developer.log('✅ Realtime subscription started');
    } catch (e) {
      developer.log('❌ Failed to start realtime subscription: $e');
    }
  }

  // Priority score calculation from Code 1
  double _calculatePriorityScore(Map<String, dynamic> report) {
    final now = DateTime.now();
    final createdAt = (report['created_at'] as String?)?.isNotEmpty == true
        ? DateTime.parse(report['created_at'])
        : now;
    final age = now.difference(createdAt);

    final votes = (report['votes'] as Map<String, dynamic>?) ??
        {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0};
    final riskScore = (report['risk_score'] as num?)?.toDouble() ?? 0.0;
    final predictedLabel = report['predicted_label'] as String?;
    final predictedConfidence = (report['predicted_confidence'] as num?)?.toDouble() ?? 0.0;
    final isEmergency = report['is_emergency'] as bool? ?? false;
    final isSensitive = report['is_sensitive'] as bool? ?? false;
    final imageVerified = report['image_verified'] as bool? ?? false;

    // 1. Base risk score (50% weight)
    double baseScore = riskScore * 0.5;

    // 2. Vote score (30% weight)
    int dangerous = votes['dangerous'] as int? ?? 0;
    int suspicious = votes['suspicious'] as int? ?? 0;
    int normal = votes['normal'] as int? ?? 0;
    int fake = votes['fake'] as int? ?? 0;
    int totalVotes = dangerous + suspicious + normal + fake;

    double voteScore = 0;
    if (totalVotes > 0) {
      double voteValue = ((dangerous * 1.0) + (suspicious * 0.5) + (normal * 0.2) + (fake * -1.0)) / totalVotes;
      voteScore = (voteValue * 50 + 50) * 0.3;
    }

    // 3. Verification & AI bonuses (20% weight)
    double bonusScore = 0;
    if (imageVerified) bonusScore += 10;
    if (predictedConfidence > 0.8) bonusScore += 5;
    if (isSensitive) bonusScore += 5;
    if (predictedLabel == 'dangerous') bonusScore += 10;
    bonusScore *= 0.2;

    // 4. Time multiplier
    double timeMultiplier;
    if (age.inHours < 6) {
      timeMultiplier = 1.0;
    } else if (age.inHours < 12) {
      timeMultiplier = 0.8;
    } else if (age.inHours < 24) {
      timeMultiplier = 0.5;
    } else if (age.inHours < 36 && (riskScore > 60 || isEmergency || isSensitive || predictedLabel == 'dangerous')) {
      timeMultiplier = 0.3;
    } else {
      timeMultiplier = 0.1;
    }

    // Emergency boost
    if (isEmergency && age.inHours < 12) {
      timeMultiplier = 1.0;
    }

    final finalScore = (baseScore + voteScore + bonusScore) * timeMultiplier;

    developer.log('''
📊 PRIORITY SCORE for report ${report['id']}:
   Risk: $riskScore | Votes: D:$dangerous S:$suspicious N:$normal F:$fake
   AI: $predictedLabel (${predictedConfidence?.toStringAsFixed(2)})
   Emergency: $isEmergency | Sensitive: $isSensitive | Verified: $imageVerified
   Age: ${age.inHours}h | Time Multiplier: $timeMultiplier
   FINAL SCORE: ${finalScore.toStringAsFixed(2)}
''');

    return finalScore;
  }

  void _processAndUpdateReports(List<Map<String, dynamic>> reports) {
    developer.log('🔄 Processing ${reports.length} reports...');

    // Calculate priority scores
    final reportsWithScores = reports.map((report) {
      final score = _calculatePriorityScore(report);
      return {...report, '_priorityScore': score};
    }).toList();

    // Sort by priority score descending
    reportsWithScores.sort((a, b) =>
        (b['_priorityScore'] as double).compareTo(a['_priorityScore'] as double));

    setState(() {
      _allReports = reportsWithScores;
      _isLoading = false;
      _errorMessage = null;

      // Initialize card keys and controllers
      for (var report in _allReports) {
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
        if (!_sensitiveContentRevealed.containsKey(id)) {
          _sensitiveContentRevealed[id] = false;
        }
        if (!_showSensitiveWarning.containsKey(id)) {
          _showSensitiveWarning[id] = false;
        }
      }
    });

    developer.log('✅ Processed ${reportsWithScores.length} reports');
  }

  Future<void> _loadReports() async {
    developer.log('📥 Loading reports from database...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('reports')
          .select('*')
          .limit(100);

      developer.log('✅ Loaded ${response.length} reports from DB');

      if (!mounted) return;
      _processAndUpdateReports(List<Map<String, dynamic>>.from(response));
    } catch (e, stackTrace) {
      developer.log('❌ Error loading reports: $e');
      developer.log('   Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load reports: $e';
        });
      }
    }
  }

  // ==================== FILTERING ====================

  bool _isOfflineCrime(String crimeType) {
    final onlineCrimes = ['hacking', 'harassment', 'fraud', 'scams', 'phishing',
      'cyberbullying', 'identity theft', 'online'];

    final lowerType = crimeType.toLowerCase();
    for (var onlineCrime in onlineCrimes) {
      if (lowerType.contains(onlineCrime)) {
        return false;
      }
    }
    return true;
  }

  bool _isSensitiveCrime(String crimeType) {
    final lowerType = crimeType.toLowerCase();
    final sensitiveKeywords = ['killing', 'murder', 'homicide', 'dead', 'body', 'corpse'];
    return sensitiveKeywords.any((keyword) => lowerType.contains(keyword));
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    developer.log('🔍 Filtering reports: MainTab=$_selectedMainTab, AreaTab=$_selectedAreaTab, Sort=$_sortMode');

    List<Map<String, dynamic>> filtered = _allReports.where((report) {
      // Filter by Online/Offline main tab
      final crimeType = (report['crime_type'] as String? ?? 'unknown').toLowerCase();
      final isOffline = _isOfflineCrime(crimeType);

      if (_selectedMainTab == 0 && !isOffline) return false;
      if (_selectedMainTab == 1 && isOffline) return false;

      // Filter by category
      if (_selectedMainTab == 0) {
        if (_selectedOfflineCategory == 0) return true;
        final selectedCategory = _offlineCategories[_selectedOfflineCategory];
        final categoryName = selectedCategory['name'].toString().toLowerCase();
        return crimeType.contains(categoryName);
      } else {
        if (_selectedOnlineCategory == 0) return true;
        final selectedCategory = _onlineCategories[_selectedOnlineCategory];
        final categoryName = selectedCategory['name'].toString().toLowerCase();
        return crimeType.contains(categoryName);
      }
    }).toList();

    // Filter by area tab
    if (_selectedAreaTab == 1) {
      // My Area
      final myArea = _authService.currentUser?.area;
      developer.log('🏠 Filtering by My Area: $myArea');
      if (myArea != null) {
        filtered = filtered.where((r) {
          final reportArea = r['area'] as String?;
          final reportCity = r['city'] as String?;
          return reportArea == myArea || reportCity == myArea;
        }).toList();
      }
    } else if (_selectedAreaTab == 2 && _selectedSearchArea != null) {
      // Search Area
      developer.log('🔍 Filtering by Search Area: $_selectedSearchArea');
      filtered = filtered.where((r) {
        final reportArea = r['area'] as String?;
        final reportCity = r['city'] as String?;
        return reportArea == _selectedSearchArea || reportCity == _selectedSearchArea;
      }).toList();
    }

    // Apply sorting
    if (_sortMode == 'time') {
      filtered.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] as String);
        final bTime = DateTime.parse(b['created_at'] as String);
        return bTime.compareTo(aTime);
      });
      developer.log('📅 Sorted by TIME');
    } else {
      developer.log('📊 Sorted by PRIORITY (pre-sorted from _processAndUpdateReports)');
    }

    developer.log('✅ Filtered result: ${filtered.length} reports');
    return filtered;
  }

  // ==================== VOTING ====================

  Future<void> _updateVote(String reportId, String voteType) async {
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      _showSnackBar('Please login to vote', Colors.orange);
      return;
    }

    developer.log('🗳️ Voting: $voteType on report $reportId by user $userId');

    int currentReportIndex = -1;
    try {
      currentReportIndex = _allReports.indexWhere((report) => report['id'].toString() == reportId);
      if (currentReportIndex == -1) return;

      final currentReport = Map<String, dynamic>.from(_allReports[currentReportIndex]);
      final currentVotes = Map<String, dynamic>.from(
          (currentReport['votes'] as Map<String, dynamic>?) ??
              {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0}
      );
      final currentUserVotes = Map<String, String>.from(
          (currentReport['user_votes'] as Map<String, dynamic>? ?? {})
              .map((key, value) => MapEntry(key, value.toString())));

      final previousVote = currentUserVotes[userId];

      if (previousVote == voteType) {
        // Remove vote
        developer.log('   Removing previous vote: $voteType');
        setState(() {
          currentVotes[voteType] = (currentVotes[voteType] as int? ?? 0) - 1;
          currentUserVotes.remove(userId);
          _allReports[currentReportIndex] = {
            ...currentReport,
            'votes': currentVotes,
            'user_votes': currentUserVotes,
          };
        });

        await _supabase.from('reports').update({
          'votes': currentVotes,
          'user_votes': currentUserVotes,
        }).eq('id', reportId);

        developer.log('✅ Vote removed');
        return;
      }

      if (previousVote != null) {
        currentVotes[previousVote] = (currentVotes[previousVote] as int? ?? 0) - 1;
      }

      currentVotes[voteType] = (currentVotes[voteType] as int? ?? 0) + 1;
      currentUserVotes[userId] = voteType;

      setState(() {
        _allReports[currentReportIndex] = {
          ...currentReport,
          'votes': currentVotes,
          'user_votes': currentUserVotes,
        };
      });

      developer.log('   New vote counts: D:${currentVotes['dangerous']} S:${currentVotes['suspicious']} N:${currentVotes['normal']} F:${currentVotes['fake']}');

      await _supabase.from('reports').update({
        'votes': currentVotes,
        'user_votes': currentUserVotes,
      }).eq('id', reportId);

      // Recalculate priority scores after vote
      _processAndUpdateReports(_allReports);

      developer.log('✅ Vote updated and priorities recalculated');

    } catch (e) {
      developer.log('❌ Error updating vote: $e');
      _showSnackBar('Failed to update vote. Please try again.', Colors.red);
    }
  }

  // ==================== COLOR SYSTEM ====================

  Color _getCardColor(Map<String, dynamic> report) {
    final votes = (report['votes'] as Map<String, dynamic>?) ??
        {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0};

    final dangerousVotes = votes['dangerous'] as int? ?? 0;
    final suspiciousVotes = votes['suspicious'] as int? ?? 0;
    final fakeVotes = votes['fake'] as int? ?? 0;
    final normalVotes = votes['normal'] as int? ?? 0;

    final totalVotes = dangerousVotes + suspiciousVotes + fakeVotes + normalVotes;

    // AI prediction priority when no votes
    if (totalVotes == 0) {
      final predictedLabel = report['predicted_label'] as String?;
      switch (predictedLabel) {
        case 'dangerous':
          return Colors.red[800]!;
        case 'suspicious':
          return Colors.orange[800]!;
        case 'fake':
          return Colors.purple[700]!;
        case 'normal':
          return Colors.green[800]!;
        default:
          double riskScore = (report['risk_score'] as num?)?.toDouble() ?? 0.0;
          if (riskScore > 70) return Colors.red[900]!;
          if (riskScore > 50) return Colors.red[700]!;
          if (riskScore > 30) return Colors.orange[700]!;
          return Colors.grey[800]!;
      }
    }

    // Gradual color system
    if (totalVotes < 2) {
      if (dangerousVotes == 1) return Colors.red[300]!;
      if (suspiciousVotes == 1) return Colors.orange[300]!;
      if (fakeVotes == 1) return Colors.purple[300]!;
      if (normalVotes == 1) return Colors.green[300]!;
      return Colors.grey[700]!;
    }

    // Fake consensus
    if (fakeVotes >= 3) {
      final fakePercent = (fakeVotes / totalVotes) * 100;
      if (fakePercent >= 70) return Colors.purple[900]!;
      if (fakePercent >= 50) return Colors.purple[700]!;
      return Colors.purple[500]!;
    }

    // Dangerous consensus
    if (dangerousVotes >= 3) {
      final dangerPercent = (dangerousVotes / totalVotes) * 100;
      if (dangerPercent >= 80) return Colors.red[900]!;
      if (dangerPercent >= 60) return Colors.red[700]!;
      return Colors.red[500]!;
    }

    if (dangerousVotes == 2) {
      if (totalVotes <= 4) return Colors.orange[700]!;
      return Colors.orange[500]!;
    }

    if (dangerousVotes == 1) {
      if (totalVotes <= 3) return Colors.yellow[700]!;
      return Colors.yellow[500]!;
    }

    // Suspicious consensus
    if (suspiciousVotes >= 3) {
      final suspiciousPercent = (suspiciousVotes / totalVotes) * 100;
      if (suspiciousPercent >= 70) return Colors.orange[900]!;
      return Colors.orange[700]!;
    }

    if (suspiciousVotes == 2) return Colors.amber[700]!;
    if (suspiciousVotes == 1) return Colors.amber[300]!;

    // Normal consensus
    if (normalVotes >= 3) {
      final normalPercent = (normalVotes / totalVotes) * 100;
      if (normalPercent >= 80) return Colors.green[900]!;
      if (normalPercent >= 60) return Colors.green[700]!;
      return Colors.green[500]!;
    }

    if (normalVotes == 2) return Colors.lightGreen[700]!;
    if (normalVotes == 1) return Colors.lightGreen[300]!;

    // Mixed votes
    final maxVotes = [dangerousVotes, suspiciousVotes, fakeVotes, normalVotes].reduce((a, b) => a > b ? a : b);
    final voteTypesWithVotes = [
      dangerousVotes > 0,
      suspiciousVotes > 0,
      fakeVotes > 0,
      normalVotes > 0
    ].where((hasVotes) => hasVotes).length;

    if (voteTypesWithVotes >= 2) {
      if (dangerousVotes > 0 && dangerousVotes == maxVotes) {
        return Colors.deepOrange[700]!;
      }
      if (suspiciousVotes > 0 && suspiciousVotes == maxVotes) {
        return Colors.amber[800]!;
      }
      return Colors.blueGrey[700]!;
    }

    return Colors.grey[700]!;
  }

  // ==================== SENSITIVE CONTENT ====================

  void _handleSensitiveContentTap(String reportId, String crimeType) {
    final isSensitive = _isSensitiveCrime(crimeType);

    if (isSensitive && !_sensitiveContentRevealed[reportId]!) {
      _showSensitiveContentDialog(reportId, crimeType);
    }
  }

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
                      developer.log('👁️ Sensitive content revealed for report $reportId');
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

  // ==================== DOWNLOAD ====================

  Future<void> _downloadFile(String url, String filename, BuildContext context) async {
    if (_downloadingFiles[url] == true) return;

    setState(() {
      _downloadingFiles[url] = true;
    });

    developer.log('⬇️ Starting download: $filename');

    try {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        var photoStatus = await Permission.photos.request();
        if (!photoStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          setState(() => _downloadingFiles[url] = false);
          return;
        }
      }

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        saveDir = await getApplicationDocumentsDirectory();
      } else {
        saveDir = await getDownloadsDirectory();
      }

      if (saveDir == null) {
        throw Exception('Could not determine save directory');
      }

      final savePath = '${saveDir.path}/$filename';
      developer.log('   Saving to: $savePath');

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            developer.log('   Progress: $progress%');
          }
        },
      );

      developer.log('✅ Download complete: $filename');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $filename'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                OpenFilex.open(savePath);
              },
            ),
          ),
        );
      }

    } catch (e) {
      developer.log('❌ Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _downloadingFiles[url] = false;
      });
    }
  }

  // ==================== UTILITY ====================

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  List<double>? _parseCoordinates(String? location) {
    if (location == null || !location.startsWith('POINT(')) return null;
    final coordsStr = location.replaceAll('POINT(', '').replaceAll(')', '').trim();
    final coords = coordsStr.split(' ').map((s) => double.tryParse(s)).whereType<double>().toList();
    return coords.length == 2 ? coords : null;
  }

  String _getLocationText(Map<String, dynamic> report) {
    final crimeType = (report['crime_type'] as String? ?? '').toLowerCase();
    if (!_isOfflineCrime(crimeType)) {
      return 'Online Incident';
    }

    final coords = _parseCoordinates(report['location'] as String?);
    if (coords != null) {
      return 'Area: ${coords[1].toStringAsFixed(5)}, ${coords[0].toStringAsFixed(5)}';
    }

    final city = report['city'] as String?;
    final area = report['area'] as String?;
    if (area != null && area.isNotEmpty) {
      return 'Area: $area';
    }
    if (city != null && city.isNotEmpty) {
      return 'Area: $city';
    }

    return 'Location: Not Specified';
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

  // ==================== UI BUILDERS ====================

  Widget _buildMainTabBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildMainTabButton('OFFLINE', 0, Icons.location_on, Colors.red),
          _buildMainTabButton('ONLINE', 1, Icons.wifi, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildMainTabButton(String label, int index, IconData icon, Color activeColor) {
    final isSelected = _selectedMainTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMainTab = index;
            developer.log('🔄 Switched to ${label.toLowerCase()} crimes');
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: TabBar(
        controller: _areaTabController,
        indicatorColor: Colors.red,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: const [
          Tab(text: 'ALL REPORTS'),
          Tab(text: 'MY AREA'),
          Tab(text: 'SEARCH AREA'),
        ],
      ),
    );
  }

  Widget _buildAreaSearch() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDropdownHeight = constraints.maxHeight > 300 ? 200.0 : constraints.maxHeight * 0.5;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              bottom: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showAreaDropdown ? Colors.blueAccent : Colors.white24,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _areaSearchController,
                  focusNode: _areaSearchFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search area...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _areaSearchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _areaSearchController.clear();
                        setState(() {
                          _selectedSearchArea = null;
                          _showAreaDropdown = false;
                        });
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _filterAreas,
                  onTap: () => setState(() => _showAreaDropdown = true),
                ),
              ),
              if (_showAreaDropdown && _filteredAreas.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxDropdownHeight),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A38),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filteredAreas.length > 50 ? 50 : _filteredAreas.length,
                      itemBuilder: (context, index) {
                        final area = _filteredAreas[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          title: Text(
                            area['area_name_en'] != null
                                ? '${area['area_name']} (${area['area_name_en']})'
                                : area['area_name'],
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            area['division_en'] != null
                                ? '${area['division']} (${area['division_en']})'
                                : area['division'],
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                          onTap: () => _selectSearchArea(area),
                        );
                      },
                    ),
                  ),
                ),
              if (_showAreaDropdown && _filteredAreas.isEmpty && _searchQuery.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No areas found',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    final categories = _selectedMainTab == 0 ? _offlineCategories : _onlineCategories;
    final selectedCategory = _selectedMainTab == 0 ? _selectedOfflineCategory : _selectedOnlineCategory;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryColor = category['color'] as Color;
          final isSelected = selectedCategory == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : categoryColor),
                  const SizedBox(width: 4),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
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
                  developer.log('🏷️ Category selected: ${category['name']}');
                });
              },
              selectedColor: categoryColor,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? categoryColor : categoryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              backgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 10),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortToggle() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sort:',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                _buildSortChip('Priority', 'priority', Icons.trending_up, Colors.redAccent),
                const SizedBox(width: 8),
                _buildSortChip('Time', 'time', Icons.access_time, Colors.blueAccent),
              ],
            ),
          ),
          Text(
            '${_getFilteredReports().length} reports',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String mode, IconData icon, Color activeColor) {
    final isSelected = _sortMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortMode = mode;
          developer.log('📊 Sort mode changed to: $mode');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? activeColor : Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey[500],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey[600],
                      size: 48,
                    ),
                  ),
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
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    : Image(
                  image: imageProvider,
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              },
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

  Widget _buildImageGallery(List<dynamic> images, String reportId, String crimeType) {
    return Column(
      children: images.asMap().entries.map((entry) {
        final imageUrl = entry.value as String;
        final isDownloading = _downloadingFiles[imageUrl] ?? false;
        final isLocalFile = imageUrl.startsWith('/data') ||
            imageUrl.startsWith('/storage') ||
            File(imageUrl).existsSync();

        return GestureDetector(
          onTap: () => _showFullScreenImage(imageUrl),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[900],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                isLocalFile
                    ? Image.file(
                  File(imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, color: Colors.red),
                  ),
                )
                    : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: isDownloading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.download, color: Colors.white, size: 20),
                      onPressed: isDownloading
                          ? null
                          : () {
                        final ext = imageUrl.split('.').last.split('?').first;
                        final filename = 'report_img_${DateTime.now().millisecondsSinceEpoch}.$ext';
                        _downloadFile(imageUrl, filename, context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
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
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
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
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : [],
              ),
              child: Transform.scale(
                scale: isSelected ? 1.1 : 1.0,
                child: IconButton(
                  icon: Icon(icon, color: isSelected ? color : Colors.white70, size: 20),
                  onPressed: onPressed,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
    final videos = (report['videos'] as List<dynamic>?) ?? [];
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
    final priorityScore = report['_priorityScore'] as double? ?? 0.0;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 30.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                videos: videos,
                audioUrl: audioUrl,
                timestamp: timestamp,
                votes: votes,
                isEmergency: isEmergency,
                cardColor: cardColor,
                textColor: textColor,
                priorityScore: priorityScore,
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
    required List<dynamic> videos,
    required String? audioUrl,
    required DateTime timestamp,
    required Map<String, dynamic> votes,
    required bool isEmergency,
    required Color cardColor,
    required Color textColor,
    required double priorityScore,
  }) {
    return AnimatedBuilder(
      animation: _hoverControllers[reportId]!,
      builder: (context, child) {
        final hoverValue = _hoverControllers[reportId]!.value;
        final scale = 1.0 + hoverValue * 0.02;

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
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: cardColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _cardKeys[reportId]?.currentState?.toggleCard(),
                  splashColor: Colors.white10,
                  highlightColor: Colors.white12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOffline ? Icons.location_on : Icons.wifi,
                                    size: 12,
                                    color: textColor.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    crimeType.toUpperCase(),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (isEmergency)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning, size: 10, color: Colors.redAccent),
                                    const SizedBox(width: 2),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (priorityScore > 30) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priorityScore > 50
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  priorityScore.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: priorityScore > 50 ? Colors.redAccent : Colors.orangeAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          reportText,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Location
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationText,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Images with sensitive content handling
                      if (images.isNotEmpty)
                        _buildImagePreview(
                          images: images,
                          reportId: reportId,
                          crimeType: crimeType,
                        ),

                      // Videos
                      if (videos.isNotEmpty)
                        ...videos.asMap().entries.map((entry) {
                          final videoUrl = entry.value as String;
                          final isDownloading = _downloadingFiles[videoUrl] ?? false;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: TimelineVideoPlayer(
                                    videoUrl: videoUrl,
                                    autoPlay: false,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: isDownloading
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : const Icon(Icons.download, color: Colors.white, size: 20),
                                      onPressed: isDownloading
                                          ? null
                                          : () {
                                        final ext = videoUrl.split('.').last.split('?').first;
                                        final filename = 'report_video_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                        _downloadFile(videoUrl, filename, context);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      // Audio indicator
                      if (audioUrl != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              Icon(Icons.audiotrack,
                                  color: textColor.withOpacity(0.7),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Audio attached',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(timestamp.toIso8601String()),
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.flip,
                                  color: textColor.withOpacity(0.5),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vote',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
        final scale = 1.0 + hoverValue * 0.02;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scale(scale),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.grey, Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _cardKeys[reportId]?.currentState?.toggleCard(),
                  splashColor: Colors.white10,
                  highlightColor: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'VOTE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flip,
                              color: textColor.withOpacity(0.5),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 10,
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
        padding: const EdgeInsets.all(12),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              height: 300,
              width: double.infinity,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final categories = _selectedMainTab == 0 ? _offlineCategories : _onlineCategories;
    final selectedCategory = _selectedMainTab == 0 ? _selectedOfflineCategory : _selectedOnlineCategory;
    final categoryName = categories[selectedCategory]['name'] as String;

    String areaMessage = '';
    if (_selectedAreaTab == 1) {
      areaMessage = ' in your area';
    } else if (_selectedAreaTab == 2) {
      areaMessage = ' in ${_selectedSearchArea ?? 'selected area'}';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          const Text(
            'No reports found',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            categoryName == 'All'
                ? 'No ${_selectedMainTab == 0 ? 'offline' : 'online'} reports$areaMessage yet'
                : 'No "$categoryName" reports$areaMessage',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            'Error loading reports',
            style: TextStyle(color: Colors.red[300], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    super.build(context);
    developer.log('🏗️ TimelineScreen build called - MainTab: $_selectedMainTab, AreaTab: $_selectedAreaTab');

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              toolbarHeight: 30,
              title: const Text(
                '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red[900]!,
                      Colors.red[800]!,
                      Colors.black,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    developer.log('🔄 Manual refresh triggered');
                    setState(() {
                      _isLoading = true;
                    });
                    _loadReports();
                  },
                  tooltip: 'Refresh',
                  color: Colors.white70,
                ),
              ],
            ),
            body: GestureDetector(
              onTap: () {
                if (_showAreaDropdown) {
                  setState(() => _showAreaDropdown = false);
                  _areaSearchFocusNode.unfocus();
                }
              },
              child: Column(
                children: [
                  // Main tabs: Offline/Online
                  _buildMainTabBar(),

                  // Area tabs: All/My Area/Search Area
                  _buildAreaTabBar(),

                  // Area search (only on Search Area tab)
                  if (_selectedAreaTab == 2) _buildAreaSearch(),

                  // Category chips
                  _buildCategoryChips(),

                  // Sort toggle
                  _buildSortToggle(),

                  // Reports list
                  Expanded(
                    child: Stack(
                      children: [
                        if (_isLoading) _buildShimmerLoading(),

                        if (!_isLoading && _getFilteredReports().isEmpty && _errorMessage == null)
                          _buildEmptyState(),

                        if (!_isLoading && _errorMessage != null && _allReports.isEmpty)
                          _buildErrorState(),

                        if (!_isLoading && _getFilteredReports().isNotEmpty)
                          RefreshIndicator(
                            onRefresh: () async {
                              developer.log('🔄 Pull-to-refresh triggered');
                              await _loadReports();
                            },
                            color: Colors.red,
                            backgroundColor: Colors.grey[900],
                            child: AnimationLimiter(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
          ),
        );
      },
    );
  }
}

// Extension to darken colors
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