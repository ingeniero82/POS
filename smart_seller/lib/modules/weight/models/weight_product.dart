import '../../../models/product.dart';

/// Modelo extendido para productos pesados
/// Incluye funcionalidades específicas para manejo de peso
class WeightProduct extends Product {
  // Campos adicionales específicos para productos pesados
  double? targetWeight; // Peso objetivo para el producto
  double? tolerance; // Tolerancia en el peso (±)
  DateTime? lastWeighed; // Última vez que se pesó
  String? scaleId; // ID de la balanza utilizada
  bool requiresScale; // Indica si requiere balanza obligatoriamente
  
  WeightProduct({
    // Campos heredados de Product
    super.id,
    required super.code,
    required super.shortCode,
    required super.name,
    required super.description,
    required super.price,
    required super.cost,
    required super.stock,
    required super.minStock,
    required super.category,
    required super.unit,
    required super.createdAt,
    required super.updatedAt,
    super.isActive = true,
    super.imageUrl,
    super.isWeighted = true, // Siempre true para productos pesados
    super.pricePerKg,
    super.weight,
    super.minWeight,
    super.maxWeight,
    
    // Campos específicos de WeightProduct
    this.targetWeight,
    this.tolerance,
    this.lastWeighed,
    this.scaleId,
    this.requiresScale = false,
  });

  // Constructor desde Product
  WeightProduct.fromProduct(Product product, {
    double? targetWeight,
    double? tolerance,
    DateTime? lastWeighed,
    String? scaleId,
    bool requiresScale = false,
  }) : targetWeight = targetWeight,
       tolerance = tolerance,
       lastWeighed = lastWeighed,
       scaleId = scaleId,
       requiresScale = requiresScale,
       super(
         id: product.id,
         code: product.code,
         shortCode: product.shortCode,
         name: product.name,
         description: product.description,
         price: product.price,
         cost: product.cost,
         stock: product.stock,
         minStock: product.minStock,
         category: product.category,
         unit: product.unit,
         createdAt: product.createdAt,
         updatedAt: product.updatedAt,
         isActive: product.isActive,
         imageUrl: product.imageUrl,
         isWeighted: true,
         pricePerKg: product.pricePerKg,
         weight: product.weight,
         minWeight: product.minWeight,
         maxWeight: product.maxWeight,
       );

  // Constructor desde Map (para base de datos)
  WeightProduct.fromMap(Map<String, dynamic> map)
      : targetWeight = map['targetWeight'],
        tolerance = map['tolerance'],
        lastWeighed = map['lastWeighed'] != null 
            ? DateTime.parse(map['lastWeighed']) 
            : null,
        scaleId = map['scaleId'],
        requiresScale = map['requiresScale'] == 1,
        super.fromMap(map);

  // Convertir a Map (para base de datos)
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'targetWeight': targetWeight,
      'tolerance': tolerance,
      'lastWeighed': lastWeighed?.toIso8601String(),
      'scaleId': scaleId,
      'requiresScale': requiresScale ? 1 : 0,
    });
    return map;
  }

  // Copiar con modificaciones
  @override
  WeightProduct copyWith({
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
    double? targetWeight,
    double? tolerance,
    DateTime? lastWeighed,
    String? scaleId,
    bool? requiresScale,
  }) {
    return WeightProduct(
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
      targetWeight: targetWeight ?? this.targetWeight,
      tolerance: tolerance ?? this.tolerance,
      lastWeighed: lastWeighed ?? this.lastWeighed,
      scaleId: scaleId ?? this.scaleId,
      requiresScale: requiresScale ?? this.requiresScale,
    );
  }

  // Validar si el peso actual está dentro del rango válido
  bool isWeightValid() {
    if (weight == null) return false;
    
    // Validar límites mínimos y máximos
    if (minWeight != null && weight! < minWeight!) return false;
    if (maxWeight != null && weight! > maxWeight!) return false;
    
    // Validar tolerancia si hay peso objetivo
    if (targetWeight != null && tolerance != null) {
      final diff = (weight! - targetWeight!).abs();
      return diff <= tolerance!;
    }
    
    return true;
  }

  // Calcular diferencia con el peso objetivo
  double? getWeightDifference() {
    if (weight == null || targetWeight == null) return null;
    return weight! - targetWeight!;
  }

  // Verificar si está dentro de la tolerancia
  bool isWithinTolerance() {
    if (tolerance == null) return true;
    final diff = getWeightDifference();
    if (diff == null) return false;
    return diff.abs() <= tolerance!;
  }

  // Obtener porcentaje de diferencia con el peso objetivo
  double? getWeightDifferencePercentage() {
    if (weight == null || targetWeight == null || targetWeight == 0) return null;
    return ((weight! - targetWeight!) / targetWeight!) * 100;
  }

  // Obtener status del peso
  WeightStatus getWeightStatus() {
    if (weight == null) return WeightStatus.unknown;
    
    if (!isWeightValid()) {
      if (minWeight != null && weight! < minWeight!) return WeightStatus.underWeight;
      if (maxWeight != null && weight! > maxWeight!) return WeightStatus.overWeight;
    }
    
    if (targetWeight != null && tolerance != null) {
      final diff = getWeightDifference()!;
      if (diff.abs() <= tolerance!) {
        return WeightStatus.optimal;
      } else if (diff < 0) {
        return WeightStatus.underWeight;
      } else {
        return WeightStatus.overWeight;
      }
    }
    
    return WeightStatus.valid;
  }

  // Obtener mensaje de status
  String getWeightStatusMessage() {
    switch (getWeightStatus()) {
      case WeightStatus.optimal:
        return 'Peso óptimo';
      case WeightStatus.valid:
        return 'Peso válido';
      case WeightStatus.underWeight:
        return 'Peso insuficiente';
      case WeightStatus.overWeight:
        return 'Peso excesivo';
      case WeightStatus.unknown:
        return 'Peso desconocido';
    }
  }

  // Actualizar peso con timestamp
  WeightProduct updateWeight(double newWeight, {String? scaleId}) {
    return copyWith(
      weight: newWeight,
      lastWeighed: DateTime.now(),
      scaleId: scaleId,
    );
  }

  // Verificar si necesita ser pesado nuevamente
  bool needsReweighing({Duration? maxAge}) {
    if (lastWeighed == null) return true;
    if (maxAge == null) return false;
    
    final age = DateTime.now().difference(lastWeighed!);
    return age > maxAge;
  }

  // Convertir a Product estándar
  Product toProduct() {
    return Product(
      id: id,
      code: code,
      shortCode: shortCode,
      name: name,
      description: description,
      price: price,
      cost: cost,
      stock: stock,
      minStock: minStock,
      category: category,
      unit: unit,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: isActive,
      imageUrl: imageUrl,
      isWeighted: isWeighted,
      pricePerKg: pricePerKg,
      weight: weight,
      minWeight: minWeight,
      maxWeight: maxWeight,
    );
  }
}

// Enum para el estado del peso
enum WeightStatus {
  optimal,    // Peso óptimo (dentro de tolerancia)
  valid,      // Peso válido (dentro de límites)
  underWeight, // Peso insuficiente
  overWeight,  // Peso excesivo
  unknown,     // Peso desconocido
} 