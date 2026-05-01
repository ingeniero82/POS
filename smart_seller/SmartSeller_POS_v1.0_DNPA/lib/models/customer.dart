class Customer {
  int? id;
  late String name;
  late String email;
  late String phone;
  String? address;
  String? city;
  String? documentNumber;
  String? documentType;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  
  // Campos para fidelización
  double pointsRate = 1.0; // ✅ NUEVO: Tasa de puntos por cada $1000 (ej: 1.0 = 1 punto por $1000)
  int accumulatedPoints = 0; // ✅ NUEVO: Puntos acumulados del cliente
  DateTime? lastPurchase;
  double totalPurchases = 0.0;
  double storeCredit = 0.0; // ✅ NUEVO: Saldo a favor del cliente
  
  // Constructor
  Customer({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.city,
    this.documentNumber,
    this.documentType,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.pointsRate = 1.0, // ✅ NUEVO: Tasa por defecto 1.0
    this.accumulatedPoints = 0, // ✅ NUEVO: Puntos acumulados por defecto 0
    this.lastPurchase,
    this.totalPurchases = 0.0,
    this.storeCredit = 0.0,
  });
  
  // Constructor desde Map (para base de datos)
  Customer.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    email = map['email'];
    phone = map['phone'];
    address = map['address'];
    city = map['city'];
    documentNumber = map['documentNumber'];
    documentType = map['documentType'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    pointsRate = (map['pointsRate'] ?? 1.0).toDouble(); // ✅ NUEVO: Tasa de puntos
    accumulatedPoints = map['accumulatedPoints'] ?? 0; // ✅ NUEVO: Puntos acumulados
    lastPurchase = map['lastPurchase'] != null 
        ? DateTime.parse(map['lastPurchase']) 
        : null;
    totalPurchases = map['totalPurchases'] ?? 0.0;
    storeCredit = (map['storeCredit'] ?? 0.0).toDouble();
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'documentNumber': documentNumber,
      'documentType': documentType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'pointsRate': pointsRate, // ✅ NUEVO: Tasa de puntos
      'accumulatedPoints': accumulatedPoints, // ✅ NUEVO: Puntos acumulados
      'lastPurchase': lastPurchase?.toIso8601String(),
      'totalPurchases': totalPurchases,
      'storeCredit': storeCredit,
    };
  }
  
  // Copiar con modificaciones
  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? documentNumber,
    String? documentType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    double? pointsRate, // ✅ NUEVO: Tasa de puntos
    int? accumulatedPoints, // ✅ NUEVO: Puntos acumulados
    DateTime? lastPurchase,
    double? totalPurchases,
    double? storeCredit,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      documentNumber: documentNumber ?? this.documentNumber,
      documentType: documentType ?? this.documentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      pointsRate: pointsRate ?? this.pointsRate, // ✅ NUEVO: Tasa de puntos
      accumulatedPoints: accumulatedPoints ?? this.accumulatedPoints, // ✅ NUEVO: Puntos acumulados
      lastPurchase: lastPurchase ?? this.lastPurchase,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      storeCredit: storeCredit ?? this.storeCredit,
    );
  }
  
  // ✅ NUEVO: Método para calcular puntos ganados en una venta
  int calculatePointsEarned(double saleTotal) {
    return ((saleTotal / 1000) * pointsRate).floor();
  }
  
  // ✅ NUEVO: Método para agregar puntos de una venta
  void addPointsFromSale(double saleTotal) {
    final pointsEarned = calculatePointsEarned(saleTotal);
    accumulatedPoints += pointsEarned;
    totalPurchases += saleTotal;
    lastPurchase = DateTime.now();
    updatedAt = DateTime.now();
  }
}

enum DocumentType {
  cedula,
  pasaporte,
  nit,
  tarjetaIdentidad,
  otro,
} 