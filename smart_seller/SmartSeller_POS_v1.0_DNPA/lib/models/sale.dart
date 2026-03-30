// Modelo de venta sin Isar

/// Parte de un pago mixto: método + monto (ej. Efectivo 50.000, Nequi 23.000).
class PaymentPart {
  final String method;
  final double amount;

  PaymentPart({required this.method, required this.amount});

  Map<String, dynamic> toMap() => {'method': method, 'amount': amount};

  static PaymentPart fromMap(Map<String, dynamic> map) => PaymentPart(
        method: map['method'] as String? ?? 'Efectivo',
        amount:
            (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      );
}

class Sale {
  int? id;
  late DateTime date;
  late double total;
  late String user;
  String? paymentMethod;
  late List<SaleItem> items;

  /// Desglose por método cuando es pago mixto (ej. parte efectivo, parte Nequi).
  /// Si no es null, paymentMethod suele ser "Mixto" y la contabilidad/reportes usan esto.
  List<PaymentPart>? paymentBreakdown;

  /// ID del cliente del sistema (customers) si la venta fue con cliente seleccionado.
  int? customerId;
  /// ID del cliente de facturación electrónica (clients) si la venta fue con cliente DIAN.
  int? clientId;

  // ✅ NUEVO: Campos profesionales para reportes
  double? discount; // Descuento total aplicado
  double? discountPercentage; // Porcentaje de descuento
  bool isReturn = false; // Indica si es una devolución
  int? originalSaleId; // ID de la venta original (si es devolución)
  double? returnedAmount; // Monto devuelto

  /// Indica si la venta fue anulada (no se cuenta en totales ni en inventario).
  bool isAnulada = false;
  DateTime? anuladaAt;
  String? anuladaPor;

  // Constructor
  Sale({
    this.id,
    required this.date,
    required this.total,
    required this.user,
    this.paymentMethod,
    required this.items,
    this.paymentBreakdown,
    this.customerId,
    this.clientId,
    this.discount,
    this.discountPercentage,
    this.isReturn = false,
    this.originalSaleId,
    this.returnedAmount,
    this.isAnulada = false,
    this.anuladaAt,
    this.anuladaPor,
  });
}

class SaleItem {
  late String name;
  late double price;
  late int quantity;
  late String unit;
  double? discount; // ✅ NUEVO: Descuento por item
  double? discountPercentage; // ✅ NUEVO: % de descuento por item
  /// IVA del producto (0 = exento, 19 = gravado). Para reporte de cierre "IVA incluido".
  int ivaPercentage;

  /// ID en tabla `products` (POS). Permite "productos frecuentes" y reportes sin depender solo de nombre/unidad.
  int? productId;

  /// Kg vendidos (producto pesado con inventario por kg). Si es null, el descuento de stock usa [quantity] en unidades.
  double? weightKg;

  // Constructor
  SaleItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    this.discount,
    this.discountPercentage,
    this.ivaPercentage = 19,
    this.productId,
    this.weightKg,
  });
}
