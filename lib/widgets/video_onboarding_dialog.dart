import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../ui/aura.dart';

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
  ///
  /// Los títulos ya no llevan «1.», «2.»: el pie del diálogo dice en qué paso
  /// estás, y numerarlo dos veces solo alargaba el titular.
  static const List<Map<String, String>> _tutorials = [
    {
      'title': 'Cómo pedir un médico a domicilio',
      'description':
          'Elige "Médico a domicilio" en el catálogo, describe al menos dos '
          'síntomas (por ejemplo "fiebre y dolor de cabeza") y confirma tu '
          'dirección. Verás el tiempo de espera de tu sector antes de aceptar.',
      'icon': 'medical_services',
      'video': '',
    },
    {
      'title': 'Seguimiento y mapa en tiempo real',
      'description':
          'Una vez que un profesional toma tu solicitud verás quién es, podrás '
          'abrir su ficha con su registro y experiencia, y seguir su llegada '
          'en el mapa. También puedes escribirle por el chat clínico.',
      'icon': 'map',
      'video': '',
    },
    {
      'title': 'Toma de muestras y exámenes',
      'description':
          'El laboratorio no es un servicio de urgencia: eliges un bloque de '
          'horario que el laboratorista publicó, indicas los exámenes y '
          'anotas tus condiciones previas, como el ayuno.',
      'icon': 'biotech',
      'video': '',
    },
    {
      'title': 'Videoconsultas y resultados',
      'description':
          'Puedes agendar una consulta por videollamada, y descargar tus '
          'informes de laboratorio desde "Mis exámenes". También te llegan '
          'por correo apenas el laboratorio los carga.',
      'icon': 'video_call',
      'video': '',
    },
  ];

  bool get _isLast => _currentStep == _tutorials.length - 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tutorial = _tutorials[_currentStep];

    return Dialog(
      backgroundColor: p.card,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AuraRadius.allXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleBar(p),
              const SizedBox(height: AuraSpace.md),
              // El cuerpo se desplaza en vez de recortarse: con la letra
              // grande, la descripción de un paso no cabe en el alto del
              // diálogo y antes salía la franja de desbordamiento.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _hero(p, tutorial),
                      const SizedBox(height: AuraSpace.md),
                      Semantics(
                        header: true,
                        child: Text(
                          tutorial['title']!,
                          style: AppType.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.xs),
                      Text(
                        tutorial['description']!,
                        style: AppType.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.lg),
              _footer(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(AppPalette p) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AuraSpace.xs),
          decoration: BoxDecoration(
            color: p.accentSurface,
            borderRadius: AuraRadius.allSm,
          ),
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: p.accentText,
            size: AuraIcon.md,
          ),
        ),
        const SizedBox(width: AuraSpace.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Primeros pasos en Aura',
              style: AppType.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
        AuraIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Cerrar la guía',
          color: p.textMuted,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// Banda de color con el icono del paso.
  ///
  /// Antes era un `LinearGradient` entre dos veces el mismo verde —es decir,
  /// un relleno plano con el coste de un degradado— y el alto estaba clavado
  /// en 140 px: el bloque no crecía con la letra, tenía que caber a la fuerza.
  Widget _hero(AppPalette p, Map<String, String> tutorial) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.lg,
      ),
      decoration: BoxDecoration(
        color: p.brandDeep,
        borderRadius: AuraRadius.allMd,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconData(tutorial['icon']!),
            size: AuraIcon.display,
            color: p.onBrandDeep,
          ),
          const SizedBox(height: AuraSpace.xs),
          _buildStepBadge(tutorial),
        ],
      ),
    );
  }

  Widget _footer(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Paso ${_currentStep + 1} de ${_tutorials.length}',
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: AuraButton.secondary(
                  label: 'Anterior',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => setState(() => _currentStep--),
                ),
              ),
              const SizedBox(width: AuraTap.gap),
            ],
            Expanded(
              flex: 2,
              child: AuraButton.primary(
                label: _isLast ? 'Entendido' : 'Siguiente',
                size: AuraButtonSize.medium,
                icon: _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                trailingIcon: true,
                onPressed: () {
                  if (_isLast) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _currentStep++);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Distintivo bajo el icono del paso.
  ///
  /// Con video muestra un botón que lo abre de verdad; sin él, solo el número
  /// de paso. Anunciar "Reproducir video guía (0:45)" sobre un contenedor
  /// inerte hace que la ayuda parezca rota, que es peor que no ofrecerla.
  Widget _buildStepBadge(Map<String, String> tutorial) {
    final p = context.palette;
    final video = tutorial['video'] ?? '';
    final hasVideo = video.isNotEmpty;
    final label = hasVideo
        ? 'Ver el video'
        : 'Paso ${_currentStep + 1} de ${_tutorials.length}';

    final badge = Container(
      constraints: BoxConstraints(minHeight: hasVideo ? AuraTap.min : 0),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.sm,
        vertical: AuraSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: p.onBrandDeep.withValues(alpha: 0.16),
        borderRadius: AuraRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVideo ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
            color: p.onBrandDeep,
            size: AuraIcon.sm,
          ),
          const SizedBox(width: AuraSpace.xxs),
          Flexible(
            child: Text(
              label,
              style: AppType.label.copyWith(
                color: p.onBrandDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (!hasVideo) return badge;

    // Cuando el distintivo abre algo, es un botón: 44 px de alto y anunciado
    // como tal. Antes era un `GestureDetector` de unos 25 px sobre un
    // contenedor que un lector de pantalla leía como texto suelto.
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: AuraRadius.allPill,
          child: InkWell(
            borderRadius: AuraRadius.allPill,
            onTap: () => launchUrl(
              Uri.parse(video),
              mode: LaunchMode.externalApplication,
            ),
            child: badge,
          ),
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
