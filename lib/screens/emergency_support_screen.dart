import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:justice_link_user/screens/emergency_service.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:hex/hex.dart';

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

  // 0 = Scanning, 1 = Responder, 2 = Caller
  int _viewState = 0;

  Map<String, dynamic>? _currentEmergencyData;
  LatLng? _myLocation;
  StreamSubscription? _emergencySubscription;
  StreamSubscription? _responseSubscription;
  int _respondersCount = 0;

  // NEW: Track if this user has already pressed a button for this session
  bool _hasVoted = false;

  final MapController _mapController = MapController();

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
    _supabase
        .from('emergencies')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> rawData) {

      final myActive = rawData.where((e) => e['user_id'] == widget.currentUserId && e['status'] == 'active').toList();
      final othersActive = rawData.where((e) => e['user_id'] != widget.currentUserId && e['status'] == 'active').toList();

      if (mounted) {
        if (myActive.isNotEmpty) {
          // I AM CALLER
          if (_viewState != 2) {
            setState(() {
              _viewState = 2;
              _currentEmergencyData = myActive.last;
            });
            _listenForResponders(_currentEmergencyData!['id'].toString());
          }
        } else {
          // I AM SAFE / RESPONDER
          if (_viewState == 2) setState(() => _viewState = 0);

          // AUTO-SWITCH TO MAP IF THERE IS AN ACTIVE ALERT
          if (_viewState == 0 && othersActive.isNotEmpty) {
            setState(() {
              _viewState = 1;
              _currentEmergencyData = othersActive.last;
              _hasVoted = false; // Reset vote state for new emergency
            });
          } else if (_viewState == 1 && othersActive.isEmpty) {
            setState(() => _viewState = 0);
          }
        }
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

  // --- NEW: VOTE LOGIC ---
  Future<void> _submitVote(String voteType) async {
    if (_currentEmergencyData == null || _hasVoted) return;

    setState(() => _hasVoted = true); // Disable buttons immediately

    try {
      final emergencyId = _currentEmergencyData!['id'];

      // 1. Log the vote in the new table
      await _supabase.from('emergency_votes').insert({
        'emergency_id': emergencyId,
        'user_id': widget.currentUserId,
        'vote_type': voteType,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Update the main status
      // If someone marks it as Done or Fake, we update the status so it closes for everyone
      String newStatus = voteType == 'resolved' ? 'resolved' : 'fake';

      await _supabase.from('emergencies')
          .update({'status': newStatus})
          .eq('id', emergencyId);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Marked as ${voteType.toUpperCase()}"),
              backgroundColor: voteType == 'resolved' ? Colors.green : Colors.red
          )
      );

      // The stream listener will automatically switch viewState to 0 once the status updates

    } catch (e) {
      print("Vote Error: $e");
      // If error (e.g. already voted), just let them know
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

        // --- NEW: 2 BUTTONS SECTION ---
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
                  // BUTTON 1: HELP DONE
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
                  // BUTTON 2: FAKE REPORT
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: _viewState == 2 ? _buildCallerView() : (_viewState == 1 ? _buildResponderView() : _buildScanningView()),
    );
  }
}