import 'dart:convert';
import 'package:aura/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Live tracking map that replaces the old `MockRoutePainter` canvas. It shows
/// the patient's home and the professional's real position on OpenStreetMap
/// tiles, draws the driving route between them (OSRM, with a straight-line
/// fallback) and reports the real remaining distance and ETA.
class TrackingMap extends StatefulWidget {
  final double? patientLat;
  final double? patientLng;
  final String addressText;
  final double? professionalLat;
  final double? professionalLng;
  final double height;

  const TrackingMap({
    super.key,
    required this.addressText,
    this.patientLat,
    this.patientLng,
    this.professionalLat,
    this.professionalLng,
    this.height = 200,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  AppPalette get p => context.palette;
  final MapController _mapController = MapController();

  LatLng? _home;
  LatLng? _pro;
  List<LatLng> _route = const [];
  double? _distanceKm;
  int? _etaMin;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _pro = _proFromWidget();
    _resolveHome();
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The professional's live GPS arrives via SSE and rebuilds this widget.
    if (widget.professionalLat != oldWidget.professionalLat ||
        widget.professionalLng != oldWidget.professionalLng) {
      _pro = _proFromWidget();
      _refreshRoute();
      _fitCamera();
    }
    if (widget.patientLat != oldWidget.patientLat ||
        widget.patientLng != oldWidget.patientLng ||
        widget.addressText != oldWidget.addressText) {
      _resolveHome();
    }
  }

  LatLng? _proFromWidget() {
    if (widget.professionalLat != null && widget.professionalLng != null) {
      return LatLng(widget.professionalLat!, widget.professionalLng!);
    }
    return null;
  }

  Future<void> _resolveHome() async {
    if (widget.patientLat != null && widget.patientLng != null) {
      _home = LatLng(widget.patientLat!, widget.patientLng!);
    } else {
      // Older bookings stored no coordinates: geocode the address string.
      try {
        final results = await Geocoding().locationFromAddress(widget.addressText);
        if (results.isNotEmpty) {
          _home = LatLng(results.first.latitude, results.first.longitude);
        }
      } catch (e) {
        debugPrint('Home geocoding failed: $e');
      }
    }
    if (!mounted) return;
    setState(() {});
    _refreshRoute();
    _fitCamera();
  }

  Future<void> _refreshRoute() async {
    final home = _home;
    final pro = _pro;
    if (home == null || pro == null) {
      if (mounted) setState(() => _route = const []);
      return;
    }

    // Try OSRM for a real driving route + duration; fall back to a straight line.
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pro.longitude},${pro.latitude};${home.longitude},${home.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final coords = (route['geometry']['coordinates'] as List<dynamic>)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          final meters = (route['distance'] as num).toDouble();
          final seconds = (route['duration'] as num).toDouble();
          if (!mounted) return;
          setState(() {
            _route = coords;
            _distanceKm = meters / 1000;
            _etaMin = (seconds / 60).ceil();
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('OSRM routing failed, using straight line: $e');
    }

    // Fallback: straight segment with haversine distance and a ~30 km/h estimate.
    final meters = const Distance().as(LengthUnit.Meter, pro, home);
    if (!mounted) return;
    setState(() {
      _route = [pro, home];
      _distanceKm = meters / 1000;
      _etaMin = (meters / 1000 / 30 * 60).ceil();
    });
  }

  void _fitCamera() {
    if (!_mapReady) return;
    final points = <LatLng>[
      ?_home,
      ?_pro,
      ..._route,
    ];
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(36),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final center = _home ?? _pro ?? const LatLng(-34.6037, -58.3816);
    final hasAny = _home != null || _pro != null;

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    _fitCamera();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aura.salud',
                  ),
                  if (_route.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route,
                          strokeWidth: 4,
                          color: p.accent,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_home != null)
                        Marker(
                          point: _home!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.home, color: Color(0xFFF43F5E), size: 30),
                        ),
                      if (_pro != null)
                        Marker(
                          point: _pro!,
                          width: 44,
                          height: 44,
                          child: const _ProfessionalMarker(),
                        ),
                    ],
                  ),
                ],
              ),

              if (!hasAny)
                Container(
                  color: context.palette.fill,
                  alignment: Alignment.center,
                  child: Text(
                    'Ubicando al profesional…',
                    style: TextStyle(fontSize: 11, color: context.palette.textMuted),
                  ),
                ),

              Positioned(
                left: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  color: Colors.white70,
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 7, color: Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Real distance + ETA read-out
        if (_distanceKm != null)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.route, color: p.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${_distanceKm!.toStringAsFixed(1)} km restantes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: context.palette.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time, color: p.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  _pro == null
                      ? 'Esperando GPS'
                      : '≈ ${_etaMin ?? '--'} min',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: context.palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfessionalMarker extends StatelessWidget {
  const _ProfessionalMarker();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.accent,
        shape: BoxShape.circle,
        border: Border.all(color: p.card, width: 3),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.local_shipping, color: p.card, size: 18),
    );
  }
}
