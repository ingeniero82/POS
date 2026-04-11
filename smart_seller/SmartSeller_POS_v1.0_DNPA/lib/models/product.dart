// Modelo de producto sin Isar

class Product {
  int? id;
  late String code;
  /// Opcional. Si es null, en caja solo aplica búsqueda por [code] o por nombre.
  String? shortCode;
  late String name;
  late String description;
  late double price;
  late double cost;
  late int stock;
  late int minStock;
  late String category; // Nombre de la categoría (dinámico)
  late String unit;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  String? imageUrl;
  
  /// Porcentaje de IVA: 19 = gravado, 0 = exento. Por defecto 19.
  int ivaPercentage = 19;

  // Campos para productos pesados
  bool isWeighted = false; // Indica si es un producto que se vende por peso
  double? pricePerKg; // Precio por kilogramo
  double? weight; // Peso actual del producto (para productos pesados)
  double? minWeight; // Peso mínimo para venta
  double? maxWeight; // Peso máximo para venta

  /// Si es true y [isWeighted], el inventario se controla en kg ([stockKg]); si false, en unidades ([stock]).
  bool weightedStockInKg = false;
  /// Kilogramos disponibles cuando [weightedStockInKg] es true.
  double stockKg = 0;

  // Campos calculados
  double get profit => price - cost;
  // ✅ CORREGIDO: Fórmula estándar de POS: (Precio de venta - Costo) / Precio de venta × 100
  double get profitMargin => price > 0 ? ((price - cost) / price) * 100 : 0;
  bool get isLowStock => isWeighted && weightedStockInKg
      ? stockKg <= minStock
      : stock <= minStock;
  
  // Para productos pesados, el precio se calcula dinámicamente
  double get calculatedPrice {
    if (isWeighted && pricePerKg != null && weight != null) {
      return pricePerKg! * weight!;
    }
    return price;
  }
  
  // Constructor
  Product({
    this.id,
    required this.code,
    this.shortCode,
    required this.name,
    required this.description,
    required this.price,
    required this.cost,
    required this.stock,
    required this.minStock,
    required this.category,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.imageUrl,
    this.ivaPercentage = 19,
    this.isWeighted = false,
    this.pricePerKg,
    this.weight,
    this.minWeight,
    this.maxWeight,
    this.weightedStockInKg = false,
    this.stockKg = 0,
  });
  
  // Constructor desde Map (para base de datos)
  Product.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    final sc = map['shortCode'];
    if (sc == null || sc.toString().trim().isEmpty) {
      shortCode = null;
    } else {
      shortCode = sc.toString();
    }
    name = map['name'];
    description = map['description'];
    price = map['price'];
    cost = map['cost'];
    stock = map['stock'];
    minStock = map['minStock'];
    category = map['category'] ?? 'Sin categoría';
    unit = map['unit'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    imageUrl = map['imageUrl'];
    ivaPercentage = map['ivaPercentage'] ?? 19;
    isWeighted = map['isWeighted'] == 1;
    pricePerKg = map['pricePerKg'];
    weight = map['weight'];
    minWeight = map['minWeight'];
    maxWeight = map['maxWeight'];
    weightedStockInKg = (map['weightedStockInKg'] as int? ?? 0) == 1;
    stockKg = (map['stockKg'] as num?)?.toDouble() ?? 0.0;
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'shortCode': (shortCode == null || shortCode!.trim().isEmpty)
          ? null
          : shortCode!.trim(),
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock': stock,
      'minStock': minStock,
      'category': category,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'imageUrl': imageUrl,
      'ivaPercentage': ivaPercentage,
      'isWeighted': isWeighted ? 1 : 0,
      'pricePerKg': pricePerKg,
      'weight': weight,
      'minWeight': minWeight,
      'maxWeight': maxWeight,
      'weightedStockInKg': weightedStockInKg ? 1 : 0,
      'stockKg': stockKg,
    };
  }
  
  // Copiar con modificaciones
  Product copyWith({
    int? id,
    String? code,
    String? shortCode,
    String? name,
    String? description,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    String? category,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? imageUrl,
    int? ivaPercentage,
    bool? isWeighted,
    double? pricePerKg,
    double? weight,
    double? minWeight,
    double? maxWeight,
    bool? weightedStockInKg,
    double? stockKg,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      shortCode: shortCode ?? this.shortCode,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      ivaPercentage: ivaPercentage ?? this.ivaPercentage,
      isWeighted: isWeighted ?? this.isWeighted,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      weight: weight ?? this.weight,
      minWeight: minWeight ?? this.minWeight,
      maxWeight: maxWeight ?? this.maxWeight,
      weightedStockInKg: weightedStockInKg ?? this.weightedStockInKg,
      stockKg: stockKg ?? this.stockKg,
    );
  }
}

// Enum eliminado - ahora usamos grupos dinámicos 