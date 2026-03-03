// Modelo para sesiones de caja
// Representa la apertura y cierre de caja diaria

class CashSession {
  final int? id;
  final DateTime openDate; // Fecha y hora de apertura
  final DateTime? closeDate; // Fecha y hora de cierre
  final double initialAmount; // Monto inicial de apertura
  final double? finalAmount; // Monto final al cerrar
  final double? totalIncome; // Total de ingresos del día
  final double? totalExpense; // Total de egresos del día
  final double? difference; // Diferencia entre teórico y real
  final int userId; // Usuario que abrió la caja
  final int? closedByUserId; // Usuario que cerró la caja
  final String status; // 'open', 'closed', 'pending_review'
  final String? notes; // Notas del cierre
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  CashSession({
    this.id,
    required this.openDate,
    this.closeDate,
    required this.initialAmount,
    this.finalAmount,
    this.totalIncome,
    this.totalExpense,
    this.difference,
    required this.userId,
    this.closedByUserId,
    this.status = 'open',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Convertir de Map a CashSession
  factory CashSession.fromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'],
      openDate: DateTime.parse(map['open_date']),
      closeDate: map['close_date'] != null ? DateTime.parse(map['close_date']) : null,
      initialAmount: map['initial_amount']?.toDouble() ?? 0.0,
      finalAmount: map['final_amount']?.toDouble(),
      totalIncome: map['total_income']?.toDouble(),
      totalExpense: map['total_expense']?.toDouble(),
      difference: map['difference']?.toDouble(),
      userId: map['user_id'],
      closedByUserId: map['closed_by_user_id'],
      status: map['status'] ?? 'open',
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isActive: map['is_active'] == 1,
    );
  }

  // Convertir de CashSession a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'open_date': openDate.toIso8601String(),
      'close_date': closeDate?.toIso8601String(),
      'initial_amount': initialAmount,
      'final_amount': finalAmount,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'difference': difference,
      'user_id': userId,
      'closed_by_user_id': closedByUserId,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Crear copia con cambios
  CashSession copyWith({
    int? id,
    DateTime? openDate,
    DateTime? closeDate,
    double? initialAmount,
    double? finalAmount,
    double? totalIncome,
    double? totalExpense,
    double? difference,
    int? userId,
    int? closedByUserId,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CashSession(
      id: id ?? this.id,
      openDate: openDate ?? this.openDate,
      closeDate: closeDate ?? this.closeDate,
      initialAmount: initialAmount ?? this.initialAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      difference: difference ?? this.difference,
      userId: userId ?? this.userId,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Calcular saldo teórico
  double get theoreticalBalance {
    return initialAmount + (totalIncome ?? 0) - (totalExpense ?? 0);
  }

  // Verificar si la sesión está abierta
  bool get isOpen => status == 'open';

  // Verificar si la sesión está cerrada
  bool get isClosed => status == 'closed';

  @override
  String toString() {
    return 'CashSession(id: $id, openDate: $openDate, status: $status, initialAmount: $initialAmount)';
  }
}
