import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aura_surface.dart';
import 'tokens.dart';

/// Opción grande de un flujo guiado.
///
/// Es el componente central del rediseño. Todo lo que antes era un desplegable,
/// un grupo de radios diminutos o un campo de texto libre —«¿Para quién?»,
/// «¿Dónde?», «¿Cuándo?»— pasa a ser una lista de estas: bloques de 60 px o más
/// donde el objetivo táctil **es** la tarjeta entera, no un punto de 20 px a la
/// izquierda.
///
/// El estado seleccionado no se distingue solo por el color: cambia el grosor
/// del borde, el fondo, y aparece una marca de verificación. Quien no separa el
/// verde del gris sigue viendo cuál eligió.
class AuraChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Se pinta a la derecha: un precio, una duración, una distancia.
  final String? trailingText;

  /// Insignia sobre el título: «Requiere orden», «Recomendado».
  final Widget? badge;
  final bool enabled;

  const AuraChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.selected = false,
    this.onTap,
    this.trailingText,
    this.badge,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = selected && enabled;

    return Semantics(
      // `inMutuallyExclusiveGroup` + `selected` es lo que hace que un lector de
      // pantalla lo lea como «opción, seleccionada, 2 de 4» y no como un botón
      // suelto más.
      inMutuallyExclusiveGroup: true,
      selected: active,
      enabled: enabled,
      button: true,
      label: [
        title,
        if (subtitle != null) subtitle,
        if (trailingText != null) trailingText,
      ].join('. '),
      child: ExcludeSemantics(
        child: Material(
          color: active ? p.accentSurface : p.card,
          borderRadius: AuraRadius.allMd,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: AuraRadius.allMd,
            focusColor: p.accent.withValues(alpha: 0.16),
            child: AnimatedContainer(
              duration: AuraMotion.fast,
              curve: AuraMotion.curve,
              constraints: const BoxConstraints(minHeight: AuraTap.large),
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.md,
                vertical: AuraSpace.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AuraRadius.allMd,
                border: Border.all(
                  color: active
                      ? p.accent
                      : (enabled ? p.border : p.border.withValues(alpha: 0.6)),
                  // 2 px cuando está activo, 1.5 cuando no: el borde no salta
                  // de grosor lo suficiente para desplazar la maquetación.
                  width: active ? 2 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: active ? p.accent : p.fill,
                        borderRadius: AuraRadius.allSm,
                      ),
                      child: Icon(
                        icon,
                        size: AuraIcon.md,
                        color: active
                            ? context.scheme.onPrimary
                            : (enabled ? p.textSecondary : p.onDisabled),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badge != null) ...[
                          badge!,
                          const SizedBox(height: AuraSpace.xxs),
                        ],
                        Text(
                          title,
                          style: AppType.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: enabled
                                ? (active ? p.accentText : p.textPrimary)
                                : p.onDisabled,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AuraSpace.xxxs),
                          Text(
                            subtitle!,
                            style: AppType.bodySmall.copyWith(
                              color: enabled ? p.textMuted : p.onDisabled,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingText != null) ...[
                    const SizedBox(width: AuraSpace.xs),
                    Text(
                      trailingText!,
                      textAlign: TextAlign.end,
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? p.accentText : p.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(width: AuraSpace.xs),
                  // Redundancia deliberada con el color: marca cuando está
                  // elegida, círculo vacío cuando no.
                  Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: AuraIcon.lg - 4,
                    color: active ? p.accent : p.borderStrong,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Azulejo de servicio de la rejilla del inicio.
///
/// Vertical y no horizontal: en una lista vertical de nueve filas hay que leer
/// nueve subtítulos para elegir; en una rejilla de dos columnas la elección se
/// hace por icono y nombre, que es como la gente elige «médico» o «enfermería».
class AuraServiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Texto corto bajo el nombre: la espera típica. Nada más.
  final String? hint;
  final Widget? badge;

  /// Trata el azulejo como destacado (fondo de marca). Se usa para la atención
  /// urgente, que tiene que verse primero sin ser roja.
  final bool emphasis;

  const AuraServiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.hint,
    this.badge,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = emphasis ? p.onBrandDeep : p.textPrimary;
    final iconBg = emphasis
        ? p.onBrandDeep.withValues(alpha: 0.16)
        : p.accentSurface;
    final iconFg = emphasis ? p.onBrandDeep : p.accentText;

    return Semantics(
      button: true,
      label: hint == null ? label : '$label. $hint',
      child: ExcludeSemantics(
        child: Material(
          color: emphasis ? p.brandDeep : p.card,
          borderRadius: AuraRadius.allLg,
          child: InkWell(
            onTap: onTap,
            borderRadius: AuraRadius.allLg,
            focusColor: p.accent.withValues(alpha: 0.20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 132),
              padding: const EdgeInsets.all(AuraSpace.sm),
              decoration: BoxDecoration(
                borderRadius: AuraRadius.allLg,
                border: emphasis ? null : Border.all(color: p.border),
                boxShadow: emphasis
                    ? AuraShadow.none()
                    : AuraShadow.soft(context.isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: AuraRadius.allSm,
                        ),
                        child: Icon(icon, size: AuraIcon.lg, color: iconFg),
                      ),
                      const Spacer(),
                      if (badge != null) Flexible(child: badge!),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppType.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: AuraSpace.xxxs),
                        Text(
                          hint!,
                          style: AppType.label.copyWith(
                            color: emphasis
                                ? p.onBrandDeep.withValues(alpha: 0.82)
                                : p.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de acción: un icono, un texto, una flecha. Toda la fila es tocable.
///
/// Reemplaza a los `GestureDetector` sobre una `Row` de 17 px de alto que había
/// en seguimiento e historial.
class AuraActionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final AuraTone tone;

  const AuraActionRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.tone = AuraTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDanger = tone == AuraTone.error;
    final fg = isDanger ? p.error : p.textPrimary;
    final iconColor = isDanger ? p.error : p.accent;
    final iconBg = isDanger ? p.errorSurface : p.accentSurface;

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AuraRadius.allSm,
            focusColor: p.accent.withValues(alpha: 0.16),
            child: Container(
              constraints: const BoxConstraints(minHeight: AuraTap.min + 8),
              padding: const EdgeInsets.symmetric(
                vertical: AuraSpace.sm,
                horizontal: AuraSpace.xxs,
              ),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: AuraRadius.allXs,
                    ),
                    child: Icon(icon, size: AuraIcon.md, color: iconColor),
                  ),
                  const SizedBox(width: AuraSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AuraSpace.xxxs),
                          Text(
                            subtitle!,
                            style: AppType.bodySmall.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: p.textMuted,
                        size: AuraIcon.lg - 4,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
