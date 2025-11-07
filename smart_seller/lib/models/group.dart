// Modelo de grupo dinámico para productos

class Group {
  int? id;
  late String name;
  late String description;
  late String color;
  late String icon;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  
  // ✅ NUEVO: Tasa de IVA por defecto para la categoría (0%, 5%, 19%)
  double defaultVatRate = 0.19; // Tasa por defecto 19%
  String defaultVatType = 'GRAVADO'; // EXENTO, EXCLUIDO, GRAVADO

  Group({
    this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.defaultVatRate = 0.19,
    this.defaultVatType = 'GRAVADO',
  });

  // Constructor desde Map (para base de datos)
  Group.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    description = map['description'];
    color = map['color'];
    icon = map['icon'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    // ✅ NUEVO: Campos de IVA por defecto
    defaultVatRate = (map['defaultVatRate'] ?? 0.19).toDouble();
    defaultVatType = map['defaultVatType'] ?? 'GRAVADO';
  }

  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      // ✅ NUEVO: Campos de IVA por defecto
      'defaultVatRate': defaultVatRate,
      'defaultVatType': defaultVatType,
    };
  }

  // Copiar con modificaciones
  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    double? defaultVatRate,
    String? defaultVatType,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      defaultVatType: defaultVatType ?? this.defaultVatType,
    );
  }

  @override
  String toString() {
    return 'Group(id: $id, name: $name, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 