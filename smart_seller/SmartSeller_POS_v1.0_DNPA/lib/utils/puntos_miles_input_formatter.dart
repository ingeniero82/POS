import 'package:flutter/services.dart';

/// Formateador que aplica punto de miles mientras se escribe (estilo Colombia).
/// Solo dígitos; el punto se inserta automáticamente (ej: 10000 → 10.000).
class PuntosMilesInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final soloDigitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final formateado = _conPuntos(soloDigitos);
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }

  static String _conPuntos(String digitos) {
    final buffer = StringBuffer();
    for (int i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }
}

/// Parsea texto con punto de miles (Colombia) a número. Ej: "10.000" → 10000.
double? parseMontoPuntosMiles(String text) {
  final s = text.trim().replaceAll(' ', '').replaceAll('.', '');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Formatea número con punto de miles (solo pesos). Ej: 10000 → "10.000".
String formatMontoPuntosMiles(double value) {
  final entera = value.floor();
  return entera.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}
