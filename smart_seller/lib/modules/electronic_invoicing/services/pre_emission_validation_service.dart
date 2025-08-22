import '../models/electronic_document.dart';
import '../models/system_configuration.dart';
import '../services/system_configuration_service.dart';
import '../../../models/client.dart';
import '../../../models/product.dart';

class PreEmissionValidationService {
  // ✅ Validar cliente para facturación electrónica
  static List<String> validateClient(Client client) {
    List<String> errors = [];
    
    if (client.documentType.isEmpty) {
      errors.add('El cliente debe tener tipo de documento');
    }
    
    if (client.documentNumber.isEmpty) {
      errors.add('El cliente debe tener número de documento');
    }
    
    if (client.email?.isEmpty ?? true) {
      errors.add('El cliente debe tener correo electrónico');
    } else if (!_isValidEmail(client.email!)) {
      errors.add('El correo electrónico del cliente no tiene formato válido');
    }
    
    return errors;
  }
  
  // ✅ Validar productos para facturación electrónica
  static List<String> validateProducts(List<Product> products) {
    List<String> errors = [];
    
    if (products.isEmpty) {
      errors.add('Debe haber al menos un producto en la factura');
      return errors;
    }
    
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final productIndex = i + 1;
      
      if (product.code.isEmpty) {
        errors.add('Producto $productIndex: Debe tener código');
      }
      
      if (product.name.isEmpty) {
        errors.add('Producto $productIndex: Debe tener descripción');
      }
    }
    
    return errors;
  }
  
  // ✅ Validar configuración del sistema
  static Future<List<String>> validateSystemConfiguration() async {
    List<String> errors = [];
    
    try {
      final config = await SystemConfigurationService.getConfiguration();
      
      // Validar consecutivos disponibles
      if (!config.isConsecutiveInRange(config.nextConsecutive)) {
        errors.add('No hay consecutivos disponibles en el rango definido (${config.dianResolutionRange})');
      }
      
      // Validar prefijo configurado
      if (config.invoicePrefix.isEmpty) {
        errors.add('El prefijo de factura no está configurado');
      }
      
      // Validar ambiente definido
      if (config.environment.isEmpty) {
        errors.add('El ambiente no está definido');
      }
      
      // Validar software con ID y PIN
      if (config.softwareId.isEmpty) {
        errors.add('El ID del software no está asignado');
      }
      
      if (config.softwarePin.isEmpty) {
        errors.add('El PIN del software no está asignado');
      } else if (config.softwarePin.length != 5) {
        errors.add('El PIN del software debe tener 5 dígitos');
      }
      
      // Validar resolución DIAN
      if (config.dianResolutionNumber.isEmpty) {
        errors.add('El número de resolución DIAN no está configurado');
      }
      
      if (config.dianResolutionPrefix.isEmpty) {
        errors.add('El prefijo de resolución DIAN no está configurado');
      }
      
      if (config.dianResolutionRange.isEmpty) {
        errors.add('El rango de resolución DIAN no está configurado');
      }
      
      // Validar datos de la empresa
      if (config.companyName.isEmpty) {
        errors.add('El nombre de la empresa no está configurado');
      }
      
      if (config.companyNit.isEmpty) {
        errors.add('El NIT de la empresa no está configurado');
      }
      
      if (config.companyAddress.isEmpty) {
        errors.add('La dirección de la empresa no está configurada');
      }
      
      if (config.companyCity.isEmpty) {
        errors.add('La ciudad de la empresa no está configurada');
      }
      
      if (config.companyDepartment.isEmpty) {
        errors.add('El departamento de la empresa no está configurado');
      }
      
      if (config.companyEmail.isEmpty) {
        errors.add('El correo de la empresa no está configurado');
      }
      
      // Validar rutas de archivos
      if (config.xmlOutputPath.isEmpty) {
        errors.add('La ruta de salida XML no está configurada');
      }
      
      if (config.pdfOutputPath.isEmpty) {
        errors.add('La ruta de salida PDF no está configurada');
      }
      
    } catch (e) {
      errors.add('Error al validar la configuración del sistema: $e');
    }
    
    return errors;
  }
  
  // ✅ Validar documento electrónico completo
  static Future<List<String>> validateElectronicDocument(ElectronicDocument document) async {
    List<String> errors = [];
    
    // Validar campos obligatorios del documento
    if (document.prefix.isEmpty) {
      errors.add('El prefijo del documento es obligatorio');
    }
    
    if (document.consecutive.isEmpty) {
      errors.add('El consecutivo del documento es obligatorio');
    }
    
    if (document.operationType == null) {
      errors.add('El tipo de operación es obligatorio');
    }
    
    if (document.paymentForm == null) {
      errors.add('La forma de pago es obligatoria');
    }
    
    // Validar items del documento
    if (document.items.isEmpty) {
      errors.add('El documento debe tener al menos un item');
    } else {
      for (int i = 0; i < document.items.length; i++) {
        final item = document.items[i];
        final itemIndex = i + 1;
        
              if (item.productCode.isEmpty) {
        errors.add('Item $itemIndex: El código del producto es obligatorio');
      }
      
      if (item.productName.isEmpty) {
        errors.add('Item $itemIndex: La descripción del producto es obligatoria');
      }
        
        if (item.quantity <= 0) {
          errors.add('Item $itemIndex: La cantidad debe ser mayor a 0');
        }
        
        if (item.unitPrice <= 0) {
          errors.add('Item $itemIndex: El precio unitario debe ser mayor a 0');
        }
      }
    }
    
    // Validar totales
    if (document.subtotal <= 0) {
      errors.add('El subtotal debe ser mayor a 0');
    }
    
    if (document.total <= 0) {
      errors.add('El total debe ser mayor a 0');
    }
    
    // Validar que el total sea igual a subtotal + impuestos - descuentos + cargos
    final calculatedTotal = document.subtotal + 
                           document.totalTaxes - 
                           document.totalDiscounts + 
                           document.totalCharges;
    
    if ((document.total - calculatedTotal).abs() > 0.01) {
      errors.add('El total no coincide con la suma de subtotal + impuestos - descuentos + cargos');
    }
    
    return errors;
  }
  
  // ✅ Validación completa antes de emitir
  static Future<ValidationResult> validateBeforeEmission({
    required Client client,
    required List<Product> products,
    required ElectronicDocument document,
  }) async {
    final allErrors = <String>[];
    
    // 1. Validar cliente
    final clientErrors = validateClient(client);
    allErrors.addAll(clientErrors);
    
    // 2. Validar productos
    final productErrors = validateProducts(products);
    allErrors.addAll(productErrors);
    
    // 3. Validar configuración del sistema
    final systemErrors = await validateSystemConfiguration();
    allErrors.addAll(systemErrors);
    
    // 4. Validar documento electrónico
    final documentErrors = await validateElectronicDocument(document);
    allErrors.addAll(documentErrors);
    
    // 5. Validar consecutivo disponible
    try {
      final config = await SystemConfigurationService.getConfiguration();
      if (!config.isConsecutiveInRange(config.nextConsecutive)) {
        allErrors.add('No hay consecutivos disponibles. Consecutivo actual: ${config.currentConsecutive}, Rango: ${config.dianResolutionRange}');
      }
    } catch (e) {
      allErrors.add('Error al validar consecutivos: $e');
    }
    
    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: _generateWarnings(client, products),
    );
  }
  
  // ✅ Generar advertencias (no bloquean la emisión)
  static List<String> _generateWarnings(Client client, List<Product> products) {
    final warnings = <String>[];
    
    // Advertencias del cliente
    if (client.phone?.isEmpty ?? true) {
      warnings.add('El cliente no tiene teléfono registrado (recomendado para facturación)');
    }
    
    if (client.address?.isEmpty ?? true) {
      warnings.add('El cliente no tiene dirección registrada (recomendado para facturación)');
    }
    
    if (client.city?.isEmpty ?? true) {
      warnings.add('El cliente no tiene ciudad registrada (recomendado para facturación)');
    }
    
    if (client.department?.isEmpty ?? true) {
      warnings.add('El cliente no tiene departamento registrado (recomendado para facturación)');
    }
    
    // Advertencias de productos
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final productIndex = i + 1;
      
      if (product.description.isEmpty && product.name.isNotEmpty) {
        warnings.add('Producto $productIndex: Considerar agregar descripción detallada');
      }
      
      if (product.price <= 0) {
        warnings.add('Producto $productIndex: El precio es 0 o negativo');
      }
    }
    
    return warnings;
  }
  
  // ✅ Validar email
  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }
  
  // ✅ Obtener resumen de validación
  static String getValidationSummary(ValidationResult result) {
    if (result.isValid) {
      return '✅ Todas las validaciones han pasado correctamente';
    } else {
      return '❌ La factura no puede ser emitida. Errores encontrados: ${result.errors.length}';
    }
  }
  
  // ✅ Verificar si se puede emitir
  static bool canEmitInvoice(ValidationResult result) {
    return result.isValid;
  }
  
  // ✅ Obtener mensaje de bloqueo
  static String getBlockingMessage(ValidationResult result) {
    if (result.isValid) {
      return 'La factura puede ser emitida';
    }
    
    final errorCount = result.errors.length;
    final warningCount = result.warnings.length;
    
    return 'La emisión de la factura está bloqueada por $errorCount error(es). '
           '${warningCount > 0 ? 'Además, hay $warningCount advertencia(s).' : ''}';
  }
}

// ✅ Clase para el resultado de la validación
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
  
  // ✅ Obtener todos los mensajes (errores + advertencias)
  List<String> get allMessages => [...errors, ...warnings];
  
  // ✅ Verificar si hay errores críticos
  bool get hasCriticalErrors => errors.isNotEmpty;
  
  // ✅ Verificar si solo hay advertencias
  bool get hasOnlyWarnings => errors.isEmpty && warnings.isNotEmpty;
  
  // ✅ Obtener resumen de estado
  String get statusSummary {
    if (isValid) {
      return '✅ Válido para emisión';
    } else if (hasOnlyWarnings) {
      return '⚠️ Válido con advertencias';
    } else {
      return '❌ Bloqueado por errores';
    }
  }
  
  // ✅ Obtener color del estado
  String get statusColor {
    if (isValid) return 'green';
    if (hasOnlyWarnings) return 'orange';
    return 'red';
  }
}
