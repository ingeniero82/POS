import 'package:flutter/material.dart';
import '../services/pre_emission_validation_service.dart';

class PreEmissionValidationWidget extends StatelessWidget {
  final ValidationResult validationResult;
  final VoidCallback? onRetry;
  final VoidCallback? onProceed;

  const PreEmissionValidationWidget({
    super.key,
    required this.validationResult,
    this.onRetry,
    this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header del estado de validación
            _buildValidationHeader(),
            const SizedBox(height: 16),

            // ✅ Resumen de validación
            _buildValidationSummary(),
            const SizedBox(height: 16),

            // ✅ Lista de errores (si los hay)
            if (validationResult.hasCriticalErrors) ...[
              _buildErrorsList(),
              const SizedBox(height: 16),
            ],

            // ✅ Lista de advertencias (si las hay)
            if (validationResult.warnings.isNotEmpty) ...[
              _buildWarningsList(),
              const SizedBox(height: 16),
            ],

            // ✅ Botones de acción
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ✅ Widget para header del estado de validación
  Widget _buildValidationHeader() {
    Color headerColor;
    IconData headerIcon;

    if (validationResult.isValid) {
      headerColor = Colors.green;
      headerIcon = Icons.check_circle;
    } else if (validationResult.hasOnlyWarnings) {
      headerColor = Colors.orange;
      headerIcon = Icons.warning;
    } else {
      headerColor = Colors.red;
      headerIcon = Icons.error;
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
                  validationResult.statusSummary,
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDescription(),
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

  // ✅ Widget para resumen de validación
  Widget _buildValidationSummary() {
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
          const Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen de Validación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            PreEmissionValidationService.getValidationSummary(validationResult),
            style: const TextStyle(fontSize: 14),
          ),
          if (validationResult.hasCriticalErrors) ...[
            const SizedBox(height: 8),
            Text(
              PreEmissionValidationService.getBlockingMessage(validationResult),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Widget para lista de errores
  Widget _buildErrorsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Errores Críticos (${validationResult.errors.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'La factura no puede ser emitida hasta que se corrijan estos errores:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...validationResult.errors.map((error) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, color: Colors.red, size: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
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

  // ✅ Widget para lista de advertencias
  Widget _buildWarningsList() {
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
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Advertencias (${validationResult.warnings.length})',
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
            'Estas advertencias no bloquean la emisión, pero se recomienda corregirlas:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...validationResult.warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, color: Colors.orange, size: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
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
        // Botón de reintentar validación
        if (onRetry != null) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar Validación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Botón de proceder (solo si es válido)
        if (validationResult.isValid && onProceed != null) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onProceed,
              icon: const Icon(Icons.check),
              label: const Text('Proceder con Emisión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (validationResult.hasCriticalErrors) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('No se puede emitir'),
            ),
          ),
        ],
      ],
    );
  }

  // ✅ Obtener descripción del estado
  String _getStatusDescription() {
    if (validationResult.isValid) {
      return 'La factura cumple con todos los requisitos para ser emitida';
    } else if (validationResult.hasOnlyWarnings) {
      return 'La factura puede ser emitida, pero tiene advertencias';
    } else {
      return 'La factura no puede ser emitida debido a errores críticos';
    }
  }
}

// ✅ Widget simplificado para mostrar solo el estado
class ValidationStatusWidget extends StatelessWidget {
  final ValidationResult validationResult;
  final bool showDetails;

  const ValidationStatusWidget({
    super.key,
    required this.validationResult,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDetails) {
      return _buildSimpleStatus();
    }

    return PreEmissionValidationWidget(
      validationResult: validationResult,
    );
  }

  Widget _buildSimpleStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (validationResult.isValid) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Válido para emisión';
    } else if (validationResult.hasOnlyWarnings) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Válido con advertencias';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Bloqueado por errores';
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
  }
}
