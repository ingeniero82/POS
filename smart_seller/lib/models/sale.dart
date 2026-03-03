// Modelo de venta sin Isar

class Sale {
  int? id;
  late DateTime date;
  late double total;
  late String user;
  String? paymentMethod;
  late List<SaleItem> items;
  
  // ✅ NUEVO: Campos profesionales para reportes
  double? discount; // Descuento total aplicado
  double? discountPercentage; // Porcentaje de descuento
  bool isReturn = false; // Indica si es una devolución
  int? originalSaleId; // ID de la venta original (si es devolución)
  double? returnedAmount; // Monto devuelto
  
  // ✅ NUEVO: Desglose de ventas por tipo de IVA
  double exemptAmount = 0.0; // Ventas exentas
  double excludedAmount = 0.0; // Ventas excluidas
  double taxedAmount = 0.0; // Ventas gravadas
  
  // ✅ NUEVO: Desglose de IVA por tasas
  double vatAt0 = 0.0; // IVA a tasa 0%
  double vatAt5 = 0.0; // IVA a tasa 5%
  double vatAt19 = 0.0; // IVA a tasa 19%
  double totalVat = 0.0; // Total IVA
  
  // ✅ NUEVO: IpoConsumo y bolsas
  double ipoConsumoAmount = 0.0; // Total IpoConsumo
  double plasticBagTaxAmount = 0.0; // Total impuesto bolsas
  int plasticBagCount = 0; // Cantidad de bolsas
  
  // ✅ NUEVO: Subtotal antes de impuestos
  double subtotal = 0.0; // Subtotal sin impuestos
  
  // Constructor
  Sale({
    this.id,
    required this.date,
    required this.total,
    required this.user,
    this.paymentMethod,
    required this.items,
    this.discount,
    this.discountPercentage,
    this.isReturn = false,
    this.originalSaleId,
    this.returnedAmount,
    this.exemptAmount = 0.0,
    this.excludedAmount = 0.0,
    this.taxedAmount = 0.0,
    this.vatAt0 = 0.0,
    this.vatAt5 = 0.0,
    this.vatAt19 = 0.0,
    this.totalVat = 0.0,
    this.ipoConsumoAmount = 0.0,
    this.plasticBagTaxAmount = 0.0,
    this.plasticBagCount = 0,
    this.subtotal = 0.0,
  });
}

class SaleItem {
  late String name;
  late double price;
  late int quantity;
  late String unit;
  double? discount; // ✅ NUEVO: Descuento por item
  double? discountPercentage; // ✅ NUEVO: % de descuento por item
  
  // ✅ NUEVO: Campos de IVA del item
  String vatType = 'GRAVADO'; // EXENTO, EXCLUIDO, GRAVADO
  double vatRate = 0.19; // Tasa de IVA aplicada
  double itemVat = 0.0; // IVA calculado para este item
  
  // ✅ NUEVO: Campos de IpoConsumo del item
  bool hasIpoConsumo = false;
  double? ipoConsumoRate;
  String? ipoConsumoType;
  double itemIpoConsumo = 0.0; // IpoConsumo calculado
  
  // ✅ NUEVO: Campos de bolsas plásticas
  bool isPlasticBag = false;
  double? plasticBagTax;
  int? bagQuantity; // Cantidad de bolsas (si aplica)
  
  // ✅ NUEVO: Subtotal del item (sin impuestos)
  double itemSubtotal = 0.0;
  
  // Constructor
  SaleItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    this.discount,
    this.discountPercentage,
    this.vatType = 'GRAVADO',
    this.vatRate = 0.19,
    this.itemVat = 0.0,
    this.hasIpoConsumo = false,
    this.ipoConsumoRate,
    this.ipoConsumoType,
    this.itemIpoConsumo = 0.0,
    this.isPlasticBag = false,
    this.plasticBagTax,
    this.bagQuantity,
    this.itemSubtotal = 0.0,
  });
  
  // Calcular total del item (con impuestos)
  double get total {
    double base = itemSubtotal > 0 ? itemSubtotal : (price * quantity);
    if (discount != null && discount! > 0) {
      base -= discount!;
    } else if (discountPercentage != null && discountPercentage! > 0) {
      base -= (base * discountPercentage! / 100);
    }
    return base + itemVat + itemIpoConsumo + (plasticBagTax != null && bagQuantity != null ? plasticBagTax! * bagQuantity! : 0.0);
  }
} 