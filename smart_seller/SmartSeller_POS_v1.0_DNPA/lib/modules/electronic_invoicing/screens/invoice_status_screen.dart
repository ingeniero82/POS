import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/invoice_status_controller.dart';
import '../models/electronic_document.dart';
import '../widgets/invoice_status_widget.dart';
import '../widgets/invoice_filters_widget.dart';
import '../widgets/invoice_details_widget.dart';

class InvoiceStatusScreen extends StatelessWidget {
  const InvoiceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(InvoiceStatusController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Facturas Electrónicas'),
        backgroundColor: Get.theme.colorScheme.primary,
        foregroundColor: Get.theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
            tooltip: 'Refrescar',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFiltersDialog(context, controller),
            tooltip: 'Filtros',
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

            // ✅ Lista de facturas
            Expanded(
              child: _buildInvoicesList(controller),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewInvoiceDialog(context, controller),
        backgroundColor: Get.theme.colorScheme.primary,
        foregroundColor: Get.theme.colorScheme.onPrimary,
        tooltip: 'Nueva Factura',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ✅ Sección de resumen y estadísticas
  Widget _buildSummarySection(InvoiceStatusController controller) {
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
          Text(
            'Resumen de Facturas',
            style: Get.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                  'Enviadas',
                  controller.sentCount,
                  Colors.blue,
                  Icons.send,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Aceptadas',
                  controller.acceptedCount,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Rechazadas',
                  controller.rejectedCount,
                  Colors.red,
                  Icons.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  'Anuladas',
                  controller.cancelledCount,
                  Colors.grey,
                  Icons.cancel,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Información de filtros
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
                  controller.appliedFiltersSummary,
                  style: Get.textTheme.bodyMedium?.copyWith(
                    color: Get.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (controller.hasActiveFilters)
                TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('Limpiar Filtros'),
                ),
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
  Widget _buildSearchBar(InvoiceStatusController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: controller.searchInvoices,
        decoration: InputDecoration(
          hintText: 'Buscar facturas por número, cliente, estado...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => controller.searchInvoices(''),
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

  // ✅ Lista de facturas
  Widget _buildInvoicesList(InvoiceStatusController controller) {
    if (controller.filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Get.theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay facturas para mostrar',
              style: Get.textTheme.titleMedium?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.hasActiveFilters
                  ? 'Intenta ajustar los filtros aplicados'
                  : 'Crea tu primera factura electrónica',
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
      itemCount: controller.filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = controller.filteredInvoices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InvoiceStatusWidget(
            invoice: invoice,
            onTap: () => _showInvoiceDetails(context, controller, invoice),
          ),
        );
      },
    );
  }

  // ✅ Mostrar diálogo de filtros
  void _showFiltersDialog(
      BuildContext context, InvoiceStatusController controller) {
    showDialog(
      context: context,
      builder: (context) => InvoiceFiltersWidget(
        controller: controller,
      ),
    );
  }

  // ✅ Mostrar detalles de factura
  void _showInvoiceDetails(
    BuildContext context,
    InvoiceStatusController controller,
    ElectronicDocument invoice,
  ) {
    controller.selectInvoice(invoice);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceDetailsWidget(
        controller: controller,
        invoice: invoice,
      ),
    );
  }

  // ✅ Mostrar diálogo de nueva factura
  void _showNewInvoiceDialog(
      BuildContext context, InvoiceStatusController controller) {
    // ✅ Por ahora solo mostramos un mensaje
    // En una implementación real, aquí se abriría el flujo de creación
    Get.snackbar(
      'Nueva Factura',
      'Para crear una nueva factura, ve al POS y selecciona "Factura Electrónica"',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 4),
    );
  }
}
