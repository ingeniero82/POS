// Modelo para métodos de pago
// Define los diferentes métodos de pago disponibles

class PaymentMethod {
  final int? id;
  final String name; // Nombre del método de pago
  final String code; // Código único del método
  final String type; // 'cash', 'card', 'transfer', 'check', 'other'
  final bool requiresChange; // Si requiere devolución (efectivo)
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentMethod({
    this.id,
    required this.name,
    required this.code,
    required this.type,
    this.requiresChange = false,
    this.isActive = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convertir de Map a PaymentMethod
  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      type: map['type'],
      requiresChange: map['requires_change'] == 1,
      isActive: map['is_active'] == 1,
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Convertir de PaymentMethod a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'requires_change': requiresChange ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Crear copia con cambios
  PaymentMethod copyWith({
    int? id,
    String? name,
    String? code,
    String? type,
    bool? requiresChange,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      requiresChange: requiresChange ?? this.requiresChange,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PaymentMethod(id: $id, name: $name, code: $code, type: $type)';
  }
}
