// screens/complaint_history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ComplaintHistoryScreen extends StatefulWidget {
  const ComplaintHistoryScreen({super.key});

  @override
  State<ComplaintHistoryScreen> createState() => _ComplaintHistoryScreenState();
}

class _ComplaintHistoryScreenState extends State<ComplaintHistoryScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  // Streams for real-time updates
  StreamSubscription<List<Map<String, dynamic>>>? _reportsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _investigationsSubscription;

  // Map to store investigation data keyed by report_id
  Map<String, Map<String, dynamic>> _investigationsMap = {};

  // Timer for updating live time counters
  Timer? _liveUpdateTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
    _animationController.forward();

    // Start live timer for updating time counters every minute
    _liveUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reportsSubscription?.cancel();
    _investigationsSubscription?.cancel();
    _liveUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load user's reports
      final reportsResponse = await _supabase
          .from('reports')
          .select('*')
          .eq('user_id', user.uid)
          .order('created_at', ascending: false);

      // Load all investigations for these reports
      final investigationsResponse = await _supabase
          .from('investigations')
          .select('*');

      if (!mounted) return;

      // Create map of investigations by report_id
      final Map<String, Map<String, dynamic>> invMap = {};
      for (var inv in investigationsResponse) {
        final reportId = inv['report_id']?.toString();
        if (reportId != null) {
          invMap[reportId] = inv as Map<String, dynamic>;
        }
      }

      setState(() {
        _reports = List<Map<String, dynamic>>.from(reportsResponse ?? []);
        _investigationsMap = invMap;
        _isLoading = false;
      });

      _subscribeToUpdates(user.uid);
    } catch (e) {
      debugPrint('Error loading complaint history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates(String userId) {
    // Subscribe to reports changes
    _reportsSubscription = _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((reports) {
      if (mounted) {
        setState(() => _reports = reports);
      }
    });

    // Subscribe to investigations changes (for status updates)
    _investigationsSubscription = _supabase
        .from('investigations')
        .stream(primaryKey: ['id'])
        .listen((investigations) {
      if (mounted) {
        final Map<String, Map<String, dynamic>> invMap = {};
        for (var inv in investigations) {
          final reportId = inv['report_id']?.toString();
          if (reportId != null) {
            invMap[reportId] = inv as Map<String, dynamic>;
          }
        }
        setState(() => _investigationsMap = invMap);
      }
    });
  }

  // Calculate Phase 1: Report created → Investigation started
  Map<String, dynamic> _calculatePhase1Times(Map<String, dynamic> report, Map<String, dynamic>? investigation) {
    final createdAt = DateTime.parse(report['created_at'] as String);
    final now = DateTime.now();

    if (investigation == null) {
      // Still waiting for police to take investigation
      return {
        'status': 'waiting',
        'startTime': createdAt,
        'endTime': null,
        'duration': now.difference(createdAt),
        'isComplete': false,
      };
    }

    final startedAt = DateTime.parse(investigation['started_at'] as String);
    return {
      'status': 'completed',
      'startTime': createdAt,
      'endTime': startedAt,
      'duration': startedAt.difference(createdAt),
      'isComplete': true,
    };
  }

  // Calculate Phase 2: Investigation started → Completed
  Map<String, dynamic> _calculatePhase2Times(Map<String, dynamic>? investigation) {
    if (investigation == null) {
      return {
        'status': 'not_started',
        'startTime': null,
        'endTime': null,
        'duration': Duration.zero,
        'isComplete': false,
        'isActive': false,
      };
    }

    final startedAt = DateTime.parse(investigation['started_at'] as String);
    final status = investigation['status'] as String? ?? 'pending';
    final now = DateTime.now();

    if (status == 'completed' || status == 'closed') {
      final completedAt = investigation['completed_at'] != null
          ? DateTime.parse(investigation['completed_at'] as String)
          : DateTime.parse(investigation['updated_at'] as String);

      return {
        'status': 'completed',
        'startTime': startedAt,
        'endTime': completedAt,
        'duration': completedAt.difference(startedAt),
        'isComplete': true,
        'isActive': false,
      };
    }

    // Still in progress
    return {
      'status': 'in_progress',
      'startTime': startedAt,
      'endTime': null,
      'duration': now.difference(startedAt),
      'isComplete': false,
      'isActive': true,
    };
  }

  String _formatDuration(Duration duration, {bool showSeconds = false}) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final List<String> parts = [];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (showSeconds && seconds > 0 && duration.inMinutes < 1) {
      parts.add('${seconds}s');
    }

    return parts.isEmpty ? '0m' : parts.join(' ');
  }

  String _getOverallStatus(Map<String, dynamic>? investigation) {
    if (investigation == null) return 'submitted';
    final status = investigation['status'] as String? ?? 'pending';

    switch (status) {
      case 'pending':
        return 'under_investigation';
      case 'in_progress':
      case 'under_review':
        return 'investigating';
      case 'completed':
        return 'completed';
      case 'closed':
        return 'closed';
      default:
        return 'submitted';
    }
  }

  List<StepData> _getSteps(String overallStatus) {
    return [
      StepData(
        title: 'Submitted',
        icon: Icons.send,
        isComplete: true,
        isActive: overallStatus == 'submitted',
      ),
      StepData(
        title: 'Under Investigation',
        icon: Icons.search,
        isComplete: overallStatus != 'submitted',
        isActive: overallStatus == 'under_investigation' || overallStatus == 'investigating',
      ),
      StepData(
        title: 'Completed',
        icon: Icons.check_circle,
        isComplete: overallStatus == 'completed' || overallStatus == 'closed',
        isActive: overallStatus == 'completed',
      ),
    ];
  }

  Color _getStatusColor(String overallStatus) {
    switch (overallStatus) {
      case 'submitted':
        return Colors.blue;
      case 'under_investigation':
      case 'investigating':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text(
          'MY COMPLAINTS',
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
              colors: [Colors.blue[900]!, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: _isLoading
                ? _buildShimmerLoading()
                : _reports.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.blue,
              backgroundColor: Colors.grey[900],
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  return _buildComplaintCard(_reports[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> report) {
    final reportId = report['id'].toString();
    final investigation = _investigationsMap[reportId];
    final overallStatus = _getOverallStatus(investigation);
    final steps = _getSteps(overallStatus);

    final phase1 = _calculatePhase1Times(report, investigation);
    final phase2 = _calculatePhase2Times(investigation);

    final crimeType = report['crime_type'] as String? ?? 'General';
    final description = report['description'] as String? ?? 'No description';
    final createdAt = DateTime.parse(report['created_at'] as String);
    final images = (report['images'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(overallStatus).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: _getStatusColor(overallStatus).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with crime type and date
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(overallStatus).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: _getStatusColor(overallStatus).withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(overallStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(overallStatus).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(overallStatus),
                          color: _getStatusColor(overallStatus),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(overallStatus).toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(overallStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Progress Stepper
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProgressStepper(steps),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 16),

            // Time Tracking Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Phase 1: Report to Investigation
                  _buildTimeCard(
                    phase: 1,
                    title: 'Assignment Time',
                    subtitle: 'Report → Investigation',
                    timing: phase1,
                    icon: Icons.assignment_ind,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  // Phase 2: Investigation to Completion
                  _buildTimeCard(
                    phase: 2,
                    title: 'Resolution Time',
                    subtitle: 'Investigation → Complete',
                    timing: phase2,
                    icon: Icons.timer,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Image preview (if exists)
            if (images.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length > 3 ? 3 : images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: index == 2 && images.length > 3
                            ? Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${images.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                            : null,
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // View Details Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showComplaintDetails(report, investigation, phase1, phase2),
                  icon: const Icon(Icons.visibility),
                  label: const Text('VIEW DETAILS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStepper(List<StepData> steps) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isActive = steps[stepIndex + 1].isActive || steps[stepIndex + 1].isComplete;
          final isComplete = steps[stepIndex].isComplete && steps[stepIndex + 1].isComplete;

          return Expanded(
            child: Container(
              height: 3,
              color: isComplete
                  ? Colors.green
                  : isActive
                  ? Colors.orange
                  : Colors.grey[700],
            ),
          );
        } else {
          // Step circle
          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.isComplete
                      ? Colors.green
                      : step.isActive
                      ? Colors.orange
                      : Colors.grey[800],
                  border: Border.all(
                    color: step.isComplete
                        ? Colors.green
                        : step.isActive
                        ? Colors.orange
                        : Colors.grey[600]!,
                    width: 2,
                  ),
                  boxShadow: step.isActive
                      ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                      : null,
                ),
                child: Icon(
                  step.isComplete ? Icons.check : step.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: step.isComplete || step.isActive
                        ? Colors.white
                        : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: step.isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Widget _buildTimeCard({
    required int phase,
    required String title,
    required String subtitle,
    required Map<String, dynamic> timing,
    required IconData icon,
    required Color color,
  }) {
    final isComplete = timing['isComplete'] as bool;
    final isActive = timing['isActive'] as bool? ?? false;
    final duration = timing['duration'] as Duration;
    final startTime = timing['startTime'] as DateTime?;
    final endTime = timing['endTime'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? color
              : isComplete
              ? Colors.green.withOpacity(0.5)
              : color.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green.withOpacity(0.2)
                      : isActive
                      ? color.withOpacity(0.3)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? Border.all(color: color)
                      : isComplete
                      ? Border.all(color: Colors.green)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: isComplete
                            ? Colors.green
                            : isActive
                            ? color
                            : Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (startTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.play_circle,
                  size: 12,
                  color: isComplete ? Colors.green : color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Started: ${DateFormat('MMM dd, HH:mm').format(startTime)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                if (endTime != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.stop_circle, size: 12, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Completed: ${DateFormat('MMM dd, HH:mm').format(endTime)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showComplaintDetails(
      Map<String, dynamic> report,
      Map<String, dynamic>? investigation,
      Map<String, dynamic> phase1,
      Map<String, dynamic> phase2,
      ) {
    final reportId = report['id'].toString();
    final statusHistory = investigation != null
        ? List<Map<String, dynamic>>.from(investigation['status_history'] as List? ?? [])
        : <Map<String, dynamic>>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COMPLAINT DETAILS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Report ID
                        _buildDetailRow('Report ID', '#${reportId.substring(0, 8).toUpperCase()}'),
                        _buildDetailRow('Crime Type', report['crime_type'] ?? 'General'),
                        _buildDetailRow('Location', '${report['city'] ?? 'Unknown'}${report['area'] != null ? ', ${report['area']}' : ''}'),

                        const Divider(height: 32, color: Colors.grey),

                        // Description
                        const Text(
                          'DESCRIPTION',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report['description'] ?? 'No description provided',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),

                        const Divider(height: 32, color: Colors.grey),

                        // Time tracking detailed
                        const Text(
                          'TIME TRACKING',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailTimeRow(
                          'Phase 1: Assignment',
                          phase1['startTime'] as DateTime?,
                          phase1['endTime'] as DateTime?,
                          phase1['duration'] as Duration,
                          phase1['isComplete'] as bool,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailTimeRow(
                          'Phase 2: Resolution',
                          phase2['startTime'] as DateTime?,
                          phase2['endTime'] as DateTime?,
                          phase2['duration'] as Duration,
                          phase2['isComplete'] as bool,
                        ),

                        // Status History
                        if (statusHistory.isNotEmpty) ...[
                          const Divider(height: 32, color: Colors.grey),
                          const Text(
                            'STATUS HISTORY',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...statusHistory.reversed.map((entry) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(entry['from_status'] as String).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getStatusText(entry['from_status'] as String),
                                      style: TextStyle(
                                        color: _getStatusColor(entry['from_status'] as String),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(entry['to_status'] as String).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getStatusText(entry['to_status'] as String),
                                      style: TextStyle(
                                        color: _getStatusColor(entry['to_status'] as String),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM dd, HH:mm').format(
                                      DateTime.parse(entry['changed_at'] as String),
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],

                        // Notes from investigation
                        if (investigation != null && investigation['notes'] != null) ...[
                          const Divider(height: 32, color: Colors.grey),
                          const Text(
                            'OFFICER NOTES',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Text(
                              investigation['notes'] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTimeRow(String label, DateTime? start, DateTime? end, Duration duration, bool isComplete) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (start != null)
            Text(
              'Started: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(start)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          if (end != null)
            Text(
              'Completed: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(end)}',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'submitted':
        return Icons.send;
      case 'under_investigation':
      case 'investigating':
        return Icons.search;
      case 'completed':
        return Icons.check_circle;
      case 'closed':
        return Icons.lock;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'under_investigation':
        return 'Under Investigation';
      case 'investigating':
        return 'Investigating';
      case 'completed':
        return 'Completed';
      case 'closed':
        return 'Closed';
      default:
        return 'Unknown';
    }
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            height: 400,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 20),
          const Text(
            'No complaints yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your complaint history will appear here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for stepper data
class StepData {
  final String title;
  final IconData icon;
  final bool isComplete;
  final bool isActive;

  StepData({
    required this.title,
    required this.icon,
    required this.isComplete,
    required this.isActive,
  });
}