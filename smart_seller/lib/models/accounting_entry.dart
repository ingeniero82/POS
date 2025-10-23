class AccountingEntry {
  final int? id;
  final String type; // 'income' o 'expense'
  final double amount;
  final String description;
  final String? category;
  final DateTime date;
  final int userId;
  final DateTime createdAt;
  final bool isActive;

  AccountingEntry({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    required this.date,
    required this.userId,
    required this.createdAt,
    this.isActive = true,
  });

  // Convertir de Map a AccountingEntry
  factory AccountingEntry.fromMap(Map<String, dynamic> map) {
    return AccountingEntry(
      id: map['id'],
      type: map['type'],
      amount: map['amount'].toDouble(),
      description: map['description'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
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
      'date': date.toIso8601String(),
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Crear copia con cambios
  AccountingEntry copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? category,
    DateTime? date,
    int? userId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return AccountingEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'AccountingEntry(id: $id, type: $type, amount: $amount, description: $description, category: $category, date: $date, userId: $userId, createdAt: $createdAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountingEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
