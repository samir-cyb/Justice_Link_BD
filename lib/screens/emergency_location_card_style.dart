import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart'; // lightweight HTTP client

class EmergencyLocationCard extends StatefulWidget {
  final LatLng callerLocation; // emergency caller position
  final DateTime timestamp;
  final String userId;
  final VoidCallback onRespond;
  final bool isOwnEmergency;

  const EmergencyLocationCard({
    super.key,
    required this.callerLocation,
    required this.timestamp,
    required this.userId,
    required this.onRespond,
    required this.isOwnEmergency,
  });

  @override
  State<EmergencyLocationCard> createState() => _EmergencyLocationCardState();
}

class _EmergencyLocationCardState extends State<EmergencyLocationCard> {
  /* ------------- STATE ------------- */
  late final MapController _mapController;
  StreamSubscription<Position>? _positionStream;
  LatLng? _myPosition; // live responder position
  List<LatLng> _routePoints = [];
  double? _distance; // metres
  String? _eta; // human readable
  bool _isRouting = false;
  String _routingError = '';
  bool _mapReady = false;

  final Distance _distanceCalc = const Distance();
  final Dio _dio = Dio();

  /* ------------- LIFE-CYCLE ------------- */
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  /* ------------- LOCATION STREAM ------------- */
  Future<void> _startLocationStream() async {
    bool service = await Geolocator.isLocationServiceEnabled();
    if (!service) return;

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // refresh every 10 m moved
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPosition = newPos);
      _updateRouteAndMetadata();
      _updateCamera();
    });
  }

  /* ------------- ROUTING & METADATA ------------- */
  Future<void> _updateRouteAndMetadata() async {
    if (_myPosition == null) return;

    setState(() => _isRouting = true);

    try {
      // OSRM demo server – free, no key needed
      final url =
          'http://router.project-osrm.org/route/v1/driving/'
          '${_myPosition!.longitude},${_myPosition!.latitude};'
          '${widget.callerLocation.longitude},${widget.callerLocation.latitude}'
          '?overview=full&geometries=geojson';

      final res = await _dio.get(url);
      final geometry = res.data['routes'][0]['geometry'] as String;
      final distanceM = res.data['routes'][0]['distance'] as double; // metres
      final durationS = res.data['routes'][0]['duration'] as double; // seconds

      final points = _decodePolyline(geometry);

      setState(() {
        _routePoints = points;
        _distance = distanceM;
        _eta = _formatETA(durationS);
        _routingError = '';
        _isRouting = false;
      });
    } catch (e) {
      // fallback: straight line + crow-fly distance
      final straight = <LatLng>[_myPosition!, widget.callerLocation];
      setState(() {
        _routePoints = straight;
        _distance = _distanceCalc.as(LengthUnit.Meter, _myPosition!, widget.callerLocation);
        _eta = null;
        _routingError = 'Routing unavailable';
        _isRouting = false;
      });
    }
  }

  /* ------------- CAMERA ------------- */
  void _updateCamera() {
    if (!_mapReady || _myPosition == null) return;

    final bounds = LatLngBounds.fromPoints([_myPosition!, widget.callerLocation]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  /* ------------- HELPERS ------------- */
  // GeoJSON → LatLng list
  List<LatLng> _decodePolyline(String geoJson) {
    // OSRM returns GeoJSON LineString
    final coords = (geoJson.split(';').first.split(',').map(double.parse).toList());
    final List<LatLng> list = [];
    for (int i = 0; i < coords.length; i += 2) {
      list.add(LatLng(coords[i + 1], coords[i])); // lat, lon
    }
    return list;
  }

  String _formatETA(double seconds) {
    if (seconds < 60) return '${seconds.round()} s';
    final min = (seconds / 60).round();
    return '$min min';
  }

  /* ------------- UI ------------- */
  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isRouting,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.red.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isOwnEmergency ? 'YOUR EMERGENCY' : 'NEARBY EMERGENCY',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              // Live distance + ETA
              if (_distance != null)
                Text(
                  widget.isOwnEmergency
                      ? 'You are at this location'
                      : 'Distance: ${_distance!.toStringAsFixed(0)} m'
                      '${_eta == null ? '' : '  •  ETA: $_eta'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),

              // Map
              SizedBox(
                height: 200,
                child: _buildMapSection(),
              ),
              const SizedBox(height: 12),

              // Coordinates
              Text(
                'Caller: ${widget.callerLocation.latitude.toStringAsFixed(5)}, '
                    '${widget.callerLocation.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                'Reported: ${DateFormat('MMM dd, yyyy – hh:mm a').format(widget.timestamp)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Respond button (only for responders)
              if (!widget.isOwnEmergency)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onRespond,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'RESPOND TO EMERGENCY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.callerLocation,
              initialZoom: 15,
              onMapReady: () {
                _mapReady = true;
                if (_myPosition != null) _updateCamera();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.justicelink.user',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => _launchUrl('https://openstreetmap.org/copyright'),
                  ),
                ],
              ),
              if (_routePoints.isNotEmpty && !widget.isOwnEmergency)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.withOpacity(0.8),
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Caller (RED)
                  Marker(
                    width: 40,
                    height: 40,
                    point: widget.callerLocation,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  // Responder (GREEN) – only if we have a fix
                  if (_myPosition != null)
                    Marker(
                      width: 40,
                      height: 40,
                      point: _myPosition!,
                      child: Icon(
                        Icons.navigation,
                        color: widget.isOwnEmergency ? Colors.red : Colors.green,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isRouting)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_routingError.isNotEmpty && !widget.isOwnEmergency)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _routingError,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}