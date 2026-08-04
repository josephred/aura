/// Formato de importes de la plataforma.
///
/// Existía por triplicado: una función `formatClp` en `appointments_screen`, y
/// dos expresiones regulares copiadas a mano en el seguimiento y en el
/// formulario de solicitud. Las copias se etiquetaban como **ARS** —pesos
/// argentinos— en una app que cobra en CLP: el paciente veía la moneda
/// equivocada justo en la pantalla donde acepta el monto.
///
/// Hoy la plataforma opera en un solo país. Esto no es un sistema multi-país;
/// es el único sitio donde habría que tocar el día que lo sea, en lugar de
/// buscar seis literales repartidos por las pantallas.
class Money {
  const Money._();

  /// Código ISO 4217. Debe coincidir con `currency_id` en las preferencias de
  /// Mercado Pago del backend, o el cobro se crea en otra moneda que la que
  /// se le mostró al paciente.
  static const code = 'CLP';

  static const symbol = r'$';

  /// El peso chileno no usa decimales, así que los importes son enteros y el
  /// separador de miles es el punto.
  static const _thousandsSeparator = '.';

  /// `$19.500`. Con [withCode], `$19.500 CLP`.
  static String format(int amount, {bool withCode = false}) {
    final negative = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(_thousandsSeparator);
      }
      buffer.write(digits[i]);
    }

    final formatted = '${negative ? '-' : ''}$symbol$buffer';

    return withCode ? '$formatted $code' : formatted;
  }
}
