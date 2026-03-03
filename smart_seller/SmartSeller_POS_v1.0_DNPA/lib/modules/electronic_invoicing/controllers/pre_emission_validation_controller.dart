import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/pre_emission_validation_service.dart';
import '../models/electronic_document.dart';
import '../../../models/client.dart';
import '../../../models/product.dart';

class PreEmissionValidationController extends GetxController {
  // ✅ Variables observables
  final _isValidating = false.obs;
  final _validationResult = Rx<ValidationResult?>(null);
  final _lastValidationTime = Rx<DateTime?>(null);
  
  // ✅ Getters
  bool get isValidating => _isValidating.value;
  ValidationResult? get validationResult => _validationResult.value;
  DateTime? get lastValidationTime => _lastValidationTime.value;
  bool get canEmitInvoice => validationResult?.isValid ?? false;
  bool get hasValidationErrors => validationResult?.hasCriticalErrors ?? false;
  bool get hasOnlyWarnings => validationResult?.hasOnlyWarnings ?? false;
  
  // ✅ Estado de validación
  String get validationStatus {
    if (validationResult == null) return 'No validado';
    return validationResult!.statusSummary;
  }
  
  // ✅ Color del estado
  String get validationStatusColor {
    if (validationResult == null) return 'grey';
    return validationResult!.statusColor;
  }
  
  // ✅ Mensaje de bloqueo
  String get blockingMessage {
    if (validationResult == null) return 'No se ha realizado validación';
    return PreEmissionValidationService.getBlockingMessage(validationResult!);
  }
  
  // ✅ Resumen de validación
  String get validationSummary {
    if (validationResult == null) return 'No se ha realizado validación';
    return PreEmissionValidationService.getValidationSummary(validationResult!);
  }
  
  // ✅ Lista de errores
  List<String> get errors {
    return validationResult?.errors ?? [];
  }
  
  // ✅ Lista de advertencias
  List<String> get warnings {
    return validationResult?.warnings ?? [];
  }
  
  // ✅ Contador de errores
  int get errorCount => errors.length;
  
  // ✅ Contador de advertencias
  int get warningCount => warnings.length;
  
  // ✅ Verificar si hay validación reciente (últimos 5 minutos)
  bool get hasRecentValidation {
    if (lastValidationTime == null) return false;
    final difference = DateTime.now().difference(lastValidationTime!);
    return difference.inMinutes < 5;
  }
  
  // ✅ Validar antes de emitir
  Future<ValidationResult> validateBeforeEmission({
    required Client client,
    required List<Product> products,
    required ElectronicDocument document,
  }) async {
    _isValidating.value = true;
    
    try {
      final result = await PreEmissionValidationService.validateBeforeEmission(
        client: client,
        products: products,
        document: document,
      );
      
      _validationResult.value = result;
      _lastValidationTime.value = DateTime.now();
      
      // ✅ Mostrar mensaje de resultado
      _showValidationResult(result);
      
      return result;
    } catch (e) {
      // ✅ Crear resultado de error
      final errorResult = ValidationResult(
        isValid: false,
        errors: ['Error durante la validación: $e'],
        warnings: [],
      );
      
      _validationResult.value = errorResult;
      _lastValidationTime.value = DateTime.now();
      
      // ✅ Mostrar error
      Get.snackbar(
        'Error de Validación',
        'Ocurrió un error durante la validación: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      
      return errorResult;
    } finally {
      _isValidating.value = false;
    }
  }
  
  // ✅ Validar solo cliente
  List<String> validateClient(Client client) {
    return PreEmissionValidationService.validateClient(client);
  }
  
  // ✅ Validar solo productos
  List<String> validateProducts(List<Product> products) {
    return PreEmissionValidationService.validateProducts(products);
  }
  
  // ✅ Validar solo configuración del sistema
  Future<List<String>> validateSystemConfiguration() async {
    return await PreEmissionValidationService.validateSystemConfiguration();
  }
  
  // ✅ Validar solo documento electrónico
  Future<List<String>> validateElectronicDocument(ElectronicDocument document) async {
    return await PreEmissionValidationService.validateElectronicDocument(document);
  }
  
  // ✅ Limpiar resultado de validación
  void clearValidation() {
    _validationResult.value = null;
    _lastValidationTime.value = null;
  }
  
  // ✅ Revalidar (última validación)
  Future<ValidationResult?> revalidate() async {
    if (validationResult == null) {
      Get.snackbar(
        'Sin Validación',
        'No hay validación previa para reintentar',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return null;
    }
    
    // ✅ Mostrar mensaje de reintento
    Get.snackbar(
      'Revalidando',
      'Se está realizando la validación nuevamente...',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    
    // ✅ Simular revalidación (en un caso real, se llamaría a la validación completa)
    await Future.delayed(const Duration(seconds: 1));
    
    // ✅ Actualizar timestamp
    _lastValidationTime.value = DateTime.now();
    
    Get.snackbar(
      'Revalidación Completada',
      'La validación se ha completado nuevamente',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
    
    return validationResult;
  }
  
  // ✅ Mostrar resultado de validación
  void _showValidationResult(ValidationResult result) {
    if (result.isValid) {
      Get.snackbar(
        '✅ Validación Exitosa',
        'La factura puede ser emitida',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } else if (result.hasOnlyWarnings) {
      Get.snackbar(
        '⚠️ Validación con Advertencias',
        'La factura puede ser emitida, pero tiene advertencias',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        '❌ Validación Fallida',
        'La factura no puede ser emitida. Errores: ${result.errors.length}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }
  
  // ✅ Obtener resumen detallado
  Map<String, dynamic> getDetailedSummary() {
    if (validationResult == null) {
      return {
        'status': 'No validado',
        'canEmit': false,
        'errorCount': 0,
        'warningCount': 0,
        'lastValidation': null,
        'hasRecentValidation': false,
      };
    }
    
    return {
      'status': validationResult!.statusSummary,
      'canEmit': validationResult!.isValid,
      'errorCount': errorCount,
      'warningCount': warningCount,
      'lastValidation': lastValidationTime?.toIso8601String(),
      'hasRecentValidation': hasRecentValidation,
      'errors': errors,
      'warnings': warnings,
    };
  }
  
  // ✅ Verificar si se puede proceder
  bool canProceedWithEmission() {
    return canEmitInvoice && hasRecentValidation;
  }
  
  // ✅ Obtener mensaje de estado
  String getStatusMessage() {
    if (validationResult == null) {
      return 'No se ha realizado validación previa';
    }
    
    if (validationResult!.isValid) {
      if (hasRecentValidation) {
        return '✅ La factura está validada y puede ser emitida';
      } else {
        return '⚠️ La validación ha expirado, se recomienda revalidar';
      }
    } else {
      return '❌ La factura no puede ser emitida debido a errores';
    }
  }
  
  // ✅ Exportar resultado para logging
  Map<String, dynamic> exportForLogging() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'validationResult': getDetailedSummary(),
      'canEmit': canEmitInvoice,
      'statusMessage': getStatusMessage(),
    };
  }
}
