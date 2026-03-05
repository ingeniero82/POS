class CompanyConfig {
  final int? id;
  final String companyName;
  final String address;
  final String phone;
  final String? email;
  final String? website;
  final String? taxId; // NIT o RUT
  final String headerText;
  final String footerText;
  
  // ✅ NUEVOS CAMPOS PARA FACTURACIÓN ELECTRÓNICA
  final String? documentType; // Tipo de documento (31 = NIT)
  final String? nitNumber; // Número de NIT sin guión ni puntos
  final String? verificationDigit; // DV (Dígito de Verificación)
  final String? city; // Ciudad
  final String? department; // Departamento
  final String? country; // País
  final String? fiscalRegime; // Régimen fiscal (común, simplificado, etc.)
  final String? fiscalResponsibilities; // Responsabilidades fiscales (O-13, I-23, etc.)
  
  /// Programa de puntos: solo acumulación. El encargado decide qué dar por los puntos.
  final bool pointsEnabled;
  /// Legacy: no se usa para canje ni se muestra en pantalla (compatibilidad BD).
  final double pointsPesosPerPoint;
  /// Por cada [pointsPesosBase] pesos de compra el cliente gana [pointsPerBase] puntos.
  final double pointsPesosBase;
  final double pointsPerBase;

  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyConfig({
    this.id,
    required this.companyName,
    required this.address,
    required this.phone,
    this.email,
    this.website,
    this.taxId,
    required this.headerText,
    required this.footerText,
    // ✅ NUEVOS CAMPOS
    this.documentType,
    this.nitNumber,
    this.verificationDigit,
    this.city,
    this.department,
    this.country,
    this.fiscalRegime,
    this.fiscalResponsibilities,
    this.pointsEnabled = false,
    this.pointsPesosPerPoint = 10.0,
    this.pointsPesosBase = 2000.0,
    this.pointsPerBase = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_name': companyName,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'tax_id': taxId,
      'header_text': headerText,
      'footer_text': footerText,
      // ✅ NUEVOS CAMPOS
      'document_type': documentType,
      'nit_number': nitNumber,
      'verification_digit': verificationDigit,
      'city': city,
      'department': department,
      'country': country,
      'fiscal_regime': fiscalRegime,
      'fiscal_responsibilities': fiscalResponsibilities,
      'points_enabled': pointsEnabled ? 1 : 0,
      'points_pesos_per_point': pointsPesosPerPoint,
      'points_pesos_base': pointsPesosBase,
      'points_per_base': pointsPerBase,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CompanyConfig.fromMap(Map<String, dynamic> map) {
    return CompanyConfig(
      id: map['id'],
      companyName: map['company_name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      website: map['website'],
      taxId: map['tax_id'],
      headerText: map['header_text'] ?? 'FACTURA DE VENTA',
      footerText: map['footer_text'] ?? 'Gracias por su compra',
      // ✅ NUEVOS CAMPOS
      documentType: map['document_type'],
      nitNumber: map['nit_number'],
      verificationDigit: map['verification_digit'],
      city: map['city'],
      department: map['department'],
      country: map['country'],
      fiscalRegime: map['fiscal_regime'],
      fiscalResponsibilities: map['fiscal_responsibilities'],
      pointsEnabled: (map['points_enabled'] ?? 0) == 1,
      pointsPesosPerPoint: (map['points_pesos_per_point'] ?? 10.0).toDouble(),
      pointsPesosBase: (map['points_pesos_base'] ?? 2000.0).toDouble(),
      pointsPerBase: (map['points_per_base'] ?? 1.0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  CompanyConfig copyWith({
    int? id,
    String? companyName,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? headerText,
    String? footerText,
    // ✅ NUEVOS CAMPOS
    String? documentType,
    String? nitNumber,
    String? verificationDigit,
    String? city,
    String? department,
    String? country,
    String? fiscalRegime,
    String? fiscalResponsibilities,
    bool? pointsEnabled,
    double? pointsPesosPerPoint,
    double? pointsPesosBase,
    double? pointsPerBase,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyConfig(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      // ✅ NUEVOS CAMPOS
      documentType: documentType ?? this.documentType,
      nitNumber: nitNumber ?? this.nitNumber,
      verificationDigit: verificationDigit ?? this.verificationDigit,
      city: city ?? this.city,
      department: department ?? this.department,
      country: country ?? this.country,
      fiscalRegime: fiscalRegime ?? this.fiscalRegime,
      fiscalResponsibilities: fiscalResponsibilities ?? this.fiscalResponsibilities,
      pointsEnabled: pointsEnabled ?? this.pointsEnabled,
      pointsPesosPerPoint: pointsPesosPerPoint ?? this.pointsPesosPerPoint,
      pointsPesosBase: pointsPesosBase ?? this.pointsPesosBase,
      pointsPerBase: pointsPerBase ?? this.pointsPerBase,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 