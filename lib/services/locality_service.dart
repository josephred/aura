import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// En qué punto está la resolución de la ubicación.
///
/// Se distinguen los motivos de fallo porque la salida es distinta en cada
/// caso: si falta el permiso hay que pedirlo, si el GPS está apagado hay que
/// mandar a ajustes, y si simplemente no se pudo geocodificar basta reintentar.
enum LocalityStatus {
  /// Todavía no se ha intentado.
  idle,
  locating,
  ready,

  /// El usuario denegó el permiso esta vez.
  denied,

  /// Denegado permanentemente: solo se arregla desde los ajustes del sistema.
  deniedForever,

  /// El GPS del dispositivo está apagado.
  serviceDisabled,

  /// Hubo posición pero no se pudo traducir a un nombre de lugar.
  failed,
}

/// Resultado de resolver dónde está el usuario.
class LocalityResult {
  final LocalityStatus status;
  final String? locality;
  final double? latitude;
  final double? longitude;

  const LocalityResult(this.status, {this.locality, this.latitude, this.longitude});
}

/// Traduce la posición del dispositivo en el nombre de la comuna.
///
/// Es la comuna —no la calle— lo que interesa: es la unidad con la que el
/// servidor reparte las solicitudes (`DispatchZoneService`) y calcula el tiempo
/// de espera del sector.
class LocalityService {
  const LocalityService();

  /// Obtiene la comuna actual.
  ///
  /// Con [askPermission] en false no muestra ningún diálogo: sirve para el
  /// refresco silencioso al abrir la app, donde pedir permiso de golpe sin que
  /// el usuario haya tocado nada es intrusivo. La cabecera lo pide cuando la
  /// persona toca el indicador.
  Future<LocalityResult> resolve({bool askPermission = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocalityResult(LocalityStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (!askPermission) {
          return const LocalityResult(LocalityStatus.denied);
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocalityResult(LocalityStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocalityResult(LocalityStatus.denied);
      }

      // Precisión media y no alta: para nombrar una comuna sobra, y evita
      // tener el GPS encendido más tiempo del necesario.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final locality = await _localityFor(position.latitude, position.longitude);

      return LocalityResult(
        locality == null ? LocalityStatus.failed : LocalityStatus.ready,
        locality: locality,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('LocalityService.resolve failed: $e');
      return const LocalityResult(LocalityStatus.failed);
    }
  }

  /// Nombre de la comuna a partir de unas coordenadas.
  ///
  /// El campo correcto varía por país: en Chile la comuna llega en `locality`,
  /// pero en direcciones urbanas densas a veces aparece en `subLocality`, y en
  /// zonas rurales solo hay `subAdministrativeArea`. De ahí la cadena de
  /// alternativas en vez de leer un único campo.
  Future<String?> _localityFor(double lat, double lng) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;

      final p = marks.first;
      for (final candidate in [
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
      ]) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint('LocalityService reverse geocoding failed: $e');
      return null;
    }
  }
}
