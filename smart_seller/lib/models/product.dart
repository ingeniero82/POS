// Modelo de producto sin Isar

class Product {
  int? id;
  late String code;
  late String shortCode;
  late String name;
  late String description;
  late double price;
  late double cost;
  late int stock;
  late int minStock;
  late ProductCategory category;
  late String unit;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  String? imageUrl;
  
  // Campos para productos pesados
  bool isWeighted = false; // Indica si es un producto que se vende por peso
  double? pricePerKg; // Precio por kilogramo
  double? weight; // Peso actual del producto (para productos pesados)
  double? minWeight; // Peso mínimo para venta
  double? maxWeight; // Peso máximo para venta

  // Campos calculados
  double get profit => price - cost;
  double get profitMargin => cost > 0 ? ((price - cost) / cost) * 100 : 0;
  bool get isLowStock => stock <= minStock;
  
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
    required this.shortCode,
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
    this.isWeighted = false,
    this.pricePerKg,
    this.weight,
    this.minWeight,
    this.maxWeight,
  });
  
  // Constructor desde Map (para base de datos)
  Product.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    shortCode = map['shortCode'];
    name = map['name'];
    description = map['description'];
    price = map['price'];
    cost = map['cost'];
    stock = map['stock'];
    minStock = map['minStock'];
    category = ProductCategory.values.firstWhere(
      (e) => e.toString() == 'ProductCategory.${map['category']}',
      orElse: () => ProductCategory.otros,
    );
    unit = map['unit'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    imageUrl = map['imageUrl'];
    isWeighted = map['isWeighted'] == 1;
    pricePerKg = map['pricePerKg'];
    weight = map['weight'];
    minWeight = map['minWeight'];
    maxWeight = map['maxWeight'];
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'shortCode': shortCode,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock': stock,
      'minStock': minStock,
      'category': category.toString().split('.').last,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'imageUrl': imageUrl,
      'isWeighted': isWeighted ? 1 : 0,
      'pricePerKg': pricePerKg,
      'weight': weight,
      'minWeight': minWeight,
      'maxWeight': maxWeight,
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
    ProductCategory? category,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? imageUrl,
    bool? isWeighted,
    double? pricePerKg,
    double? weight,
    double? minWeight,
    double? maxWeight,
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
      isWeighted: isWeighted ?? this.isWeighted,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      weight: weight ?? this.weight,
      minWeight: minWeight ?? this.minWeight,
      maxWeight: maxWeight ?? this.maxWeight,
    );
  }
}

enum ProductCategory {
  frutasVerduras,
  lacteos,
  panaderia,
  carnes,
  bebidas,
  abarrotes,
  limpieza,
  cuidadoPersonal,
  otros,
} 