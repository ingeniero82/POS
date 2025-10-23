class SupplierPayment {
  final int? id;
  final int supplierId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? description;
  final int userId;
  final DateTime createdAt;
  final bool isActive;

  SupplierPayment({
    this.id,
    required this.supplierId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.description,
    required this.userId,
    required this.createdAt,
    this.isActive = true,
  });

  // Convertir de Map a SupplierPayment
  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'],
      supplierId: map['supplier_id'],
      amount: map['amount'].toDouble(),
      paymentDate: DateTime.parse(map['payment_date']),
      paymentMethod: map['payment_method'],
      description: map['description'],
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
    );
  }

  // Convertir de SupplierPayment a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'description': description,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Crear copia con cambios
  SupplierPayment copyWith({
    int? id,
    int? supplierId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? description,
    int? userId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'SupplierPayment(id: $id, supplierId: $supplierId, amount: $amount, paymentDate: $paymentDate, paymentMethod: $paymentMethod, description: $description, userId: $userId, createdAt: $createdAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplierPayment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
