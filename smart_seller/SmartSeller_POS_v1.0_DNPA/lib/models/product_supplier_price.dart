/// Precio de compra actual de un producto para un proveedor (Fase 1).
/// Un producto puede tener varios proveedores; cada par (producto, proveedor) es único.
class ProductSupplierPrice {
  final int? id;
  final int productId;
  final int supplierId;
  /// Código o referencia que usa el proveedor para este ítem.
  final String? supplierReference;
  final double purchasePrice;
  final DateTime updatedAt;

  const ProductSupplierPrice({
    this.id,
    required this.productId,
    required this.supplierId,
    this.supplierReference,
    required this.purchasePrice,
    required this.updatedAt,
  });

  factory ProductSupplierPrice.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic v) => (v as num).toInt();
    return ProductSupplierPrice(
      id: map['id'] != null ? asInt(map['id']) : null,
      productId: asInt(map['product_id']),
      supplierId: asInt(map['supplier_id']),
      supplierReference: map['supplier_reference'] as String?,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'supplier_id': supplierId,
      'supplier_reference': supplierReference,
      'purchase_price': purchasePrice,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMapForInsert() {
    final m = toMap();
    m.remove('id');
    return m;
  }

  ProductSupplierPrice copyWith({
    int? id,
    int? productId,
    int? supplierId,
    String? supplierReference,
    double? purchasePrice,
    DateTime? updatedAt,
  }) {
    return ProductSupplierPrice(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      supplierReference: supplierReference ?? this.supplierReference,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Fila con datos del producto y proveedor (resultado de búsqueda o listados).
class ProductSupplierPriceDetail {
  final ProductSupplierPrice offer;
  final String productCode;
  final String productShortCode;
  final String productName;
  final String supplierName;

  const ProductSupplierPriceDetail({
    required this.offer,
    required this.productCode,
    required this.productShortCode,
    required this.productName,
    required this.supplierName,
  });

  factory ProductSupplierPriceDetail.fromJoinedMap(Map<String, dynamic> map) {
    return ProductSupplierPriceDetail(
      offer: ProductSupplierPrice.fromMap(map),
      productCode: map['product_code'] as String? ?? '',
      productShortCode: map['product_short_code'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      supplierName: map['supplier_name'] as String? ?? '',
    );
  }
}
