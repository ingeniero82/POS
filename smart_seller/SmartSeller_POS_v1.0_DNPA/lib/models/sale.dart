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
  });
}

class SaleItem {
  late String name;
  late double price;
  late int quantity;
  late String unit;
  double? discount; // ✅ NUEVO: Descuento por item
  double? discountPercentage; // ✅ NUEVO: % de descuento por item
  
  // Constructor
  SaleItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    this.discount,
    this.discountPercentage,
  });
} 