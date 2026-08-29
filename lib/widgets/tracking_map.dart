import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Mapa de seguimiento en vivo, en lugar del antiguo lienzo `MockRoutePainter`.
///
/// Muestra el domicilio del paciente y la posición real del profesional sobre
/// las teselas de OpenStreetMap, dibuja la ruta entre ambos (OSRM, con una
/// recta como respaldo) e informa de la distancia y el tiempo que quedan de
/// verdad.
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
    // El GPS del profesional llega por SSE y reconstruye este widget.
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
      // Las solicitudes antiguas no guardaban coordenadas: hay que geocodificar
      // el texto de la dirección.
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

    // Primero OSRM, que da la ruta de conducción y su duración reales; si falla,
    // se cae a una recta.
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

    // Respaldo: segmento recto, distancia por haversine y una estimación a
    // unos 30 km/h.
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
                          width: 44,
                          height: 44,
                          child: const _MapPin(
                            icon: Icons.home_rounded,
                            semanticLabel: 'Tu domicilio',
                            destination: true,
                          ),
                        ),
                      if (_pro != null)
                        Marker(
                          point: _pro!,
                          width: 44,
                          height: 44,
                          child: const _MapPin(
                            icon: Icons.local_shipping_rounded,
                            semanticLabel: 'El profesional',
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              if (!hasAny)
                Container(
                  color: p.fill,
                  alignment: Alignment.center,
                  child: const AuraLoading(
                    message: 'Ubicando al profesional en el mapa…',
                  ),
                ),

              _attribution(),
            ],
          ),
        ),

        if (_distanceKm != null) _readout(),
      ],
    );
  }

  /// Atribución obligatoria por la política de uso de las teselas.
  Widget _attribution() {
    return Positioned(
      left: AuraSpace.xxs,
      bottom: AuraSpace.xxxs,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.xxs,
          vertical: AuraSpace.xxxs,
        ),
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: 0.88),
          borderRadius: AuraRadius.allXs,
        ),
        child: Text(
          '© OpenStreetMap',
          style: AppType.label.copyWith(color: p.textSecondary),
        ),
      ),
    );
  }

  /// Cuánto falta, en distancia y en tiempo.
  Widget _readout() {
    final distance = '${_distanceKm!.toStringAsFixed(1)} km';
    final eta = _pro == null
        ? 'Esperando la señal'
        : '${_etaMin ?? '--'} min';

    return Padding(
      padding: const EdgeInsets.all(AuraSpace.sm),
      child: Semantics(
        liveRegion: true,
        label: _pro == null
            ? 'Faltan $distance. Todavía no llega la señal del profesional.'
            : 'Faltan $distance, unos $eta.',
        child: ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: _ReadoutItem(
                  icon: Icons.route_rounded,
                  text: '$distance por recorrer',
                ),
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                child: _ReadoutItem(
                  icon: Icons.access_time_rounded,
                  text: _pro == null ? eta : 'Llega en unos $eta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadoutItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReadoutItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, color: p.accent, size: AuraIcon.sm),
        const SizedBox(width: AuraSpace.xxs),
        Flexible(
          child: Text(
            text,
            style: AppType.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Marca del mapa.
///
/// Los dos puntos comparten forma y se separan por icono además de por color:
/// sobre las teselas de OpenStreetMap, distinguirlos solo por el tono era
/// pedirle a la persona que acertara con dos círculos de tamaño de moneda.
class _MapPin extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;

  /// El domicilio, en el color de destino; en falso, el profesional en camino.
  final bool destination;

  const _MapPin({
    required this.icon,
    required this.semanticLabel,
    this.destination = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destination ? p.error : p.accent;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: p.card, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: p.card, size: AuraIcon.sm),
      ),
    );
  }
}
