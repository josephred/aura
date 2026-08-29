import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tokens.dart';

/// Jerarquía de acción.
///
/// El problema que resuelve: había pantallas con `Guardar`, `Continuar`,
/// `Confirmar`, `Volver`, `Cancelar` y `Más opciones` dibujados todos igual, y
/// la persona tenía que leerlos uno a uno para saber cuál era el que quería.
/// Una pantalla tiene **una** acción primaria. Todo lo demás baja de nivel.
enum AuraButtonKind {
  /// Relleno de marca. Una por pantalla.
  primary,

  /// Contorno. La alternativa razonable a la primaria.
  secondary,

  /// Solo texto. Salidas y atajos.
  tertiary,

  /// Relleno rojo. Solo para lo que destruye algo y no se puede deshacer.
  danger,
}

enum AuraButtonSize {
  /// 44 px. Dentro de una tarjeta.
  small,

  /// 52 px. El tamaño normal.
  medium,

  /// 60 px. La acción principal de una pantalla.
  large,
}

/// Botón del sistema, con sus estados completos.
///
/// Estados que contempla: normal, presionado, foco (anillo visible), inhabilitado
/// y cargando. El de carga importa más de lo que parece: la app tenía cuatro
/// botones —«Aceptar y pagar», «Unirse a la videoconsulta», «Verificar pago»—
/// que lanzaban una petición de red sin cambiar de aspecto, así que en una red
/// lenta la única lectura posible era que el botón estaba roto, y se tocaba otra
/// vez.
class AuraButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AuraButtonKind kind;
  final AuraButtonSize size;
  final IconData? icon;

  /// Icono al final en vez de al principio. Para «continuar», donde la flecha
  /// apunta hacia donde va la persona.
  final bool trailingIcon;
  final bool loading;
  final bool expand;

  /// Qué anuncia un lector de pantalla. Por defecto, [label]; se cambia cuando
  /// el rótulo visible no basta por sí solo fuera de contexto.
  final String? semanticLabel;

  const AuraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AuraButtonKind.primary,
    this.size = AuraButtonSize.medium,
    this.icon,
    this.trailingIcon = false,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  });

  const AuraButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AuraButtonSize.large,
    this.icon,
    this.trailingIcon = false,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  }) : kind = AuraButtonKind.primary;

  const AuraButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AuraButtonSize.medium,
    this.icon,
    this.trailingIcon = false,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  }) : kind = AuraButtonKind.secondary;

  const AuraButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AuraButtonSize.medium,
    this.icon,
    this.trailingIcon = false,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
  }) : kind = AuraButtonKind.tertiary;

  const AuraButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AuraButtonSize.medium,
    this.icon,
    this.trailingIcon = false,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  }) : kind = AuraButtonKind.danger;

  double get _height => switch (size) {
    AuraButtonSize.small => AuraTap.min,
    AuraButtonSize.medium => AuraTap.comfortable,
    AuraButtonSize.large => AuraTap.large,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;

    final (Color bg, Color fg, Color? borderColor) = switch (kind) {
      AuraButtonKind.primary => (p.accent, context.scheme.onPrimary, null),
      AuraButtonKind.secondary => (Colors.transparent, p.accent, p.borderStrong),
      AuraButtonKind.tertiary => (Colors.transparent, p.accent, null),
      AuraButtonKind.danger => (p.error, context.scheme.onError, null),
    };

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(expand ? double.infinity : 0, _height),
      ),
      // El objetivo táctil nunca baja del mínimo aunque el rótulo sea corto.
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: size == AuraButtonSize.small ? AuraSpace.md : AuraSpace.lg,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AuraRadius.allMd),
      ),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return kind == AuraButtonKind.primary || kind == AuraButtonKind.danger
              ? p.disabledFill
              : Colors.transparent;
        }
        if (states.contains(WidgetState.pressed) &&
            kind != AuraButtonKind.primary &&
            kind != AuraButtonKind.danger) {
          return p.accentSurface;
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? p.onDisabled : fg,
      ),
      side: borderColor == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? p.border
                    : borderColor,
                width: 1.5,
              ),
            ),
      // Anillo de foco visible, en lugar del tinte casi imperceptible de
      // Material. Sin esto no hay forma de recorrer la app con teclado.
      overlayColor: WidgetStatePropertyAll(
        kind == AuraButtonKind.primary || kind == AuraButtonKind.danger
            ? Colors.white.withValues(alpha: 0.14)
            : p.accent.withValues(alpha: 0.10),
      ),
      textStyle: WidgetStatePropertyAll(
        (size == AuraButtonSize.small ? AppType.bodyMedium : AppType.button)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    ).copyWith(
      shape: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return RoundedRectangleBorder(
            borderRadius: AuraRadius.allMd,
            side: BorderSide(color: p.textPrimary, width: 3),
          );
        }
        return RoundedRectangleBorder(
          borderRadius: AuraRadius.allMd,
          side: borderColor != null && !states.contains(WidgetState.disabled)
              ? BorderSide(color: borderColor, width: 1.5)
              : BorderSide.none,
        );
      }),
    );

    final iconWidget = icon == null
        ? null
        : Icon(icon, size: size == AuraButtonSize.small ? AuraIcon.sm : AuraIcon.md);

    final Widget content = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: enabled ? fg : p.onDisabled,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconWidget != null && !trailingIcon) ...[
                iconWidget,
                const SizedBox(width: AuraSpace.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (iconWidget != null && trailingIcon) ...[
                const SizedBox(width: AuraSpace.xs),
                iconWidget,
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      // Un botón que está cargando tiene que decirlo, no solo dibujar una
      // rueda: para quien usa lector de pantalla, la rueda no existe.
      hint: loading ? 'Procesando' : null,
      child: ExcludeSemantics(
        excluding: semanticLabel != null,
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: content,
        ),
      ),
    );
  }
}

/// Botón de icono con objetivo táctil garantizado.
///
/// Existe porque `IconButton` a secas terminaba en 26 px de alto en varias
/// pantallas, y uno de esos botones de 26 px era el que cerraba el aviso de
/// riesgo vital del inicio.
class AuraIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  /// Obligatorio. Un botón que solo es un dibujo no dice nada a un lector de
  /// pantalla, y en esta app había una decena así.
  final String tooltip;
  final Color? color;
  final Color? background;
  final double size;

  const AuraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.background,
    this.size = AuraIcon.md,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: background ?? Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            focusColor: p.accent.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AuraTap.min,
                minHeight: AuraTap.min,
              ),
              child: Icon(
                icon,
                size: size,
                color: onPressed == null
                    ? p.onDisabled
                    : (color ?? p.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
