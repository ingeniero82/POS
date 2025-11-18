/// Utilidades para formatear números en formato colombiano (pesos)
/// Formato: puntos (.) para separar miles, sin decimales por defecto
/// Ejemplo: 100000 -> 100.000
/// Ejemplo: 1000000 -> 1.000.000

class CurrencyFormatter {
  /// Formatea un número como moneda colombiana (pesos)
  /// [amount] - El monto a formatear
  /// [includeDecimals] - Si incluir decimales (por defecto false)
  /// [includeSymbol] - Si incluir el símbolo $ (por defecto true)
  /// 
  /// Retorna: String formateado (ej: "100.000" o "$ 100.000")
  static String formatCurrency(
    double amount, {
    bool includeDecimals = false,
    bool includeSymbol = true,
  }) {
    // Redondear si no se incluyen decimales
    final numToFormat = includeDecimals ? amount : amount.roundToDouble();
    
    // Convertir a entero si no hay decimales
    final intValue = includeDecimals ? null : numToFormat.toInt();
    
    // Formatear con separadores de miles (puntos)
    String formatted;
    if (includeDecimals) {
      // Con decimales: usar comas para decimales
      final parts = numToFormat.toStringAsFixed(2).split('.');
      final integerPart = _formatWithThousandSeparators(int.parse(parts[0]));
      formatted = '$integerPart,${parts[1]}';
    } else {
      // Sin decimales: solo separadores de miles
      formatted = _formatWithThousandSeparators(intValue!);
    }
    
    // Agregar símbolo si se requiere
    return includeSymbol ? '\$ $formatted' : formatted;
  }
  
  /// Formatea un número entero con separadores de miles (puntos)
  /// Ejemplo: 100000 -> "100.000"
  static String _formatWithThousandSeparators(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
  
  /// Formatea un número simple (sin símbolo de moneda)
  /// Útil para cantidades, porcentajes, etc.
  static String formatNumber(double number, {bool includeDecimals = false}) {
    if (includeDecimals) {
      return number.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    } else {
      return _formatWithThousandSeparators(number.toInt());
    }
  }
}

