import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/pending_invoice_queue_controller.dart';
import '../models/pending_invoice_queue.dart';
import '../widgets/pending_invoice_queue_widget.dart';
import '../widgets/retry_config_widget.dart';

class PendingInvoiceQueueScreen extends StatelessWidget {
  const PendingInvoiceQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PendingInvoiceQueueController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de Facturas Pendientes'),
        backgroundColor: Get.theme.colorScheme.primary,
        foregroundColor: Get.theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
            tooltip: 'Refrescar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showRetryConfigDialog(context, controller),
            tooltip: 'Configuración de Reintentos',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Column(
          children: [
            // ✅ Resumen y estadísticas
            _buildSummarySection(controller),
            
            // ✅ Barra de búsqueda
            _buildSearchBar(controller),
            
            // ✅ Lista de items en la cola
            Expanded(
              child: _buildQueueItemsList(controller),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.canPerformRetries ? controller.retryAllAvailable : null,
        backgroundColor: Get.theme.colorScheme.primary,
        foregroundColor: Get.theme.colorScheme.onPrimary,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar Todo'),
        tooltip: 'Reintentar todas las facturas disponibles',
      ),
    );
  }

  // ✅ Sección de resumen y estadísticas
  Widget _buildSummarySection(PendingInvoiceQueueController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.queue,
                color: Get.theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Cola de Facturas Pendientes',
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ✅ Estadísticas por estado
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Pendientes',
                  controller.pendingCount,
                  Colors.orange,
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Procesando',
                  controller.processingCount,
                  Colors.blue,
                  Icons.sync,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Fallidos',
                  controller.failedCount,
                  Colors.red,
                  Icons.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Reintentando',
                  controller.retryingCount,
                  Colors.yellow,
                  Icons.refresh,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Completados',
                  controller.completedCount,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // ✅ Información adicional
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Get.theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.statusMessage,
                  style: Get.textTheme.bodyMedium?.copyWith(
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // ✅ Configuración de reintentos
          Row(
            children: [
              Icon(
                Icons.settings,
                color: Get.theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.retryConfigText,
                  style: Get.textTheme.bodySmall?.copyWith(
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (controller.autoRetryActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Auto',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // ✅ Botones de acción
          Row(
            children: [
              if (controller.hasItemsNeedingRetry)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.canPerformRetries ? controller.retryAllAvailable : null,
                    icon: const Icon(Icons.refresh),
                    label: Text('Reintentar (${controller.itemsNeedingRetry})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              
              if (controller.hasCompletedItems) ...[
                if (controller.hasItemsNeedingRetry) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.clearCompletedItems,
                    icon: const Icon(Icons.cleaning_services),
                    label: Text('Limpiar Completados (${controller.completedCount})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
              
              if (controller.hasFailedItems) ...[
                if (controller.hasItemsNeedingRetry || controller.hasCompletedItems) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.clearFailedItems,
                    icon: const Icon(Icons.delete_sweep),
                    label: Text('Limpiar Fallidos (${controller.failedCount})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Tarjeta de estado
  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: Get.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Get.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ Barra de búsqueda
  Widget _buildSearchBar(PendingInvoiceQueueController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          // ✅ La búsqueda se maneja en el controlador
          // Por ahora solo refrescamos la vista
          controller.refresh();
        },
        decoration: InputDecoration(
          hintText: 'Buscar por número de factura, cliente, error...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              // ✅ Limpiar búsqueda
              controller.refresh();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Get.theme.colorScheme.surface,
        ),
      ),
    );
  }

  // ✅ Lista de items en la cola
  Widget _buildQueueItemsList(PendingInvoiceQueueController controller) {
    if (controller.totalItems == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_play_next,
              size: 64,
              color: Get.theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Cola de Pendientes Vacía',
              style: Get.textTheme.titleMedium?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay facturas pendientes de envío',
              style: Get.textTheme.bodyMedium?.copyWith(
                color: Get.theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: controller.queueItems.length,
      itemBuilder: (context, index) {
        final item = controller.queueItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PendingInvoiceQueueWidget(
            item: item,
            onRetry: () => controller.retryInvoice(item.id),
            onRemove: () => controller.removeFromQueue(item.id),
          ),
        );
      },
    );
  }

  // ✅ Mostrar diálogo de configuración de reintentos
  void _showRetryConfigDialog(BuildContext context, PendingInvoiceQueueController controller) {
    showDialog(
      context: context,
      builder: (context) => RetryConfigWidget(
        controller: controller,
      ),
    );
  }
}
