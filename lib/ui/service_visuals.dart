/// Un servicio, un icono, un nombre corto. En un solo sitio.
///
/// Antes había **tres** tablas distintas para lo mismo: `_getIconData` en el
/// inicio, `_getServiceIcon` en el formulario y otro `_getServiceIcon` en el
/// seguimiento. El mismo servicio salía con tres dibujos diferentes según la
/// pantalla —enfermería era una tirita, un hospital y una cruz— y además
/// mezclaban familias: `Icons.healing` (relleno), `Icons.favorite_border`
/// (contorno) y `Icons.camera_enhance` en la misma rejilla.
///
/// Aquí la familia es una sola: **rounded**, rellena. Y los nombres son los que
/// una persona usaría en voz alta: «Médico», no «Atención Médica a Domicilio».
library;

import 'package:flutter/material.dart';

/// Iconos por `iconName` del catálogo (el campo que manda el servidor).
IconData serviceIconFor(String iconName, {String? serviceId}) {
  // El id manda sobre el `iconName` cuando existe: es más específico y no
  // depende de que el catálogo del servidor use la nomenclatura antigua.
  switch (serviceId) {
    case 'medico':
      return Icons.medical_services_rounded;
    case 'enfermeria':
      return Icons.vaccines_rounded;
    case 'kine_motora':
      return Icons.directions_walk_rounded;
    case 'kine_respiratoria':
      return Icons.air_rounded;
    case 'cuidados':
      return Icons.volunteer_activism_rounded;
    case 'ambulancia':
    case 'traslado_simple':
    case 'traslado_avanzado':
      return Icons.emergency_rounded;
    case 'radiologia':
      return Icons.personal_injury_rounded;
    case 'laboratorio':
      return Icons.biotech_rounded;
    case 'electrocardiograma':
      return Icons.monitor_heart_rounded;
  }

  switch (iconName) {
    case 'Activity':
      return Icons.vaccines_rounded;
    case 'UserRoundPlus':
      return Icons.medical_services_rounded;
    case 'Footprints':
      return Icons.directions_walk_rounded;
    case 'Lungs':
      return Icons.air_rounded;
    case 'HeartHandshake':
      return Icons.volunteer_activism_rounded;
    case 'Truck':
      return Icons.emergency_rounded;
    case 'ScanFace':
      return Icons.personal_injury_rounded;
    case 'FlaskConical':
      return Icons.biotech_rounded;
    case 'Heart':
      return Icons.monitor_heart_rounded;
    default:
      return Icons.health_and_safety_rounded;
  }
}

/// Nombre corto y hablado del servicio.
///
/// El catálogo trae «Procedimientos de Enfermería» y «Ambulancia de Transporte
/// Programado». Eso es cómo se llama el servicio en un contrato, no cómo se
/// llama cuando alguien lo necesita.
String serviceShortName(String serviceId, String fallback) {
  return switch (serviceId) {
    'medico' => 'Médico',
    'enfermeria' => 'Enfermería',
    'kine_motora' => 'Kinesiología',
    'kine_respiratoria' => 'Kinesiología respiratoria',
    'cuidados' => 'Cuidados en casa',
    'ambulancia' => 'Ambulancia',
    'radiologia' => 'Radiografía',
    'laboratorio' => 'Exámenes',
    'electrocardiograma' => 'Electrocardiograma',
    _ => fallback,
  };
}

/// Para qué sirve, en una línea que se lee de un vistazo.
///
/// Sustituye a los subtítulos de catálogo, que son correctos y nadie lee:
/// «Administración de medicamentos, curaciones, sondas e inyecciones.»
String serviceOneLiner(String serviceId, String fallback) {
  return switch (serviceId) {
    'medico' => 'Fiebre, dolor, malestar',
    'enfermeria' => 'Inyecciones y curaciones',
    'kine_motora' => 'Recuperar movilidad',
    'kine_respiratoria' => 'Despejar los pulmones',
    'cuidados' => 'Acompañamiento por horas',
    'ambulancia' => 'Traslado programado',
    'radiologia' => 'Rayos X en casa',
    'laboratorio' => 'Sangre y orina',
    'electrocardiograma' => 'Control del corazón',
    _ => fallback,
  };
}

/// Los servicios que van en la rejilla del inicio, en orden.
///
/// Seis y no nueve. Los tres que faltan —kinesiología respiratoria, radiografía
/// y electrocardiograma— no desaparecen: están en «Ver todos», a un toque. La
/// rejilla es para lo que se pide a diario; la lista completa, para lo que se
/// pide con una orden médica en la mano y ya se sabe cómo se llama.
const List<String> homeServiceIds = [
  'medico',
  'enfermeria',
  'kine_motora',
  'laboratorio',
  'cuidados',
  'ambulancia',
];

/// La espera típica, redondeada y en lenguaje llano.
///
/// El catálogo dice `'45 - 60'` y la app lo pintaba como «45 - 60 min». Un
/// rango de quince minutos no ayuda a decidir nada; «~45 min» sí.
String etaHint(String baseEta) {
  final first = baseEta.split('-').first.trim();
  final minutes = int.tryParse(first);
  if (minutes == null) return '';
  if (minutes >= 120) {
    final hours = (minutes / 60).round();
    return 'Desde $hours h';
  }
  return 'Desde $minutes min';
}
