import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Selector de ubicación sobre OpenStreetMap, en lugar del antiguo lienzo
/// `MockMapPainter`.
///
/// La persona mueve el mapa bajo una chincheta fija —o toca «Mi ubicación» para
/// saltar al GPS del teléfono—: el centro del mapa es el punto elegido, y se
/// traduce a una dirección legible por geocodificación inversa.
class MapLocationPicker extends StatefulWidget {
  final LatLng initialCenter;
  final double height;
  final Color? accentColor;

  /// Si se intenta centrar en el GPS del teléfono en cuanto carga el mapa.
  final bool autoLocateOnInit;

  /// Se dispara (con retardo) cuando el punto elegido se asienta, con la
  /// dirección resuelta si se pudo obtener.
  final void Function(LatLng point, String? address) onLocationChanged;

  const MapLocationPicker({
    super.key,
    required this.onLocationChanged,
    this.initialCenter = const LatLng(-34.6037, -58.3816), // Buenos Aires
    this.height = 200,
    this.accentColor,
    this.autoLocateOnInit = false,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  AppPalette get p => context.palette;
  final MapController _mapController = MapController();
  late LatLng _center = widget.initialCenter;
  bool _locating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.autoLocateOnInit) {
      // Solo salta si el permiso ya estaba concedido; al cargar no pregunta.
      WidgetsBinding.instance.addPostFrameCallback((_) => _locateMe(silent: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onCenterSettled(LatLng point) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final address = await _reverseGeocode(point);
      if (!mounted) return;
      widget.onLocationChanged(point, address);
    });
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(point.latitude, point.longitude);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final parts = <String>[
        if ((p.street ?? '').isNotEmpty) p.street!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return null;
    }
  }

  Future<void> _locateMe({bool silent = false}) async {
    if (!silent) setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (silent) return;
        _showMessage('Activa el GPS del teléfono para usar tu ubicación.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return; // En el intento silencioso no se pregunta nada.
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) {
          _showMessage(
            'No tenemos permiso para usar tu ubicación. Puedes mover el mapa '
            'para marcar el punto.',
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      _mapController.move(target, 16);
      setState(() => _center = target);
      _onCenterSettled(target);
    } catch (e) {
      debugPrint('Geolocation failed: $e');
      if (!silent) {
        _showMessage(
          'No pudimos obtener tu ubicación. Mueve el mapa para marcar el punto.',
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _locating = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? p.accent;

    return ClipRRect(
      borderRadius: AuraRadius.allMd,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: (camera, hasGesture) {
                  _center = camera.center;
                  if (hasGesture) _onCenterSettled(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aura.salud',
                ),
              ],
            ),

            // Chincheta fija: su punta marca la coordenada elegida.
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Semantics(
                image: true,
                label: 'El punto elegido es el centro del mapa.',
                child: Icon(
                  Icons.location_on_rounded,
                  color: accentColor,
                  size: 40,
                ),
              ),
            ),

            Positioned(
              right: AuraSpace.xs,
              bottom: AuraSpace.xs,
              child: _locateButton(accentColor),
            ),

            _attribution(),
          ],
        ),
      ),
    );
  }

  /// Botón de «mi ubicación».
  ///
  /// Mide 44 px. Antes era un icono de 18 con 8 px de relleno: 34 px de lado,
  /// flotando sobre un mapa que se arrastra con el dedo, así que fallar el
  /// toque no hacía nada o movía el mapa y cambiaba la dirección elegida.
  Widget _locateButton(Color accentColor) {
    return Material(
      color: p.card,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: 'Usar mi ubicación',
        child: Semantics(
          button: true,
          enabled: !_locating,
          label: 'Usar mi ubicación',
          child: ExcludeSemantics(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _locating ? null : () => _locateMe(),
              child: SizedBox(
                width: AuraTap.min,
                height: AuraTap.min,
                child: Center(
                  child: _locating
                      ? SizedBox(
                          height: AuraIcon.sm,
                          width: AuraIcon.sm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        )
                      : Icon(
                          Icons.my_location_rounded,
                          color: accentColor,
                          size: AuraIcon.md,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
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
}
