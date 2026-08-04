import 'package:flutter/material.dart';

extension ThemeContext on BuildContext {
  Color get cardColor => Theme.of(this).cardColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get scaffoldColor => Theme.of(this).scaffoldBackgroundColor;
  Color get textColor => Theme.of(this).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A);
  /// Los grises se invierten entre temas: slate-400 contrasta sobre la tarjeta
  /// oscura (5.71:1) y slate-500 sobre la blanca (4.76:1). Usar el mismo en
  /// ambos deja uno de los dos por debajo del mínimo.
  Color get secondaryTextColor => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
