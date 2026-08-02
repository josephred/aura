import 'package:flutter/material.dart';

/// Modal interactivo de ayuda con guías paso a paso e instrucciones en video
/// para guiarlos en la reserva de atención clínica y llamadas.
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

  final List<Map<String, String>> _tutorials = [
    {
      'title': '1. Cómo solicitar médico a domicilio',
      'description':
          'Ingresa a la aplicación, elige la especialidad o "Médico a domicilio", indica al menos dos síntomas (ej: "fiebre y dolor de cabeza") y confirma tu ubicación.',
      'icon': 'medical_services',
    },
    {
      'title': '2. Seguimiento y mapa en tiempo real',
      'description':
          'Una vez asignado el profesional, podrás ver su ubicación GPS en vivo, tiempo estimado de llegada y contactarte por chat o llamada.',
      'icon': 'map',
    },
    {
      'title': '3. Toma de Muestras y Exámenes',
      'description':
          'Programa la recolección de muestras (sangre/orina) seleccionando tu bloque de horario preferido y adjuntando si cuentas con orden médica.',
      'icon': 'biotech',
    },
    {
      'title': '4. Videoconsultas y Resultados',
      'description':
          'Accede a telemedicina directa y descarga tus resultados clínicos e historial en formato PDF desde la sección "Mis Exámenes".',
      'icon': 'video_call',
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
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF0D9488),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Guía y Video Tutoriales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Reproducir Video Guía (0:45)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tutorial['title']!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tutorial['description']!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paso ${_currentStep + 1} de ${_tutorials.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                        backgroundColor: const Color(0xFF0D9488),
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
