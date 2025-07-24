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

  // Constructor
  Group({
    this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Constructor desde Map (para base de datos)
  Group.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'] ?? '';
    description = map['description'] ?? '';
    color = map['color'] ?? '#9E9E9E';
    icon = map['icon'] ?? 'category';
    
    // Parsear fechas de forma segura
    try {
      createdAt = DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    try {
      updatedAt = DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      updatedAt = DateTime.now();
    }
    
    isActive = map['isActive'] == 1;
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
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Group(id: $id, name: $name, description: $description, color: $color, icon: $icon, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 