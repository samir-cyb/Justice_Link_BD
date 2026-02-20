import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:justice_link_user/providers/emergency_provider.dart';
import 'package:justice_link_user/widgets/emergency_location_card.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:hex/hex.dart';
import 'dart:developer' as developer;

class EmergencySupportScreen extends StatefulWidget {
  final String currentUserId;

  const EmergencySupportScreen({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<EmergencySupportScreen> createState() => _EmergencySupportScreenState();
}

class _EmergencySupportScreenState extends State<EmergencySupportScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final EmergencyService _emergencyService = EmergencyService();
  final SupabaseClient _supabase = Supabase.instance.client;

  int _viewState = 0; // 0 = Scanning, 1 = Responder, 2 = Caller

  Map<String, dynamic>? _currentEmergencyData;
  LatLng? _myLocation;
  StreamSubscription? _emergencySubscription;
  StreamSubscription? _responseSubscription;
  int _respondersCount = 0;
  bool _hasVoted = false;

  final MapController _mapController = MapController();

  // FIX 1: Track handled emergencies to prevent re-alerting
  final Set<String> _handledEmergencyIds = {};
  String? _activeEmergencyId;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeState();
  }

  @override
  void dispose() {
    _emergencySubscription?.cancel();
    _responseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if(mounted) {
        setState(() {
          _myLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if(mounted) setState(() => _myLocation = const LatLng(23.8103, 90.4125));
    }
  }

  void _initializeState() {
    _emergencySubscription = _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> rawData) {

      // FIX 1: Filter out already handled emergencies
      final activeEmergencies = rawData.where((e) =>
      e['status'] == 'active'
      ).toList();

      final myActive = activeEmergencies.where((e) =>
      e['user_id'] == widget.currentUserId
      ).toList();

      final othersActive = activeEmergencies.where((e) =>
      e['user_id'] != widget.currentUserId &&
          !_handledEmergencyIds.contains(e['id'].toString()) // Skip handled
      ).toList();

      if (mounted) {
        // Check if provider is already showing an emergency
        final emergencyState = context.read<EmergencyState>();
        if (emergencyState.showEmergencyCard && emergencyState.currentEmergency != null) {
          // Don't interfere if provider is active
          return;
        }

        if (myActive.isNotEmpty) {
          if (_viewState != 2) {
            setState(() {
              _viewState = 2;
              _currentEmergencyData = myActive.last;
              _activeEmergencyId = myActive.last['id'].toString();
            });
            _listenForResponders(_currentEmergencyData!['id'].toString());
          }
        } else {
          if (_viewState == 2) {
            setState(() {
              _viewState = 0;
              _activeEmergencyId = null;
            });
          }

          if (_viewState == 0 && othersActive.isNotEmpty) {
            final emergency = othersActive.last;
            final emergencyId = emergency['id'].toString();

            // Only switch if it's a different emergency
            if (_activeEmergencyId != emergencyId) {
              setState(() {
                _viewState = 1;
                _currentEmergencyData = emergency;
                _activeEmergencyId = emergencyId;
                _hasVoted = false;
              });
            }
          } else if (_viewState == 1 && othersActive.isEmpty) {
            setState(() {
              _viewState = 0;
              _activeEmergencyId = null;
              _currentEmergencyData = null;
            });
          }
        }
      }
    });
  }

  // FIX 1: Mark emergency as handled (call this when responding)
  void _markEmergencyHandled(String emergencyId) {
    developer.log('✅ Marking emergency as handled: $emergencyId');
    setState(() {
      _handledEmergencyIds.add(emergencyId);
      // If this was the active one, clear it
      if (_activeEmergencyId == emergencyId) {
        _activeEmergencyId = null;
        _currentEmergencyData = null;
        _viewState = 0;
      }
    });
  }

  void _listenForResponders(String emergencyId) {
    _responseSubscription?.cancel();
    _responseSubscription = _supabase
        .from('emergency_responses')
        .stream(primaryKey: ['id'])
        .listen((data) {
      final relevant = data.where((e) => e['emergency_id'] == emergencyId).toList();
      if (mounted) setState(() => _respondersCount = relevant.length);
    });
  }

  void _forceClearAllMySOS() async {
    await _supabase
        .from('emergencies')
        .update({'status': 'resolved'})
        .eq('user_id', widget.currentUserId);
  }

  Future<void> _submitVote(String voteType) async {
    if (_currentEmergencyData == null || _hasVoted) return;

    setState(() => _hasVoted = true);

    try {
      final emergencyId = _currentEmergencyData!['id'];

      await _supabase.from('emergency_votes').insert({
        'emergency_id': emergencyId,
        'user_id': widget.currentUserId,
        'vote_type': voteType,
        'created_at': DateTime.now().toIso8601String(),
      });

      String newStatus = voteType == 'resolved' ? 'resolved' : 'fake';

      await _supabase.from('emergencies')
          .update({'status': newStatus})
          .eq('id', emergencyId);

      // FIX 1: Mark as handled after voting
      _markEmergencyHandled(emergencyId.toString());

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Marked as ${voteType.toUpperCase()}"),
              backgroundColor: voteType == 'resolved' ? Colors.green : Colors.red
          )
      );

    } catch (e) {
      developer.log("Vote Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vote recorded or already submitted."))
      );
    }
  }

  LatLng _parseLocation(dynamic location) {
    if (location is String) {
      if (location.startsWith('010100')) {
        try {
          final bytes = HEX.decode(location);
          final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
          final longitude = byteData.getFloat64(9, Endian.little);
          final latitude = byteData.getFloat64(17, Endian.little);
          return LatLng(latitude, longitude);
        } catch (e) { return const LatLng(0, 0); }
      }
      if (location.startsWith('POINT')) {
        try {
          final coords = location.replaceAll('POINT(', '').replaceAll(')', '').split(' ');
          return LatLng(double.parse(coords[1]), double.parse(coords[0]));
        } catch (e) { return const LatLng(0, 0); }
      }
    }
    return const LatLng(0, 0);
  }

  // --- VIEWS ---

  Widget _buildScanningView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.radar, size: 80, color: Colors.blueAccent),
      const SizedBox(height: 20),
      const Text("Scanning for Signals...", style: TextStyle(color: Colors.white70, fontSize: 18)),
    ]));
  }

  Widget _buildResponderView() {
    return Consumer<EmergencyState>(
      builder: (context, emergencyState, child) {
        if (emergencyState.showEmergencyCard &&
            emergencyState.currentEmergency != null) {
          return _buildProviderEmergencyView(context, emergencyState);
        }

        return _buildRegularResponderView();
      },
    );
  }

  Widget _buildProviderEmergencyView(BuildContext context, EmergencyState emergencyState) {
    final emergency = emergencyState.currentEmergency!;
    final emergencyId = emergencyState.emergencyId!;

    final locationStr = emergency['location']?.toString() ?? '';
    final coords = _parseCoordinatesFromEmergency(locationStr);

    if (coords == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emergencyState.clearEmergency();
      });

      return Scaffold(
        appBar: AppBar(
          title: const Text('EMERGENCY ERROR', style: TextStyle(fontSize: 14)),
          backgroundColor: Colors.red,
          toolbarHeight: 40,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => emergencyState.hideCard(),
          ),
        ),
        body: const Center(child: Text('Could not parse emergency location')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RESPONDING TO EMERGENCY',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        toolbarHeight: 42,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => emergencyState.hideCard(),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _markEmergencyResolved(emergencyId);
              emergencyState.clearEmergency();
              // FIX 1: Also mark as handled locally
              _markEmergencyHandled(emergencyId);
            },
            child: const Text(
              'RESOLVED',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: EmergencyLocationCard(
        key: ValueKey('emergency_$emergencyId'),
        callerLocation: coords,
        timestamp: DateTime.tryParse(emergency['created_at'] ?? '') ?? DateTime.now(),
        userId: emergency['user_id'] ?? '',
        isOwnEmergency: emergency['user_id'] == widget.currentUserId,
        onRespond: () => _handleRespond(context, emergency),
      ),
    );
  }

  Widget _buildRegularResponderView() {
    final victimLoc = _currentEmergencyData != null
        ? _parseLocation(_currentEmergencyData!['location'])
        : const LatLng(23.8103, 90.4125);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: victimLoc, initialZoom: 16.0),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.justicelink.bd',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(markers: [
              Marker(point: victimLoc, width: 60, height: 60, child: const Icon(Icons.location_on, color: Colors.red, size: 60)),
              if (_myLocation != null)
                Marker(point: _myLocation!, width: 40, height: 40, child: const Icon(Icons.navigation, color: Colors.blue, size: 40)),
            ]),
          ],
        ),

        Positioned(
          bottom: 30, left: 16, right: 16,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24)
                ),
                child: Text(
                    "Emergency: ${_currentEmergencyData?['type'] ?? 'Unknown'}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("HELP DONE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasVoted ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      onPressed: _hasVoted ? null : () => _submitVote('resolved'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.report_gmailerrorred),
                      label: const Text("FAKE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasVoted ? Colors.grey : Colors.red[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      onPressed: _hasVoted ? null : () => _submitVote('fake'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCallerView() {
    return Container(
      color: Colors.red[900],
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          const Text("SOS ACTIVE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Type: ${_currentEmergencyData?['type'] ?? 'General'}", style: const TextStyle(color: Colors.yellow, fontSize: 18)),
          const SizedBox(height: 10),
          Text("Responders: $_respondersCount", style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
            onPressed: _forceClearAllMySOS,
            child: const Text("I AM SAFE"),
          )
        ],
      ),
    );
  }

  LatLng? _parseCoordinatesFromEmergency(String locationStr) {
    try {
      if (locationStr.length > 16 && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(locationStr)) {
        return _parseWKBHex(locationStr);
      }

      final cleanStr = locationStr.replaceAll(RegExp(r'SRID=\d+;'), '');
      final match = RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(cleanStr);
      if (match != null) {
        return LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }

      return null;
    } catch (e) {
      developer.log('Error parsing coordinates: $e');
      return null;
    }
  }

  LatLng? _parseWKBHex(String hex) {
    try {
      if (hex.length < 34) return null;
      final bytes = HEX.decode(hex);
      final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
      final longitude = byteData.getFloat64(9, Endian.little);
      final latitude = byteData.getFloat64(17, Endian.little);
      return LatLng(latitude, longitude);
    } catch (e) {
      developer.log('WKB parse error: $e');
      return null;
    }
  }

  Future<void> _markEmergencyResolved(String emergencyId) async {
    try {
      await _supabase
          .from('emergencies')
          .update({'status': 'resolved'})
          .eq('id', emergencyId);
    } catch (e) {
      developer.log('Error resolving emergency: $e');
    }
  }

  void _handleRespond(BuildContext context, Map<String, dynamic> emergency) {
    // FIX 1: Mark as handled immediately when responding
    final emergencyId = emergency['id'].toString();
    _markEmergencyHandled(emergencyId);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.blue),
              title: const Text('Navigate to Caller'),
              subtitle: const Text('Open in Google Maps'),
              onTap: () async {
                Navigator.pop(context);
                final loc = _parseCoordinatesFromEmergency(emergency['location']?.toString() ?? '');
                if (loc != null) {
                  final uri = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}'
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call Emergency Services'),
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse('tel:999');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.orange),
              title: const Text('Message Caller'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<EmergencyState>(
      builder: (context, emergencyState, child) {
        // If provider has an emergency, mark it as handled locally to prevent duplicate alerts
        if (emergencyState.showEmergencyCard &&
            emergencyState.currentEmergency != null) {

          final emergencyId = emergencyState.emergencyId;
          if (emergencyId != null && !_handledEmergencyIds.contains(emergencyId)) {
            // Use post-frame callback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handledEmergencyIds.add(emergencyId);
            });
          }

          return _buildProviderEmergencyView(context, emergencyState);
        }

        if (_viewState == 2) return _buildCallerView();
        if (_viewState == 1) return _buildResponderView();
        return _buildScanningView();
      },
    );
  }
}