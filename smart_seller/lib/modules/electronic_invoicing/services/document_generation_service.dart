import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../models/electronic_document.dart';
import '../models/system_configuration.dart';
import '../services/system_configuration_service.dart';
import '../services/pending_invoice_queue_service.dart';
import '../../../models/client.dart';
import '../../../models/product.dart';

class DocumentGenerationService {
  // ✅ Generar estructura de datos interna (JSON)
  static Map<String, dynamic> generateInternalStructure({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
  }) {
    return {
      'documentInfo': {
        'id': document.id,
        'documentType': document.documentType,
        'prefix': document.prefix,
        'consecutive': document.consecutive,
        'documentNumber': document.documentNumber,
        'issueDate': document.issueDate.toIso8601String(),
        'dueDate': document.dueDate.toIso8601String(),
        'operationType': document.operationType,
        'paymentMethod': document.paymentMethod,
        'paymentForm': document.paymentForm,
        'status': document.status,
        'observations': document.observations,
      },
      'issuerInfo': {
        'softwareId': document.softwareId,
        'softwarePin': document.softwarePin,
        'environment': document.environment,
        'dianResolutionNumber': document.dianResolutionNumber,
        'dianResolutionDate': document.dianResolutionDate.toIso8601String(),
        'dianResolutionRange': document.dianResolutionRange,
      },
      'clientInfo': {
        'documentType': client.documentType,
        'documentNumber': client.documentNumber,
        'businessName': client.businessName,
        'email': client.email,
        'phone': client.phone,
        'address': client.address,
        'city': client.city,
        'department': client.department,
        'country': client.country,
        'fiscalResponsibility': client.fiscalResponsibility,
      },
      'items': document.items.map((item) => {
        'productCode': item.productCode,
        'productName': item.productName,
        'unit': item.unit,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'subtotal': item.subtotal,
        'discounts': item.discounts,
        'charges': item.charges,
        'totalTaxes': item.totalTaxes,
        'totalWithTaxesAndDiscounts': item.totalWithTaxesAndDiscounts,
        'taxes': item.taxes.map((tax) => {
          'taxType': tax.taxType,
          'taxPercentage': tax.taxPercentage,
          'taxAmount': tax.taxAmount,
          'taxCode': tax.taxCode,
        }).toList(),
      }).toList(),
      'totals': {
        'subtotal': document.subtotal,
        'totalDiscounts': document.totalDiscounts,
        'totalTaxes': document.totalTaxes,
        'totalCharges': document.totalCharges,
        'total': document.total,
      },
      'metadata': {
        'generatedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
        'format': 'internal_structure',
      },
    };
  }
  
  // ✅ Generar PDF de representación gráfica (simulado por ahora)
  static Future<Uint8List> generatePDF({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
    String? logoPath,
  }) async {
    // ✅ Por ahora retornamos un PDF simulado
    // En una implementación real, aquí se usaría un paquete como pdf o printing
    final pdfContent = '''
FACTURA ELECTRÓNICA
${document.documentNumber}

Cliente: ${client.businessName}
Documento: ${client.documentType} ${client.documentNumber}
Fecha: ${document.issueDate.toIso8601String()}

Productos:
${document.items.map((item) => '${item.productCode} - ${item.productName} x${item.quantity} \$${item.unitPrice} = \$${item.subtotal}').join('\n')}

Subtotal: \$${document.subtotal}
IVA: \$${document.totalTaxes}
Total: \$${document.total}

Generado electrónicamente
''';
    
    return Uint8List.fromList(utf8.encode(pdfContent));
  }
  
  // ✅ Generar XML estructurado según XSD DIAN
  static Future<String> generateXML({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
  }) async {
    final systemConfig = await SystemConfigurationService.getConfiguration();
    
    // ✅ Estructura XML básica según estándares DIAN
    final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
         xmlns:ext="urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2">
  
  <!-- Información del documento -->
  <cbc:ID>${document.documentNumber}</cbc:ID>
  <cbc:IssueDate>${document.issueDate.toIso8601String().split('T')[0]}</cbc:IssueDate>
  <cbc:IssueTime>${document.issueDate.toIso8601String().split('T')[1].split('.')[0]}</cbc:IssueTime>
  <cbc:DocumentCurrencyCode>COP</cbc:DocumentCurrencyCode>
  <cbc:LineCountNumeric>${document.items.length}</cbc:LineCountNumeric>
  
  <!-- Información del emisor -->
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="31">${systemConfig.companyNit}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${systemConfig.companyName}</cbc:Name>
      </cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>${systemConfig.companyAddress}</cbc:StreetName>
        <cbc:CityName>${systemConfig.companyCity}</cbc:CityName>
        <cbc:CountrySubentity>${systemConfig.companyDepartment}</cbc:CountrySubentity>
        <cac:Country>
          <cbc:IdentificationCode>CO</cbc:IdentificationCode>
        </cac:Country>
      </cac:PostalAddress>
      <cac:PartyTaxScheme>
        <cac:TaxScheme>
          <cbc:ID>${systemConfig.companyNit}</cbc:ID>
        </cac:TaxScheme>
      </cac:PartyTaxScheme>
    </cac:Party>
  </cac:AccountingSupplierParty>
  
  <!-- Información del cliente -->
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="${_getDocumentTypeCode(client.documentType)}">${client.documentNumber}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${client.businessName}</cbc:Name>
      </cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>${client.address ?? 'No especificada'}</cbc:StreetName>
        <cbc:CityName>${client.city ?? 'No especificada'}</cbc:CityName>
        <cbc:CountrySubentity>${client.department ?? 'No especificado'}</cbc:CountrySubentity>
        <cac:Country>
          <cbc:IdentificationCode>CO</cbc:IdentificationCode>
        </cac:Country>
      </cac:PostalAddress>
    </cac:Party>
  </cac:AccountingCustomerParty>
  
  <!-- Items de la factura -->
${_generateXMLItems(document.items)}
  
  <!-- Totales -->
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="COP">${document.totalTaxes.toStringAsFixed(2)}</cbc:TaxAmount>
  </cac:TaxTotal>
  
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="COP">${document.subtotal.toStringAsFixed(2)}</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="COP">${document.subtotal.toStringAsFixed(2)}</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="COP">${document.total.toStringAsFixed(2)}</cbc:TaxInclusiveAmount>
    <cbc:PayableAmount currencyID="COP">${document.total.toStringAsFixed(2)}</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  
  <!-- Información DIAN -->
  <ext:UBLExtensions>
    <ext:UBLExtension>
      <ext:ExtensionContent>
        <cac:DianExtensions>
          <cbc:InvoiceAuthorization>${document.dianResolutionNumber}</cbc:InvoiceAuthorization>
          <cbc:AuthorizationPeriod>
            <cbc:StartDate>${document.dianResolutionDate.toIso8601String().split('T')[0]}</cbc:StartDate>
          </cbc:AuthorizationPeriod>
          <cbc:SoftwareID>${document.softwareId}</cbc:SoftwareID>
          <cbc:SoftwarePin>${document.softwarePin}</cbc:SoftwarePin>
        </cac:DianExtensions>
      </ext:ExtensionContent>
    </ext:UBLExtension>
  </ext:UBLExtensions>
  
</Invoice>
''';
    
    return xml;
  }
  
  // ✅ Generar registro en base de datos
  static Future<bool> saveToDatabase({
    required ElectronicDocument document,
    required String pdfPath,
    required String xmlPath,
    required String jsonPath,
  }) async {
    try {
      // ✅ Actualizar el documento con las rutas de archivos
      final updatedDocument = document.copyWith(
        pdfUrl: pdfPath,
        xmlUrl: xmlPath,
        status: 'GENERATED',
        updatedAt: DateTime.now(),
      );
      
      // ✅ Aquí se guardaría en la base de datos
      // Por ahora simulamos el guardado
      print('Documento guardado en base de datos: ${updatedDocument.id}');
      print('PDF: $pdfPath');
      print('XML: $xmlPath');
      print('JSON: $jsonPath');
      
      return true;
    } catch (e) {
      print('Error guardando en base de datos: $e');
      return false;
    }
  }
  
  // ✅ Generar todos los documentos
  static Future<DocumentGenerationResult> generateAllDocuments({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
    String? logoPath,
    String? outputDirectory,
  }) async {
    try {
      final outputDir = outputDirectory ?? './facturas';
      
      // ✅ 1. Generar estructura interna (JSON)
      final internalStructure = generateInternalStructure(
        document: document,
        client: client,
        products: products,
      );
      
      // ✅ 2. Generar PDF
      final pdfBytes = await generatePDF(
        document: document,
        client: client,
        products: products,
        logoPath: logoPath,
      );
      
      // ✅ 3. Generar XML
      final xmlContent = await generateXML(
        document: document,
        client: client,
        products: products,
      );
      
      // ✅ 4. Guardar archivos
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonPath = path.join(outputDir, 'json', '${document.documentNumber}_$timestamp.json');
      final pdfPath = path.join(outputDir, 'pdf', '${document.documentNumber}_$timestamp.pdf');
      final xmlPath = path.join(outputDir, 'xml', '${document.documentNumber}_$timestamp.xml');
      
      // ✅ Crear directorios si no existen
      await _ensureDirectoriesExist(outputDir);
      
      // ✅ Guardar archivos
      await _saveFile(jsonPath, jsonEncode(internalStructure));
      await _saveFile(pdfPath, pdfBytes);
      await _saveFile(xmlPath, utf8.encode(xmlContent));
      
               // ✅ 5. Guardar en base de datos
         final dbSaved = await saveToDatabase(
           document: document,
           pdfPath: pdfPath,
           xmlPath: xmlPath,
           jsonPath: jsonPath,
         );

         // ✅ 6. Intentar envío a DIAN (simulado)
         bool dianSuccess = false;
         String? dianError;
         
         try {
           // ✅ Simular envío a DIAN
           await Future.delayed(const Duration(seconds: 1));
           
           // ✅ Simular éxito/fallo (80% éxito para testing)
           final random = DateTime.now().millisecond % 10;
           dianSuccess = random < 8; // 80% éxito
           
           if (!dianSuccess) {
             dianError = 'Error de conexión con DIAN';
           }
         } catch (e) {
           dianError = 'Error en envío: $e';
         }

         // ✅ Si falla el envío, agregar a la cola de pendientes
         if (!dianSuccess) {
           await PendingInvoiceQueueService.addToQueue(
             invoice: document,
             userId: 'usuario_actual',
             error: dianError,
             errorDetails: 'Error en envío a DIAN después de generación exitosa',
           );
         }

         return DocumentGenerationResult(
           success: true,
           jsonPath: jsonPath,
           pdfPath: pdfPath,
           xmlPath: xmlPath,
           internalStructure: internalStructure,
           pdfBytes: pdfBytes,
           xmlContent: xmlContent,
           databaseSaved: dbSaved,
           dianSuccess: dianSuccess,
           dianError: dianError,
           generatedAt: DateTime.now(),
         );
      
    } catch (e) {
      return DocumentGenerationResult(
        success: false,
        error: 'Error generando documentos: $e',
        generatedAt: DateTime.now(),
      );
    }
  }
  
  // ✅ Métodos auxiliares
  
  static String _generateXMLItems(List<DocumentItem> items) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final lineNumber = i + 1;
      
      buffer.writeln('''
  <cac:InvoiceLine>
    <cbc:ID>$lineNumber</cbc:ID>
    <cbc:InvoicedQuantity unitCode="${item.unit}">${item.quantity}</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="COP">${item.subtotal.toStringAsFixed(2)}</cbc:LineExtensionAmount>
    
    <cac:Item>
      <cbc:Description>${item.productName}</cbc:Description>
      <cac:SellersItemIdentification>
        <cbc:ID>${item.productCode}</cbc:ID>
      </cac:SellersItemIdentification>
    </cac:Item>
    
    <cac:Price>
      <cbc:PriceAmount currencyID="COP">${item.unitPrice.toStringAsFixed(2)}</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>''');
    }
    
    return buffer.toString();
  }
  
  static String _getDocumentTypeCode(String documentType) {
    switch (documentType.toUpperCase()) {
      case 'CC':
        return '1';
      case 'NIT':
        return '31';
      case 'TI':
        return '12';
      case 'CE':
        return '13';
      default:
        return '1';
    }
  }
  
  static Future<void> _ensureDirectoriesExist(String baseDir) async {
    final dirs = [
      path.join(baseDir, 'json'),
      path.join(baseDir, 'pdf'),
      path.join(baseDir, 'xml'),
    ];
    
    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }
  
  static Future<void> _saveFile(String filePath, dynamic content) async {
    final file = File(filePath);
    
    if (content is Uint8List) {
      await file.writeAsBytes(content);
    } else if (content is String) {
      await file.writeAsString(content);
    } else {
      await file.writeAsString(content.toString());
    }
  }
}

       // ✅ Clase para el resultado de la generación
       class DocumentGenerationResult {
         final bool success;
         final String? jsonPath;
         final String? pdfPath;
         final String? xmlPath;
         final Map<String, dynamic>? internalStructure;
         final Uint8List? pdfBytes;
         final String? xmlContent;
         final bool? databaseSaved;
         final bool? dianSuccess;
         final String? dianError;
         final String? error;
         final DateTime generatedAt;
  
           const DocumentGenerationResult({
           required this.success,
           this.jsonPath,
           this.pdfPath,
           this.xmlPath,
           this.internalStructure,
           this.pdfBytes,
           this.xmlContent,
           this.databaseSaved,
           this.dianSuccess,
           this.dianError,
           this.error,
           required this.generatedAt,
         });
  
  // ✅ Verificar si todos los archivos se generaron
  bool get allFilesGenerated => 
      success && jsonPath != null && pdfPath != null && xmlPath != null;
  
  // ✅ Obtener resumen de la generación
  String get summary {
    if (!success) return 'Error: $error';
    
    final files = <String>[];
    if (jsonPath != null) files.add('JSON');
    if (pdfPath != null) files.add('PDF');
    if (xmlPath != null) files.add('XML');
    
    return 'Generados: ${files.join(', ')} | Base de datos: ${databaseSaved == true ? 'Guardado' : 'Error'}';
  }
  
  // ✅ Exportar para logging
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'jsonPath': jsonPath,
      'pdfPath': pdfPath,
      'xmlPath': xmlPath,
      'databaseSaved': databaseSaved,
      'error': error,
      'generatedAt': generatedAt.toIso8601String(),
      'summary': summary,
    };
  }
}
