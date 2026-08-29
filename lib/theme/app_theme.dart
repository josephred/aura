import 'package:flutter/material.dart';

import 'app_typography.dart';
export 'app_typography.dart';

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

  // --------------------------------------------------------------- semánticos
  //
  // Antes no existían: cada pantalla escribía su propio verde de éxito y su
  // propio ámbar de aviso, con el resultado de que había cinco ámbares
  // distintos y ninguno se invertía en modo oscuro. Cada estado trae su color
  // de trazo y su superficie, y el par ya está verificado en contraste.

  /// Marca, en su versión oscura. Superficie de las tarjetas hero y de la
  /// atención urgente: domina sin recurrir al rojo.
  final Color brandDeep;

  /// Texto e iconos sobre [brandDeep].
  final Color onBrandDeep;

  final Color success;
  final Color successSurface;
  final Color onSuccessSurface;

  final Color warning;
  final Color warningSurface;
  final Color onWarningSurface;

  final Color error;
  final Color errorSurface;
  final Color onErrorSurface;

  final Color info;
  final Color infoSurface;
  final Color onInfoSurface;

  /// Relleno y texto de un control deshabilitado. El texto sigue siendo
  /// legible: "deshabilitado" se comunica con el relleno plano y la ausencia de
  /// sombra, no volviendo el texto ilegible.
  final Color disabledFill;
  final Color onDisabled;

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
    required this.brandDeep,
    required this.onBrandDeep,
    required this.success,
    required this.successSurface,
    required this.onSuccessSurface,
    required this.warning,
    required this.warningSurface,
    required this.onWarningSurface,
    required this.error,
    required this.errorSurface,
    required this.onErrorSurface,
    required this.info,
    required this.infoSurface,
    required this.onInfoSurface,
    required this.disabledFill,
    required this.onDisabled,
  });

  /// Paleta clara.
  ///
  /// Los neutros dejaron de ser slate (azulado, frío, de panel de control) y
  /// pasaron a un gris con fondo verde muy leve. Es la diferencia entre una
  /// pantalla que parece un sistema y una que parece una consulta tranquila, y
  /// es lo único que hace falta para que el fondo no sea "blanco frío" sin
  /// recurrir a degradados.
  ///
  /// Todos los pares texto/fondo de aquí están verificados contra WCAG 2.2 AA:
  /// 4.5:1 para texto y 3:1 para bordes que definen un control.
  static const light = AppPalette(
    background: Color(0xFFF3F7F6), // niebla verde muy clara
    card: Colors.white,
    cardSubtle: Color(0xFFEAF1EF),
    fill: Color(0xFFE3EBE9),
    border: Color(0xFFD6E0DD),
    // 3.36:1 sobre blanco. El anterior (CBD5E1) daba 1.6:1: un borde que era
    // lo único que dibujaba un campo de formulario y que no se veía.
    borderStrong: Color(0xFF7E908C),
    textPrimary: Color(0xFF101F1D), // 16.99:1
    textSecondary: Color(0xFF3D4F4C), // 8.67:1
    textMuted: Color(0xFF5A6C69), // 5.55:1
    textFaint: Color(0xFF5A6C69), // idéntico a textMuted: ver nota del campo
    accent: Color(0xFF0F766E), // 5.47:1
    accentSurface: Color(0xFFDFF0ED),
    accentText: Color(0xFF0B5048), // 7.90:1 sobre accentSurface
    brandDeep: Color(0xFF0B3B38), // 12.38:1 con texto blanco
    onBrandDeep: Colors.white,
    success: Color(0xFF15803D), // 5.02:1
    successSurface: Color(0xFFE6F4EA),
    onSuccessSurface: Color(0xFF0F5C2C), // 7.15:1
    warning: Color(0xFFA16207), // 4.92:1
    warningSurface: Color(0xFFFDF3E3),
    onWarningSurface: Color(0xFF7A4A06), // 6.80:1
    error: Color(0xFFB42318), // 6.57:1
    errorSurface: Color(0xFFFDECEA),
    onErrorSurface: Color(0xFF8F1D14), // 7.80:1
    info: Color(0xFF175CD3), // 5.99:1
    infoSurface: Color(0xFFE8F0FE),
    onInfoSurface: Color(0xFF10428F), // 8.34:1
    disabledFill: Color(0xFFE3EBE9),
    onDisabled: Color(0xFF5A6C69),
  );

  /// Paleta oscura.
  ///
  /// No es la clara con los grises invertidos: en oscuro la marca tiene que
  /// aclararse para seguir contrastando, y las superficies semánticas pasan de
  /// tintes claros a fondos profundos con el trazo claro encima. Cada par está
  /// verificado igual que en claro.
  static const dark = AppPalette(
    background: Color(0xFF0B1413),
    card: Color(0xFF152322),
    cardSubtle: Color(0xFF0F1C1B),
    fill: Color(0xFF1D302E),
    border: Color(0xFF2B3F3C),
    borderStrong: Color(0xFF607E79), // 3.67:1 sobre la tarjeta
    textPrimary: Color(0xFFE8F0EE), // 14.00:1
    textSecondary: Color(0xFFB6C6C3), // 9.15:1
    textMuted: Color(0xFF93A5A2), // 6.29:1
    textFaint: Color(0xFF93A5A2),
    accent: Color(0xFF3FCFBE), // 8.40:1
    accentSurface: Color(0xFF0E3B37),
    accentText: Color(0xFF8FE8DA), // 8.66:1 sobre accentSurface
    // En oscuro la tarjeta hero no puede ser "más oscura que el fondo": se
    // aclara un paso y sigue siendo la superficie dominante.
    brandDeep: Color(0xFF0E3B37),
    onBrandDeep: Color(0xFFE8F0EE),
    success: Color(0xFF54D07E), // 8.26:1
    successSurface: Color(0xFF0F3320),
    onSuccessSurface: Color(0xFF8FE0AB), // 8.86:1
    warning: Color(0xFFE5B75A), // 8.69:1
    warningSurface: Color(0xFF3A2C0D),
    onWarningSurface: Color(0xFFF0CE8A), // 8.99:1
    error: Color(0xFFFF8A7A), // 7.08:1
    errorSurface: Color(0xFF3D1712),
    onErrorSurface: Color(0xFFFFB3A6), // 9.21:1
    info: Color(0xFF7FB0F7), // 7.30:1
    infoSurface: Color(0xFF122A4D),
    onInfoSurface: Color(0xFFAECBFA), // 8.69:1
    disabledFill: Color(0xFF1D302E),
    onDisabled: Color(0xFF93A5A2),
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
    Color? brandDeep,
    Color? onBrandDeep,
    Color? success,
    Color? successSurface,
    Color? onSuccessSurface,
    Color? warning,
    Color? warningSurface,
    Color? onWarningSurface,
    Color? error,
    Color? errorSurface,
    Color? onErrorSurface,
    Color? info,
    Color? infoSurface,
    Color? onInfoSurface,
    Color? disabledFill,
    Color? onDisabled,
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
      brandDeep: brandDeep ?? this.brandDeep,
      onBrandDeep: onBrandDeep ?? this.onBrandDeep,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      onSuccessSurface: onSuccessSurface ?? this.onSuccessSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      onWarningSurface: onWarningSurface ?? this.onWarningSurface,
      error: error ?? this.error,
      errorSurface: errorSurface ?? this.errorSurface,
      onErrorSurface: onErrorSurface ?? this.onErrorSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      onInfoSurface: onInfoSurface ?? this.onInfoSurface,
      disabledFill: disabledFill ?? this.disabledFill,
      onDisabled: onDisabled ?? this.onDisabled,
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
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      onBrandDeep: Color.lerp(onBrandDeep, other.onBrandDeep, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      onSuccessSurface: Color.lerp(onSuccessSurface, other.onSuccessSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      onWarningSurface: Color.lerp(onWarningSurface, other.onWarningSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      onErrorSurface: Color.lerp(onErrorSurface, other.onErrorSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      onInfoSurface: Color.lerp(onInfoSurface, other.onInfoSurface, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
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
  static ThemeData get light => _base(_scheme(AppPalette.light, Brightness.light), AppPalette.light);

  static ThemeData get dark => _base(_scheme(AppPalette.dark, Brightness.dark), AppPalette.dark);

  /// El `ColorScheme` se deriva de la paleta en vez de escribirse aparte.
  ///
  /// Antes eran dos fuentes de verdad: la paleta decía una cosa y el
  /// `ColorScheme` de Material otra, así que un `FilledButton` sin estilo
  /// propio salía de un color distinto al de un botón hecho a mano al lado.
  /// Todo lo que Material pinta por su cuenta —diálogos, `SnackBar`, el cursor
  /// de un campo— sale ahora de los mismos tokens.
  static ColorScheme _scheme(AppPalette p, Brightness brightness) {
    final onBrand = brightness == Brightness.light ? Colors.white : const Color(0xFF08201E);
    return ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: onBrand,
      primaryContainer: p.accentSurface,
      onPrimaryContainer: p.accentText,
      secondary: p.brandDeep,
      onSecondary: p.onBrandDeep,
      secondaryContainer: p.accentSurface,
      onSecondaryContainer: p.accentText,
      tertiary: p.info,
      onTertiary: onBrand,
      tertiaryContainer: p.infoSurface,
      onTertiaryContainer: p.onInfoSurface,
      error: p.error,
      onError: onBrand,
      errorContainer: p.errorSurface,
      onErrorContainer: p.onErrorSurface,
      surface: p.card,
      onSurface: p.textPrimary,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.background,
      surfaceContainer: p.cardSubtle,
      surfaceContainerHigh: p.fill,
      surfaceContainerHighest: p.fill,
      onSurfaceVariant: p.textMuted,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.card,
      inversePrimary: p.accentSurface,
    );
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette) {
    final isLight = scheme.brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.card,
      dividerColor: palette.border,
      canvasColor: palette.card,
      extensions: [palette],
      textTheme: _textTheme(palette),

      // El foco tiene que verse. Sin esto, recorrer la app con teclado o con un
      // conmutador es recorrerla a ciegas: WCAG 2.4.7 lo exige y Material lo
      // dibuja tan tenue que en varias de estas superficies desaparecía.
      focusColor: palette.accent.withValues(alpha: 0.12),
      hoverColor: palette.accent.withValues(alpha: 0.06),
      splashColor: palette.accent.withValues(alpha: 0.10),
      highlightColor: palette.accent.withValues(alpha: 0.06),

      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),

      // 52 px de alto y radio 16 en todo botón que no traiga estilo propio, que
      // es lo que hace que los botones sueltos de pantallas aún sin migrar no
      // desentonen con los del sistema nuevo.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: AppType.button.copyWith(fontWeight: FontWeight.w700),
          disabledBackgroundColor: palette.disabledFill,
          disabledForegroundColor: palette.onDisabled,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: palette.accent,
          foregroundColor: scheme.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: AppType.button.copyWith(fontWeight: FontWeight.w700),
          disabledBackgroundColor: palette.disabledFill,
          disabledForegroundColor: palette.onDisabled,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.borderStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: AppType.button.copyWith(fontWeight: FontWeight.w700),
          disabledForegroundColor: palette.onDisabled,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: AppType.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          // 44×44 en todo botón de icono. El objetivo táctil no es el dibujo:
          // la app tenía cierres de aviso de 26 px y borrados de 28.
          minimumSize: const Size(44, 44),
          foregroundColor: palette.textSecondary,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? palette.card : palette.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: palette.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: palette.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
        labelStyle: AppType.bodyMedium.copyWith(color: palette.textMuted),
        floatingLabelStyle: AppType.label.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: AppType.bodyMedium.copyWith(color: palette.textMuted),
        errorStyle: AppType.bodySmall.copyWith(
          color: palette.error,
          fontWeight: FontWeight.w600,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: AppType.bodyMedium.copyWith(color: palette.card),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        titleTextStyle: AppType.titleMedium.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: AppType.bodyMedium.copyWith(color: palette.textSecondary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: palette.borderStrong,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.titleMedium.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.fill,
        selectedColor: palette.accentSurface,
        side: BorderSide(color: palette.border),
        labelStyle: AppType.bodySmall.copyWith(color: palette.textSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.fill,
        circularTrackColor: palette.fill,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: palette.textMuted,
        titleTextStyle: AppType.bodyMedium.copyWith(color: palette.textPrimary),
        subtitleTextStyle: AppType.bodySmall.copyWith(color: palette.textMuted),
        minVerticalPadding: 12,
      ),
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
      displaySmall: AppType.hero.copyWith(
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
      ),
      headlineLarge: AppType.display.copyWith(
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
      ),
      headlineMedium: AppType.titleLarge.copyWith(
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
        fontWeight: FontWeight.w600,
        color: palette.textSecondary,
      ),
      labelSmall: AppType.overline.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.textMuted,
      ),
    );
  }
}
