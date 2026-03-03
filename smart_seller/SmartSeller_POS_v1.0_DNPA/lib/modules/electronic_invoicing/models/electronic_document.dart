// Modelo para documentos electrónicos según normativa DIAN

class ElectronicDocument {
  int? id;
  
  // ✅ a) ENCABEZADO DEL DOCUMENTO
  late String documentType; // FE, NC, ND, DS, etc.
  late String prefix; // Prefijo configurable: FV, FA, etc.
  late String consecutive; // Consecutivo único dentro del rango de resolución
  late DateTime issueDate; // Fecha y hora de emisión
  late String operationType; // Estándar, exportación, etc.
  late String paymentMethod; // Contado, crédito
  late String paymentForm; // Efectivo, transferencia, tarjeta, etc.
  late DateTime dueDate;
  String? observations;
  late String status; // DRAFT, SENT, APPROVED, REJECTED
  late DateTime createdAt;
  late DateTime updatedAt;
  
  // ✅ b) INFORMACIÓN DEL EMISOR Y ADQUIRIENTE
  // Emisor (ya implementado en CompanyConfig)
  String? clientDocumentType;
  String? clientDocumentNumber;
  String? clientBusinessName;
  String? clientEmail;
  String? clientPhone;
  String? clientAddress;
  String? clientCity;
  String? clientDepartment;
  String? clientFiscalResponsibility;
  
  // ✅ c) DETALLE DE LOS ITEMS
  List<DocumentItem> items = [];
  
  // ✅ d) TOTALES
  double subtotal = 0.0;
  double totalDiscounts = 0.0;
  double totalTaxes = 0.0;
  double totalCharges = 0.0;
  double total = 0.0;
  
  // ✅ e) INFORMACIÓN TÉCNICA (SOFTWARE DE FACTURACIÓN)
  late String softwareId; // ID del software asignado por DIAN
  late String softwarePin; // PIN del software (5 dígitos)
  late String environment; // Pruebas o Producción
  late String dianResolutionNumber; // Número de resolución DIAN
  late DateTime dianResolutionDate; // Fecha de resolución DIAN
  late String dianResolutionRange; // Rango de facturas permitido
  
  // Campos DIAN de respuesta
  String? dianResponse;
  String? dianAuthorizationNumber;
  DateTime? dianAuthorizationDate;
  String? qrCode;
  String? pdfUrl;
  String? xmlUrl;
  
  // Constructor
  ElectronicDocument({
    this.id,
    required this.documentType,
    required this.prefix,
    required this.consecutive,
    required this.issueDate,
    required this.operationType,
    required this.paymentMethod,
    required this.paymentForm,
    required this.dueDate,
    this.observations,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.clientDocumentType,
    this.clientDocumentNumber,
    this.clientBusinessName,
    this.clientEmail,
    this.clientPhone,
    this.clientAddress,
    this.clientCity,
    this.clientDepartment,
    this.clientFiscalResponsibility,
    this.items = const [],
    this.subtotal = 0.0,
    this.totalDiscounts = 0.0,
    this.totalTaxes = 0.0,
    this.totalCharges = 0.0,
    this.total = 0.0,
    required this.softwareId,
    required this.softwarePin,
    required this.environment,
    required this.dianResolutionNumber,
    required this.dianResolutionDate,
    required this.dianResolutionRange,
    this.dianResponse,
    this.dianAuthorizationNumber,
    this.dianAuthorizationDate,
    this.qrCode,
    this.pdfUrl,
    this.xmlUrl,
  });
  
  // Constructor desde Map (para base de datos)
  ElectronicDocument.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    documentType = map['documentType'];
    prefix = map['prefix'] ?? 'FV';
    consecutive = map['consecutive'] ?? '';
    issueDate = DateTime.parse(map['issueDate']);
    operationType = map['operationType'] ?? 'ESTANDAR';
    paymentMethod = map['paymentMethod'];
    paymentForm = map['paymentForm'] ?? 'CONTADO';
    dueDate = DateTime.parse(map['dueDate']);
    observations = map['observations'];
    status = map['status'];
    createdAt = DateTime.parse(map['createdAt']);
    updatedAt = DateTime.parse(map['updatedAt']);
    
    clientDocumentType = map['clientDocumentType'];
    clientDocumentNumber = map['clientDocumentNumber'];
    clientBusinessName = map['clientBusinessName'];
    clientEmail = map['clientEmail'];
    clientPhone = map['clientPhone'];
    clientAddress = map['clientAddress'];
    clientCity = map['clientCity'];
    clientDepartment = map['clientDepartment'];
    clientFiscalResponsibility = map['clientFiscalResponsibility'];
    
    subtotal = map['subtotal'] ?? 0.0;
    totalDiscounts = map['totalDiscounts'] ?? 0.0;
    totalTaxes = map['totalTaxes'] ?? 0.0;
    totalCharges = map['totalCharges'] ?? 0.0;
    total = map['total'] ?? 0.0;
    
    softwareId = map['softwareId'] ?? '';
    softwarePin = map['softwarePin'] ?? '';
    environment = map['environment'] ?? 'PRUEBAS';
    dianResolutionNumber = map['dianResolutionNumber'] ?? '';
    dianResolutionDate = map['dianResolutionDate'] != null 
        ? DateTime.parse(map['dianResolutionDate']) 
        : DateTime.now();
    dianResolutionRange = map['dianResolutionRange'] ?? '';
    
    dianResponse = map['dianResponse'];
    dianAuthorizationNumber = map['dianAuthorizationNumber'];
    dianAuthorizationDate = map['dianAuthorizationDate'] != null 
        ? DateTime.parse(map['dianAuthorizationDate']) 
        : null;
    qrCode = map['qrCode'];
    pdfUrl = map['pdfUrl'];
    xmlUrl = map['xmlUrl'];
    
    // Cargar items si existen
    if (map['items'] != null) {
      items = (map['items'] as List)
          .map((item) => DocumentItem.fromMap(item))
          .toList();
    }
  }
  
  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentType': documentType,
      'prefix': prefix,
      'consecutive': consecutive,
      'issueDate': issueDate.toIso8601String(),
      'operationType': operationType,
      'paymentMethod': paymentMethod,
      'paymentForm': paymentForm,
      'dueDate': dueDate.toIso8601String(),
      'observations': observations,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      
      'clientDocumentType': clientDocumentType,
      'clientDocumentNumber': clientDocumentNumber,
      'clientBusinessName': clientBusinessName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'clientCity': clientCity,
      'clientDepartment': clientDepartment,
      'clientFiscalResponsibility': clientFiscalResponsibility,
      
      'subtotal': subtotal,
      'totalDiscounts': totalDiscounts,
      'totalTaxes': totalTaxes,
      'totalCharges': totalCharges,
      'total': total,
      
      'softwareId': softwareId,
      'softwarePin': softwarePin,
      'environment': environment,
      'dianResolutionNumber': dianResolutionNumber,
      'dianResolutionDate': dianResolutionDate.toIso8601String(),
      'dianResolutionRange': dianResolutionRange,
      
      'dianResponse': dianResponse,
      'dianAuthorizationNumber': dianAuthorizationNumber,
      'dianAuthorizationDate': dianAuthorizationDate?.toIso8601String(),
      'qrCode': qrCode,
      'pdfUrl': pdfUrl,
      'xmlUrl': xmlUrl,
      
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
  
  // Calcular totales
  void calculateTotals() {
    subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    totalDiscounts = items.fold(0.0, (sum, item) => sum + (item.discounts ?? 0.0));
    totalTaxes = items.fold(0.0, (sum, item) => sum + item.totalTaxes);
    totalCharges = items.fold(0.0, (sum, item) => sum + (item.charges ?? 0.0));
    total = subtotal - totalDiscounts + totalTaxes + totalCharges;
  }
  
  // Validar documento
  bool get isValid {
    return documentNumber.isNotEmpty &&
           documentType.isNotEmpty &&
           prefix.isNotEmpty &&
           consecutive.isNotEmpty &&
           paymentMethod.isNotEmpty &&
           paymentForm.isNotEmpty &&
           softwareId.isNotEmpty &&
           softwarePin.isNotEmpty &&
           dianResolutionNumber.isNotEmpty &&
           clientDocumentNumber != null &&
           clientBusinessName != null &&
           items.isNotEmpty;
  }
  
  // Obtener número completo del documento
  String get documentNumber => '$prefix$consecutive';
  
  // Obtener errores de validación
  List<String> get validationErrors {
    List<String> errors = [];
    
    if (prefix.isEmpty) {
      errors.add('El prefijo del documento es obligatorio');
    }
    
    if (consecutive.isEmpty) {
      errors.add('El consecutivo del documento es obligatorio');
    }
    
    if (documentType.isEmpty) {
      errors.add('El tipo de documento es obligatorio');
    }
    
    if (paymentMethod.isEmpty) {
      errors.add('El método de pago es obligatorio');
    }
    
    if (paymentForm.isEmpty) {
      errors.add('La forma de pago es obligatoria');
    }
    
    if (softwareId.isEmpty) {
      errors.add('El ID del software de facturación es obligatorio');
    }
    
    if (softwarePin.isEmpty) {
      errors.add('El PIN del software es obligatorio');
    }
    
    if (dianResolutionNumber.isEmpty) {
      errors.add('El número de resolución DIAN es obligatorio');
    }
    
    if (clientDocumentNumber == null || clientDocumentNumber!.isEmpty) {
      errors.add('Los datos del cliente son obligatorios');
    }
    
    if (items.isEmpty) {
      errors.add('Debe agregar al menos un producto');
    }
    
    return errors;
  }
  
  // Copiar con modificaciones
  ElectronicDocument copyWith({
    int? id,
    String? documentType,
    String? prefix,
    String? consecutive,
    DateTime? issueDate,
    String? operationType,
    String? paymentMethod,
    String? paymentForm,
    DateTime? dueDate,
    String? observations,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientDocumentType,
    String? clientDocumentNumber,
    String? clientBusinessName,
    String? clientEmail,
    String? clientPhone,
    String? clientAddress,
    String? clientCity,
    String? clientDepartment,
    String? clientFiscalResponsibility,
    List<DocumentItem>? items,
    double? subtotal,
    double? totalDiscounts,
    double? totalTaxes,
    double? totalCharges,
    double? total,
    String? softwareId,
    String? softwarePin,
    String? environment,
    String? dianResolutionNumber,
    DateTime? dianResolutionDate,
    String? dianResolutionRange,
    String? dianResponse,
    String? dianAuthorizationNumber,
    DateTime? dianAuthorizationDate,
    String? qrCode,
    String? pdfUrl,
    String? xmlUrl,
  }) {
    return ElectronicDocument(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      prefix: prefix ?? this.prefix,
      consecutive: consecutive ?? this.consecutive,
      issueDate: issueDate ?? this.issueDate,
      operationType: operationType ?? this.operationType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentForm: paymentForm ?? this.paymentForm,
      dueDate: dueDate ?? this.dueDate,
      observations: observations ?? this.observations,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientDocumentType: clientDocumentType ?? this.clientDocumentType,
      clientDocumentNumber: clientDocumentNumber ?? this.clientDocumentNumber,
      clientBusinessName: clientBusinessName ?? this.clientBusinessName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      clientCity: clientCity ?? this.clientCity,
      clientDepartment: clientDepartment ?? this.clientDepartment,
      clientFiscalResponsibility: clientFiscalResponsibility ?? this.clientFiscalResponsibility,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalDiscounts: totalDiscounts ?? this.totalDiscounts,
      totalTaxes: totalTaxes ?? this.totalTaxes,
      totalCharges: totalCharges ?? this.totalCharges,
      total: total ?? this.total,
      softwareId: softwareId ?? this.softwareId,
      softwarePin: softwarePin ?? this.softwarePin,
      environment: environment ?? this.environment,
      dianResolutionNumber: dianResolutionNumber ?? this.dianResolutionNumber,
      dianResolutionDate: dianResolutionDate ?? this.dianResolutionDate,
      dianResolutionRange: dianResolutionRange ?? this.dianResolutionRange,
      dianResponse: dianResponse ?? this.dianResponse,
      dianAuthorizationNumber: dianAuthorizationNumber ?? this.dianAuthorizationNumber,
      dianAuthorizationDate: dianAuthorizationDate ?? this.dianAuthorizationDate,
      qrCode: qrCode ?? this.qrCode,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      xmlUrl: xmlUrl ?? this.xmlUrl,
    );
  }
}

// ✅ c) DETALLE DE LOS ITEMS - Modelo actualizado para items del documento
class DocumentItem {
  int? id;
  late String productCode; // SKU, código interno
  late String productName; // Descripción
  late String unit; // Unidad de medida: EA, UN, KGM, etc.
  late double quantity;
  late double unitPrice;
  late double subtotal;
  
  // ✅ NUEVOS CAMPOS PARA IMPUESTOS Y DESCUENTOS
  double? discounts; // Descuentos si aplica
  double? charges; // Cargos si aplica
  List<ItemTax> taxes = []; // Impuestos aplicables con porcentaje y valor
  String? observations;
  
  // Constructor
  DocumentItem({
    this.id,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.discounts,
    this.charges,
    this.taxes = const [],
    this.observations,
  });
  
  // Constructor desde Map
  DocumentItem.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    productCode = map['productCode'];
    productName = map['productName'];
    unit = map['unit'];
    quantity = map['quantity']?.toDouble() ?? 0.0;
    unitPrice = map['unitPrice']?.toDouble() ?? 0.0;
    subtotal = map['subtotal']?.toDouble() ?? 0.0;
    discounts = map['discounts']?.toDouble();
    charges = map['charges']?.toDouble();
    observations = map['observations'];
    
    // Cargar impuestos si existen
    if (map['taxes'] != null) {
      taxes = (map['taxes'] as List)
          .map((tax) => ItemTax.fromMap(tax))
          .toList();
    }
  }
  
  // Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productCode': productCode,
      'productName': productName,
      'unit': unit,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'discounts': discounts,
      'charges': charges,
      'taxes': taxes.map((tax) => tax.toMap()).toList(),
      'observations': observations,
    };
  }
  
  // Calcular subtotal
  void calculateSubtotal() {
    subtotal = quantity * unitPrice;
  }
  
  // Calcular total de impuestos del item
  double get totalTaxes {
    return taxes.fold(0.0, (sum, tax) => sum + tax.taxAmount);
  }
  
  // Calcular total del item con impuestos y descuentos
  double get totalWithTaxesAndDiscounts {
    return subtotal - (discounts ?? 0.0) + totalTaxes + (charges ?? 0.0);
  }
}

// ✅ NUEVO: Modelo para impuestos de items
class ItemTax {
  late String taxType; // IVA, ICA, etc.
  late double taxPercentage; // Porcentaje del impuesto
  late double taxAmount; // Valor del impuesto
  late String taxCode; // Código del impuesto según DIAN
  
  ItemTax({
    required this.taxType,
    required this.taxPercentage,
    required this.taxAmount,
    required this.taxCode,
  });
  
  ItemTax.fromMap(Map<String, dynamic> map) {
    taxType = map['taxType'];
    taxPercentage = map['taxPercentage']?.toDouble() ?? 0.0;
    taxAmount = map['taxAmount']?.toDouble() ?? 0.0;
    taxCode = map['taxCode'];
  }
  
  Map<String, dynamic> toMap() {
    return {
      'taxType': taxType,
      'taxPercentage': taxPercentage,
      'taxAmount': taxAmount,
      'taxCode': taxCode,
    };
  }
}

// ✅ NUEVO: Modelo para configuración del software de facturación
class SoftwareConfiguration {
  late String softwareId; // ID asignado por DIAN
  late String softwarePin; // PIN de 5 dígitos
  late String environment; // PRUEBAS o PRODUCCION
  late String dianResolutionNumber; // Número de resolución
  late DateTime dianResolutionDate; // Fecha de resolución
  late String dianResolutionRange; // Rango de facturas permitido
  late String softwareName; // Nombre del software
  late String softwareVersion; // Versión del software
  
  SoftwareConfiguration({
    required this.softwareId,
    required this.softwarePin,
    required this.environment,
    required this.dianResolutionNumber,
    required this.dianResolutionDate,
    required this.dianResolutionRange,
    required this.softwareName,
    required this.softwareVersion,
  });
  
  SoftwareConfiguration.fromMap(Map<String, dynamic> map) {
    softwareId = map['softwareId'];
    softwarePin = map['softwarePin'];
    environment = map['environment'];
    dianResolutionNumber = map['dianResolutionNumber'];
    dianResolutionDate = DateTime.parse(map['dianResolutionDate']);
    dianResolutionRange = map['dianResolutionRange'];
    softwareName = map['softwareName'];
    softwareVersion = map['softwareVersion'];
  }
  
  Map<String, dynamic> toMap() {
    return {
      'softwareId': softwareId,
      'softwarePin': softwarePin,
      'environment': environment,
      'dianResolutionNumber': dianResolutionNumber,
      'dianResolutionDate': dianResolutionDate.toIso8601String(),
      'dianResolutionRange': dianResolutionRange,
      'softwareName': softwareName,
      'softwareVersion': softwareVersion,
    };
  }
}

// Tipos de documento según DIAN
enum DocumentType {
  facturaElectronica('FE', 'Factura Electrónica'),
  notaCredito('NC', 'Nota Crédito'),
  notaDebito('ND', 'Nota Débito'),
  documentoSoporte('DS', 'Documento Soporte'),
  facturaContingencia('FC', 'Factura Contingencia'),
  facturaExportacion('FX', 'Factura Exportación');
  
  const DocumentType(this.code, this.name);
  final String code;
  final String name;
}

// Estados del documento
enum DocumentStatus {
  draft('DRAFT', 'Borrador'),
  sent('SENT', 'Enviado'),
  approved('APPROVED', 'Aprobado'),
  rejected('REJECTED', 'Rechazado'),
  pending('PENDING', 'Pendiente');
  
  const DocumentStatus(this.code, this.name);
  final String code;
  final String name;
}

// ✅ NUEVO: Tipos de operación
enum OperationType {
  estandar('ESTANDAR', 'Estándar'),
  exportacion('EXPORTACION', 'Exportación'),
  contingencia('CONTINGENCIA', 'Contingencia');
  
  const OperationType(this.code, this.name);
  final String code;
  final String name;
}

// ✅ NUEVO: Métodos de pago
enum PaymentMethod {
  contado('CONTADO', 'Contado'),
  credito('CREDITO', 'Crédito');
  
  const PaymentMethod(this.code, this.name);
  final String code;
  final String name;
}

// ✅ NUEVO: Formas de pago
enum PaymentForm {
  efectivo('EFECTIVO', 'Efectivo'),
  transferencia('TRANSFERENCIA', 'Transferencia'),
  tarjeta('TARJETA', 'Tarjeta'),
  cheque('CHEQUE', 'Cheque'),
  otro('OTRO', 'Otro');
  
  const PaymentForm(this.code, this.name);
  final String code;
  final String name;
}

// ✅ NUEVO: Tipos de impuesto
enum TaxType {
  iva('IVA', 'Impuesto al Valor Agregado'),
  ica('ICA', 'Impuesto de Industria y Comercio'),
  inc('INC', 'Impuesto Nacional al Consumo');
  
  const TaxType(this.code, this.name);
  final String code;
  final String name;
}

// ✅ NUEVO: Unidades de medida
enum UnitOfMeasure {
  ea('EA', 'Unidad'),
  un('UN', 'Unidad'),
  kgm('KGM', 'Kilogramo'),
  ltr('LTR', 'Litro'),
  mtr('MTR', 'Metro'),
  pza('PZA', 'Pieza');
  
  const UnitOfMeasure(this.code, this.name);
  final String code;
  final String name;
} 