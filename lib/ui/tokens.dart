/// # Tokens del sistema de diseño de Aura
///
/// Una sola definición para cada decisión visual que se repite. Antes de esto
/// la app tenía diez radios distintos (2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24,
/// 28, 30, 999), separaciones verticales en catorce valores distintos y unos
/// 140 colores escritos a mano en las pantallas. Nada de eso era una decisión:
/// era el residuo de haber escrito cada pantalla por separado.
///
/// La regla al usar estos tokens: si necesitas un valor que no está aquí,
/// probablemente lo que necesitas es uno de los que sí está.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------- espaciado

/// Escala de espaciado en pasos de 4. Todo el aire de la app sale de aquí.
///
/// Los nombres son de tamaño y no de uso a propósito: `md` sirve igual para
/// separar dos párrafos que para el padding de una tarjeta, y ponerle nombre
/// de uso ("cardPadding") habría multiplicado los tokens sin añadir decisiones.
abstract final class AuraSpace {
  /// 2 — separaciones ópticas dentro de una misma línea.
  static const double xxxs = 2;

  /// 4 — entre un icono y su etiqueta.
  static const double xxs = 4;

  /// 8 — entre elementos muy relacionados.
  static const double xs = 8;

  /// 12 — entre filas de una misma tarjeta.
  static const double sm = 12;

  /// 16 — padding estándar de tarjeta y separación entre tarjetas.
  static const double md = 16;

  /// 20 — márgenes laterales de pantalla.
  static const double lg = 20;

  /// 24 — entre bloques distintos de una pantalla.
  static const double xl = 24;

  /// 32 — antes de una acción principal.
  static const double xxl = 32;

  /// 40 — entre secciones mayores.
  static const double xxxl = 40;

  /// 56 — aire de los estados vacíos.
  static const double huge = 56;

  /// Margen lateral de pantalla. Un solo número para que ninguna pantalla
  /// quede desalineada respecto de otra.
  static const double screenX = lg;

  /// Espacio que hay que reservar bajo el contenido para que la barra inferior
  /// no tape la última tarjeta.
  static const double navClearance = 96;
}

// -------------------------------------------------------------------- radios

/// Cuatro radios. No hay un quinto caso.
abstract final class AuraRadius {
  /// 8 — insignias, chips pequeños, miniaturas.
  static const double xs = 8;

  /// 12 — campos de formulario y controles.
  static const double sm = 12;

  /// 16 — botones y tarjetas interiores.
  static const double md = 16;

  /// 20 — tarjetas de contenido.
  static const double lg = 20;

  /// 28 — superficies grandes: hojas inferiores, tarjetas hero.
  static const double xl = 28;

  /// Píldoras. Un número grande, no `999`, porque `999` en una caja de 40 px de
  /// alto y una de 400 dan el mismo resultado y sugiere un control que no es.
  static const double pill = 100;

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));

  /// Hoja inferior: solo las esquinas de arriba.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

// -------------------------------------------------------------- iconografía

/// Tamaños de icono.
///
/// El piso es 18 y no 12. Un icono de 12 px junto a texto de 15 no es un icono:
/// es una mancha. Los tamaños diminutos que había antes (8, 10, 11, 12, 13)
/// desaparecen del sistema.
abstract final class AuraIcon {
  /// 18 — dentro de una línea de texto.
  static const double sm = 18;

  /// 22 — el tamaño por defecto, en botones y filas de lista.
  static const double md = 22;

  /// 28 — iconos de servicio y de navegación.
  static const double lg = 28;

  /// 36 — icono principal de una tarjeta grande.
  static const double xl = 36;

  /// 48 — ilustración de un estado vacío o de éxito.
  static const double display = 48;
}

// ------------------------------------------------------------ objetivos táctiles

/// Medidas mínimas de cualquier cosa que se pueda tocar.
///
/// WCAG 2.2 AA (2.5.8) pide 24×24 como mínimo absoluto; 44×44 es lo que
/// recomienda la práctica y lo que este producto necesita, porque su público
/// declarado son personas adultas que a menudo usan el teléfono con una mano.
abstract final class AuraTap {
  /// 44 — mínimo de cualquier control.
  static const double min = 44;

  /// 52 — alto de un botón normal.
  static const double comfortable = 52;

  /// 60 — alto de la acción principal de una pantalla y de las opciones de un
  /// flujo guiado, que es donde el error de toque cuesta más caro.
  static const double large = 60;

  /// Separación mínima entre dos controles tocables contiguos, para que fallar
  /// el toque no active el de al lado.
  static const double gap = AuraSpace.sm;
}

// ------------------------------------------------------------------ movimiento

/// Duraciones y curvas.
///
/// Ninguna animación de esta app puede hacer esperar a nadie: la más larga es
/// de un cuarto de segundo. La regla es que la animación explique un cambio que
/// ya ocurrió, no que lo retrase.
abstract final class AuraMotion {
  /// 120 ms — respuesta al toque, cambio de color.
  static const Duration fast = Duration(milliseconds: 120);

  /// 180 ms — aparición y desaparición de un elemento.
  static const Duration base = Duration(milliseconds: 180);

  /// 240 ms — transición entre pasos de un flujo.
  static const Duration slow = Duration(milliseconds: 240);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOut;
}

// ------------------------------------------------------------------ elevación

/// Sombras.
///
/// Suaves y de tinte frío en claro; inexistentes en oscuro, donde la separación
/// entre superficies la da el color y no la sombra. La app tenía sombras con
/// `alpha: 0.01` —literalmente invisibles— que solo costaban una capa de
/// composición por tarjeta.
abstract final class AuraShadow {
  static List<BoxShadow> none() => const [];

  /// Tarjeta apoyada en el fondo.
  static List<BoxShadow> soft(bool isDark) => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0D0B2320),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ];

  /// Elemento que flota: barra inferior, hoja, botón destacado.
  static List<BoxShadow> lifted(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 20,
            offset: Offset(0, -2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x140B2320),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ];

  /// Diálogo o menú por encima de todo.
  static List<BoxShadow> overlay(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F0B2320),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ];
}

// ---------------------------------------------------------------- breakpoints

/// Anchos a partir de los cuales cambia la composición.
///
/// La app es móvil primero: estos cortes existen para que en una tablet o en el
/// navegador el contenido no se estire hasta perder legibilidad, no para
/// diseñar una pantalla de escritorio distinta.
abstract final class AuraBreak {
  /// Teléfono pequeño. Por debajo de esto, las rejillas caen a una columna.
  static const double compact = 360;

  /// Teléfono grande / tablet en vertical.
  static const double medium = 600;

  /// Tablet en horizontal y escritorio.
  static const double expanded = 900;

  /// Ancho máximo de una columna de contenido. Más allá, el texto se vuelve
  /// incómodo de leer y los botones absurdamente anchos.
  static const double readable = 560;

  static bool isCompact(BuildContext c) =>
      MediaQuery.sizeOf(c).width < compact;
  static bool isMedium(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= medium;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= expanded;

  /// Cuántas columnas caben en la rejilla de servicios.
  static int serviceColumns(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= expanded) return 4;
    if (w >= medium) return 3;
    return 2;
  }
}

/// Centra y acota el contenido en pantallas anchas.
///
/// Sin esto, la versión web de la app estira una tarjeta a 1400 px y deja el
/// texto en una sola línea de punta a punta.
class AuraReadable extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AuraReadable({
    super.key,
    required this.child,
    this.maxWidth = AuraBreak.readable,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
