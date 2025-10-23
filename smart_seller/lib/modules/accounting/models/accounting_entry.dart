// Modelo base para entradas contables
// Representa cualquier movimiento contable (ingreso o egreso)

class AccountingEntry {
  final int? id;
  final String type; // 'income' o 'expense'
  final double amount;
  final String description;
  final String? category;
  final String? subcategory;
  final DateTime date;
  final String? reference; // Referencia a factura, comprobante, etc.
  final String? paymentMethod; // Método de pago utilizado
  final int userId; // Usuario que registró la transacción
  final int? cashSessionId; // Sesión de caja asociada
  final String? relatedEntity; // Cliente, proveedor, etc.
  final int? relatedEntityId; // ID de la entidad relacionada
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? notes; // Notas adicionales
  final String? documentNumber; // Número de documento/comprobante

  AccountingEntry({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    this.subcategory,
    required this.date,
    this.reference,
    this.paymentMethod,
    required this.userId,
    this.cashSessionId,
    this.relatedEntity,
    this.relatedEntityId,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.notes,
    this.documentNumber,
  });

  // Convertir de Map a AccountingEntry
  factory AccountingEntry.fromMap(Map<String, dynamic> map) {
    return AccountingEntry(
      id: map['id'],
      type: map['type'],
      amount: map['amount']?.toDouble() ?? 0.0,
      description: map['description'],
      category: map['category'],
      subcategory: map['subcategory'],
      date: DateTime.parse(map['date']),
      reference: map['reference'],
      paymentMethod: map['payment_method'],
      userId: map['user_id'],
      cashSessionId: map['cash_session_id'],
      relatedEntity: map['related_entity'],
      relatedEntityId: map['related_entity_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isActive: map['is_active'] == 1,
      notes: map['notes'],
      documentNumber: map['document_number'],
    );
  }

  // Convertir de AccountingEntry a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'date': date.toIso8601String(),
      'reference': reference,
      'payment_method': paymentMethod,
      'user_id': userId,
      'cash_session_id': cashSessionId,
      'related_entity': relatedEntity,
      'related_entity_id': relatedEntityId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'document_number': documentNumber,
    };
  }

  // Crear copia con cambios
  AccountingEntry copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? category,
    String? subcategory,
    DateTime? date,
    String? reference,
    String? paymentMethod,
    int? userId,
    int? cashSessionId,
    String? relatedEntity,
    int? relatedEntityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? notes,
    String? documentNumber,
  }) {
    return AccountingEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      date: date ?? this.date,
      reference: reference ?? this.reference,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      userId: userId ?? this.userId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      relatedEntity: relatedEntity ?? this.relatedEntity,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      documentNumber: documentNumber ?? this.documentNumber,
    );
  }

  @override
  String toString() {
    return 'AccountingEntry(id: $id, type: $type, amount: $amount, description: $description, date: $date, userId: $userId)';
  }
}
