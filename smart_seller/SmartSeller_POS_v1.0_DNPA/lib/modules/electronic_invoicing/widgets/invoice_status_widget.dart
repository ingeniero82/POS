import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/electronic_document.dart';
import '../models/invoice_status.dart';

class InvoiceStatusWidget extends StatelessWidget {
  final ElectronicDocument invoice;
  final VoidCallback onTap;

  const InvoiceStatusWidget({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Header con número de documento y estado
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.documentNumber,
                          style: Get.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cliente: ${invoice.clientDocumentNumber}',
                          style: Get.textTheme.bodyMedium?.copyWith(
                            color: Get.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(invoice.status),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // ✅ Información de la factura
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Fecha: ${_formatDate(invoice.issueDate)}',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.attach_money,
                          'Total: \$${invoice.total.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.shopping_cart,
                          'Items: ${invoice.items.length}',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.access_time,
                          'Creada: ${_formatDateTime(invoice.createdAt)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // ✅ Observaciones (si existen)
              if (invoice.observations != null && invoice.observations!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Get.theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: Get.theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          invoice.observations!,
                          style: Get.textTheme.bodySmall?.copyWith(
                            color: Get.theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Widget para mostrar el estado
  Widget _buildStatusChip(String statusCode) {
    final status = InvoiceStatus.fromCode(statusCode);
    
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
  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.pending:
        return Colors.orange;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.accepted:
        return Colors.green;
      case InvoiceStatus.rejected:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
    }
  }

  // ✅ Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ✅ Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
