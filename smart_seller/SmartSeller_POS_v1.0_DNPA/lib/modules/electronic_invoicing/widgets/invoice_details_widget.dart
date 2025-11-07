import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/invoice_status_controller.dart';
import '../models/electronic_document.dart';
import '../models/invoice_status.dart';

class InvoiceDetailsWidget extends StatelessWidget {
  final InvoiceStatusController controller;
  final ElectronicDocument invoice;

  const InvoiceDetailsWidget({
    super.key,
    required this.controller,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ✅ Header con botón de cerrar
          _buildHeader(context),
          
          // ✅ Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Información básica de la factura
                  _buildInvoiceBasicInfo(),
                  
                  const SizedBox(height: 24),
                  
                  // ✅ Detalles del cliente
                  _buildClientInfo(),
                  
                  const SizedBox(height: 24),
                  
                  // ✅ Items de la factura
                  _buildInvoiceItems(),
                  
                  const SizedBox(height: 24),
                  
                  // ✅ Totales
                  _buildInvoiceTotals(),
                  
                  const SizedBox(height: 24),
                  
                  // ✅ Historial de estados
                  _buildStatusHistory(),
                  
                  const SizedBox(height: 24),
                  
                  // ✅ Acciones disponibles
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Header con botón de cerrar
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long,
            color: Get.theme.colorScheme.onPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Detalles de Factura',
              style: Get.textTheme.titleLarge?.copyWith(
                color: Get.theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Get.theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Información básica de la factura
  Widget _buildInvoiceBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de la Factura',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow('Número', invoice.documentNumber),
            _buildInfoRow('Prefijo', invoice.prefix),
            _buildInfoRow('Consecutivo', invoice.consecutive.toString()),
            _buildInfoRow('Fecha de Emisión', _formatDate(invoice.issueDate)),
            _buildInfoRow('Fecha de Vencimiento', _formatDate(invoice.dueDate)),
            _buildInfoRow('Estado', _getStatusDescription(invoice.status)),
            _buildInfoRow('Tipo de Operación', invoice.operationType),
            _buildInfoRow('Método de Pago', invoice.paymentMethod),
            _buildInfoRow('Forma de Pago', invoice.paymentForm),
          ],
        ),
      ),
    );
  }

  // ✅ Información del cliente
  Widget _buildClientInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información del Cliente',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow('Documento', '${invoice.clientDocumentType} ${invoice.clientDocumentNumber}'),
            _buildInfoRow('Nombre/Razón Social', invoice.clientBusinessName),
            _buildInfoRow('Email', invoice.clientEmail ?? 'No especificado'),
            _buildInfoRow('Teléfono', invoice.clientPhone ?? 'No especificado'),
            _buildInfoRow('Dirección', invoice.clientAddress ?? 'No especificada'),
            _buildInfoRow('Ciudad', invoice.clientCity ?? 'No especificada'),
            _buildInfoRow('Departamento', invoice.clientDepartment ?? 'No especificado'),
            _buildInfoRow('Responsabilidad Fiscal', invoice.clientFiscalResponsibility ?? 'No especificada'),
          ],
        ),
      ),
    );
  }

  // ✅ Items de la factura
  Widget _buildInvoiceItems() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items de la Factura (${invoice.items.length})',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...invoice.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  // ✅ Fila de item
  Widget _buildItemRow(DocumentItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: Get.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '\$${item.totalWithTaxesAndDiscounts.toStringAsFixed(2)}',
                style: Get.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Código: ${item.productCode}',
                style: Get.textTheme.bodySmall?.copyWith(
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Cantidad: ${item.quantity} ${item.unit}',
                style: Get.textTheme.bodySmall?.copyWith(
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Precio: \$${item.unitPrice.toStringAsFixed(2)}',
                style: Get.textTheme.bodySmall?.copyWith(
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if ((item.discounts ?? 0) > 0 || (item.charges ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if ((item.discounts ?? 0) > 0)
                  Text(
                    'Descuento: -\$${(item.discounts ?? 0).toStringAsFixed(2)}',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                if ((item.discounts ?? 0) > 0 && (item.charges ?? 0) > 0)
                  const SizedBox(width: 16),
                if ((item.charges ?? 0) > 0)
                  Text(
                    'Cargo: +\$${(item.charges ?? 0).toStringAsFixed(2)}',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Totales de la factura
  Widget _buildInvoiceTotals() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totales',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTotalRow('Subtotal', invoice.subtotal, false),
            _buildTotalRow('Descuentos', invoice.totalDiscounts, true),
            _buildTotalRow('Impuestos', invoice.totalTaxes, false),
            _buildTotalRow('Cargos', invoice.totalCharges, false),
            const Divider(),
            _buildTotalRow('Total', invoice.total, false, isTotal: true),
          ],
        ),
      ),
    );
  }

  // ✅ Fila de total
  Widget _buildTotalRow(String label, double amount, bool isDiscount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Get.textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.toStringAsFixed(2)}',
            style: Get.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Historial de estados
  Widget _buildStatusHistory() {
    return Obx(() {
      if (controller.statusHistory.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial de Estados',
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No hay historial de estados disponible',
                    style: Get.textTheme.bodyMedium?.copyWith(
                      color: Get.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de Estados',
                style: Get.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              ...controller.statusHistory.map((tracking) => _buildStatusTrackingRow(tracking)),
            ],
          ),
        ),
      );
    });
  }

  // ✅ Fila de seguimiento de estado
  Widget _buildStatusTrackingRow(InvoiceStatusTracking tracking) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(tracking.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(tracking.status).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                IconData(
                  int.parse(tracking.status.icon),
                  fontFamily: 'MaterialIcons',
                ),
                color: _getStatusColor(tracking.status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tracking.status.description,
                  style: Get.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(tracking.status),
                  ),
                ),
              ),
              Text(
                _formatDateTime(tracking.timestamp),
                style: Get.textTheme.bodySmall?.copyWith(
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (tracking.reason != null && tracking.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo: ${tracking.reason}',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (tracking.notes != null && tracking.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notas: ${tracking.notes}',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Botones de acción
  Widget _buildActionButtons() {
    return Obx(() {
      final currentStatus = controller.currentInvoiceStatus;
      if (currentStatus == null) return const SizedBox.shrink();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Acciones Disponibles',
                style: Get.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (currentStatus.canBeSent)
                    ElevatedButton.icon(
                      onPressed: () => _sendToDIAN(),
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar a DIAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  
                  if (currentStatus.canBeCancelled)
                    ElevatedButton.icon(
                      onPressed: () => _cancelInvoice(),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Anular Factura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  
                  if (currentStatus == InvoiceStatus.sent)
                    ElevatedButton.icon(
                      onPressed: () => _markAsAccepted(),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Marcar como Aceptada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  
                  if (currentStatus == InvoiceStatus.sent)
                    ElevatedButton.icon(
                      onPressed: () => _markAsRejected(),
                      icon: const Icon(Icons.error),
                      label: const Text('Marcar como Rechazada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  // ✅ Acciones
  void _sendToDIAN() {
    controller.sendInvoiceToDIAN(
      invoiceId: invoice.id?.toString() ?? '',
      userId: 'usuario_actual', // En una implementación real se obtendría del sistema
    );
  }

  void _cancelInvoice() {
    _showCancelDialog();
  }

  void _markAsAccepted() {
    _showAcceptDialog();
  }

  void _markAsRejected() {
    _showRejectDialog();
  }

  // ✅ Diálogos de acción
  void _showCancelDialog() {
    final reasonController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('Anular Factura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Estás seguro de que quieres anular esta factura?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo de anulación',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                controller.cancelInvoice(
                  invoiceId: invoice.id?.toString() ?? '',
                  reason: reasonController.text,
                  userId: 'usuario_actual',
                );
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog() {
    final responseController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('Marcar como Aceptada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta factura ha sido aceptada por DIAN'),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              decoration: const InputDecoration(
                labelText: 'Respuesta de DIAN',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (responseController.text.isNotEmpty) {
                controller.markAsAccepted(
                  invoiceId: invoice.id?.toString() ?? '',
                  dianResponse: responseController.text,
                  userId: 'usuario_actual',
                );
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    final responseController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('Marcar como Rechazada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta factura ha sido rechazada por DIAN'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              decoration: const InputDecoration(
                labelText: 'Respuesta de DIAN',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty && responseController.text.isNotEmpty) {
                controller.markAsRejected(
                  invoiceId: invoice.id?.toString() ?? '',
                  reason: reasonController.text,
                  dianResponse: responseController.text,
                  userId: 'usuario_actual',
                );
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // ✅ Métodos auxiliares
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Get.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'No especificado',
              style: Get.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(String statusCode) {
    final status = InvoiceStatus.fromCode(statusCode);
    return status.description;
  }

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
