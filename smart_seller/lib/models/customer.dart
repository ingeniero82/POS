class Customer {
  int? id;
  late String name;
  late String email;
  late String phone;
  String? address;
  String? documentNumber;
  String? documentType;
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  
  // Campos para fidelización
  int points = 0;
  String? membershipLevel; // bronze, silver, gold, platinum
  DateTime? lastPurchase;
  double totalPurchases = 0.0;
  
  // Constructor
  Customer({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.documentNumber,
    this.documentType,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.points = 0,
    this.membershipLevel,
    this.lastPurchase,
    this.totalPurchases = 0.0,
  });
  
  // Constructor desde Map (para base de datos)
  Customer.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    email = map['email'];
    phone = map['phone'];
    address = map['address'];
    documentNumber = map['documentNumber'];
    documentType = map['documentType'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    points = map['points'] ?? 0;
    membershipLevel = map['membershipLevel'];
    lastPurchase = map['lastPurchase'] != null 
        ? DateTime.parse(map['lastPurchase']) 
        : null;
    totalPurchases = map['totalPurchases'] ?? 0.0;
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'documentNumber': documentNumber,
      'documentType': documentType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'points': points,
      'membershipLevel': membershipLevel,
      'lastPurchase': lastPurchase?.toIso8601String(),
      'totalPurchases': totalPurchases,
    };
  }
  
  // Copiar con modificaciones
  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? documentNumber,
    String? documentType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? points,
    String? membershipLevel,
    DateTime? lastPurchase,
    double? totalPurchases,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      documentNumber: documentNumber ?? this.documentNumber,
      documentType: documentType ?? this.documentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      points: points ?? this.points,
      membershipLevel: membershipLevel ?? this.membershipLevel,
      lastPurchase: lastPurchase ?? this.lastPurchase,
      totalPurchases: totalPurchases ?? this.totalPurchases,
    );
  }
  
  // Calcular nivel de membresía basado en puntos
  String calculateMembershipLevel() {
    if (points >= 1000) return 'platinum';
    if (points >= 500) return 'gold';
    if (points >= 200) return 'silver';
    return 'bronze';
  }
  
  // Agregar puntos por compra
  void addPoints(double purchaseAmount) {
    int pointsEarned = (purchaseAmount / 1000).round(); // 1 punto por cada $1000
    points += pointsEarned;
    membershipLevel = calculateMembershipLevel();
    totalPurchases += purchaseAmount;
    lastPurchase = DateTime.now();
  }
}

enum DocumentType {
  cedula,
  pasaporte,
  nit,
  tarjetaIdentidad,
  otro,
} 