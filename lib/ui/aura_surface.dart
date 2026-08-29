import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tokens.dart';

/// Tarjeta. La unidad de agrupación de la app.
///
/// Un solo componente con tres tonos, en vez de los cuatro radios y las cinco
/// combinaciones de borde y sombra que había repartidas por las pantallas.
class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Tarjeta destacada: fondo de marca oscuro. Es el recurso para la atención
  /// urgente y para la próxima atención, que tienen que dominar la pantalla sin
  /// recurrir al rojo ni a un degradado.
  final bool emphasis;

  /// Sin sombra ni relleno propio: solo un contorno. Para agrupar sin añadir
  /// otra capa visual.
  final bool outlined;
  final Color? background;
  final String? semanticLabel;

  const AuraCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.emphasis = false,
    this.outlined = false,
    this.background,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = context.isDark;

    final bg = background ??
        (emphasis ? p.brandDeep : (outlined ? Colors.transparent : p.card));
    final border = emphasis
        ? null
        : Border.all(color: outlined ? p.border : p.border, width: 1);

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AuraRadius.allLg,
        border: border,
        boxShadow: outlined || emphasis
            ? AuraShadow.none()
            : AuraShadow.soft(isDark),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AuraRadius.allLg,
          focusColor: p.accent.withValues(alpha: 0.14),
          child: content,
        ),
      );
    }

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        child: content,
      );
    }
    return content;
  }
}

/// Rótulo de sección.
///
/// Sustituye a los `Text('ESPECIALIDADES DISPONIBLES')` en versalitas de 12 pt
/// repartidos por la app. En minúsculas, con el peso haciendo la jerarquía: las
/// versalitas se leen peor y estaban compitiendo en tamaño con el contenido.
class AuraSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const AuraSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppType.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.accent,
                minimumSize: const Size(0, AuraTap.min),
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.xs),
              ),
              child: Text(
                action!,
                style: AppType.bodySmall.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Los cinco tonos que puede tener un mensaje en pantalla.
enum AuraTone { neutral, info, success, warning, error }

/// Colores resueltos de un tono. Se expone para que las pantallas puedan pintar
/// una insignia o un punto con el mismo par sin repetir el `switch`.
({Color fg, Color surface, Color onSurface, IconData icon}) auraToneColors(
  BuildContext context,
  AuraTone tone,
) {
  final p = context.palette;
  return switch (tone) {
    AuraTone.neutral => (
      fg: p.textSecondary,
      surface: p.fill,
      onSurface: p.textSecondary,
      icon: Icons.info_outline_rounded,
    ),
    AuraTone.info => (
      fg: p.info,
      surface: p.infoSurface,
      onSurface: p.onInfoSurface,
      icon: Icons.info_outline_rounded,
    ),
    AuraTone.success => (
      fg: p.success,
      surface: p.successSurface,
      onSurface: p.onSuccessSurface,
      icon: Icons.check_circle_outline_rounded,
    ),
    AuraTone.warning => (
      fg: p.warning,
      surface: p.warningSurface,
      onSurface: p.onWarningSurface,
      icon: Icons.warning_amber_rounded,
    ),
    AuraTone.error => (
      fg: p.error,
      surface: p.errorSurface,
      onSurface: p.onErrorSurface,
      icon: Icons.error_outline_rounded,
    ),
  };
}

/// Aviso en línea.
///
/// Siempre lleva icono además del color: un estado que solo se distingue por el
/// color no se distingue para quien no separa esos colores (WCAG 1.4.1).
class AuraBanner extends StatelessWidget {
  final String message;
  final String? title;
  final AuraTone tone;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AuraBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AuraTone.info,
    this.icon,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = auraToneColors(context, tone);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AuraRadius.allMd,
          border: Border.all(color: c.fg.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? c.icon, color: c.fg, size: AuraIcon.md),
            const SizedBox(width: AuraSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppType.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.xxs),
                  ],
                  Text(
                    message,
                    style: AppType.bodySmall.copyWith(color: c.onSurface),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AuraSpace.xs),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: c.onSurface,
                        minimumSize: const Size(0, AuraTap.min),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.sm,
                        ),
                        backgroundColor: c.fg.withValues(alpha: 0.12),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AuraRadius.allSm,
                        ),
                      ),
                      child: Text(
                        actionLabel!,
                        style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              Padding(
                padding: const EdgeInsets.only(left: AuraSpace.xs),
                child: Tooltip(
                  message: 'Ocultar aviso',
                  child: Semantics(
                    button: true,
                    label: 'Ocultar aviso',
                    child: InkWell(
                      onTap: onDismiss,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: AuraTap.min,
                        height: AuraTap.min,
                        child: Icon(Icons.close_rounded, size: AuraIcon.sm),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Insignia corta: un estado, una categoría.
class AuraBadge extends StatelessWidget {
  final String label;
  final AuraTone tone;
  final IconData? icon;

  const AuraBadge({
    super.key,
    required this.label,
    this.tone = AuraTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = auraToneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.xs,
        vertical: AuraSpace.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AuraRadius.allXs,
        border: Border.all(color: c.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AuraIcon.sm - 2, color: c.onSurface),
            const SizedBox(width: AuraSpace.xxs),
          ],
          Text(
            label,
            style: AppType.label.copyWith(
              fontWeight: FontWeight.w700,
              color: c.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila etiqueta / valor de un resumen.
///
/// Usa `Expanded` con proporciones en vez del `SizedBox(width: 110)` fijo que
/// tenía la pantalla de pago: con la letra al 200 % ese ancho fijo dejaba la
/// dirección partida en una columna de dos caracteres.
class AuraSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool strong;

  const AuraSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AuraIcon.sm, color: p.textMuted),
                const SizedBox(width: AuraSpace.xs),
              ],
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: AppType.bodySmall.copyWith(color: p.textMuted),
                ),
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style:
                      (strong ? AppType.bodyLarge : AppType.bodySmall).copyWith(
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
