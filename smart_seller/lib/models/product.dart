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

  // ✅ NUEVO: Campos para facturación electrónica DIAN
  String? taxCode; // Código de impuesto (IVA, Exento, etc.)
  double taxRate = 19.0; // Tasa de impuesto (19% por defecto)
  bool isExempt = false; // Si está exento de impuestos
  String? productType; // Tipo de producto según DIAN
  String? brand; // Marca del producto
  String? model; // Modelo del producto
  String? barcode; // Código de barras EAN/UPC
  String? manufacturer; // Fabricante
  String? countryOfOrigin; // País de origen
  String? customsCode; // Código arancelario
  double? netWeight; // Peso neto
  double? grossWeight; // Peso bruto
  String? dimensions; // Dimensiones (Largo x Ancho x Alto)
  String? material; // Material del producto
  String? warranty; // Garantía
  String? expirationDate; // Fecha de vencimiento
  bool isService = false; // Si es un servicio en lugar de producto
  String? serviceCode; // Código de servicio según DIAN

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
  
  // ✅ NUEVO: Calcular impuestos para facturación electrónica
  double get taxAmount => isExempt ? 0 : (price * taxRate / 100);
  double get totalWithTax => price + taxAmount;
  
  // ✅ NUEVO: Obtener información para facturación electrónica
  Map<String, dynamic> get electronicInvoiceData {
    return {
      'code': code,
      'name': name,
      'description': description,
      'unit': unit,
      'quantity': 1, // Se ajustará según la venta
      'price': price,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'total': totalWithTax,
      'isExempt': isExempt,
      'productType': productType ?? 'PRODUCTO',
      'brand': brand,
      'model': model,
      'barcode': barcode,
      'manufacturer': manufacturer,
      'countryOfOrigin': countryOfOrigin,
      'customsCode': customsCode,
      'netWeight': netWeight,
      'grossWeight': grossWeight,
      'dimensions': dimensions,
      'material': material,
      'warranty': warranty,
      'expirationDate': expirationDate,
      'isService': isService,
      'serviceCode': serviceCode,
    };
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
    // ✅ NUEVO: Parámetros para facturación electrónica
    this.taxCode,
    this.taxRate = 19.0,
    this.isExempt = false,
    this.productType,
    this.brand,
    this.model,
    this.barcode,
    this.manufacturer,
    this.countryOfOrigin,
    this.customsCode,
    this.netWeight,
    this.grossWeight,
    this.dimensions,
    this.material,
    this.warranty,
    this.expirationDate,
    this.isService = false,
    this.serviceCode,
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
    
    // ✅ NUEVO: Campos de facturación electrónica
    taxCode = map['taxCode'];
    taxRate = map['taxRate'] ?? 19.0;
    isExempt = map['isExempt'] == 1;
    productType = map['productType'];
    brand = map['brand'];
    model = map['model'];
    barcode = map['barcode'];
    manufacturer = map['manufacturer'];
    countryOfOrigin = map['countryOfOrigin'];
    customsCode = map['customsCode'];
    netWeight = map['netWeight'];
    grossWeight = map['grossWeight'];
    dimensions = map['dimensions'];
    material = map['material'];
    warranty = map['warranty'];
    expirationDate = map['expirationDate'];
    isService = map['isService'] == 1;
    serviceCode = map['serviceCode'];
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
      // ✅ NUEVO: Campos de facturación electrónica
      'taxCode': taxCode,
      'taxRate': taxRate,
      'isExempt': isExempt ? 1 : 0,
      'productType': productType,
      'brand': brand,
      'model': model,
      'barcode': barcode,
      'manufacturer': manufacturer,
      'countryOfOrigin': countryOfOrigin,
      'customsCode': customsCode,
      'netWeight': netWeight,
      'grossWeight': grossWeight,
      'dimensions': dimensions,
      'material': material,
      'warranty': warranty,
      'expirationDate': expirationDate,
      'isService': isService ? 1 : 0,
      'serviceCode': serviceCode,
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
    // ✅ NUEVO: Parámetros de facturación electrónica
    String? taxCode,
    double? taxRate,
    bool? isExempt,
    String? productType,
    String? brand,
    String? model,
    String? barcode,
    String? manufacturer,
    String? countryOfOrigin,
    String? customsCode,
    double? netWeight,
    double? grossWeight,
    String? dimensions,
    String? material,
    String? warranty,
    String? expirationDate,
    bool? isService,
    String? serviceCode,
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
      // ✅ NUEVO: Campos de facturación electrónica
      taxCode: taxCode ?? this.taxCode,
      taxRate: taxRate ?? this.taxRate,
      isExempt: isExempt ?? this.isExempt,
      productType: productType ?? this.productType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      barcode: barcode ?? this.barcode,
      manufacturer: manufacturer ?? this.manufacturer,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      customsCode: customsCode ?? this.customsCode,
      netWeight: netWeight ?? this.netWeight,
      grossWeight: grossWeight ?? this.grossWeight,
      dimensions: dimensions ?? this.dimensions,
      material: material ?? this.material,
      warranty: warranty ?? this.warranty,
      expirationDate: expirationDate ?? this.expirationDate,
      isService: isService ?? this.isService,
      serviceCode: serviceCode ?? this.serviceCode,
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
  servicios, // ✅ NUEVO: Para servicios
  otros,
} 