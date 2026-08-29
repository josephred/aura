import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aura_button.dart';
import 'tokens.dart';

/// Un paso de un flujo guiado.
///
/// El patrón que sustituye a los formularios largos: **una pregunta por
/// pantalla**. La pregunta arriba, en grande; las opciones debajo; la acción
/// para avanzar anclada al fondo, siempre en el mismo sitio.
///
/// La pregunta es el título de la pantalla, no un rótulo dentro de ella. Esa es
/// la diferencia entre «¿Dónde necesitas atención?» y un campo «Dirección» en
/// medio de otros ocho.
class AuraFlowStep extends StatelessWidget {
  /// La pregunta. Corta, en segunda persona, terminada en signo de
  /// interrogación cuando lo es.
  final String question;

  /// Una línea de contexto, solo si sin ella la pregunta queda ambigua.
  final String? help;

  /// El contenido del paso: normalmente una columna de [AuraChoiceTile].
  final Widget child;

  /// Rótulo de la acción de avanzar. Dice qué pasa al tocarla, no «Siguiente».
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final IconData? primaryIcon;

  /// Acción secundaria bajo la principal. Opcional y de menor peso.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Qué falta para poder avanzar. Se muestra junto al botón inhabilitado, no
  /// escondido dentro de él: la app tenía botones que solo decían qué faltaba
  /// en su propio rótulo, al fondo, lejos del campo sin rellenar.
  final String? blockedReason;

  const AuraFlowStep({
    super.key,
    required this.question,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.help,
    this.primaryLoading = false,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.blockedReason,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.screenX,
              AuraSpace.xs,
              AuraSpace.screenX,
              AuraSpace.lg,
            ),
            child: AuraReadable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      question,
                      style: AppType.hero.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (help != null) ...[
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      help!,
                      style: AppType.bodyMedium.copyWith(color: p.textMuted),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
        _FlowFooter(
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          primaryLoading: primaryLoading,
          primaryIcon: primaryIcon,
          secondaryLabel: secondaryLabel,
          onSecondary: onSecondary,
          blockedReason: blockedReason,
        ),
      ],
    );
  }
}

/// Zona de acción anclada al fondo.
///
/// Anclada y no al final del scroll porque en un teléfono grande, sostenido con
/// una mano, el fondo de la pantalla es lo único que el pulgar alcanza sin
/// recolocar el aparato.
class _FlowFooter extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? blockedReason;

  const _FlowFooter({
    required this.primaryLabel,
    required this.onPrimary,
    required this.primaryLoading,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.blockedReason,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final blocked = onPrimary == null && blockedReason != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.screenX,
        AuraSpace.sm,
        AuraSpace.screenX,
        AuraSpace.sm + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: AuraShadow.lifted(context.isDark),
      ),
      child: AuraReadable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocked) ...[
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AuraIcon.sm,
                      color: p.textMuted,
                    ),
                    const SizedBox(width: AuraSpace.xs),
                    Expanded(
                      child: Text(
                        blockedReason!,
                        style: AppType.bodySmall.copyWith(color: p.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.xs),
            ],
            AuraButton.primary(
              label: primaryLabel,
              onPressed: onPrimary,
              loading: primaryLoading,
              icon: primaryIcon,
              trailingIcon: true,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AuraSpace.xxs),
              AuraButton.tertiary(
                label: secondaryLabel!,
                onPressed: onSecondary,
                expand: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabecera de un flujo: volver, progreso, salir.
///
/// El progreso es una barra y un «2 de 4», no un «PASO 1 DE 2» fijo que mentía
/// —la pantalla anterior lo declaraba mientras mostraba los ocho bloques del
/// formulario de una vez.
class AuraFlowHeader extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onBack;

  /// Qué se está pidiendo, en dos palabras. Sale sobre la barra de progreso.
  final String title;
  final VoidCallback? onClose;

  const AuraFlowHeader({
    super.key,
    required this.step,
    required this.total,
    required this.onBack,
    required this.title,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = total <= 0 ? 0.0 : (step + 1) / total;

    return Container(
      color: p.background,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.xs,
        AuraSpace.xs,
        AuraSpace.xs,
        AuraSpace.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              AuraIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: step == 0 ? 'Volver al inicio' : 'Volver al paso anterior',
                onPressed: onBack,
                color: p.textPrimary,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (onClose != null)
                AuraIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Salir sin enviar la solicitud',
                  onPressed: onClose,
                  color: p.textMuted,
                )
              else
                const SizedBox(width: AuraTap.min),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.sm),
            child: Semantics(
              // El lector de pantalla anuncia «Paso 2 de 4»; la barra sola no
              // significa nada para quien no la ve.
              label: 'Paso ${step + 1} de $total',
              value: '${(progress * 100).round()} por ciento',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: AuraRadius.allPill,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: AuraMotion.slow,
                    curve: AuraMotion.curve,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: p.fill,
                      valueColor: AlwaysStoppedAnimation(p.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transición entre pasos: entra desde el lado hacia el que se avanza.
///
/// Es la única animación de posición de la app. Existe porque sin ella, dos
/// pasos consecutivos con la misma forma parecen la misma pantalla que no
/// reaccionó al toque.
class AuraStepTransition extends StatelessWidget {
  final Widget child;

  /// Clave que cambia con el paso. Es lo que dispara la transición.
  final Object stepKey;
  final bool forward;

  const AuraStepTransition({
    super.key,
    required this.child,
    required this.stepKey,
    this.forward = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AuraMotion.slow,
      switchInCurve: AuraMotion.curve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: Offset(forward ? 0.06 : -0.06, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(stepKey), child: child),
    );
  }
}
