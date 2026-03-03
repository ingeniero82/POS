import 'package:shared_preferences/shared_preferences.dart';
import '../modules/electronic_invoicing/models/electronic_document.dart';

class SoftwareConfigurationService {
  static const String _softwareIdKey = 'software_id';
  static const String _softwarePinKey = 'software_pin';
  static const String _environmentKey = 'environment';
  static const String _dianResolutionNumberKey = 'dian_resolution_number';
  static const String _dianResolutionDateKey = 'dian_resolution_date';
  static const String _dianResolutionRangeKey = 'dian_resolution_range';
  static const String _softwareNameKey = 'software_name';
  static const String _softwareVersionKey = 'software_version';
  
  // ✅ Obtener configuración del software
  static Future<SoftwareConfiguration> getConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    
    return SoftwareConfiguration(
      softwareId: prefs.getString(_softwareIdKey) ?? '',
      softwarePin: prefs.getString(_softwarePinKey) ?? '',
      environment: prefs.getString(_environmentKey) ?? 'PRUEBAS',
      dianResolutionNumber: prefs.getString(_dianResolutionNumberKey) ?? '',
      dianResolutionDate: DateTime.tryParse(
        prefs.getString(_dianResolutionDateKey) ?? ''
      ) ?? DateTime.now(),
      dianResolutionRange: prefs.getString(_dianResolutionRangeKey) ?? '',
      softwareName: prefs.getString(_softwareNameKey) ?? 'Smart Seller POS',
      softwareVersion: prefs.getString(_softwareVersionKey) ?? '1.0.0',
    );
  }
  
  // ✅ Guardar configuración del software
  static Future<bool> saveConfiguration(SoftwareConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      await prefs.setString(_softwareIdKey, config.softwareId);
      await prefs.setString(_softwarePinKey, config.softwarePin);
      await prefs.setString(_environmentKey, config.environment);
      await prefs.setString(_dianResolutionNumberKey, config.dianResolutionNumber);
      await prefs.setString(_dianResolutionDateKey, config.dianResolutionDate.toIso8601String());
      await prefs.setString(_dianResolutionRangeKey, config.dianResolutionRange);
      await prefs.setString(_softwareNameKey, config.softwareName);
      await prefs.setString(_softwareVersionKey, config.softwareVersion);
      
      return true;
    } catch (e) {
      print('Error guardando configuración del software: $e');
      return false;
    }
  }
  
  // ✅ Validar configuración del software
  static bool isConfigurationValid(SoftwareConfiguration config) {
    return config.softwareId.isNotEmpty &&
           config.softwarePin.isNotEmpty &&
           config.softwarePin.length == 5 &&
           config.dianResolutionNumber.isNotEmpty &&
           config.dianResolutionRange.isNotEmpty;
  }
  
  // ✅ Obtener errores de validación
  static List<String> getValidationErrors(SoftwareConfiguration config) {
    List<String> errors = [];
    
    if (config.softwareId.isEmpty) {
      errors.add('El ID del software de facturación es obligatorio');
    }
    
    if (config.softwarePin.isEmpty) {
      errors.add('El PIN del software es obligatorio');
    } else if (config.softwarePin.length != 5) {
      errors.add('El PIN del software debe tener exactamente 5 dígitos');
    }
    
    if (config.dianResolutionNumber.isEmpty) {
      errors.add('El número de resolución DIAN es obligatorio');
    }
    
    if (config.dianResolutionRange.isEmpty) {
      errors.add('El rango de facturas permitido es obligatorio');
    }
    
    return errors;
  }
  
  // ✅ Generar consecutivo automático
  static String generateConsecutive(String prefix, String range) {
    // Implementar lógica para generar consecutivo único
    // Por ahora retorna un timestamp como consecutivo
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }
  
  // ✅ Validar rango de consecutivos
  static bool isConsecutiveInRange(String consecutive, String range) {
    try {
      // Implementar validación del rango de consecutivos
      // Por ahora retorna true
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ Obtener configuración por defecto para pruebas
  static SoftwareConfiguration getDefaultTestConfiguration() {
    return SoftwareConfiguration(
      softwareId: 'TEST_SOFTWARE_001',
      softwarePin: '12345',
      environment: 'PRUEBAS',
      dianResolutionNumber: 'RESOLUCION_TEST_001',
      dianResolutionDate: DateTime.now(),
      dianResolutionRange: '1-999999',
      softwareName: 'Smart Seller POS',
      softwareVersion: '1.0.0',
    );
  }
  
  // ✅ Verificar si la configuración está lista para producción
  static bool isReadyForProduction(SoftwareConfiguration config) {
    return config.environment == 'PRODUCCION' &&
           isConfigurationValid(config) &&
           config.softwareId != 'TEST_SOFTWARE_001' &&
           config.softwarePin != '12345';
  }
  
  // ✅ Cambiar ambiente (pruebas/producción)
  static Future<bool> changeEnvironment(String newEnvironment) async {
    if (newEnvironment != 'PRUEBAS' && newEnvironment != 'PRODUCCION') {
      return false;
    }
    
    final config = await getConfiguration();
    final updatedConfig = SoftwareConfiguration(
      softwareId: config.softwareId,
      softwarePin: config.softwarePin,
      environment: newEnvironment,
      dianResolutionNumber: config.dianResolutionNumber,
      dianResolutionDate: config.dianResolutionDate,
      dianResolutionRange: config.dianResolutionRange,
      softwareName: config.softwareName,
      softwareVersion: config.softwareVersion,
    );
    
    return await saveConfiguration(updatedConfig);
  }
  
  // ✅ Obtener información del software para DIAN
  static Map<String, dynamic> getSoftwareInfoForDIAN(SoftwareConfiguration config) {
    return {
      'softwareId': config.softwareId,
      'softwarePin': config.softwarePin,
      'environment': config.environment,
      'softwareName': config.softwareName,
      'softwareVersion': config.softwareVersion,
      'resolutionNumber': config.dianResolutionNumber,
      'resolutionDate': config.dianResolutionDate.toIso8601String(),
      'resolutionRange': config.dianResolutionRange,
    };
  }
}
