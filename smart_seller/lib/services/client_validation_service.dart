import '../models/client.dart';

class ClientValidationService {
  // Validar si un cliente puede recibir facturación electrónica
  static bool canReceiveElectronicInvoice(Client client) {
    return _validateRequiredFields(client).isEmpty;
  }
  
  // Obtener lista de campos faltantes para facturación electrónica
  static List<String> getMissingFields(Client client) {
    return _validateRequiredFields(client);
  }
  
  // Validar campos obligatorios para facturación electrónica
  static List<String> _validateRequiredFields(Client client) {
    List<String> missingFields = [];
    
    // ✅ Validar tipo de documento
    if (client.documentType.isEmpty) {
      missingFields.add('Tipo de documento');
    }
    
    // ✅ Validar número de documento
    if (client.documentNumber.isEmpty) {
      missingFields.add('Número de documento');
    }
    
    // ✅ Validar nombre o razón social
    if (client.businessName.isEmpty) {
      missingFields.add('Nombre o razón social');
    }
    
    // ✅ Validar dirección
    if (client.address == null || client.address!.isEmpty) {
      missingFields.add('Dirección');
    }
    
    // ✅ Validar ciudad
    if (client.city == null || client.city!.isEmpty) {
      missingFields.add('Ciudad');
    }
    
    // ✅ Validar departamento
    if (client.department == null || client.department!.isEmpty) {
      missingFields.add('Departamento');
    }
    
    // ✅ Validar correo electrónico (OBLIGATORIO para envío)
    if (client.email == null || client.email!.isEmpty) {
      missingFields.add('Correo electrónico');
    } else if (!_isValidEmail(client.email!)) {
      missingFields.add('Correo electrónico (formato inválido)');
    }
    
    // ✅ Validar teléfono (RECOMENDADO)
    if (client.phone == null || client.phone!.isEmpty) {
      missingFields.add('Teléfono (recomendado)');
    } else if (!_isValidPhone(client.phone!)) {
      missingFields.add('Teléfono (formato inválido)');
    }
    
    return missingFields;
  }
  
  // Validar formato de email
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  // Validar formato de teléfono
  static bool _isValidPhone(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanPhone.length >= 7 && cleanPhone.length <= 10;
  }
  
  // Obtener mensaje de error para mostrar al usuario
  static String getValidationErrorMessage(Client client) {
    final missingFields = getMissingFields(client);
    
    if (missingFields.isEmpty) {
      return 'El cliente cumple con todos los requisitos para facturación electrónica';
    }
    
    if (missingFields.length == 1) {
      return 'El cliente no puede recibir facturación electrónica. Falta: ${missingFields.first}';
    }
    
    return 'El cliente no puede recibir facturación electrónica. Faltan: ${missingFields.join(', ')}';
  }
  
  // Verificar si un cliente tiene datos mínimos para facturación
  static bool hasMinimumDataForInvoice(Client client) {
    return client.documentType.isNotEmpty &&
           client.documentNumber.isNotEmpty &&
           client.businessName.isNotEmpty &&
           client.address != null && client.address!.isNotEmpty &&
           client.city != null && client.city!.isNotEmpty &&
           client.department != null && client.department!.isNotEmpty;
  }
  
  // Obtener resumen de validación del cliente
  static Map<String, dynamic> getClientValidationSummary(Client client) {
    final missingFields = getMissingFields(client);
    final hasMinimumData = hasMinimumDataForInvoice(client);
    final canReceiveInvoice = canReceiveElectronicInvoice(client);
    
    return {
      'canReceiveElectronicInvoice': canReceiveInvoice,
      'hasMinimumData': hasMinimumData,
      'missingFields': missingFields,
      'missingFieldsCount': missingFields.length,
      'validationMessage': getValidationErrorMessage(client),
      'isEmailValid': client.email != null && client.email!.isNotEmpty && _isValidEmail(client.email!),
      'isPhoneValid': client.phone != null && client.phone!.isNotEmpty && _isValidPhone(client.phone!),
    };
  }
}
