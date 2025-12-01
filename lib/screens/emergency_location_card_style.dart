import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class EmergencyLocationCard extends StatefulWidget {
  final latlng.LatLng location;
  final DateTime timestamp;
  final String userId;
  final VoidCallback onRespond;
  final bool isOwnEmergency;

  const EmergencyLocationCard({
    super.key,
    required this.location,
    required this.timestamp,
    required this.userId,
    required this.onRespond,
    required this.isOwnEmergency,
  });

  @override
  State<EmergencyLocationCard> createState() => _EmergencyLocationCardState();
}

class _EmergencyLocationCardState extends State<EmergencyLocationCard> {
  late final MapController mapController;
  double? distance;
  latlng.LatLng? currentPosition;
  bool isMapReady = false;
  List<latlng.LatLng> routePoints = [];
  bool isRouting = false;
  String routingError = '';

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _initializeLocation();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // Hardcoded current position (green marker)
    final hardcodedCurrentPosition = latlng.LatLng(
      widget.location.latitude + 0.00001, // Approximately 1 meters north
      widget.location.longitude,
    );

    // Hardcoded distance calculation (0.1 meters)
    final hardcodedDistance = 1.0;

    setState(() {
      currentPosition = hardcodedCurrentPosition;
      distance = hardcodedDistance;
    });

    if (!widget.isOwnEmergency) {
      _getRoute(hardcodedCurrentPosition, widget.location);
    }

    if (isMapReady) _updateMapView();
  }

  Future<void> _getRoute(latlng.LatLng start, latlng.LatLng end) async {
    try {
      setState(() {
        isRouting = true;
        routingError = '';
      });

      // Create a simple straight line route for demo purposes
      final points = [start, end];

      setState(() {
        routePoints = points;
        isRouting = false;
      });
    } catch (e) {
      setState(() {
        routingError = 'Routing failed';
        isRouting = false;
      });
    }
  }

  void _updateMapView() {
    if (currentPosition == null) return;

    final points = [
      widget.location,
      currentPosition!,
    ];

    try {
      final bounds = LatLngBounds.fromPoints(points);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      final center = latlng.LatLng(
        (widget.location.latitude + currentPosition!.latitude) / 2,
        (widget.location.longitude + currentPosition!.longitude) / 2,
      );
      mapController.move(center, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: isRouting,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

              if (distance != null)
                Text(
                  widget.isOwnEmergency
                      ? 'You are at this location'
                      : 'Distance: ${distance!.toStringAsFixed(2)} meters',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),

              SizedBox(
                height: 200,
                child: _buildMapSection(),
              ),
              const SizedBox(height: 12),

              Text(
                'Location: ${widget.location.latitude.toStringAsFixed(5)}, '
                    '${widget.location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),

              Text(
                'Reported: ${DateFormat('MMM dd, yyyy - hh:mm a').format(widget.timestamp)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),

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
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentPosition ?? widget.location,
              initialZoom: 15.0,
              onMapReady: () {
                setState(() => isMapReady = true);
                if (currentPosition != null) {
                  _updateMapView();
                }
              },
            ),
            children: [
        TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.app',
        tileProvider: CancellableNetworkTileProvider(),
      ),

              if (routePoints.isNotEmpty && !widget.isOwnEmergency)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue.withOpacity(0.7),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: widget.location,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  if (currentPosition != null)
                    Marker(
                      width: 40,
                      height: 40,
                      point: currentPosition!,
                      child: Icon(
                        Icons.location_pin,
                        color: widget.isOwnEmergency ? Colors.red : Colors.green,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (isRouting)
            const Center(child: CircularProgressIndicator()),
          if (routingError.isNotEmpty && !widget.isOwnEmergency)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  routingError,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ),
        ],
      ),
    );
  }
}