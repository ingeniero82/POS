// Modelo para documentos electrónicos según normativa DIAN

class ElectronicDocument {
  int? id;
  late String documentType; // FE, NC, ND, DS, etc.
  late String documentNumber;
  late DateTime issueDate;
  late DateTime dueDate;
  late String paymentMethod;
  String? observations;
  late String status; // DRAFT, SENT, APPROVED, REJECTED
  late DateTime createdAt;
  late DateTime updatedAt;
  
  // Campos del cliente
  String? clientDocumentType;
  String? clientDocumentNumber;
  String? clientBusinessName;
  String? clientEmail;
  String? clientPhone;
  String? clientAddress;
  String? clientFiscalResponsibility;
  
  // Campos de productos
  List<DocumentItem> items = [];
  
  // Campos de totales
  double subtotal = 0.0;
  double taxes = 0.0;
  double total = 0.0;
  
  // Campos DIAN
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
    required this.documentNumber,
    required this.issueDate,
    required this.dueDate,
    required this.paymentMethod,
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
    this.clientFiscalResponsibility,
    this.items = const [],
    this.subtotal = 0.0,
    this.taxes = 0.0,
    this.total = 0.0,
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
    documentNumber = map['documentNumber'];
    issueDate = DateTime.parse(map['issueDate']);
    dueDate = DateTime.parse(map['dueDate']);
    paymentMethod = map['paymentMethod'];
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
    clientFiscalResponsibility = map['clientFiscalResponsibility'];
    
    subtotal = map['subtotal'] ?? 0.0;
    taxes = map['taxes'] ?? 0.0;
    total = map['total'] ?? 0.0;
    
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
      'documentNumber': documentNumber,
      'issueDate': issueDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'paymentMethod': paymentMethod,
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
      'clientFiscalResponsibility': clientFiscalResponsibility,
      
      'subtotal': subtotal,
      'taxes': taxes,
      'total': total,
      
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
    taxes = subtotal * 0.19; // IVA 19%
    total = subtotal + taxes;
  }
  
  // Validar documento
  bool get isValid {
    return documentNumber.isNotEmpty &&
           documentType.isNotEmpty &&
           paymentMethod.isNotEmpty &&
           clientDocumentNumber != null &&
           clientBusinessName != null &&
           items.isNotEmpty;
  }
  
  // Obtener errores de validación
  List<String> get validationErrors {
    List<String> errors = [];
    
    if (documentNumber.isEmpty) {
      errors.add('El número de documento es obligatorio');
    }
    
    if (documentType.isEmpty) {
      errors.add('El tipo de documento es obligatorio');
    }
    
    if (paymentMethod.isEmpty) {
      errors.add('El método de pago es obligatorio');
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
    String? documentNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    String? paymentMethod,
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
    String? clientFiscalResponsibility,
    List<DocumentItem>? items,
    double? subtotal,
    double? taxes,
    double? total,
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
      documentNumber: documentNumber ?? this.documentNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
      clientFiscalResponsibility: clientFiscalResponsibility ?? this.clientFiscalResponsibility,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxes: taxes ?? this.taxes,
      total: total ?? this.total,
      dianResponse: dianResponse ?? this.dianResponse,
      dianAuthorizationNumber: dianAuthorizationNumber ?? this.dianAuthorizationNumber,
      dianAuthorizationDate: dianAuthorizationDate ?? this.dianAuthorizationDate,
      qrCode: qrCode ?? this.qrCode,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      xmlUrl: xmlUrl ?? this.xmlUrl,
    );
  }
}

// Modelo para items del documento
class DocumentItem {
  int? id;
  late String productCode;
  late String productName;
  late String unit;
  late double quantity;
  late double unitPrice;
  late double subtotal;
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
    observations = map['observations'];
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
      'observations': observations,
    };
  }
  
  // Calcular subtotal
  void calculateSubtotal() {
    subtotal = quantity * unitPrice;
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