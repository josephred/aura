import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Semantic color tokens for Aura's custom UI. The app is styled with a fixed
/// slate + teal palette; instead of hardcoding those literals (which never
/// adapt to dark mode) every screen reads them from here via `context.palette`,
/// so light and dark are defined exactly once.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background; // page background (was slate-50 / slate-900)
  final Color card; // elevated surface (was Colors.white)
  final Color cardSubtle; // inset fields / soft areas (was slate-50)
  final Color fill; // chips / neutral fills (was slate-100)
  final Color border; // hairline borders (was slate-200)
  final Color borderStrong; // stronger borders (was slate-300)
  final Color textPrimary; // headings (was slate-900)
  final Color textSecondary; // body (was slate-700)
  final Color textMuted; // secondary body (was slate-500)

  /// Captions and hints.
  ///
  /// Deliberately identical to [textMuted] in light mode. It used to be
  /// slate-400, which sits at 2.56:1 on white — below even the 3:1 floor WCAG
  /// reserves for large text, while being used almost exclusively on 8-11pt
  /// captions. A token that is only legal at 24pt, in an app where nothing
  /// reaches 24pt, has no valid use; the name survives so the ~68 call sites
  /// keep their intent, the colour does not.
  final Color textFaint;

  /// Brand teal used for text, icons and button fills.
  ///
  /// teal-700, not teal-600: on white, teal-600 is 3.74:1, so every primary
  /// button in the app failed 1.4.3 for its white label. teal-700 lifts that
  /// to 5.47:1 and the visual difference is barely perceptible.
  final Color accent;
  final Color accentSurface; // teal tint behind accents
  final Color accentText; // text/icons on accentSurface

  const AppPalette({
    required this.background,
    required this.card,
    required this.cardSubtle,
    required this.fill,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentSurface,
    required this.accentText,
  });

  static const light = AppPalette(
    background: Color(0xFFF8FAFC),
    card: Colors.white,
    cardSubtle: Color(0xFFF8FAFC),
    fill: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A), // 17.85:1 sobre blanco
    textSecondary: Color(0xFF334155), // 10.35:1
    textMuted: Color(0xFF64748B), // 4.76:1
    textFaint: Color(0xFF64748B), // era 94A3B8 → 2.56:1, ahora 4.76:1
    accent: Color(0xFF0F766E), // era 0D9488 → 3.74:1, ahora 5.47:1
    accentSurface: Color(0xFFE6F6F4),
    accentText: Color(0xFF115E59), // 7.58:1 sobre accentSurface
  );

  static const dark = AppPalette(
    background: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    cardSubtle: Color(0xFF0F172A),
    fill: Color(0xFF334155),
    border: Color(0xFF334155),
    borderStrong: Color(0xFF475569),
    textPrimary: Color(0xFFF1F5F9), // 13.35:1 sobre la tarjeta oscura
    textSecondary: Color(0xFFCBD5E1), // 9.85:1
    // En oscuro los grises se invierten: slate-400 es el que contrasta contra
    // la tarjeta (#1E293B), y slate-500 el que fallaba.
    textMuted: Color(0xFF94A3B8), // 5.71:1
    textFaint: Color(0xFF94A3B8), // era 64748B → 3.07:1, ahora 5.71:1
    accent: Color(0xFF14B8A6), // 5.88:1
    accentSurface: Color(0xFF134E4A),
    accentText: Color(0xFF2DD4BF), // 5.09:1 sobre accentSurface
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? cardSubtle,
    Color? fill,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? accent,
    Color? accentSurface,
    Color? accentText,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      cardSubtle: cardSubtle ?? this.cardSubtle,
      fill: fill ?? this.fill,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentSurface: accentSurface ?? this.accentSurface,
      accentText: accentText ?? this.accentText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardSubtle: Color.lerp(cardSubtle, other.cardSubtle, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
    );
  }
}

/// Concise access to the palette, ColorScheme and brightness from any widget.
extension AppThemeContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  /// teal-700. Es también el relleno por defecto de los botones de Material,
  /// así que subirlo desde teal-600 es lo que pone el texto blanco de esos
  /// botones en 5.47:1 en vez de 3.74:1.
  static const _brandPrimary = Color(0xFF0F766E);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandPrimary,
      primary: _brandPrimary,
      secondary: const Color(0xFF115E59),
      surface: Colors.white,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: const Color(0xFF64748B),
      outlineVariant: const Color(0xFFE2E8F0),
    );
    return _base(scheme, AppPalette.light);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandPrimary,
      brightness: Brightness.dark,
      primary: const Color(0xFF14B8A6),
      secondary: const Color(0xFF2DD4BF),
      surface: const Color(0xFF1E293B),
      onSurface: const Color(0xFFF1F5F9),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outlineVariant: const Color(0xFF334155),
    );
    return _base(scheme, AppPalette.dark);
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.card,
      dividerColor: palette.border,
      canvasColor: palette.card,
      extensions: [palette],
      textTheme: _textTheme(palette),
    );
  }

  /// Escala del tema, derivada de [AppType] para que haya una sola definición
  /// de "cuánto mide el cuerpo de texto".
  ///
  /// Gobierna el texto que no lleva estilo propio: `bodyMedium` es el que hereda
  /// cualquier `Text` suelto, y `labelLarge` el de los botones de Material.
  ///
  /// Aquí sí se fijan peso y color, porque en este nivel no hay un sitio de uso
  /// que los aporte.
  ///
  /// Ya no declara `fontFamily: 'Inter'`: esa fuente nunca estuvo empaquetada
  /// —no hay sección `fonts:` en `pubspec.yaml` ni un solo `.ttf` en el
  /// proyecto—, así que Flutter caía al tipo del sistema en silencio. Se quitó
  /// la referencia en lugar de arrastrar la mentira; empaquetar Inter de verdad
  /// es un cambio aparte.
  static TextTheme _textTheme(AppPalette palette) {
    return TextTheme(
      headlineLarge: AppType.display.copyWith(
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
      ),
      titleLarge: AppType.titleLarge.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      titleMedium: AppType.titleMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      titleSmall: AppType.titleSmall.copyWith(
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      bodyLarge: AppType.bodyLarge.copyWith(color: palette.textPrimary),
      bodyMedium: AppType.bodyMedium.copyWith(color: palette.textSecondary),
      bodySmall: AppType.bodySmall.copyWith(color: palette.textMuted),
      labelLarge: AppType.button.copyWith(fontWeight: FontWeight.w700),
      labelMedium: AppType.label.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.textSecondary,
      ),
      labelSmall: AppType.label.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: palette.textMuted,
      ),
    );
  }
}
