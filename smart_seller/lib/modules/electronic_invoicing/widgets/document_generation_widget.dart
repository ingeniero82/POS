import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/document_generation_controller.dart';
import '../services/document_generation_service.dart';

class DocumentGenerationWidget extends StatelessWidget {
  final DocumentGenerationController controller;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  
  const DocumentGenerationWidget({
    super.key,
    required this.controller,
    this.onGenerate,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header del estado de generación
            _buildGenerationHeader(),
            const SizedBox(height: 16),
            
            // ✅ Progreso de generación (si está generando)
            if (controller.isGenerating) ...[
              _buildGenerationProgress(),
              const SizedBox(height: 16),
            ],
            
            // ✅ Resumen de generación
            _buildGenerationSummary(),
            const SizedBox(height: 16),
            
            // ✅ Lista de archivos generados (si los hay)
            if (controller.hasGeneratedDocuments) ...[
              _buildGeneratedFilesList(),
              const SizedBox(height: 16),
            ],
            
            // ✅ Botones de acción
            _buildActionButtons(),
          ],
        ),
      ),
    ));
  }
  
  // ✅ Widget para header del estado de generación
  Widget _buildGenerationHeader() {
    Color headerColor;
    IconData headerIcon;
    String headerText;
    
    if (controller.isGenerating) {
      headerColor = Colors.blue;
      headerIcon = Icons.sync;
      headerText = 'Generando Documentos...';
    } else if (controller.hasGeneratedDocuments) {
      headerColor = Colors.green;
      headerIcon = Icons.check_circle;
      headerText = 'Documentos Generados';
    } else {
      headerColor = Colors.grey;
      headerIcon = Icons.description;
      headerText = 'Sin Documentos Generados';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: headerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: headerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(headerIcon, color: headerColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerText,
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHeaderDescription(),
                  style: TextStyle(
                    color: headerColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget para progreso de generación
  Widget _buildGenerationProgress() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Progreso de Generación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            backgroundColor: Colors.blue.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            controller.generationProgress,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  // ✅ Widget para resumen de generación
  Widget _buildGenerationSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Resumen de Generación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.generationSummary,
            style: const TextStyle(fontSize: 14),
          ),
          if (controller.lastGenerationTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Última generación: ${_formatDateTime(controller.lastGenerationTime!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // ✅ Widget para lista de archivos generados
  Widget _buildGeneratedFilesList() {
    final files = controller.getGeneratedFiles();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Archivos Generados (${files.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Los siguientes archivos han sido generados:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...files.map((filePath) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insert_drive_file, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filePath,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  // ✅ Widget para botones de acción
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Botón de generar documentos
        if (onGenerate != null && !controller.isGenerating) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.canProceedWithGeneration() ? onGenerate : null,
              icon: const Icon(Icons.add),
              label: const Text('Generar Documentos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        
        // Botón de regenerar (solo si ya se generaron)
        if (controller.hasGeneratedDocuments && onRegenerate != null) ...[
          if (onGenerate != null) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.canProceedWithGeneration() ? onRegenerate : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        
        // Botón de limpiar
        if (controller.hasGeneratedDocuments) ...[
          if (onGenerate != null || onRegenerate != null) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.clearGenerationResult,
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  // ✅ Obtener descripción del header
  String _getHeaderDescription() {
    if (controller.isGenerating) {
      return 'Se están generando los documentos electrónicos...';
    } else if (controller.hasGeneratedDocuments) {
      return 'Todos los documentos han sido generados exitosamente';
    } else {
      return 'No se han generado documentos electrónicos';
    }
  }
  
  // ✅ Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ✅ Widget simplificado para mostrar solo el estado
class GenerationStatusWidget extends StatelessWidget {
  final DocumentGenerationController controller;
  final bool showDetails;
  
  const GenerationStatusWidget({
    super.key,
    required this.controller,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDetails) {
      return _buildSimpleStatus();
    }
    
    return DocumentGenerationWidget(
      controller: controller,
    );
  }
  
  Widget _buildSimpleStatus() {
    return Obx(() {
      Color statusColor;
      IconData statusIcon;
      String statusText;
      
      if (controller.isGenerating) {
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        statusText = 'Generando...';
      } else if (controller.hasGeneratedDocuments) {
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Generados';
      } else {
        statusColor = Colors.grey;
        statusIcon = Icons.description;
        statusText = 'Sin generar';
      }
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }
}
