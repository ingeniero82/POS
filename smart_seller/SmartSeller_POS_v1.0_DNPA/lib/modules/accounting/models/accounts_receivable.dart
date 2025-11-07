// Modelo para cuentas por cobrar (facturas pendientes de clientes)

class AccountsReceivable {
  final int? id;
  final int customerId;
  final String customerName;
  final String customerDocument;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String status; // 'pending', 'partial', 'paid', 'overdue'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountsReceivable({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.customerDocument,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountsReceivable.fromMap(Map<String, dynamic> map) {
    return AccountsReceivable(
      id: map['id'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      customerDocument: map['customer_document'],
      totalAmount: map['total_amount'].toDouble(),
      paidAmount: map['paid_amount'].toDouble(),
      pendingAmount: map['pending_amount'].toDouble(),
      invoiceNumber: map['invoice_number'],
      invoiceDate: DateTime.parse(map['invoice_date']),
      dueDate: DateTime.parse(map['due_date']),
      status: map['status'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_document': customerDocument,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'pending_amount': pendingAmount,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AccountsReceivable copyWith({
    int? id,
    int? customerId,
    String? customerName,
    String? customerDocument,
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountsReceivable(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerDocument: customerDocument ?? this.customerDocument,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Calcular días de vencimiento
  int get daysOverdue {
    final now = DateTime.now();
    final difference = now.difference(dueDate).inDays;
    return difference > 0 ? difference : 0;
  }

  // Verificar si está vencida
  bool get isOverdue {
    return DateTime.now().isAfter(dueDate) && status != 'paid';
  }

  // Calcular porcentaje pagado
  double get paymentPercentage {
    if (totalAmount == 0) return 0;
    return (paidAmount / totalAmount) * 100;
  }
}
