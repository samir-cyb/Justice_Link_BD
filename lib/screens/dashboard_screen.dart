import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Data states
  List<Map<String, dynamic>> _topAreas = [];
  List<Map<String, dynamic>> _allAreas = [];
  bool _isLoading = true;
  bool _isLoadingAll = false;
  String? _error;

  // View mode
  bool _showAllAreas = false;

  // Realtime subscription
  Stream<List<Map<String, dynamic>>>? _reportsStream;

  @override
  void initState() {
    super.initState();
    developer.log('🚀 DashboardScreen initialized');
    _loadDashboardData();
    _subscribeToRealtimeUpdates();
  }

  // ==================== DATA FETCHING ====================

  Future<void> _loadDashboardData() async {
    developer.log('📊 Loading dashboard data...');
    setState(() => _isLoading = true);

    try {
      // Fetch top 10 areas with statistics
      final topAreas = await _fetchAreaStatistics(limit: 10);

      setState(() {
        _topAreas = topAreas;
        _isLoading = false;
        _error = null;
      });

      developer.log('✅ Loaded ${topAreas.length} top areas');

    } catch (e, stackTrace) {
      developer.log('❌ Error loading dashboard: $e');
      developer.log('📚 Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load dashboard: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllAreas() async {
    developer.log('📊 Loading all 300+ areas...');
    setState(() => _isLoadingAll = true);

    try {
      final allAreas = await _fetchAreaStatistics(limit: null); // No limit

      setState(() {
        _allAreas = allAreas;
        _showAllAreas = true;
        _isLoadingAll = false;
      });

      developer.log('✅ Loaded ${allAreas.length} total areas');

    } catch (e, stackTrace) {
      developer.log('❌ Error loading all areas: $e');
      setState(() {
        _isLoadingAll = false;
      });
      _showError('Failed to load all areas: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAreaStatistics({int? limit}) async {
    developer.log('🔍 Fetching area statistics${limit != null ? " (limit: $limit)" : ""}...');

    // Step 1: Get all reports with their investigations
    // We treat 'ason' (from reports.area) as the area identifier
    final reportsResponse = await _supabase
        .from('reports')
        .select('''
          id,
          area,
          city,
          risk_score,
          predicted_label,
          created_at,
          investigations:investigations(
            status,
            started_at
          )
        ''')
        .order('created_at', ascending: false);

    developer.log('📋 Total reports fetched: ${reportsResponse.length}');

    // Step 2: Aggregate by area (Ason)
    final Map<String, Map<String, dynamic>> areaStats = {};

    for (final report in reportsResponse) {
      final areaName = report['area'] as String? ?? 'Unknown';
      final city = report['city'] as String? ?? 'Unknown';
      final riskScore = (report['risk_score'] as num?)?.toDouble() ?? 0.0;
      final predictedLabel = report['predicted_label'] as String? ?? 'normal';

      // Get investigation status
      final investigation = report['investigation'] as List<dynamic>?;
      String investigationStatus = 'not_taken';

      if (investigation != null && investigation.isNotEmpty) {
        investigationStatus = investigation[0]['status'] as String? ?? 'not_taken';
      }

      // Initialize area if not exists
      if (!areaStats.containsKey(areaName)) {
        areaStats[areaName] = {
          'area_name': areaName,
          'city': city,
          'total_reports': 0,
          'not_taken': 0,
          'pending': 0,
          'in_progress': 0,
          'solved': 0,
          'dangerous': 0,
          'high_risk_count': 0,
        };
      }

      // Update statistics
      final stats = areaStats[areaName]!;
      stats['total_reports'] = (stats['total_reports'] as int) + 1;

      // Count by investigation status
      switch (investigationStatus) {
        case 'pending':
          stats['not_taken'] = (stats['not_taken'] as int) + 1;
          break;
        case 'in_progress':
          stats['in_progress'] = (stats['in_progress'] as int) + 1;
          break;
        case 'completed':
          stats['solved'] = (stats['solved'] as int) + 1;
          break;
        default:
          stats['not_taken'] = (stats['not_taken'] as int) + 1;
      }

      // Count dangerous reports
      if (predictedLabel == 'dangerous' || riskScore > 80) {
        stats['dangerous'] = (stats['dangerous'] as int) + 1;
      }

      // Count high risk
      if (riskScore > 80) {
        stats['high_risk_count'] = (stats['high_risk_count'] as int) + 1;
      }
    }

    developer.log('📊 Areas aggregated: ${areaStats.length}');

    // Step 3: Convert to list and sort by total reports
    var areasList = areaStats.values.toList();
    areasList.sort((a, b) => (b['total_reports'] as int).compareTo(a['total_reports'] as int));

    // Step 4: Apply limit if specified
    if (limit != null && areasList.length > limit) {
      areasList = areasList.sublist(0, limit);
    }

    return areasList;
  }

  // ==================== REALTIME UPDATES ====================

  void _subscribeToRealtimeUpdates() {
    developer.log('📡 Subscribing to realtime updates...');

    _reportsStream = _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
      developer.log('🔄 Realtime update received: ${data.length} reports');
      return data;
    });

    _reportsStream?.listen(
          (reports) {
        // Refresh data when new reports come in
        _loadDashboardData();
      },
      onError: (error) {
        developer.log('❌ Realtime stream error: $error');
      },
    );
  }

  // ==================== UI BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _showAllAreas ? _buildAllAreasView() : _buildTopAreasView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CRIME DASHBOARD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showAllAreas
                        ? 'All Areas Overview'
                        : 'Top 10 High Activity Areas',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.cyanAccent],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle buttons
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  'Top 10',
                  Icons.trending_up,
                  !_showAllAreas,
                      () {
                    if (_showAllAreas) {
                      setState(() => _showAllAreas = false);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleButton(
                  'View All',
                  Icons.view_list,
                  _showAllAreas,
                      () {
                    if (!_showAllAreas) {
                      if (_allAreas.isEmpty) {
                        _loadAllAreas();
                      } else {
                        setState(() => _showAllAreas = true);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
            colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
          )
              : null,
          color: isActive ? null : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.white.withOpacity(0.5) : Colors.white24,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAreasView() {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_topAreas.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E2A38),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topAreas.length,
        itemBuilder: (context, index) {
          final area = _topAreas[index];
          return _buildAreaCard(area, index + 1);
        },
      ),
    );
  }

  Widget _buildAllAreasView() {
    if (_isLoadingAll) {
      return _buildLoadingWidget(message: 'Loading all areas...');
    }

    return Column(
      children: [
        // Search bar for all areas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search area...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
            ),
            onChanged: (query) {
              // Filter logic here if needed
            },
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allAreas.length,
            itemBuilder: (context, index) {
              final area = _allAreas[index];
              return _buildAreaCard(area, index + 1, isCompact: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAreaCard(Map<String, dynamic> area, int rank, {bool isCompact = false}) {
    final total = area['total_reports'] as int;
    final notTaken = area['not_taken'] as int;
    final inProgress = area['in_progress'] as int;
    final solved = area['solved'] as int;
    final dangerous = area['dangerous'] as int;
    final highRisk = area['high_risk_count'] as int;

    // Determine severity color
    Color severityColor = Colors.green;
    if (dangerous > 0 || highRisk > 0) {
      severityColor = Colors.red;
    } else if (inProgress > 0) {
      severityColor = Colors.orange;
    } else if (notTaken > 0) {
      severityColor = Colors.yellow;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E2A38).withOpacity(0.95),
            const Color(0xFF1E2A38).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: severityColor.withOpacity(0.5),
          width: dangerous > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(dangerous > 0 ? 0.3 : 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header with rank and area name
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dangerous > 0
                      ? [Colors.redAccent.withOpacity(0.3), Colors.transparent]
                      : [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: rank <= 3
                            ? [Colors.amberAccent, Colors.orange]
                            : [Colors.blueAccent, Colors.cyanAccent],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (rank <= 3 ? Colors.amberAccent : Colors.blueAccent).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Area info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area['area_name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${area['city']} • $total reports',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Danger badge
                  if (dangerous > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$dangerous',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Statistics grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Not Taken', notTaken, Colors.grey),
                  _buildStatColumn('Pending', inProgress, Colors.orange),
                  _buildStatColumn('Solved', solved, Colors.green),
                  _buildStatColumn('Dangerous', dangerous, Colors.red),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: solved / (total == 0 ? 1 : total),
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    solved == total ? Colors.green : Colors.blueAccent,
                  ),
                  minHeight: 6,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget({String message = 'Loading dashboard...'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No reports yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reports will appear here once submitted',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    developer.log('🔴 DashboardScreen disposed');
    super.dispose();
  }
}