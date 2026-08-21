import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// A.3 — guía de ayuda paso a paso para el primer ingreso.
///
/// Los videotutoriales están previstos pero **aún no existen**: falta decidir
/// dónde se alojan. El punto de enchufe es el campo `video` de cada paso: en
/// cuanto tenga una URL, ese paso muestra un botón de reproducción real. Hasta
/// entonces la guía no anuncia un video que nadie puede ver.
class VideoOnboardingDialog extends StatefulWidget {
  const VideoOnboardingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const VideoOnboardingDialog(),
    );
  }

  @override
  State<VideoOnboardingDialog> createState() => _VideoOnboardingDialogState();
}

class _VideoOnboardingDialogState extends State<VideoOnboardingDialog> {
  int _currentStep = 0;

  /// Pasos de la guía. `video` queda vacío hasta que existan los tutoriales
  /// grabados; poner ahí la URL es todo lo que hace falta para activarlos.
  static const List<Map<String, String>> _tutorials = [
    {
      'title': '1. Cómo solicitar médico a domicilio',
      'description':
          'Elige "Médico a domicilio" en el catálogo, describe al menos dos '
          'síntomas (por ejemplo "fiebre y dolor de cabeza") y confirma tu '
          'dirección. Verás el tiempo de espera de tu sector antes de aceptar.',
      'icon': 'medical_services',
      'video': '',
    },
    {
      'title': '2. Seguimiento y mapa en tiempo real',
      'description':
          'Una vez que un profesional toma tu solicitud verás quién es, podrás '
          'abrir su ficha con su registro y experiencia, y seguir su llegada '
          'en el mapa. También puedes escribirle por el chat clínico.',
      'icon': 'map',
      'video': '',
    },
    {
      'title': '3. Toma de muestras y exámenes',
      'description':
          'El laboratorio no es un servicio de urgencia: eliges un bloque de '
          'horario que el laboratorista publicó, indicas los exámenes y '
          'anotas tus condiciones previas, como el ayuno.',
      'icon': 'biotech',
      'video': '',
    },
    {
      'title': '4. Videoconsultas y resultados',
      'description':
          'Puedes agendar una consulta por videollamada, y descargar tus '
          'informes de laboratorio desde "Mis exámenes". También te llegan '
          'por correo apenas el laboratorio los carga.',
      'icon': 'video_call',
      'video': '',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final tutorial = _tutorials[_currentStep];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF0F766E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Primeros pasos en Aura',
                      style: AppType.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Cerrar la guía',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(tutorial['icon']!),
                        size: 44,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      _buildStepBadge(tutorial),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tutorial['title']!,
              style: AppType.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tutorial['description']!,
              style: AppType.bodySmall.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Paso ${_currentStep + 1} de ${_tutorials.length}',
                    style: AppType.label.copyWith(color: Colors.grey),
                  ),
                ),
                Row(
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('Anterior'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_currentStep < _tutorials.length - 1) {
                          setState(() => _currentStep++);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        _currentStep == _tutorials.length - 1
                            ? 'Entendido'
                            : 'Siguiente',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Distintivo bajo el icono del paso.
  ///
  /// Con video muestra un botón que lo abre de verdad; sin él, solo el número
  /// de paso. Anunciar "Reproducir video guía (0:45)" sobre un contenedor
  /// inerte hace que la ayuda parezca rota, que es peor que no ofrecerla.
  Widget _buildStepBadge(Map<String, String> tutorial) {
    final video = tutorial['video'] ?? '';
    final hasVideo = video.isNotEmpty;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVideo ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              hasVideo
                  ? 'Ver video'
                  : 'Paso ${_currentStep + 1} de ${_tutorials.length}',
              style: AppType.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (!hasVideo) return badge;

    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(video),
        mode: LaunchMode.externalApplication,
      ),
      child: badge,
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'map':
        return Icons.map_rounded;
      case 'biotech':
        return Icons.biotech_rounded;
      case 'video_call':
        return Icons.video_call_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
