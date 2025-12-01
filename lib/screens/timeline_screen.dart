import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:collection/collection.dart';

import '../services/auth_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  int _selectedFilter = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey<FlipCardState>> _cardKeys = {};
  final Map<String, AnimationController> _hoverControllers = {};
  final Map<String, bool> _isHovering = {};

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    for (var controller in _hoverControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReports() async {
    try {
      final response = await _supabase
          .from('reports')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response ?? []);
        _isLoading = false;

        for (var report in _reports) {
          final id = report['id'].toString();
          _cardKeys[id] ??= GlobalKey<FlipCardState>();
          _hoverControllers[id] ??= AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          _isHovering[id] ??= false;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading reports: $e');
    }
  }

  Future<void> _updateVote(String reportId, String voteType) async {
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      debugPrint('Cannot vote - no user ID');
      return;
    }

    try {
      final reportIndex = _reports.indexWhere((r) => r['id'].toString() == reportId);
      if (reportIndex == -1) {
        debugPrint('Report not found');
        return;
      }

      final report = Map<String, dynamic>.from(_reports[reportIndex]);
      final votes = Map<String, dynamic>.from(
          report['votes'] ?? {'fake': 0, 'normal': 0, 'dangerous': 0, 'suspicious': 0}
      );

      final userVotes = Map<String, String>.from(
          (report['user_votes'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map((key, value) => MapEntry(key, value.toString()))
          );

          final aiLabel = report['predicted_label'] as String? ?? 'normal';
      final aiConfidence = (report['predicted_confidence'] as num?)?.toDouble() ?? 0.5;

      double voteWeight = _calculateVoteWeight(voteType, aiLabel, aiConfidence);

      final previousVote = userVotes[userId];

      if (previousVote != null && previousVote == voteType) {
        // Remove existing vote - convert to double before subtraction
        votes[previousVote] = (votes[previousVote] as num).toDouble() - 1;
        userVotes.remove(userId);
      } else {
        // Apply new weighted vote - ensure we're working with doubles
        if (previousVote != null) {
          votes[previousVote] = (votes[previousVote] as num).toDouble() - 1;
        }
        votes[voteType] = ((votes[voteType] as num?)?.toDouble() ?? 0) + voteWeight;
        userVotes[userId] = voteType;
      }

      // Calculate new risk score
      final newRiskScore = _calculateDynamicRiskScore(
        report,
        votes,
        aiLabel: aiLabel,
        aiConfidence: aiConfidence,
      );

      // Update UI immediately
      setState(() {
        _reports[reportIndex] = {
          ...report,
          'votes': votes,
          'user_votes': userVotes,
          'risk_score': newRiskScore,
        };
      });

      // Sync with database - ensure we're sending proper numeric types
      final response = await _supabase.from('reports').update({
        'votes': votes.map((k, v) => MapEntry(k, v is int ? v.toDouble() : v)),
        'user_votes': userVotes,
        'risk_score': newRiskScore,
      }).eq('id', reportId);

      if (response.error != null) {
        debugPrint('Failed to update report: ${response.error!.message}');
        if (mounted) _loadReports(); // Refresh on error
      }

    } catch (e) {
      debugPrint('Error in _updateVote: $e');
      if (mounted) _loadReports(); // Refresh on error
    }
  }

  double _calculateVoteWeight(String voteType, String aiLabel, double aiConfidence) {
    double weight = 1.0;

    if (aiConfidence > 0.7) {
      if (aiLabel == 'dangerous' && voteType == 'fake') {
        weight *= 0.3;
      } else if (aiLabel == 'fake' && voteType == 'dangerous') {
        weight *= 0.5;
      }
    }

    if ((aiLabel == 'dangerous' && voteType == 'dangerous') ||
        (aiLabel == 'fake' && voteType == 'fake')) {
      weight *= 1.5;
    }

    return weight;
  }

  double _calculateDynamicRiskScore(
      Map<String, dynamic> report,
      Map<String, dynamic> votes, {
        required String aiLabel,
        required double aiConfidence,
      }) {
    final aiWeight = 0.3 + (aiConfidence * 0.4);
    double aiScore = 0;

    switch (aiLabel) {
      case 'dangerous': aiScore = 80; break;
      case 'suspicious': aiScore = 40; break;
      case 'fake': aiScore = 5; break;
      default: aiScore = 20;
    }

    final totalVotes = votes.values.fold<double>(0, (sum, v) => sum + (v is num ? v.toDouble() : 0));
    final dangerRatio = totalVotes > 0 ? ((votes['dangerous'] as num?)?.toDouble() ?? 0) / totalVotes : 0;
    final communityScore = dangerRatio * 100;

    double score = (aiScore * aiWeight) + (communityScore * (1 - aiWeight));

    if (report['is_emergency'] == true) score += 15;

    return score.clamp(0, 100).toDouble();
  }

  Color _getCardColor(Map<String, dynamic> report) {
    final votes = report['votes'] ?? {
      'dangerous': 0,
      'suspicious': 0,
      'normal': 0,
      'fake': 0
    };

    final dangerousVotes = (votes['dangerous'] as num?)?.toDouble() ?? 0;
    final suspiciousVotes = (votes['suspicious'] as num?)?.toDouble() ?? 0;
    final fakeVotes = (votes['fake'] as num?)?.toDouble() ?? 0;
    final aiLabel = report['predicted_label'] ?? 'normal';

    // AI detected FAKE report
    if (aiLabel == 'fake') {
      if (dangerousVotes >= 3) return Colors.red[900]!;       // 3+ dangerous = Red
      if (dangerousVotes >= 2) return Colors.orange[800]!;    // 2 dangerous = Orange
      if (dangerousVotes >= 1) return Colors.yellow[800]!;    // 1 dangerous = Yellow
      return Colors.purple[700]!;                             // Default for fake
    }

    // AI detected DANGEROUS report
    if (aiLabel == 'dangerous') {
      if (fakeVotes >= 3) return Colors.purple[700]!;         // 3+ fake = Purple
      if (fakeVotes >= 2) return Colors.blueGrey[600]!;       // 2 fake = Grey-Blue
      return Colors.red[900]!;                                // Default for dangerous
    }

    // AI detected SUSPICIOUS report
    if (aiLabel == 'suspicious') {
      if (fakeVotes >= 3) return Colors.purple[700]!;         // 3+ fake = Purple
      if (fakeVotes >= 2) return Colors.blueGrey[600]!;       // 2 fake = Grey-Blue
      if (dangerousVotes >= 2) return Colors.red[900]!;       // 2+ dangerous = Red
      return Colors.yellow[800]!;                             // Default for suspicious
    }

    // AI detected NORMAL report
    if (aiLabel == 'normal') {
      if (dangerousVotes >= 3) return Colors.red[900]!;       // 3+ dangerous = Red
      if (dangerousVotes >= 2) return Colors.orange[800]!;    // 2 dangerous = Orange
      if (suspiciousVotes >= 3) return Colors.yellow[800]!;   // 3+ suspicious = Yellow
      if (fakeVotes >= 3) return Colors.purple[700]!;         // 3+ fake = Purple
      return Colors.grey[800]!;                               // Default for normal
    }

    // Fallback
    return Colors.grey[800]!;
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

  Stream<String> _getInvestigationStatusStream(String reportId) {
    return _supabase
        .from('investigations')
        .stream(primaryKey: ['id'])
        .eq('report_id', reportId)
        .limit(1)
        .map((data) {
      if (data.isEmpty) return 'Not Taken Yet';
      final status = data.first['status'] ?? 'not_taken';
      return status == 'not_taken' ? 'Not Taken Yet' :
      status == 'pending' ? 'Pending' :
      status == 'in_progress' ? 'In Progress' :
      status == 'completed' ? 'Completed' : 'Not Taken Yet';
    });
  }

  List<double>? _parseCoordinates(String? location) {
    if (location == null || !location.startsWith('POINT(')) return null;
    final coordsStr = location.replaceAll('POINT(', '').replaceAll(')', '').trim();
    final coords = coordsStr.split(' ').map((s) => double.tryParse(s)).whereType<double>().toList();
    return coords.length == 2 ? coords : null;
  }

  Widget _buildVoteButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required double count,
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
                count.toStringAsFixed(count.truncateToDouble() == count ? 0 : 1),
                key: ValueKey<double>(count),
                style: TextStyle(
                  color: isSelected ? color : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: const Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
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

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AnimationLimiter(
          child: Row(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 500),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                _buildFilterChip('All Reports', 0, Colors.white),
                const SizedBox(width: 12),
                _buildFilterChip('Urgent', 1, Colors.red[400]!),
                const SizedBox(width: 12),
                _buildFilterChip('Recent', 2, Colors.blueGrey[300]!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, Color color) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: _selectedFilter == index ? Colors.white : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: _selectedFilter == index,
      onSelected: (selected) => setState(() => _selectedFilter = selected ? index : _selectedFilter),
      selectedColor: color.withOpacity(0.8),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      backgroundColor: Colors.grey[850],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  List<Map<String, dynamic>> _filterReports(List<Map<String, dynamic>> reports) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 1:
        return reports.where((report) {
          final votes = (report['votes'] as Map<String, dynamic>?) ?? {'dangerous': 0};
          final isEmergency = report['is_emergency'] as bool? ?? false;
          return ((votes['dangerous'] as num?)?.toDouble() ?? 0) >= 3 || isEmergency;
        }).toList();
      case 2:
        final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
        return reports.where((report) {
          final createdAt = (report['created_at'] as String?)?.isNotEmpty == true
              ? DateTime.parse(report['created_at'])
              : now;
          return createdAt.isAfter(twentyFourHoursAgo);
        }).toList();
      default:
        return reports;
    }
  }

  Widget _buildCardFront({
    required String reportId,
    required String reportText,
    required String locationText,
    required List<dynamic> images,
    required String? audioUrl,
    required DateTime timestamp,
    required Map<String, dynamic> votes,
    required bool isEmergency,
    required Color cardColor,
    required Color textColor,
  }) {
    final report = _reports.firstWhere((r) => r['id'].toString() == reportId);
    final aiLabel = report['predicted_label'] ?? 'normal';
    final isConflict = (aiLabel == 'fake' && ((votes['dangerous'] as num?)?.toDouble() ?? 0) >= 2) ||
        (aiLabel == 'dangerous' && ((votes['fake'] as num?)?.toDouble() ?? 0) >= 3);

    return StreamBuilder<String>(
      stream: _getInvestigationStatusStream(reportId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'Not Taken Yet';
        final statusColor = status == 'Completed' ? Colors.green[700]! :
        status == 'In Progress' ? Colors.orange[700]! :
        status == 'Pending' ? Colors.blue[700]! :
        Colors.grey[700]!;

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
                    colors: [cardColor, cardColor.darken(0.1)],
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
                            if (isConflict)
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[800],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('Community Disagrees', style: const TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (((votes['dangerous'] as num?)?.toDouble() ?? 0) >= 3 || isEmergency)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Icon(
                                      Icons.warning_rounded,
                                      color: Colors.red[200],
                                      size: 28,
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reportText,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: ((votes['dangerous'] as num?)?.toDouble() ?? 0) >= 3 || isEmergency
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 18,
                                            color: textColor.withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            locationText,
                                            style: TextStyle(
                                              color: textColor.withOpacity(0.8),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [statusColor, statusColor.darken(0.2)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomLeft: Radius.circular(10),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.3),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: const BorderRadius.only(
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        _formatDate(timestamp),
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (images.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        images[0],
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            height: 200,
                                            color: Colors.grey[800],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                              height: 200,
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
                                      if (((votes['dangerous'] as num?)?.toDouble() ?? 0) >= 3 || isEmergency)
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.red[800]!, Colors.red[600]!],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'ALERT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (audioUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.audiotrack, color: textColor.withOpacity(0.8), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Audio available',
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.flip_to_front,
                                color: textColor.withOpacity(0.6),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to vote',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[850]!, Colors.grey[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VOTE ON THIS REPORT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
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
                              count: (votes['dangerous'] as num?)?.toDouble() ?? 0,
                              color: Colors.red[700]!,
                              isSelected: userVote == 'dangerous',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.warning_amber_rounded,
                              tooltip: 'Suspicious',
                              onPressed: () => _updateVote(reportId, 'suspicious'),
                              count: (votes['suspicious'] as num?)?.toDouble() ?? 0,
                              color: Colors.yellow[800]!,
                              isSelected: userVote == 'suspicious',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.check_circle_outline,
                              tooltip: 'Normal',
                              onPressed: () => _updateVote(reportId, 'normal'),
                              count: (votes['normal'] as num?)?.toDouble() ?? 0,
                              color: Colors.green[600]!,
                              isSelected: userVote == 'normal',
                              reportId: reportId,
                            ),
                            _buildVoteButton(
                              icon: Icons.block,
                              tooltip: 'Fake',
                              onPressed: () => _updateVote(reportId, 'fake'),
                              count: (votes['fake'] as num?)?.toDouble() ?? 0,
                              color: Colors.purpleAccent[700]!,
                              isSelected: userVote == 'fake',
                              reportId: reportId,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.flip_to_back,
                            color: textColor.withOpacity(0.6),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to return',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
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

  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final reportId = report['id'].toString();
    final reportText = report['description'] ?? 'No description provided';
    final coords = _parseCoordinates(report['location'] as String?);
    final locationText = coords != null
        ? 'Lat: ${coords[1].toStringAsFixed(5)}, Lon: ${coords[0].toStringAsFixed(5)}'
        : 'Location not specified';
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
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
            child: FlipCard(
              key: _cardKeys[reportId],
              flipOnTouch: false,
              front: _buildCardFront(
                reportId: reportId,
                reportText: reportText,
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

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!.lighten(0.1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[900]!, Colors.black],
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
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                if (_isLoading) _buildShimmerLoading(),
                if (!_isLoading && _reports.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.report_problem,
                          size: 80,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No reports found',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_isLoading && _reports.isNotEmpty)
                  Column(
                    children: [
                      _buildFilterChips(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadReports,
                          color: Colors.red[700]!,
                          backgroundColor: Colors.grey[900],
                          child: AnimationLimiter(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _filterReports(_reports).length,
                              itemBuilder: (context, index) {
                                final report = _filterReports(_reports)[index];
                                return _buildReportCard(report, index);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('reports')
                      .stream(primaryKey: ['id'])
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !const DeepCollectionEquality().equals(_reports, snapshot.data)) {
                          setState(() {
                            _reports = snapshot.data!;
                            _isLoading = false;
                          });
                        }
                      });
                    }
                    return Container();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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