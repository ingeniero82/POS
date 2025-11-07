import 'package:get/get.dart';
import '../services/invoice_status_service.dart';
import '../models/invoice_status.dart';
import '../models/electronic_document.dart';

class InvoiceStatusController extends GetxController {
  // ✅ Variables observables
  final _invoices = <ElectronicDocument>[].obs;
  final _filteredInvoices = <ElectronicDocument>[].obs;
  final _currentFilters = Rx<InvoiceFilterCriteria?>(null);
  final _isLoading = false.obs;
  final _selectedInvoice = Rx<ElectronicDocument?>(null);
  final _statusHistory = <InvoiceStatusTracking>[].obs;
  final _statistics = <InvoiceStatus, int>{}.obs;
  
  // ✅ Getters
  List<ElectronicDocument> get invoices => _invoices;
  List<ElectronicDocument> get filteredInvoices => _filteredInvoices;
  InvoiceFilterCriteria? get currentFilters => _currentFilters.value;
  bool get isLoading => _isLoading.value;
  ElectronicDocument? get selectedInvoice => _selectedInvoice.value;
  List<InvoiceStatusTracking> get statusHistory => _statusHistory;
  Map<InvoiceStatus, int> get statistics => _statistics;
  
  // ✅ Estado de filtros
  bool get hasActiveFilters => currentFilters?.hasActiveFilters ?? false;
  String get filterDescription => currentFilters?.filterDescription ?? 'Sin filtros';
  
  // ✅ Contadores por estado
  int get pendingCount => statistics[InvoiceStatus.pending] ?? 0;
  int get sentCount => statistics[InvoiceStatus.sent] ?? 0;
  int get acceptedCount => statistics[InvoiceStatus.accepted] ?? 0;
  int get rejectedCount => statistics[InvoiceStatus.rejected] ?? 0;
  int get cancelledCount => statistics[InvoiceStatus.cancelled] ?? 0;
  
  // ✅ Total de facturas
  int get totalInvoices => invoices.length;
  int get totalFiltered => filteredInvoices.length;
  
  // ✅ Facturas que requieren acción
  List<ElectronicDocument> get invoicesRequiringAction {
    return filteredInvoices.where((invoice) {
      final status = _getInvoiceStatus(invoice);
      return status?.requiresAction ?? false;
    }).toList();
  }
  
  // ✅ Facturas recientes
  List<ElectronicDocument> get recentInvoices {
    return filteredInvoices.where((invoice) {
      final now = DateTime.now();
      final difference = now.difference(invoice.createdAt);
      return difference.inHours < 24;
    }).toList();
  }
  
  @override
  void onInit() {
    super.onInit();
    _loadInvoices();
    _loadStatistics();
  }
  
  // ✅ Cargar todas las facturas
  Future<void> _loadInvoices() async {
    _isLoading.value = true;
    
    try {
      final allInvoices = await InvoiceStatusService.getAllInvoices();
      _invoices.value = allInvoices;
      _filteredInvoices.value = allInvoices;
    } catch (e) {
      print('Error cargando facturas: $e');
      Get.snackbar(
        'Error',
        'No se pudieron cargar las facturas: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  // ✅ Cargar estadísticas
  Future<void> _loadStatistics() async {
    try {
      final stats = await InvoiceStatusService.getStatusStatistics();
      _statistics.value = stats;
    } catch (e) {
      print('Error cargando estadísticas: $e');
    }
  }
  
  // ✅ Aplicar filtros
  Future<void> applyFilters(InvoiceFilterCriteria filters) async {
    _isLoading.value = true;
    _currentFilters.value = filters;
    
    try {
      final filtered = await InvoiceStatusService.getInvoicesWithFilters(filters);
      _filteredInvoices.value = filtered;
    } catch (e) {
      print('Error aplicando filtros: $e');
      Get.snackbar(
        'Error',
        'No se pudieron aplicar los filtros: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  // ✅ Limpiar filtros
  Future<void> clearFilters() async {
    _currentFilters.value = null;
    _filteredInvoices.value = _invoices;
  }
  
  // ✅ Buscar facturas
  Future<void> searchInvoices(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _filteredInvoices.value = _invoices;
      return;
    }
    
    _isLoading.value = true;
    
    try {
      final results = await InvoiceStatusService.searchInvoices(searchTerm);
      _filteredInvoices.value = results;
    } catch (e) {
      print('Error buscando facturas: $e');
      Get.snackbar(
        'Error',
        'No se pudo realizar la búsqueda: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  // ✅ Seleccionar factura
  Future<void> selectInvoice(ElectronicDocument invoice) async {
    _selectedInvoice.value = invoice;
    await _loadStatusHistory(invoice.id?.toString() ?? '');
  }
  
  // ✅ Cargar historial de estado
  Future<void> _loadStatusHistory(String invoiceId) async {
    try {
      final history = await InvoiceStatusService.getInvoiceStatusHistory(invoiceId);
      _statusHistory.value = history;
    } catch (e) {
      print('Error cargando historial: $e');
      _statusHistory.value = [];
    }
  }
  
  // ✅ Cambiar estado de factura
  Future<bool> changeInvoiceStatus({
    required String invoiceId,
    required InvoiceStatus newStatus,
    String? reason,
    String? dianResponse,
    String? userId,
    String? notes,
  }) async {
    try {
      final success = await InvoiceStatusService.changeInvoiceStatus(
        invoiceId: invoiceId,
        newStatus: newStatus,
        reason: reason,
        dianResponse: dianResponse,
        userId: userId,
        notes: notes,
      );
      
      if (success) {
        // ✅ Recargar datos
        await _loadInvoices();
        await _loadStatistics();
        
        // ✅ Si es la factura seleccionada, recargar historial
        if (selectedInvoice?.id.toString() == invoiceId) {
          await _loadStatusHistory(invoiceId);
        }
        
        Get.snackbar(
          '✅ Estado Actualizado',
          'El estado de la factura se ha actualizado correctamente',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
      }
      
      return success;
    } catch (e) {
      print('Error cambiando estado: $e');
      Get.snackbar(
        '❌ Error',
        'No se pudo cambiar el estado: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    }
  }
  
  // ✅ Enviar factura a DIAN
  Future<bool> sendInvoiceToDIAN({
    required String invoiceId,
    required String userId,
    String? notes,
  }) async {
    return await changeInvoiceStatus(
      invoiceId: invoiceId,
      newStatus: InvoiceStatus.sent,
      userId: userId,
      notes: notes ?? 'Enviada a DIAN',
    );
  }
  
  // ✅ Marcar como aceptada
  Future<bool> markAsAccepted({
    required String invoiceId,
    required String dianResponse,
    String? userId,
    String? notes,
  }) async {
    return await changeInvoiceStatus(
      invoiceId: invoiceId,
      newStatus: InvoiceStatus.accepted,
      dianResponse: dianResponse,
      userId: userId,
      notes: notes ?? 'Aceptada por DIAN',
    );
  }
  
  // ✅ Marcar como rechazada
  Future<bool> markAsRejected({
    required String invoiceId,
    required String reason,
    required String dianResponse,
    String? userId,
    String? notes,
  }) async {
    return await changeInvoiceStatus(
      invoiceId: invoiceId,
      newStatus: InvoiceStatus.rejected,
      reason: reason,
      dianResponse: dianResponse,
      userId: userId,
      notes: notes ?? 'Rechazada por DIAN',
    );
  }
  
  // ✅ Anular factura
  Future<bool> cancelInvoice({
    required String invoiceId,
    required String reason,
    String? userId,
    String? notes,
  }) async {
    return await changeInvoiceStatus(
      invoiceId: invoiceId,
      newStatus: InvoiceStatus.cancelled,
      reason: reason,
      userId: userId,
      notes: notes ?? 'Factura anulada',
    );
  }
  
  // ✅ Filtrar por estado
  Future<void> filterByStatus(InvoiceStatus? status) async {
    if (status == null) {
      await clearFilters();
      return;
    }
    
    final filters = currentFilters?.copyWith(status: status) ?? 
                   InvoiceFilterCriteria(status: status);
    
    await applyFilters(filters);
  }
  
  // ✅ Filtrar por fecha
  Future<void> filterByDateRange(DateTime? startDate, DateTime? endDate) async {
    final filters = currentFilters?.copyWith(
      startDate: startDate,
      endDate: endDate,
    ) ?? InvoiceFilterCriteria(
      startDate: startDate,
      endDate: endDate,
    );
    
    await applyFilters(filters);
  }
  
  // ✅ Filtrar por cliente
  Future<void> filterByClient(String? clientId, String? clientName) async {
    final filters = currentFilters?.copyWith(
      clientId: clientId,
      clientName: clientName,
    ) ?? InvoiceFilterCriteria(
      clientId: clientId,
      clientName: clientName,
    );
    
    await applyFilters(filters);
  }
  
  // ✅ Filtrar facturas recientes
  Future<void> filterRecentInvoices() async {
    final filters = currentFilters?.copyWith(isRecent: true) ?? 
                   InvoiceFilterCriteria(isRecent: true);
    
    await applyFilters(filters);
  }
  
  // ✅ Obtener estado de una factura
  InvoiceStatus? _getInvoiceStatus(ElectronicDocument invoice) {
    if (statusHistory.isEmpty) return null;
    
    // ✅ Buscar en el historial de la factura seleccionada
    if (selectedInvoice?.id == invoice.id) {
      return statusHistory.isNotEmpty ? statusHistory.first.status : null;
    }
    
    // ✅ Por ahora retornamos null, en una implementación real
    // se obtendría el estado actual de cada factura
    return null;
  }
  
  // ✅ Obtener estado actual de factura seleccionada
  InvoiceStatus? get currentInvoiceStatus {
    if (statusHistory.isEmpty) return null;
    return statusHistory.first.status;
  }
  
  // ✅ Verificar si la factura seleccionada puede ser enviada
  bool get canSendCurrentInvoice {
    final status = currentInvoiceStatus;
    return status?.canBeSent ?? false;
  }
  
  // ✅ Verificar si la factura seleccionada puede ser anulada
  bool get canCancelCurrentInvoice {
    final status = currentInvoiceStatus;
    return status?.canBeCancelled ?? false;
  }
  
  // ✅ Verificar si la factura seleccionada requiere acción
  bool get currentInvoiceRequiresAction {
    final status = currentInvoiceStatus;
    return status?.requiresAction ?? false;
  }
  
  // ✅ Obtener resumen del estado actual
  String get currentInvoiceStatusSummary {
    if (statusHistory.isEmpty) return 'Sin estado';
    return statusHistory.first.statusSummary;
  }
  
  // ✅ Obtener tiempo transcurrido del último cambio
  String get currentInvoiceTimeElapsed {
    if (statusHistory.isEmpty) return '';
    return statusHistory.first.timeElapsed;
  }
  
  // ✅ Refrescar datos
  Future<void> refresh() async {
    await _loadInvoices();
    await _loadStatistics();
    
    if (selectedInvoice != null) {
      await _loadStatusHistory(selectedInvoice!.id?.toString() ?? '');
    }
  }
  
  // ✅ Exportar historial de estado
  Future<String> exportStatusHistory() async {
    if (selectedInvoice == null) return '{}';
    
    try {
      return await InvoiceStatusService.exportStatusHistory(
        selectedInvoice!.id?.toString() ?? '',
      );
    } catch (e) {
      print('Error exportando historial: $e');
      return '{}';
    }
  }
  
  // ✅ Limpiar selección
  void clearSelection() {
    _selectedInvoice.value = null;
    _statusHistory.value = [];
  }
  
  // ✅ Obtener facturas por estado
  List<ElectronicDocument> getInvoicesByStatus(InvoiceStatus status) {
    return filteredInvoices.where((invoice) {
      final invoiceStatus = _getInvoiceStatus(invoice);
      return invoiceStatus == status;
    }).toList();
  }
  
  // ✅ Obtener resumen de filtros aplicados
  String get appliedFiltersSummary {
    if (!hasActiveFilters) return 'Mostrando todas las facturas';
    
    final filters = <String>[];
    if (currentFilters?.status != null) {
      filters.add('Estado: ${currentFilters!.status!.description}');
    }
    if (currentFilters?.startDate != null) {
      filters.add('Desde: ${_formatDate(currentFilters!.startDate!)}');
    }
    if (currentFilters?.endDate != null) {
      filters.add('Hasta: ${_formatDate(currentFilters!.endDate!)}');
    }
    if (currentFilters?.clientName != null) {
      filters.add('Cliente: ${currentFilters!.clientName}');
    }
    if (currentFilters?.isRecent == true) {
      filters.add('Recientes (24h)');
    }
    
    return 'Filtros: ${filters.join(', ')}';
  }
  
  // ✅ Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
