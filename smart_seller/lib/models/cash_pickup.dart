// Modelo para recogidas de efectivo (retiros parciales durante la jornada)

class CashPickup {
  int? id;
  late DateTime date;
  late double amount; // Monto retirado
  late String reason; // Razón del retiro
  late int userId; // Usuario que realiza el retiro
  late int? cashSessionId; // ID de la sesión de caja asociada
  String? notes; // Notas adicionales
  String? authorizedBy; // Usuario que autorizó (si aplica)
  late DateTime createdAt;
  late DateTime updatedAt;
  
  CashPickup({
    this.id,
    required this.date,
    required this.amount,
    required this.reason,
    required this.userId,
    this.cashSessionId,
    this.notes,
    this.authorizedBy,
    required this.createdAt,
    required this.updatedAt,
  });
  
  // Constructor desde Map (para base de datos)
  CashPickup.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    date = DateTime.parse(map['date']);
    amount = (map['amount'] as num).toDouble();
    reason = map['reason'];
    userId = map['userId'];
    cashSessionId = map['cashSessionId'];
    notes = map['notes'];
    authorizedBy = map['authorizedBy'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'reason': reason,
      'userId': userId,
      'cashSessionId': cashSessionId,
      'notes': notes,
      'authorizedBy': authorizedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  // Copiar con modificaciones
  CashPickup copyWith({
    int? id,
    DateTime? date,
    double? amount,
    String? reason,
    int? userId,
    int? cashSessionId,
    String? notes,
    String? authorizedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashPickup(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      userId: userId ?? this.userId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      notes: notes ?? this.notes,
      authorizedBy: authorizedBy ?? this.authorizedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

