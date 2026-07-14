import 'package:flutter/material.dart';

extension ThemeContext on BuildContext {
  Color get cardColor => Theme.of(this).cardColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get scaffoldColor => Theme.of(this).scaffoldBackgroundColor;
  Color get textColor => Theme.of(this).textTheme.bodyLarge?.color ?? const Color(0xFF0F172A);
  Color get secondaryTextColor => Theme.of(this).brightness == Brightness.dark 
      ? const Color(0xFF94A3B8) 
      : const Color(0xFF64748B);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
