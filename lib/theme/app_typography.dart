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
/// Son constantes en vez de leerse del tema porque medio centenar de métodos
/// `_buildAlgo()` no reciben `BuildContext`, y obligarlos a recibirlo para
/// poner un tamaño de letra habría sido un refactor mucho mayor que el problema.
class AppType {
  const AppType._();

  // ---------------------------------------------------------------- titulares

  /// Cifras y titulares de portada. 32 → 28 no aplica: los tamaños grandes
  /// existentes se dejaron intactos, esto es para composiciones nuevas.
  static const display = TextStyle(fontSize: 28, height: 1.2);

  static const titleLarge = TextStyle(fontSize: 22, height: 1.3);
  static const titleMedium = TextStyle(fontSize: 18, height: 1.35);
  static const titleSmall = TextStyle(fontSize: 16, height: 1.35);

  // ------------------------------------------------------------------- cuerpo

  /// El interlineado de 1.55 no es decoración: en párrafos de tres líneas es lo
  /// que más reduce el esfuerzo de lectura, y hasta ahora solo 42 de ~396
  /// estilos declaraban `height`; el resto usaba el ~1.2 del tipo.
  static const bodyLarge = TextStyle(fontSize: 17, height: 1.55);
  static const bodyMedium = TextStyle(fontSize: 15, height: 1.55);
  static const bodySmall = TextStyle(fontSize: 14, height: 1.5);

  // ---------------------------------------------------------------- etiquetas

  /// Texto de botones.
  static const button = TextStyle(fontSize: 15, height: 1.3);

  /// Etiquetas en versalitas y metadatos. Es el único rol que se queda en 12:
  /// son cadenas cortas que no se leen de corrido, y mantenerlas pequeñas es lo
  /// que devuelve la jerarquía que el piso a 12 había aplanado.
  ///
  /// Al migrar, estas etiquetas se reconocen por su `letterSpacing` **positivo**.
  /// Cuidado con la regla inversa: un `letterSpacing` negativo es tracking
  /// apretado de titular grande, justo lo contrario. El saludo de la portada
  /// («¿Cómo podemos ayudar?», 24 pt con `letterSpacing: -0.5`) cayó una vez en
  /// este rol por esa confusión y encogió a la mitad.
  static const label = TextStyle(fontSize: 12, height: 1.3);
}
