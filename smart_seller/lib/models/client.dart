// Modelo de cliente para facturación electrónica DIAN

class Client {
  int? id;
  late String documentType; // Cédula de Ciudadanía, NIT, etc.
  late String documentNumber; // Número del documento
  late String businessName; // Nombre o razón social
  String? email;
  String? phone;
  String? address;
  late String fiscalResponsibility; // Responsable de IVA, No responsable, etc.
  late DateTime createdAt;
  late DateTime updatedAt;
  bool isActive = true;
  
  // Campos adicionales para facturación
  String? city;
  String? department;
  String? country;
  String? postalCode;
  String? contactPerson;
  String? notes;
  
  // Constructor
  Client({
    this.id,
    required this.documentType,
    required this.documentNumber,
    required this.businessName,
    this.email,
    this.phone,
    this.address,
    required this.fiscalResponsibility,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.city,
    this.department,
    this.country,
    this.postalCode,
    this.contactPerson,
    this.notes,
  });
  
  // Constructor desde Map (para base de datos)
  Client.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    documentType = map['documentType'];
    documentNumber = map['documentNumber'];
    businessName = map['businessName'];
    email = map['email'];
    phone = map['phone'];
    address = map['address'];
    fiscalResponsibility = map['fiscalResponsibility'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    isActive = map['isActive'] == 1;
    city = map['city'];
    department = map['department'];
    country = map['country'];
    postalCode = map['postalCode'];
    contactPerson = map['contactPerson'];
    notes = map['notes'];
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'businessName': businessName,
      'email': email,
      'phone': phone,
      'address': address,
      'fiscalResponsibility': fiscalResponsibility,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'city': city,
      'department': department,
      'country': country,
      'postalCode': postalCode,
      'contactPerson': contactPerson,
      'notes': notes,
    };
  }
  
  // Copiar con modificaciones
  Client copyWith({
    int? id,
    String? documentType,
    String? documentNumber,
    String? businessName,
    String? email,
    String? phone,
    String? address,
    String? fiscalResponsibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? city,
    String? department,
    String? country,
    String? postalCode,
    String? contactPerson,
    String? notes,
  }) {
    return Client(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      fiscalResponsibility: fiscalResponsibility ?? this.fiscalResponsibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      city: city ?? this.city,
      department: department ?? this.department,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
    );
  }
  
  // Validaciones según normativa DIAN
  bool get isValidDocument {
    if (documentType == 'Cédula de Ciudadanía') {
      return documentNumber.length == 10 && RegExp(r'^\d+$').hasMatch(documentNumber);
    } else if (documentType == 'NIT') {
      return documentNumber.length >= 9 && RegExp(r'^\d+(-\d+)?$').hasMatch(documentNumber);
    }
    return true;
  }
  
  bool get isValidEmail {
    if (email == null || email!.isEmpty) return true; // Email es opcional
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email!);
  }
  
  bool get isValidPhone {
    if (phone == null || phone!.isEmpty) return true; // Teléfono es opcional
    return RegExp(r'^\d{7,10}$').hasMatch(phone!.replaceAll(RegExp(r'[^\d]'), ''));
  }
  
  // Validación completa del cliente
  bool get isValid {
    return businessName.isNotEmpty &&
           documentNumber.isNotEmpty &&
           isValidDocument &&
           isValidEmail &&
           isValidPhone;
  }
  
  // Obtener errores de validación
  List<String> get validationErrors {
    List<String> errors = [];
    
    if (businessName.isEmpty) {
      errors.add('El nombre/razón social es obligatorio');
    }
    
    if (documentNumber.isEmpty) {
      errors.add('El número de documento es obligatorio');
    } else if (!isValidDocument) {
      errors.add('El número de documento no es válido');
    }
    
    if (email != null && email!.isNotEmpty && !isValidEmail) {
      errors.add('El formato del email no es válido');
    }
    
    if (phone != null && phone!.isNotEmpty && !isValidPhone) {
      errors.add('El formato del teléfono no es válido');
    }
    
    return errors;
  }
}

// Tipos de documento según DIAN
enum DocumentType {
  cedulaCiudadania('Cédula de Ciudadanía'),
  nit('NIT'),
  cedulaExtranjeria('Cédula de Extranjería'),
  pasaporte('Pasaporte'),
  tarjetaIdentidad('Tarjeta de Identidad'),
  registroCivil('Registro Civil'),
  otro('Otro');
  
  const DocumentType(this.name);
  final String name;
}

// Responsabilidades fiscales según DIAN
enum FiscalResponsibility {
  responsableIva('Responsable de IVA'),
  noResponsableIva('No responsable de IVA'),
  granContribuyente('Gran Contribuyente'),
  autorretenedor('Autorretenedor'),
  agenteRetenedorIva('Agente Retenedor de IVA'),
  regimenSimple('Régimen Simple'),
  otro('Otro');
  
  const FiscalResponsibility(this.name);
  final String name;
} 