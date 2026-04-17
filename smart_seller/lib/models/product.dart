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
  late String category; // Nombre de la categoría (dinámico)
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

  // ✅ NUEVO: Campos para gestión de IVA
  String vatType = 'GRAVADO'; // EXENTO, EXCLUIDO, GRAVADO
  double vatRate = 0.19; // Tasa de IVA: 0.0, 0.05, 0.19 (0%, 5%, 19%)

  // ✅ NUEVO: Campos para IpoConsumo
  bool hasIpoConsumo = false; // Indica si tiene impuesto al consumo
  double? ipoConsumoRate; // Tasa de IpoConsumo (ej: 0.08 para 8%)
  String? ipoConsumoType; // Tipo: LICOR, CIGARRILLOS, BOLSAS, OTRO

  // ✅ NUEVO: Campos para control de bolsas plásticas
  bool isPlasticBag = false; // Indica si es una bolsa plástica
  double? plasticBagTax; // Impuesto por bolsa (valor fijo por bolsa)

  // Campos calculados
  double get profit => price - cost;
  // ✅ CORREGIDO: Fórmula estándar de POS: (Precio de venta - Costo) / Precio de venta × 100
  double get profitMargin => price > 0 ? ((price - cost) / price) * 100 : 0;
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
    this.vatType = 'GRAVADO',
    this.vatRate = 0.19,
    this.hasIpoConsumo = false,
    this.ipoConsumoRate,
    this.ipoConsumoType,
    this.isPlasticBag = false,
    this.plasticBagTax,
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
    category = map['category'] ?? 'Otros';
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
    // ✅ NUEVO: Campos de IVA
    vatType = map['vatType'] ?? 'GRAVADO';
    vatRate = (map['vatRate'] ?? 0.19).toDouble();
    // ✅ NUEVO: Campos de IpoConsumo
    hasIpoConsumo = map['hasIpoConsumo'] == 1;
    ipoConsumoRate = map['ipoConsumoRate'] != null
        ? (map['ipoConsumoRate'] as num).toDouble()
        : null;
    ipoConsumoType = map['ipoConsumoType'];
    // ✅ NUEVO: Campos de bolsas plásticas
    isPlasticBag = map['isPlasticBag'] == 1;
    plasticBagTax = map['plasticBagTax'] != null
        ? (map['plasticBagTax'] as num).toDouble()
        : null;
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
      'category': category,
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
      // ✅ NUEVO: Campos de IVA
      'vatType': vatType,
      'vatRate': vatRate,
      // ✅ NUEVO: Campos de IpoConsumo
      'hasIpoConsumo': hasIpoConsumo ? 1 : 0,
      'ipoConsumoRate': ipoConsumoRate,
      'ipoConsumoType': ipoConsumoType,
      // ✅ NUEVO: Campos de bolsas plásticas
      'isPlasticBag': isPlasticBag ? 1 : 0,
      'plasticBagTax': plasticBagTax,
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
    bool? isWeighted,
    double? pricePerKg,
    double? weight,
    double? minWeight,
    double? maxWeight,
    String? vatType,
    double? vatRate,
    bool? hasIpoConsumo,
    double? ipoConsumoRate,
    String? ipoConsumoType,
    bool? isPlasticBag,
    double? plasticBagTax,
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
      vatType: vatType ?? this.vatType,
      vatRate: vatRate ?? this.vatRate,
      hasIpoConsumo: hasIpoConsumo ?? this.hasIpoConsumo,
      ipoConsumoRate: ipoConsumoRate ?? this.ipoConsumoRate,
      ipoConsumoType: ipoConsumoType ?? this.ipoConsumoType,
      isPlasticBag: isPlasticBag ?? this.isPlasticBag,
      plasticBagTax: plasticBagTax ?? this.plasticBagTax,
    );
  }
}

// Enum eliminado - ahora usamos grupos dinámicos
