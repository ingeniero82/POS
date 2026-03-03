// Modelo para pagos de cuentas por cobrar

class ReceivablePayment {
  final int? id;
  final int accountsReceivableId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final int userId;
  final DateTime createdAt;

  ReceivablePayment({
    this.id,
    required this.accountsReceivableId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.userId,
    required this.createdAt,
  });

  factory ReceivablePayment.fromMap(Map<String, dynamic> map) {
    return ReceivablePayment(
      id: map['id'],
      accountsReceivableId: map['accounts_receivable_id'],
      amount: map['amount'].toDouble(),
      paymentDate: DateTime.parse(map['payment_date']),
      paymentMethod: map['payment_method'],
      reference: map['reference'],
      notes: map['notes'],
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accounts_receivable_id': accountsReceivableId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReceivablePayment copyWith({
    int? id,
    int? accountsReceivableId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
    int? userId,
    DateTime? createdAt,
  }) {
    return ReceivablePayment(
      id: id ?? this.id,
      accountsReceivableId: accountsReceivableId ?? this.accountsReceivableId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
