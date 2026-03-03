// Modelo para categorías de transacciones
// Organiza los ingresos y egresos por categorías

class TransactionCategory {
  final int? id;
  final String name;
  final String code;
  final String type; // 'income' o 'expense'
  final String? parentCategory; // Categoría padre para subcategorías
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionCategory({
    this.id,
    required this.name,
    required this.code,
    required this.type,
    this.parentCategory,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convertir de Map a TransactionCategory
  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      type: map['type'],
      parentCategory: map['parent_category'],
      description: map['description'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Convertir de TransactionCategory a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'parent_category': parentCategory,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Crear copia con cambios
  TransactionCategory copyWith({
    int? id,
    String? name,
    String? code,
    String? type,
    String? parentCategory,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      parentCategory: parentCategory ?? this.parentCategory,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TransactionCategory(id: $id, name: $name, code: $code, type: $type)';
  }
}
