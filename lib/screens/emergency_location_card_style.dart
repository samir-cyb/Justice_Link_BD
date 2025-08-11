import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  Position? currentPosition;
  bool isLoading = true;
  String locationError = '';
  bool isMapReady = false;
  List<latlng.LatLng> routePoints = [];
  bool isRouting = false;
  String routingError = '';

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _getCurrentLocation();
  }

  // Validate if coordinates are within acceptable ranges
  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationError = 'Location services are disabled';
          isLoading = false;
        });
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission != LocationPermission.whileInUse &&
            newPermission != LocationPermission.always) {
          setState(() {
            locationError = 'Location permissions denied';
            isLoading = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      if (!_isValidCoordinate(position.latitude, position.longitude)) {
        setState(() {
          locationError = 'Invalid current location coordinates';
          isLoading = false;
        });
        return;
      }

      setState(() {
        currentPosition = position;
        distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.location.latitude,
          widget.location.longitude,
        );
        isLoading = false;
      });

      // Fetch the route between current location and emergency location
      _getRoute(
        latlng.LatLng(position.latitude, position.longitude),
        widget.location,
      );

      // Only update map view if map is ready
      if (isMapReady) {
        _updateMapView();
      }
    } catch (e) {
      setState(() {
        locationError = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _getRoute(latlng.LatLng start, latlng.LatLng end) async {
    if (!_isValidCoordinate(start.latitude, start.longitude) ||
        !_isValidCoordinate(end.latitude, end.longitude)) {
      return;
    }

    setState(() {
      isRouting = true;
      routingError = '';
    });

    try {
      // OSRM API endpoint for driving route
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}'
            '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final geometry = routes[0]['geometry'];
            if (geometry != null && geometry['type'] == 'LineString') {
              final coordinates = geometry['coordinates'] as List;
              final points = coordinates.map((coord) {
                return latlng.LatLng(
                  coord[1].toDouble(), // latitude
                  coord[0].toDouble(), // longitude
                );
              }).toList();

              setState(() {
                routePoints = points;
                isRouting = false;
              });
              return;
            }
          }
        }
      }
      setState(() {
        routingError = 'Route not available';
        isRouting = false;
      });
    } catch (e) {
      setState(() {
        routingError = 'Routing error: ${e.toString()}';
        isRouting = false;
      });
    }
  }

  void _updateMapView() {
    if (currentPosition == null) return;

    // Create list of points for bounds
    final points = [
      widget.location,
      latlng.LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      ),
    ];

    // Check if all points are valid
    if (points.every((p) => _isValidCoordinate(p.latitude, p.longitude))) {
      try {
        // Create bounds using flutter_map's LatLngBounds
        final bounds = LatLngBounds(
          points[0], // southwest
          points[1], // northeast
        );

        // Use fitCamera for newer versions of flutter_map
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      } catch (e) {
        // Fallback for older versions or if fitCamera fails
        final lats = points.map((p) => p.latitude).toList();
        final lngs = points.map((p) => p.longitude).toList();
        final minLat = lats.reduce((a, b) => a < b ? a : b);
        final maxLat = lats.reduce((a, b) => a > b ? a : b);
        final minLng = lngs.reduce((a, b) => a < b ? a : b);
        final maxLng = lngs.reduce((a, b) => a > b ? a : b);
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;
        final latSpan = maxLat - minLat;
        final lngSpan = maxLng - minLng;
        final span = latSpan > lngSpan ? latSpan : lngSpan;
        double zoom;
        if (span < 0.005) {
          zoom = 15;
        } else if (span < 0.02) {
          zoom = 14;
        } else if (span < 0.05) {
          zoom = 13;
        } else if (span < 0.1) {
          zoom = 12;
        } else if (span < 0.5) {
          zoom = 10;
        } else {
          zoom = 8;
        }
        mapController.move(latlng.LatLng(centerLat, centerLng), zoom);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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

            // Distance Information
            if (distance != null)
              Text(
                'Distance: ${(distance! / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (locationError.isNotEmpty)
              Text(
                locationError,
                style: const TextStyle(color: Colors.orange),
              ),
            const SizedBox(height: 8),

            // Map Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: _buildMapSection(),
            ),
            const SizedBox(height: 12),

            // Location Coordinates
            Text(
              'Location: ${widget.location.latitude.toStringAsFixed(5)}, '
                  '${widget.location.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),

            // Timestamp
            Text(
              'Reported: ${DateFormat('MMM dd, yyyy - hh:mm a').format(widget.timestamp)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // Respond Button
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
    );
  }

  Widget _buildMapSection() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (locationError.isNotEmpty) {
      return Center(
        child: Text(
          'Map unavailable\n$locationError',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.orange),
        ),
      );
    }

    final emergencyLocationValid = _isValidCoordinate(
      widget.location.latitude,
      widget.location.longitude,
    );

    if (!emergencyLocationValid) {
      return const Center(
        child: Text(
          'Invalid emergency location',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: widget.location,
            initialZoom: 13.0,
            onMapReady: () {
              // Set flag that map is ready
              setState(() => isMapReady = true);

              // Update map view if we have current position
              if (currentPosition != null) {
                _updateMapView();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            // Route polyline
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Colors.blue,
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
                    point: latlng.LatLng(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                    ),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (isRouting)
          const Center(child: CircularProgressIndicator()),
        if (routingError.isNotEmpty)
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
    );
  }
}