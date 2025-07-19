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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 