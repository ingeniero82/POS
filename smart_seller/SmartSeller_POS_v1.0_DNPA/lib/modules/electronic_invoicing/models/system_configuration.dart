class SystemConfiguration {
  // ✅ Resolución DIAN
  final String dianResolutionNumber;
  final DateTime dianResolutionDate;
  final String dianResolutionPrefix;
  final String dianResolutionRange;
  
  // ✅ Consecutivo actual
  final int currentConsecutive;
  
  // ✅ Prefijo de factura
  final String invoicePrefix;
  
  // ✅ Software de facturación
  final String softwareId;
  final String softwarePin;
  
  // ✅ Ambiente
  final String environment; // 'PRUEBAS' o 'PRODUCCION'
  
  // ✅ Datos del emisor (empresa)
  final String companyName;
  final String companyNit;
  final String companyAddress;
  final String companyCity;
  final String companyDepartment;
  final String companyPhone;
  final String companyEmail;
  
  // ✅ Rutas de archivos
  final String xmlOutputPath;
  final String pdfOutputPath;
  
  // ✅ Fecha de creación/actualización
  final DateTime lastUpdated;

  const SystemConfiguration({
    required this.dianResolutionNumber,
    required this.dianResolutionDate,
    required this.dianResolutionPrefix,
    required this.dianResolutionRange,
    required this.currentConsecutive,
    required this.invoicePrefix,
    required this.softwareId,
    required this.softwarePin,
    required this.environment,
    required this.companyName,
    required this.companyNit,
    required this.companyAddress,
    required this.companyCity,
    required this.companyDepartment,
    required this.companyPhone,
    required this.companyEmail,
    required this.xmlOutputPath,
    required this.pdfOutputPath,
    required this.lastUpdated,
  });

  // ✅ Factory constructor desde Map
  factory SystemConfiguration.fromMap(Map<String, dynamic> map) {
    return SystemConfiguration(
      dianResolutionNumber: map['dian_resolution_number'] ?? '',
      dianResolutionDate: DateTime.tryParse(map['dian_resolution_date'] ?? '') ?? DateTime.now(),
      dianResolutionPrefix: map['dian_resolution_prefix'] ?? '',
      dianResolutionRange: map['dian_resolution_range'] ?? '',
      currentConsecutive: map['current_consecutive'] ?? 1,
      invoicePrefix: map['invoice_prefix'] ?? '',
      softwareId: map['software_id'] ?? '',
      softwarePin: map['software_pin'] ?? '',
      environment: map['environment'] ?? 'PRUEBAS',
      companyName: map['company_name'] ?? '',
      companyNit: map['company_nit'] ?? '',
      companyAddress: map['company_address'] ?? '',
      companyCity: map['company_city'] ?? '',
      companyDepartment: map['company_department'] ?? '',
      companyPhone: map['company_phone'] ?? '',
      companyEmail: map['company_email'] ?? '',
      xmlOutputPath: map['xml_output_path'] ?? '',
      pdfOutputPath: map['pdf_output_path'] ?? '',
      lastUpdated: DateTime.tryParse(map['last_updated'] ?? '') ?? DateTime.now(),
    );
  }

  // ✅ Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'dian_resolution_number': dianResolutionNumber,
      'dian_resolution_date': dianResolutionDate.toIso8601String(),
      'dian_resolution_prefix': dianResolutionPrefix,
      'dian_resolution_range': dianResolutionRange,
      'current_consecutive': currentConsecutive,
      'invoice_prefix': invoicePrefix,
      'software_id': softwareId,
      'software_pin': softwarePin,
      'environment': environment,
      'company_name': companyName,
      'company_nit': companyNit,
      'company_address': companyAddress,
      'company_city': companyCity,
      'company_department': companyDepartment,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'xml_output_path': xmlOutputPath,
      'pdf_output_path': pdfOutputPath,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  // ✅ Copiar con cambios
  SystemConfiguration copyWith({
    String? dianResolutionNumber,
    DateTime? dianResolutionDate,
    String? dianResolutionPrefix,
    String? dianResolutionRange,
    int? currentConsecutive,
    String? invoicePrefix,
    String? softwareId,
    String? softwarePin,
    String? environment,
    String? companyName,
    String? companyNit,
    String? companyAddress,
    String? companyCity,
    String? companyDepartment,
    String? companyPhone,
    String? companyEmail,
    String? xmlOutputPath,
    String? pdfOutputPath,
    DateTime? lastUpdated,
  }) {
    return SystemConfiguration(
      dianResolutionNumber: dianResolutionNumber ?? this.dianResolutionNumber,
      dianResolutionDate: dianResolutionDate ?? this.dianResolutionDate,
      dianResolutionPrefix: dianResolutionPrefix ?? this.dianResolutionPrefix,
      dianResolutionRange: dianResolutionRange ?? this.dianResolutionRange,
      currentConsecutive: currentConsecutive ?? this.currentConsecutive,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      softwareId: softwareId ?? this.softwareId,
      softwarePin: softwarePin ?? this.softwarePin,
      environment: environment ?? this.environment,
      companyName: companyName ?? this.companyName,
      companyNit: companyNit ?? this.companyNit,
      companyAddress: companyAddress ?? this.companyAddress,
      companyCity: companyCity ?? this.companyCity,
      companyDepartment: companyDepartment ?? this.companyDepartment,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      xmlOutputPath: xmlOutputPath ?? this.xmlOutputPath,
      pdfOutputPath: pdfOutputPath ?? this.pdfOutputPath,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // ✅ Validar configuración completa
  bool get isValid {
    return dianResolutionNumber.isNotEmpty &&
           dianResolutionPrefix.isNotEmpty &&
           dianResolutionRange.isNotEmpty &&
           invoicePrefix.isNotEmpty &&
           softwareId.isNotEmpty &&
           softwarePin.isNotEmpty &&
           softwarePin.length == 5 &&
           companyName.isNotEmpty &&
           companyNit.isNotEmpty &&
           companyAddress.isNotEmpty &&
           companyCity.isNotEmpty &&
           companyDepartment.isNotEmpty &&
           companyEmail.isNotEmpty &&
           xmlOutputPath.isNotEmpty &&
           pdfOutputPath.isNotEmpty;
  }

  // ✅ Obtener errores de validación
  List<String> get validationErrors {
    List<String> errors = [];
    
    if (dianResolutionNumber.isEmpty) {
      errors.add('Número de resolución DIAN es obligatorio');
    }
    
    if (dianResolutionPrefix.isEmpty) {
      errors.add('Prefijo de resolución DIAN es obligatorio');
    }
    
    if (dianResolutionRange.isEmpty) {
      errors.add('Rango de resolución DIAN es obligatorio');
    }
    
    if (invoicePrefix.isEmpty) {
      errors.add('Prefijo de factura es obligatorio');
    }
    
    if (softwareId.isEmpty) {
      errors.add('ID del software es obligatorio');
    }
    
    if (softwarePin.isEmpty) {
      errors.add('PIN del software es obligatorio');
    } else if (softwarePin.length != 5) {
      errors.add('PIN del software debe tener 5 dígitos');
    }
    
    if (companyName.isEmpty) {
      errors.add('Nombre de la empresa es obligatorio');
    }
    
    if (companyNit.isEmpty) {
      errors.add('NIT de la empresa es obligatorio');
    }
    
    if (companyAddress.isEmpty) {
      errors.add('Dirección de la empresa es obligatoria');
    }
    
    if (companyCity.isEmpty) {
      errors.add('Ciudad de la empresa es obligatoria');
    }
    
    if (companyDepartment.isEmpty) {
      errors.add('Departamento de la empresa es obligatorio');
    }
    
    if (companyEmail.isEmpty) {
      errors.add('Email de la empresa es obligatorio');
    }
    
    if (xmlOutputPath.isEmpty) {
      errors.add('Ruta de salida XML es obligatoria');
    }
    
    if (pdfOutputPath.isEmpty) {
      errors.add('Ruta de salida PDF es obligatoria');
    }
    
    return errors;
  }

  // ✅ Generar siguiente consecutivo
  int get nextConsecutive => currentConsecutive + 1;

  // ✅ Verificar si el consecutivo está en rango
  bool isConsecutiveInRange(int consecutive) {
    try {
      final rangeParts = dianResolutionRange.split('-');
      if (rangeParts.length != 2) return false;
      
      final start = int.tryParse(rangeParts[0]);
      final end = int.tryParse(rangeParts[1]);
      
      if (start == null || end == null) return false;
      
      return consecutive >= start && consecutive <= end;
    } catch (e) {
      return false;
    }
  }

  // ✅ Obtener configuración por defecto para pruebas
  factory SystemConfiguration.getDefaultTest() {
    final now = DateTime.now();
    return SystemConfiguration(
      dianResolutionNumber: 'RES-TEST-001-2024',
      dianResolutionDate: now,
      dianResolutionPrefix: 'TEST',
      dianResolutionRange: '1-999999',
      currentConsecutive: 1,
      invoicePrefix: 'FE',
      softwareId: 'TEST_SOFTWARE_001',
      softwarePin: '12345',
      environment: 'PRUEBAS',
      companyName: 'Empresa de Pruebas',
      companyNit: '900123456-7',
      companyAddress: 'Calle Test #123',
      companyCity: 'Bogotá',
      companyDepartment: 'Cundinamarca',
      companyPhone: '3001234567',
      companyEmail: 'test@empresa.com',
      xmlOutputPath: './facturas/xml',
      pdfOutputPath: './facturas/pdf',
      lastUpdated: now,
    );
  }

  // ✅ Verificar si está listo para producción
  bool get isReadyForProduction {
    return environment == 'PRODUCCION' &&
           isValid &&
           softwareId != 'TEST_SOFTWARE_001' &&
           softwarePin != '12345' &&
           companyName != 'Empresa de Pruebas';
  }
}
