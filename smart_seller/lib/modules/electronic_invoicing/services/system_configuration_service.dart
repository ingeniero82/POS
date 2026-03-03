import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/system_configuration.dart';

class SystemConfigurationService {
  static const String _configKey = 'electronic_invoicing_system_config';
  
  // ✅ Obtener configuración del sistema
  static Future<SystemConfiguration> getConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_configKey);
    
    if (configJson == null) {
      // Si no hay configuración, crear una por defecto
      final defaultConfig = SystemConfiguration.getDefaultTest();
      await saveConfiguration(defaultConfig);
      return defaultConfig;
    }
    
    try {
      final configMap = Map<String, dynamic>.from(
        jsonDecode(configJson) as Map
      );
      return SystemConfiguration.fromMap(configMap);
    } catch (e) {
      print('Error cargando configuración: $e');
      // Si hay error, crear configuración por defecto
      final defaultConfig = SystemConfiguration.getDefaultTest();
      await saveConfiguration(defaultConfig);
      return defaultConfig;
    }
  }
  
  // ✅ Guardar configuración del sistema
  static Future<bool> saveConfiguration(SystemConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final configJson = jsonEncode(config.toMap());
      await prefs.setString(_configKey, configJson);
      return true;
    } catch (e) {
      print('Error guardando configuración: $e');
      return false;
    }
  }
  
  // ✅ Actualizar solo campos específicos
  static Future<bool> updateConfiguration({
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
  }) async {
    final currentConfig = await getConfiguration();
    
    final updatedConfig = currentConfig.copyWith(
      dianResolutionNumber: dianResolutionNumber,
      dianResolutionDate: dianResolutionDate,
      dianResolutionPrefix: dianResolutionPrefix,
      dianResolutionRange: dianResolutionRange,
      currentConsecutive: currentConsecutive,
      invoicePrefix: invoicePrefix,
      softwareId: softwareId,
      softwarePin: softwarePin,
      environment: environment,
      companyName: companyName,
      companyNit: companyNit,
      companyAddress: companyAddress,
      companyCity: companyCity,
      companyDepartment: companyDepartment,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      xmlOutputPath: xmlOutputPath,
      pdfOutputPath: pdfOutputPath,
      lastUpdated: DateTime.now(),
    );
    
    return await saveConfiguration(updatedConfig);
  }
  
  // ✅ Incrementar consecutivo
  static Future<bool> incrementConsecutive() async {
    final config = await getConfiguration();
    final nextConsecutive = config.nextConsecutive;
    
    // Verificar que esté en rango
    if (!config.isConsecutiveInRange(nextConsecutive)) {
      print('Consecutivo fuera de rango: $nextConsecutive');
      return false;
    }
    
    return await updateConfiguration(
      currentConsecutive: nextConsecutive,
    );
  }
  
  // ✅ Obtener siguiente consecutivo sin guardar
  static Future<int> getNextConsecutive() async {
    final config = await getConfiguration();
    return config.nextConsecutive;
  }
  
  // ✅ Verificar si la configuración está lista para facturación
  static Future<bool> isReadyForInvoicing() async {
    final config = await getConfiguration();
    return config.isValid;
  }
  
  // ✅ Obtener errores de configuración
  static Future<List<String>> getConfigurationErrors() async {
    final config = await getConfiguration();
    return config.validationErrors;
  }
  
  // ✅ Cambiar ambiente
  static Future<bool> changeEnvironment(String newEnvironment) async {
    if (newEnvironment != 'PRUEBAS' && newEnvironment != 'PRODUCCION') {
      return false;
    }
    
    return await updateConfiguration(environment: newEnvironment);
  }
  
  // ✅ Cargar configuración por defecto para pruebas
  static Future<bool> loadDefaultTestConfiguration() async {
    final defaultConfig = SystemConfiguration.getDefaultTest();
    return await saveConfiguration(defaultConfig);
  }
  
  // ✅ Verificar si está listo para producción
  static Future<bool> isReadyForProduction() async {
    final config = await getConfiguration();
    return config.isReadyForProduction;
  }
  
  // ✅ Obtener información de la empresa para DIAN
  static Future<Map<String, dynamic>> getCompanyInfoForDIAN() async {
    final config = await getConfiguration();
    
    return {
      'companyName': config.companyName,
      'companyNit': config.companyNit,
      'companyAddress': config.companyAddress,
      'companyCity': config.companyCity,
      'companyDepartment': config.companyDepartment,
      'companyPhone': config.companyPhone,
      'companyEmail': config.companyEmail,
    };
  }
  
  // ✅ Obtener información del software para DIAN
  static Future<Map<String, dynamic>> getSoftwareInfoForDIAN() async {
    final config = await getConfiguration();
    
    return {
      'softwareId': config.softwareId,
      'softwarePin': config.softwarePin,
      'environment': config.environment,
      'dianResolutionNumber': config.dianResolutionNumber,
      'dianResolutionDate': config.dianResolutionDate.toIso8601String(),
      'dianResolutionPrefix': config.dianResolutionPrefix,
      'dianResolutionRange': config.dianResolutionRange,
    };
  }
  
  // ✅ Obtener información de consecutivos
  static Future<Map<String, dynamic>> getConsecutiveInfo() async {
    final config = await getConfiguration();
    
    return {
      'currentConsecutive': config.currentConsecutive,
      'nextConsecutive': config.nextConsecutive,
      'invoicePrefix': config.invoicePrefix,
      'isInRange': config.isConsecutiveInRange(config.nextConsecutive),
    };
  }
  
  // ✅ Obtener rutas de archivos
  static Future<Map<String, String>> getOutputPaths() async {
    final config = await getConfiguration();
    
    return {
      'xmlOutputPath': config.xmlOutputPath,
      'pdfOutputPath': config.pdfOutputPath,
    };
  }
  
  // ✅ Validar ruta de archivo
  static bool isValidPath(String path) {
    // Validación básica de ruta
    return path.isNotEmpty && 
           !path.contains('*') && 
           !path.contains('?') && 
           !path.contains('<') && 
           !path.contains('>') && 
           !path.contains('|');
  }
  
  // ✅ Limpiar configuración (resetear a valores por defecto)
  static Future<bool> resetConfiguration() async {
    return await loadDefaultTestConfiguration();
  }
}
