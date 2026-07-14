import 'dart:async';
import 'package:aura/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Interactive OpenStreetMap location picker that replaces the old
/// `MockMapPainter` canvas. The user pans the real map beneath a fixed centre
/// pin (or taps "Mi ubicación" to jump to their device GPS); the map centre is
/// the selected coordinate and is reverse-geocoded into a human address.
class MapLocationPicker extends StatefulWidget {
  final LatLng initialCenter;
  final double height;
  final Color? accentColor;

  /// Whether to try centring on the device GPS as soon as the map loads.
  final bool autoLocateOnInit;

  /// Fired (debounced) whenever the selected point settles, with the reverse
  /// geocoded address when one could be resolved.
  final void Function(LatLng point, String? address) onLocationChanged;

  MapLocationPicker({
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
      // Only jumps if permission is already granted; never prompts on load.
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
        _showMessage('Active el GPS del dispositivo para usar su ubicación.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return; // Don't prompt on silent auto-locate
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _showMessage('Permiso de ubicación denegado.');
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
      if (!silent) _showMessage('No se pudo obtener la ubicación.');
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
    final p = context.palette;
    final accentColor = widget.accentColor ?? p.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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

            // Fixed centre pin: its tip marks the selected coordinate.
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Icon(Icons.location_on, color: accentColor, size: 40),
            ),

            // "My location" button
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: p.card,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _locating ? null : () => _locateMe(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _locating
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          )
                        : Icon(Icons.my_location, color: accentColor, size: 18),
                  ),
                ),
              ),
            ),

            // OSM attribution (required by the tile usage policy)
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
    );
  }
}
