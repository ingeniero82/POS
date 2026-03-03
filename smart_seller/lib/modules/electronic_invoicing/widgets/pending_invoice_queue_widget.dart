import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/pending_invoice_queue.dart';

class PendingInvoiceQueueWidget extends StatelessWidget {
  final PendingInvoiceItem item;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  const PendingInvoiceQueueWidget({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header con estado y acciones
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.documentNumber,
                        style: Get.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cliente: ${item.clientName}',
                        style: Get.textTheme.bodyMedium?.copyWith(
                          color: Get.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(item.status),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Información del item
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.access_time,
                        'Creado: ${_formatDateTime(item.createdAt)}',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.sync,
                        'Último intento: ${_formatDateTime(item.lastAttempt)}',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.repeat,
                        'Intentos: ${item.attemptCount}/${item.maxRetries}',
                      ),
                      const SizedBox(height: 4),
                      if (item.nextRetryAt != null)
                        _buildInfoRow(
                          Icons.schedule,
                          'Próximo: ${_formatDateTime(item.nextRetryAt!)}',
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // ✅ Error (si existe)
            if (item.lastError != null && item.lastError!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error: ${item.lastError}',
                            style: Get.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.errorDetails != null &&
                              item.errorDetails!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.errorDetails!,
                              style: Get.textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ Detalles adicionales
            if (item.retryData != null && item.retryData!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Datos de reintento: ${item.retryData!.length} campos',
                        style: Get.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ✅ Botones de acción
            Row(
              children: [
                if (item.canRetryNow)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (item.canRetryNow && item.status != QueueStatus.completed)
                  const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete),
                    label: const Text('Remover'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // ✅ Información de tiempo
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Último intento: ${item.timeSinceLastAttempt}',
                  style: Get.textTheme.bodySmall?.copyWith(
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.nextRetryAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Próximo: ${item.timeUntilNextRetry}',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: Get.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Widget para mostrar el estado
  Widget _buildStatusChip(QueueStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconData(
              int.parse(status.icon),
              fontFamily: 'MaterialIcons',
            ),
            color: _getStatusColor(status),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            status.description,
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Widget para mostrar información en fila
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Get.theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Get.textTheme.bodySmall?.copyWith(
              color: Get.theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ✅ Obtener color del estado
  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.pending:
        return Colors.orange;
      case QueueStatus.processing:
        return Colors.blue;
      case QueueStatus.failed:
        return Colors.red;
      case QueueStatus.retrying:
        return Colors.yellow;
      case QueueStatus.completed:
        return Colors.green;
    }
  }

  // ✅ Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
