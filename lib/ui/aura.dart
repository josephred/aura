/// Sistema de diseño de Aura Salud.
///
/// Un solo `import 'package:aura/ui/aura.dart';` da acceso a los tokens y a
/// todos los componentes. Las pantallas no deberían importar `tokens.dart` ni
/// los archivos de componentes por separado.
///
/// ## Qué hay aquí y por qué
///
/// La app tenía 23 000 líneas de interfaz escritas pantalla por pantalla: unos
/// 140 colores a mano donde ya existía una paleta, catorce radios distintos,
/// texto de cuerpo en 9, 10 y 11 pt, y una veintena de controles por debajo del
/// objetivo táctil mínimo. Nada de eso eran decisiones de diseño; era lo que
/// pasa cuando cada pantalla resuelve sola los mismos problemas.
///
/// La regla de uso: **si necesitas un valor que no está en los tokens, lo que
/// necesitas casi siempre es uno de los que sí están**. Y si necesitas un
/// componente que no está aquí, primero conviene mirar si es uno de estos con
/// otro contenido dentro.
library;

export 'aura_button.dart';
export 'aura_choice.dart';
export 'aura_field.dart';
export 'aura_flow.dart';
export 'aura_states.dart';
export 'aura_surface.dart';
export 'tokens.dart';
