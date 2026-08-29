import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'tokens.dart';

/// Campo de texto del sistema.
///
/// Reglas que aplica, y que la app incumplía en casi todos sus formularios:
///
/// - **El rótulo está siempre visible.** Nunca es solo el `hint`. Un
///   marcador de posición desaparece al escribir, y con él la única pista de
///   qué se estaba rellenando.
/// - **El teclado corresponde al dato.** Un campo de edad abre el teclado
///   numérico; uno de correo, el de correo.
/// - **El error se explica y no borra nada.** Aparece bajo el campo, con icono
///   además de color, y el texto escrito sigue ahí.
/// - El objetivo táctil nunca baja de 44 px de alto.
class AuraField extends StatelessWidget {
  /// Qué se pide. Visible siempre, sobre el campo.
  final String label;
  final TextEditingController controller;

  /// Ejemplo de respuesta. Complementa al rótulo, no lo sustituye.
  final String? hint;

  /// Aclaración bajo el campo, cuando hace falta.
  final String? help;

  /// Mensaje de error. Al aparecer, cambia borde, icono y texto: no solo color.
  final String? errorText;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffix;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;
  final String? autofillHint;

  const AuraField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.help,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.suffix,
    this.icon,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.capitalization = TextCapitalization.sentences,
    this.formatters,
    this.autofillHint,
  });

  /// Atajos con el teclado y la capitalización ya resueltos, para no tener que
  /// acordarse en cada sitio de uso.
  factory AuraField.email({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hint,
    String? errorText,
    bool enabled = true,
  }) => AuraField(
    key: key,
    label: label,
    controller: controller,
    hint: hint,
    errorText: errorText,
    enabled: enabled,
    icon: Icons.alternate_email_rounded,
    keyboardType: TextInputType.emailAddress,
    capitalization: TextCapitalization.none,
    autofillHint: AutofillHints.email,
  );

  factory AuraField.phone({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hint,
    String? errorText,
    bool enabled = true,
  }) => AuraField(
    key: key,
    label: label,
    controller: controller,
    hint: hint,
    errorText: errorText,
    enabled: enabled,
    icon: Icons.phone_rounded,
    keyboardType: TextInputType.phone,
    capitalization: TextCapitalization.none,
    autofillHint: AutofillHints.telephoneNumber,
  );

  factory AuraField.number({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hint,
    String? errorText,
    bool enabled = true,
    int? maxLength,
  }) => AuraField(
    key: key,
    label: label,
    controller: controller,
    hint: hint,
    errorText: errorText,
    enabled: enabled,
    maxLength: maxLength,
    keyboardType: TextInputType.number,
    capitalization: TextCapitalization.none,
    formatters: [FilteringTextInputFormatter.digitsOnly],
  );

  factory AuraField.multiline({
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hint,
    String? help,
    String? errorText,
    int maxLines = 4,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) => AuraField(
    key: key,
    label: label,
    controller: controller,
    hint: hint,
    help: help,
    errorText: errorText,
    maxLines: maxLines,
    maxLength: maxLength,
    onChanged: onChanged,
    keyboardType: TextInputType.multiline,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: enabled ? p.textSecondary : p.onDisabled,
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          obscureText: obscureText,
          onChanged: onChanged,
          inputFormatters: formatters,
          autofillHints: autofillHint == null ? null : [autofillHint!],
          style: AppType.bodyLarge.copyWith(
            color: enabled ? p.textPrimary : p.onDisabled,
          ),
          cursorColor: p.accent,
          decoration: InputDecoration(
            hintText: hint,
            // El rótulo ya está encima; repetirlo aquí lo duplicaría al
            // enfocar el campo.
            counterText: '',
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: AuraIcon.md, color: p.textMuted),
            suffixIcon: suffix,
            constraints: const BoxConstraints(minHeight: AuraTap.comfortable),
            enabledBorder: OutlineInputBorder(
              borderRadius: AuraRadius.allSm,
              borderSide: BorderSide(
                color: hasError ? p.error : p.borderStrong,
                width: hasError ? 1.5 : 1,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AuraSpace.xxs),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: AuraIcon.sm,
                  color: p.error,
                ),
                const SizedBox(width: AuraSpace.xxs),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppType.bodySmall.copyWith(
                      color: p.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (help != null) ...[
          const SizedBox(height: AuraSpace.xxs),
          Text(
            help!,
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Grupo de opciones cortas en horizontal: día, franja horaria, tipo.
///
/// Sustituye a los `ChoiceChip` de 27 px de alto. Cada opción es un objetivo de
/// 44 px como mínimo y se separa de la de al lado, para que fallar el toque no
/// seleccione la contigua.
class AuraOptionGroup<T> extends StatelessWidget {
  final List<({T value, String label, IconData? icon})> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String? label;

  const AuraOptionGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppType.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: AuraSpace.xs),
        ],
        Wrap(
          spacing: AuraTap.gap,
          runSpacing: AuraTap.gap,
          children: options.map((o) {
            final active = o.value == selected;
            return Semantics(
              inMutuallyExclusiveGroup: true,
              selected: active,
              button: true,
              label: o.label,
              child: ExcludeSemantics(
                child: Material(
                  color: active ? p.accent : p.card,
                  borderRadius: AuraRadius.allSm,
                  child: InkWell(
                    onTap: () => onSelect(o.value),
                    borderRadius: AuraRadius.allSm,
                    focusColor: p.textPrimary.withValues(alpha: 0.20),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AuraTap.min,
                        minWidth: AuraTap.min,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.md,
                        vertical: AuraSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: AuraRadius.allSm,
                        border: Border.all(
                          color: active ? p.accent : p.borderStrong,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (o.icon != null) ...[
                            Icon(
                              o.icon,
                              size: AuraIcon.sm,
                              color: active
                                  ? context.scheme.onPrimary
                                  : p.textSecondary,
                            ),
                            const SizedBox(width: AuraSpace.xxs),
                          ],
                          Text(
                            o.label,
                            style: AppType.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? context.scheme.onPrimary
                                  : p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Detalle que se despliega bajo demanda.
///
/// La herramienta de progressive disclosure de la app: lo que el 90 % de las
/// personas no necesita ver no se borra, se pliega. Cerrado por defecto.
class AuraDisclosure extends StatefulWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final bool initiallyOpen;

  const AuraDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.initiallyOpen = false,
  });

  @override
  State<AuraDisclosure> createState() => _AuraDisclosureState();
}

class _AuraDisclosureState extends State<AuraDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: widget.title,
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: AuraRadius.allSm,
                child: Container(
                  constraints: const BoxConstraints(minHeight: AuraTap.min),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.xs,
                    vertical: AuraSpace.xs,
                  ),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: AuraIcon.sm,
                          color: p.textMuted,
                        ),
                        const SizedBox(width: AuraSpace.xs),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: AuraMotion.base,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: p.textMuted,
                          size: AuraIcon.lg - 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(
              top: AuraSpace.xs,
              left: AuraSpace.xs,
              right: AuraSpace.xs,
              bottom: AuraSpace.xs,
            ),
            child: widget.child,
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AuraMotion.base,
          sizeCurve: AuraMotion.curve,
        ),
      ],
    );
  }
}
