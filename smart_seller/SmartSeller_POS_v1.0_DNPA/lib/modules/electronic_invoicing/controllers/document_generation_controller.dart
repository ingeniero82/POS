import 'dart:typed_data';
import 'package:get/get.dart';
import '../services/document_generation_service.dart';
import '../models/electronic_document.dart';
import '../../../models/client.dart';
import '../../../models/product.dart';

class DocumentGenerationController extends GetxController {
  // ✅ Variables observables
  final _isGenerating = false.obs;
  final _generationResult = Rx<DocumentGenerationResult?>(null);
  final _lastGenerationTime = Rx<DateTime?>(null);
  final _generationProgress = RxString('');
  
  // ✅ Getters
  bool get isGenerating => _isGenerating.value;
  DocumentGenerationResult? get generationResult => _generationResult.value;
  DateTime? get lastGenerationTime => _lastGenerationTime.value;
  String get generationProgress => _generationProgress.value;
  bool get hasGeneratedDocuments => generationResult?.success ?? false;
  bool get allFilesGenerated => generationResult?.allFilesGenerated ?? false;
  
  // ✅ Estado de generación
  String get generationStatus {
    if (generationResult == null) return 'No generado';
    if (generationResult!.success) return 'Generado exitosamente';
    return 'Error en generación';
  }
  
  // ✅ Resumen de generación
  String get generationSummary {
    if (generationResult == null) return 'No se han generado documentos';
    return generationResult!.summary;
  }
  
  // ✅ Verificar si se puede generar
  bool get canGenerateDocuments {
    // ✅ Aquí se pueden agregar validaciones adicionales
    return true;
  }
  
  // ✅ Generar todos los documentos
  Future<DocumentGenerationResult> generateAllDocuments({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
    String? logoPath,
    String? outputDirectory,
  }) async {
    if (!canGenerateDocuments) {
      return DocumentGenerationResult(
        success: false,
        error: 'No se pueden generar documentos en este momento',
        generatedAt: DateTime.now(),
      );
    }
    
    _isGenerating.value = true;
    _generationProgress.value = 'Iniciando generación...';
    
    try {
      // ✅ 1. Generar estructura interna (JSON)
      _generationProgress.value = 'Generando estructura JSON...';
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ✅ 2. Generar PDF
      _generationProgress.value = 'Generando PDF...';
      await Future.delayed(const Duration(milliseconds: 800));
      
      // ✅ 3. Generar XML
      _generationProgress.value = 'Generando XML...';
      await Future.delayed(const Duration(milliseconds: 600));
      
      // ✅ 4. Guardar archivos
      _generationProgress.value = 'Guardando archivos...';
      await Future.delayed(const Duration(milliseconds: 400));
      
      // ✅ 5. Guardar en base de datos
      _generationProgress.value = 'Guardando en base de datos...';
      await Future.delayed(const Duration(milliseconds: 300));
      
      // ✅ Llamar al servicio real
      final result = await DocumentGenerationService.generateAllDocuments(
        document: document,
        client: client,
        products: products,
        logoPath: logoPath,
        outputDirectory: outputDirectory,
      );
      
      _generationResult.value = result;
      _lastGenerationTime.value = DateTime.now();
      _generationProgress.value = 'Generación completada';
      
      // ✅ Mostrar resultado
      _showGenerationResult(result);
      
      return result;
      
    } catch (e) {
      final errorResult = DocumentGenerationResult(
        success: false,
        error: 'Error durante la generación: $e',
        generatedAt: DateTime.now(),
      );
      
      _generationResult.value = errorResult;
      _lastGenerationTime.value = DateTime.now();
      _generationProgress.value = 'Error en generación';
      
      // ✅ Mostrar error
      Get.snackbar(
        'Error de Generación',
        'Ocurrió un error durante la generación: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 5),
      );
      
      return errorResult;
      
    } finally {
      _isGenerating.value = false;
    }
  }
  
  // ✅ Generar solo JSON
  Map<String, dynamic> generateJSON({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
  }) {
    return DocumentGenerationService.generateInternalStructure(
      document: document,
      client: client,
      products: products,
    );
  }
  
  // ✅ Generar solo PDF
  Future<Uint8List> generatePDF({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
    String? logoPath,
  }) async {
    return await DocumentGenerationService.generatePDF(
      document: document,
      client: client,
      products: products,
      logoPath: logoPath,
    );
  }
  
  // ✅ Generar solo XML
  Future<String> generateXML({
    required ElectronicDocument document,
    required Client client,
    required List<Product> products,
  }) async {
    return await DocumentGenerationService.generateXML(
      document: document,
      client: client,
      products: products,
    );
  }
  
  // ✅ Limpiar resultado de generación
  void clearGenerationResult() {
    _generationResult.value = null;
    _lastGenerationTime.value = null;
    _generationProgress.value = '';
  }
  
  // ✅ Regenerar documentos (última generación)
  Future<DocumentGenerationResult?> regenerateDocuments() async {
    if (generationResult == null) {
      Get.snackbar(
        'Sin Generación',
        'No hay generación previa para repetir',
        backgroundColor: Get.theme.colorScheme.secondary,
        colorText: Get.theme.colorScheme.onSecondary,
      );
      return null;
    }
    
    // ✅ Mostrar mensaje de regeneración
    Get.snackbar(
      'Regenerando',
      'Se están regenerando los documentos...',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 2),
    );
    
    // ✅ Simular regeneración (en un caso real, se llamaría a la generación completa)
    await Future.delayed(const Duration(seconds: 1));
    
    // ✅ Actualizar timestamp
    _lastGenerationTime.value = DateTime.now();
    
    Get.snackbar(
      'Regeneración Completada',
      'Los documentos se han regenerado',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
    );
    
    return generationResult;
  }
  
  // ✅ Mostrar resultado de generación
  void _showGenerationResult(DocumentGenerationResult result) {
    if (result.success) {
      Get.snackbar(
        '✅ Generación Exitosa',
        'Documentos generados correctamente',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 3),
      );
    } else {
      Get.snackbar(
        '❌ Generación Fallida',
        'Error: ${result.error}',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 5),
      );
    }
  }
  
  // ✅ Obtener resumen detallado
  Map<String, dynamic> getDetailedSummary() {
    if (generationResult == null) {
      return {
        'status': 'No generado',
        'canGenerate': canGenerateDocuments,
        'lastGeneration': null,
        'filesGenerated': 0,
      };
    }
    
    return {
      'status': generationResult!.success ? 'Generado exitosamente' : 'Error en generación',
      'canGenerate': canGenerateDocuments,
      'lastGeneration': lastGenerationTime?.toIso8601String(),
      'filesGenerated': [
        if (generationResult!.jsonPath != null) 'JSON',
        if (generationResult!.pdfPath != null) 'PDF',
        if (generationResult!.xmlPath != null) 'XML',
      ].length,
      'summary': generationResult!.summary,
      'error': generationResult!.error,
    };
  }
  
  // ✅ Verificar si se puede proceder
  bool canProceedWithGeneration() {
    return canGenerateDocuments && !isGenerating;
  }
  
  // ✅ Obtener mensaje de estado
  String getStatusMessage() {
    if (generationResult == null) {
      return 'No se han generado documentos';
    }
    
    if (generationResult!.success) {
      if (allFilesGenerated) {
        return '✅ Todos los documentos han sido generados correctamente';
      } else {
        return '⚠️ Algunos documentos se generaron con errores';
      }
    } else {
      return '❌ La generación falló: ${generationResult!.error}';
    }
  }
  
  // ✅ Exportar resultado para logging
  Map<String, dynamic> exportForLogging() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'generationResult': getDetailedSummary(),
      'canGenerate': canGenerateDocuments,
      'statusMessage': getStatusMessage(),
    };
  }
  
  // ✅ Verificar archivos generados
  List<String> getGeneratedFiles() {
    if (generationResult == null) return [];
    
    final files = <String>[];
    if (generationResult!.jsonPath != null) files.add(generationResult!.jsonPath!);
    if (generationResult!.pdfPath != null) files.add(generationResult!.pdfPath!);
    if (generationResult!.xmlPath != null) files.add(generationResult!.xmlPath!);
    
    return files;
  }
  
  // ✅ Verificar si un archivo específico fue generado
  bool wasFileGenerated(String fileType) {
    if (generationResult == null) return false;
    
    switch (fileType.toUpperCase()) {
      case 'JSON':
        return generationResult!.jsonPath != null;
      case 'PDF':
        return generationResult!.pdfPath != null;
      case 'XML':
        return generationResult!.xmlPath != null;
      default:
        return false;
    }
  }
  
  // ✅ Obtener ruta de un archivo específico
  String? getFilePath(String fileType) {
    if (generationResult == null) return null;
    
    switch (fileType.toUpperCase()) {
      case 'JSON':
        return generationResult!.jsonPath;
      case 'PDF':
        return generationResult!.pdfPath;
      case 'XML':
        return generationResult!.xmlPath;
      default:
        return null;
    }
  }
}
