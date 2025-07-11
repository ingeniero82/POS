// Modelo de movimiento de inventario sin Isar

class InventoryMovement {
  int? id;
  late int productId;
  late MovementType type;
  late int quantity;
  late MovementReason reason;
  late DateTime date;
  late int userId;
  String? observations;

  InventoryMovement({
    required this.productId,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.date,
    required this.userId,
    this.observations,
  });
}

enum MovementType {
  entrada,
  salida,
  ajuste,
}

enum MovementReason {
  compra,
  venta,
  ajusteManual,
  perdida,
  devolucion,
  otro,
} 