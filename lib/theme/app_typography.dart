import 'package:flutter/material.dart';

/// Escala tipográfica de Aura.
///
/// Existe porque la app tenía 396 tamaños escritos a mano, el 55 % de ellos por
/// debajo de 12 pt, en un producto cuyo público declarado son adultos mayores.
/// Aquí viven el tamaño y el interlineado; el color y el peso los sigue
/// poniendo cada pantalla, que es donde tienen significado.
///
/// **Solo tamaño y altura de línea, a propósito.** Si estos estilos trajeran
/// peso o color, migrar una pantalla cambiaría su aspecto de formas difíciles
/// de prever. Con `copyWith` en el sitio de uso, lo que ya estaba escrito
/// manda, y lo único que cambia es lo que queríamos cambiar.
///
/// ## El suelo subió
///
/// La revisión de las pantallas encontró texto de 9, 10 y 11 pt haciendo de
/// cuerpo —no de metadato— y `label` (12 pt) sosteniendo el aviso de seguridad
/// del inicio, los rótulos de los chips y todas las marcas de tiempo del chat.
/// El suelo real de esta app pasa a ser **13 pt**, y el cuerpo por defecto de
/// 14 a 15. Minimalismo no significa letra pequeña: significa menos cosas, y
/// las que quedan, legibles.
///
/// Son constantes en vez de leerse del tema porque medio centenar de métodos
/// `_buildAlgo()` no reciben `BuildContext`, y obligarlos a recibirlo para
/// poner un tamaño de letra habría sido un refactor mucho mayor que el problema.
class AppType {
  const AppType._();

  // ---------------------------------------------------------------- titulares

  /// 34 — la pregunta de un paso del flujo guiado. Es el rol más grande de la
  /// app y solo se usa cuando en la pantalla no hay nada que compita con él:
  /// «¿Para quién es la atención?», «¿Qué necesitas hoy?».
  static const hero = TextStyle(fontFamily: 'Roboto', fontSize: 34, height: 1.15, letterSpacing: -0.8);

  /// 30 — cifras y titulares de portada.
  static const display = TextStyle(fontFamily: 'Roboto', fontSize: 30, height: 1.2, letterSpacing: -0.6);

  static const titleLarge = TextStyle(fontFamily: 'Roboto', fontSize: 24, height: 1.25, letterSpacing: -0.4);
  static const titleMedium = TextStyle(fontFamily: 'Roboto', fontSize: 19, height: 1.3, letterSpacing: -0.2);
  static const titleSmall = TextStyle(fontFamily: 'Roboto', fontSize: 17, height: 1.35);

  // ------------------------------------------------------------------- cuerpo

  /// El interlineado de 1.5 no es decoración: en párrafos de tres líneas es lo
  /// que más reduce el esfuerzo de lectura, y hasta ahora solo 42 de ~396
  /// estilos declaraban `height`; el resto usaba el ~1.2 del tipo.
  static const bodyLarge = TextStyle(fontFamily: 'Roboto', fontSize: 18, height: 1.5);
  static const bodyMedium = TextStyle(fontFamily: 'Roboto', fontSize: 16, height: 1.5);

  /// 15 — era 14. Es el estilo más usado de la app con diferencia: subirlo un
  /// punto es el cambio de legibilidad más barato que había disponible.
  static const bodySmall = TextStyle(fontFamily: 'Roboto', fontSize: 15, height: 1.45);

  // ---------------------------------------------------------------- etiquetas

  /// Texto de botones. 17 y no 15: la acción principal de una pantalla no
  /// debería tener la letra más pequeña que el párrafo que la explica.
  static const button = TextStyle(fontFamily: 'Roboto', fontSize: 17, height: 1.2, letterSpacing: -0.1);

  /// 13 — metadatos y rótulos cortos: la fecha de una tarjeta, el nombre de
  /// una insignia, la unidad junto a una cifra. Era 12.
  ///
  /// **No es un estilo de cuerpo.** Si el texto se lee de corrido —un aviso,
  /// la descripción de una opción, un mensaje de error— el rol correcto es
  /// [bodySmall]. Ese es exactamente el mal uso que este comentario intenta
  /// evitar que vuelva: el aviso de riesgo vital del inicio estuvo en 12 pt.
  static const label = TextStyle(fontFamily: 'Roboto', fontSize: 13, height: 1.35);

  /// 13 en versalitas. Para los rótulos de sección en mayúsculas, que sin
  /// `letterSpacing` positivo se leen como un grito apelmazado.
  static const overline = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0.8,
  );

  /// Cifras tabulares: precios y contadores que se apilan y tienen que
  /// alinearse por la coma.
  static const numeric = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
