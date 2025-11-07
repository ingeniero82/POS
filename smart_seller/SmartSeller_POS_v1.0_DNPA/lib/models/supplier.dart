class Supplier {
  final int? id;
  final String name;
  final String? document;
  final String? documentType; // ✅ NUEVO: Tipo de documento (CC, NIT, etc.)
  final String? phone;
  final String? email;
  final String? address;
  final String? city; // ✅ NUEVO: Ciudad
  final String? department; // ✅ NUEVO: Departamento
  final String? postalCode; // ✅ NUEVO: Código postal
  final String? country; // ✅ NUEVO: País (por defecto Colombia)
  final String? taxRegime; // ✅ NUEVO: Régimen tributario
  final String? economicActivity; // ✅ NUEVO: Actividad económica
  final String? contactPerson; // ✅ NUEVO: Persona de contacto
  final String? contactPhone; // ✅ NUEVO: Teléfono de contacto
  final String? contactEmail; // ✅ NUEVO: Email de contacto
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Supplier({
    this.id,
    required this.name,
    this.document,
    this.documentType,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.department,
    this.postalCode,
    this.country,
    this.taxRegime,
    this.economicActivity,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Convertir de Map a Supplier
  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      document: map['document'],
      documentType: map['document_type'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      city: map['city'],
      department: map['department'],
      postalCode: map['postal_code'],
      country: map['country'],
      taxRegime: map['tax_regime'],
      economicActivity: map['economic_activity'],
      contactPerson: map['contact_person'],
      contactPhone: map['contact_phone'],
      contactEmail: map['contact_email'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isActive: map['is_active'] == 1,
    );
  }

  // Convertir de Supplier a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'document': document,
      'document_type': documentType,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'department': department,
      'postal_code': postalCode,
      'country': country,
      'tax_regime': taxRegime,
      'economic_activity': economicActivity,
      'contact_person': contactPerson,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Crear copia con cambios
  Supplier copyWith({
    int? id,
    String? name,
    String? document,
    String? documentType,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? department,
    String? postalCode,
    String? country,
    String? taxRegime,
    String? economicActivity,
    String? contactPerson,
    String? contactPhone,
    String? contactEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      document: document ?? this.document,
      documentType: documentType ?? this.documentType,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      department: department ?? this.department,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      taxRegime: taxRegime ?? this.taxRegime,
      economicActivity: economicActivity ?? this.economicActivity,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Supplier(id: $id, name: $name, document: $document, phone: $phone, email: $email, address: $address, createdAt: $createdAt, updatedAt: $updatedAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Supplier && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
