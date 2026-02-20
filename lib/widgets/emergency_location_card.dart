import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyLocationCard extends StatefulWidget {
  final LatLng callerLocation;
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

class _EmergencyLocationCardState extends State<EmergencyLocationCard>
    with TickerProviderStateMixin {

  late final AnimatedMapController _animatedMapController;
  MapController get _mapController => _animatedMapController.mapController;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  LatLng? _myPosition;
  double? _myHeading;
  double? _smoothedHeading;
  List<LatLng> _positionHistory = [];
  List<LatLng> _routePoints = [];
  double? _distance;
  String? _eta;
  bool _isRouting = false;
  String _routingError = '';
  bool _mapReady = false;

  // User details
  Map<String, dynamic>? _callerUserDetails;
  bool _loadingUserDetails = false;

  DateTime? _lastRouteCalc;
  static const _minRouteCalcInterval = Duration(seconds: 5);
  double? _lastDistanceToRoute;
  static const _maxDeviationMeters = 50.0;

  final Distance _distanceCalc = const Distance();
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    developer.log('🔵 EmergencyLocationCard: INITSTATE');

    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    _initializeServices();
    _fetchCallerDetails(); // Fetch user details
  }

  // FIX: Fetch caller details using 'uid' column instead of 'id'
  Future<void> _fetchCallerDetails() async {
    if (widget.userId.isEmpty || widget.isOwnEmergency) return;

    developer.log('🔍 Fetching caller details for uid: ${widget.userId}');

    setState(() => _loadingUserDetails = true);

    try {
      // FIX: Use 'uid' column to match your database schema
      final response = await _supabase
          .from('users')
          .select('full_name, phone_number')
          .eq('uid', widget.userId)  // <-- FIXED: was 'id', now 'uid'
          .maybeSingle();

      developer.log('📊 Supabase response: $response');

      if (mounted && response != null) {
        setState(() {
          _callerUserDetails = response;
          _loadingUserDetails = false;
        });
        developer.log('✅ Caller details fetched: ${response['full_name']}');
      } else {
        developer.log('⚠️ No user found for uid: ${widget.userId}');
        if (mounted) setState(() => _loadingUserDetails = false);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error fetching caller details: $e');
      developer.log('   Stack: $stackTrace');
      if (mounted) setState(() => _loadingUserDetails = false);
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _startLocationStream();
      _startCompassStream();
    } catch (e) {
      developer.log('Service init error: $e');
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _positionStream?.cancel();
    _compassStream?.cancel();
    _animatedMapController.dispose();
    super.dispose();
  }

  void _startCompassStream() {
    if (FlutterCompass.events == null) return;

    _compassStream = FlutterCompass.events!.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) _updateSmoothedHeading(heading);
    });
  }

  void _updateSmoothedHeading(double newHeading) {
    if (_smoothedHeading == null) {
      _smoothedHeading = newHeading;
    } else {
      double diff = newHeading - _smoothedHeading!;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      _smoothedHeading = (_smoothedHeading! + diff * 0.2) % 360;
      if (_smoothedHeading! < 0) _smoothedHeading = _smoothedHeading! + 360;
    }

    if (mounted) setState(() => _myHeading = _smoothedHeading);
  }

  Future<void> _startLocationStream() async {
    bool service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      setState(() => _routingError = 'Location service disabled');
      return;
    }

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    try {
      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (!mounted) return;

      setState(() {
        _myPosition = LatLng(initialPos.latitude, initialPos.longitude);
        _positionHistory = [_myPosition!];
      });

      await _updateRouteAndMetadata();
      _centerCameraOnUser();
    } catch (e) {
      developer.log('Initial position error: $e');
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      if (!mounted) return;

      final newPos = LatLng(pos.latitude, pos.longitude);
      _positionHistory.add(newPos);
      if (_positionHistory.length > 3) _positionHistory.removeAt(0);

      setState(() => _myPosition = newPos);

      if (_myHeading == null && _positionHistory.length >= 2) {
        _calculateHeadingFromMovement();
      }

      _centerCameraOnUser();
      _checkRouteRecalculation();
    });
  }

  void _calculateHeadingFromMovement() {
    if (_positionHistory.length < 2) return;
    final from = _positionHistory[_positionHistory.length - 2];
    final to = _positionHistory.last;
    final distance = _distanceCalc.as(LengthUnit.Meter, from, to);
    if (distance < 2.0) return;

    final heading = _calculateBearing(from, to);
    _updateSmoothedHeading(heading);
  }

  void _centerCameraOnUser() {
    if (!_mapReady || _myPosition == null) return;
    final targetRotation = _myHeading ?? 0.0;

    _animatedMapController.animateTo(
      dest: _myPosition!,
      zoom: 18,
      rotation: targetRotation,
    );
  }

  void _checkRouteRecalculation() {
    if (_myPosition == null || _routePoints.isEmpty || widget.isOwnEmergency) return;

    final now = DateTime.now();
    if (_lastRouteCalc != null && now.difference(_lastRouteCalc!) < _minRouteCalcInterval) return;

    final distanceToRoute = _calculateDistanceToRoute(_myPosition!, _routePoints);
    if (distanceToRoute > _maxDeviationMeters) {
      _updateRouteAndMetadata();
    }
  }

  double _calculateDistanceToRoute(LatLng point, List<LatLng> route) {
    if (route.length < 2) return double.infinity;
    double minDistance = double.infinity;

    for (int i = 0; i < route.length - 1; i++) {
      final distance = _distanceToSegment(point, route[i], route[i + 1]);
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final latFactor = math.cos(p.latitude * math.pi / 180);
    final px = p.longitude * latFactor;
    final py = p.latitude;
    final ax = a.longitude * latFactor;
    final ay = a.latitude;
    final bx = b.longitude * latFactor;
    final by = b.latitude;

    final abx = bx - ax;
    final aby = by - ay;
    final abLengthSq = abx * abx + aby * aby;

    if (abLengthSq == 0) return _distanceCalc.as(LengthUnit.Meter, p, a);

    var t = ((px - ax) * abx + (py - ay) * aby) / abLengthSq;
    t = t.clamp(0.0, 1.0);

    final closestPoint = LatLng(
      ay + t * aby,
      (ax + t * abx) / latFactor,
    );

    return _distanceCalc.as(LengthUnit.Meter, p, closestPoint);
  }

  Future<void> _updateRouteAndMetadata() async {
    if (_myPosition == null) return;

    setState(() => _isRouting = true);

    final straightDistance = _distanceCalc.as(
      LengthUnit.Meter,
      _myPosition!,
      widget.callerLocation,
    );

    try {
      final points = await _tryOSRM();

      if (points != null && points.isNotEmpty) {
        final distanceM = straightDistance;
        final durationS = (distanceM / 1.4);

        if (!mounted) return;

        setState(() {
          _routePoints = points;
          _distance = distanceM;
          _eta = _formatETA(durationS);
          _routingError = points.length <= 2 ? 'Direct path' : '';
          _isRouting = false;
        });

        _lastRouteCalc = DateTime.now();
      } else {
        throw Exception('No route points');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _routePoints = [_myPosition!, widget.callerLocation];
        _distance = straightDistance;
        _eta = null;
        _routingError = 'Direct path';
        _isRouting = false;
      });
    }
  }

  Future<List<LatLng>?> _tryOSRM() async {
    _cancelToken = CancelToken();

    try {
      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${_myPosition!.longitude},${_myPosition!.latitude};'
          '${widget.callerLocation.longitude},${widget.callerLocation.latitude}'
          '?overview=full&geometries=geojson';

      final res = await _dio.get(
        url,
        cancelToken: _cancelToken,
        options: Options(
          validateStatus: (status) => true,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) return null;
      if (res.data == null || res.data['code'] != 'Ok') return null;

      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final geometry = routes[0]['geometry'];
      if (geometry == null) return null;

      final coordinates = geometry['coordinates'] as List?;
      if (coordinates == null) return null;

      return coordinates.map((coord) {
        return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
      }).toList();

    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatETA(double seconds) {
    if (seconds < 60) return '${seconds.round()} s';
    final min = (seconds / 60).round();
    if (min < 60) return '$min min';
    final hours = (min / 60).floor();
    final remainingMin = min % 60;
    return '$hours h ${remainingMin}m';
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  // Build caller info widget
  Widget _buildCallerInfo() {
    if (widget.isOwnEmergency) {
      return const SizedBox.shrink();
    }

    if (_loadingUserDetails) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading caller info...', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
    }

    if (_callerUserDetails == null) {
      // Show unknown if lookup failed but we're not loading
      return Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.person_off, color: Colors.grey, size: 16),
            SizedBox(width: 6),
            Text(
              'Caller: Unknown',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final name = _callerUserDetails!['full_name'] ?? 'Unknown';
    final phone = _callerUserDetails!['phone_number'] ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Caller: $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  phone,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () async {
                  if (phone.isNotEmpty) {
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CALL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isRouting,
      child: Card(
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.red.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Compact
              Row(
                children: [
                  Icon(
                    widget.isOwnEmergency ? Icons.warning : Icons.emergency,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isOwnEmergency ? 'YOUR EMERGENCY' : 'NEARBY EMERGENCY',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Caller Info
              _buildCallerInfo(),

              // Distance & ETA - Compact
              if (_distance != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('DISTANCE', style: TextStyle(color: Colors.white70, fontSize: 8)),
                          Text(
                            '${_distance!.toStringAsFixed(0)} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_eta != null) ...[
                        Container(width: 1, height: 20, color: Colors.white24),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('ETA', style: TextStyle(color: Colors.white70, fontSize: 8)),
                            Text(
                              _eta!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],

              if (_routingError.isNotEmpty)
                Text(
                  '⚠️ $_routingError',
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                ),

              const SizedBox(height: 6),

              // Map - INCREASED height
              SizedBox(
                height: 280,
                child: _buildMapSection(),
              ),
              const SizedBox(height: 6),

              // Coordinates - Compact
              Text(
                '📍 Caller: ${widget.callerLocation.latitude.toStringAsFixed(5)}, ${widget.callerLocation.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              if (_myPosition != null) ...[
                Text(
                  '📍 You: ${_myPosition!.latitude.toStringAsFixed(5)}, ${_myPosition!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
                if (_myHeading != null)
                  Text(
                    '🧭 ${_myHeading!.toStringAsFixed(0)}° ${_getDirectionText(_myHeading!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
              ],
              Text(
                '🕐 ${DateFormat('MMM dd, hh:mm a').format(widget.timestamp)}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              const SizedBox(height: 6),

              // Buttons - Compact
              if (!widget.isOwnEmergency && _myPosition != null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _centerCameraOnUser(),
                        icon: const Icon(Icons.my_location, size: 14),
                        label: const Text('RECENTER', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onRespond(),
                        icon: const Icon(Icons.emergency, size: 14),
                        label: const Text('RESPOND', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDirectionText(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    return 'NW';
  }

  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.callerLocation,
              initialZoom: 15,
              onMapReady: () {
                setState(() => _mapReady = true);
                if (_myPosition != null) _centerCameraOnUser();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.justicelink.user',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap',
                    onTap: () => _launchUrl('https://openstreetmap.org/copyright'),
                  ),
                ],
              ),

              if (_routePoints.isNotEmpty && !widget.isOwnEmergency)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.withOpacity(0.9),
                      strokeWidth: 4,
                      borderStrokeWidth: 1,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // Caller marker
                  Marker(
                    width: 36,
                    height: 36,
                    point: widget.callerLocation,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                  // Responder marker - SMALL arrow
                  if (_myPosition != null)
                    Marker(
                      width: 32,
                      height: 32,
                      point: _myPosition!,
                      rotate: true,
                      child: _buildRotatingArrow(),
                    ),
                ],
              ),
            ],
          ),

          if (_isRouting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text('Loading...', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRotatingArrow() {
    double rotationAngle = 0;

    if (_myHeading != null) {
      rotationAngle = (_myHeading! * math.pi / 180);
    } else if (_positionHistory.length >= 2) {
      final from = _positionHistory[_positionHistory.length - 2];
      final to = _positionHistory.last;
      final bearing = _calculateBearing(from, to);
      rotationAngle = (bearing * math.pi / 180);
    }

    return AnimatedRotation(
      turns: rotationAngle / (2 * math.pi),
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: widget.isOwnEmergency ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 3),
          ],
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}