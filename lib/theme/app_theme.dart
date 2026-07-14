import 'package:flutter/material.dart';

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
  final Color textFaint; // captions / hints (was slate-400)
  final Color accent; // brand teal-600
  final Color accentSurface; // teal-50 tint behind accents
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
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
    accent: Color(0xFF0D9488),
    accentSurface: Color(0xFFE6F6F4),
    accentText: Color(0xFF0D9488),
  );

  static const dark = AppPalette(
    background: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    cardSubtle: Color(0xFF0F172A),
    fill: Color(0xFF334155),
    border: Color(0xFF334155),
    borderStrong: Color(0xFF475569),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    textFaint: Color(0xFF64748B),
    accent: Color(0xFF14B8A6),
    accentSurface: Color(0xFF134E4A),
    accentText: Color(0xFF2DD4BF),
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
  static const _brandPrimary = Color(0xFF0D9488);

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
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: palette.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: palette.textSecondary),
      ),
    );
  }
}
