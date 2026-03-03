// Modelo para pagos de cuentas por pagar

class PayablePayment {
  final int? id;
  final int accountsPayableId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final int userId;
  final DateTime createdAt;

  PayablePayment({
    this.id,
    required this.accountsPayableId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.userId,
    required this.createdAt,
  });

  factory PayablePayment.fromMap(Map<String, dynamic> map) {
    return PayablePayment(
      id: map['id'],
      accountsPayableId: map['accounts_payable_id'],
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
      'accounts_payable_id': accountsPayableId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PayablePayment copyWith({
    int? id,
    int? accountsPayableId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
    String? notes,
    int? userId,
    DateTime? createdAt,
  }) {
    return PayablePayment(
      id: id ?? this.id,
      accountsPayableId: accountsPayableId ?? this.accountsPayableId,
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
