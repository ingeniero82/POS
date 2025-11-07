// Modelo para movimientos de caja
// Registra cada entrada y salida de dinero en la caja

class CashMovement {
  final int? id;
  final String type; // 'income' o 'expense'
  final double amount;
  final String description;
  final String? paymentMethod; // efectivo, tarjeta, transferencia, etc.
  final DateTime date;
  final int userId; // Usuario que realizó el movimiento
  final int? cashSessionId; // Sesión de caja asociada
  final String? reference; // Referencia a venta, pago, etc.
  final int? referenceId; // ID de la referencia
  final String? category; // Categoría del movimiento
  final DateTime createdAt;
  final bool isActive;
  final String? notes; // Notas adicionales
  final String? documentNumber; // Número de comprobante

  CashMovement({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.paymentMethod,
    required this.date,
    required this.userId,
    this.cashSessionId,
    this.reference,
    this.referenceId,
    this.category,
    required this.createdAt,
    this.isActive = true,
    this.notes,
    this.documentNumber,
  });

  // Convertir de Map a CashMovement
  factory CashMovement.fromMap(Map<String, dynamic> map) {
    return CashMovement(
      id: map['id'],
      type: map['type'],
      amount: map['amount']?.toDouble() ?? 0.0,
      description: map['description'],
      paymentMethod: map['payment_method'],
      date: DateTime.parse(map['date']),
      userId: map['user_id'],
      cashSessionId: map['cash_session_id'],
      reference: map['reference'],
      referenceId: map['reference_id'],
      category: map['category'],
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
      notes: map['notes'],
      documentNumber: map['document_number'],
    );
  }

  // Convertir de CashMovement a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'payment_method': paymentMethod,
      'date': date.toIso8601String(),
      'user_id': userId,
      'cash_session_id': cashSessionId,
      'reference': reference,
      'reference_id': referenceId,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'document_number': documentNumber,
    };
  }

  // Crear copia con cambios
  CashMovement copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? paymentMethod,
    DateTime? date,
    int? userId,
    int? cashSessionId,
    String? reference,
    int? referenceId,
    String? category,
    DateTime? createdAt,
    bool? isActive,
    String? notes,
    String? documentNumber,
  }) {
    return CashMovement(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      reference: reference ?? this.reference,
      referenceId: referenceId ?? this.referenceId,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      documentNumber: documentNumber ?? this.documentNumber,
    );
  }

  @override
  String toString() {
    return 'CashMovement(id: $id, type: $type, amount: $amount, description: $description, date: $date, userId: $userId)';
  }
}
