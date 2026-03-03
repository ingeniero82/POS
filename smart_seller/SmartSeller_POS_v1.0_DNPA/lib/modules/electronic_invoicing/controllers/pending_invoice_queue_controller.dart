import 'package:get/get.dart';
import '../services/pending_invoice_queue_service.dart';
import '../models/pending_invoice_queue.dart';

class PendingInvoiceQueueController extends GetxController {
  // ✅ Variables observables
  final _queueItems = <PendingInvoiceItem>[].obs;
  final _isLoading = false.obs;
  final _isProcessing = false.obs;
  final _queueSummary = <String, dynamic>{}.obs;
  final _retryConfig = Rx<RetryConfig?>(null);
  final _autoRetryActive = false.obs;

  // ✅ Getters
  List<PendingInvoiceItem> get queueItems => _queueItems;
  bool get isLoading => _isLoading.value;
  bool get isProcessing => _isProcessing.value;
  Map<String, dynamic> get queueSummary => _queueSummary;
  RetryConfig? get retryConfig => _retryConfig.value;
  bool get autoRetryActive => _autoRetryActive.value;

  // ✅ Contadores por estado
  int get pendingCount => _queueSummary['pending'] ?? 0;
  int get processingCount => _queueSummary['processing'] ?? 0;
  int get failedCount => _queueSummary['failed'] ?? 0;
  int get retryingCount => _queueSummary['retrying'] ?? 0;
  int get completedCount => _queueSummary['completed'] ?? 0;
  int get totalItems => _queueSummary['totalItems'] ?? 0;
  int get itemsNeedingRetry => _queueSummary['needingRetry'] ?? 0;
  int get itemsExhaustedRetries => _queueSummary['exhaustedRetries'] ?? 0;

  // ✅ Estado de la cola
  bool get hasItems => totalItems > 0;
  bool get hasFailedItems => failedCount > 0;
  bool get hasItemsNeedingRetry => itemsNeedingRetry > 0;
  bool get hasCompletedItems => completedCount > 0;

  @override
  void onInit() {
    super.onInit();
    _loadRetryConfig();
    _loadQueueData();
  }

  @override
  void onClose() {
    // ✅ Detener timer de reintentos automáticos
    PendingInvoiceQueueService.stopAutoRetryTimer();
    super.onClose();
  }

  // ✅ Cargar configuración de reintentos
  Future<void> _loadRetryConfig() async {
    try {
      await PendingInvoiceQueueService.loadRetryConfig();
      _retryConfig.value = PendingInvoiceQueueService.retryConfig;
    } catch (e) {
      print('Error cargando configuración de reintentos: $e');
    }
  }

  // ✅ Cargar datos de la cola
  Future<void> _loadQueueData() async {
    _isLoading.value = true;

    try {
      final items = await PendingInvoiceQueueService.getQueueItems();
      final summary = await PendingInvoiceQueueService.getQueueSummary();

      _queueItems.value = items;
      _queueSummary.value = summary;
      _autoRetryActive.value = summary['autoRetryActive'] ?? false;
    } catch (e) {
      print('Error cargando datos de la cola: $e');
      Get.snackbar(
        'Error',
        'No se pudieron cargar los datos de la cola: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // ✅ Refrescar datos
  @override
  Future<void> refresh() async {
    await _loadQueueData();
  }

  // ✅ Actualizar configuración de reintentos
  Future<void> updateRetryConfig(RetryConfig config) async {
    try {
      await PendingInvoiceQueueService.setRetryConfig(config);
      _retryConfig.value = config;

      Get.snackbar(
        '✅ Configuración Actualizada',
        'La configuración de reintentos se ha actualizado correctamente',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      print('Error actualizando configuración: $e');
      Get.snackbar(
        '❌ Error',
        'No se pudo actualizar la configuración: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  // ✅ Reintentar factura específica
  Future<bool> retryInvoice(String itemId) async {
    if (_isProcessing.value) return false;

    _isProcessing.value = true;

    try {
      final success = await PendingInvoiceQueueService.retryInvoice(itemId);

      if (success) {
        Get.snackbar(
          '✅ Reintento Exitoso',
          'La factura se ha enviado correctamente',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
      } else {
        Get.snackbar(
          '⚠️ Reintento Fallido',
          'La factura no se pudo enviar, se reintentará más tarde',
          backgroundColor: Get.theme.colorScheme.secondary,
          colorText: Get.theme.colorScheme.onSecondary,
        );
      }

      // ✅ Recargar datos
      await _loadQueueData();

      return success;
    } catch (e) {
      print('Error en reintento: $e');
      Get.snackbar(
        '❌ Error',
        'Error durante el reintento: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    } finally {
      _isProcessing.value = false;
    }
  }

  // ✅ Reintentar todas las facturas disponibles
  Future<int> retryAllAvailable() async {
    if (_isProcessing.value) return 0;

    _isProcessing.value = true;

    try {
      final successCount = await PendingInvoiceQueueService.retryAllAvailable();

      Get.snackbar(
        '🔄 Reintentos Completados',
        'Se reintentaron $successCount facturas exitosamente',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );

      // ✅ Recargar datos
      await _loadQueueData();

      return successCount;
    } catch (e) {
      print('Error en reintentos masivos: $e');
      Get.snackbar(
        '❌ Error',
        'Error durante los reintentos masivos: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return 0;
    } finally {
      _isProcessing.value = false;
    }
  }

  // ✅ Remover item de la cola
  Future<bool> removeFromQueue(String itemId) async {
    try {
      final success = await PendingInvoiceQueueService.removeFromQueue(itemId);

      if (success) {
        Get.snackbar(
          '✅ Item Removido',
          'El item se ha removido de la cola correctamente',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        // ✅ Recargar datos
        await _loadQueueData();
      }

      return success;
    } catch (e) {
      print('Error removiendo de la cola: $e');
      Get.snackbar(
        '❌ Error',
        'No se pudo remover el item: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    }
  }

  // ✅ Limpiar items completados
  Future<int> clearCompletedItems() async {
    try {
      final removedCount =
          await PendingInvoiceQueueService.clearCompletedItems();

      if (removedCount > 0) {
        Get.snackbar(
          '🧹 Limpieza Completada',
          'Se removieron $removedCount items completados',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        // ✅ Recargar datos
        await _loadQueueData();
      }

      return removedCount;
    } catch (e) {
      print('Error limpiando items completados: $e');
      Get.snackbar(
        '❌ Error',
        'No se pudieron limpiar los items completados: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return 0;
    }
  }

  // ✅ Limpiar items fallidos
  Future<int> clearFailedItems() async {
    try {
      final removedCount = await PendingInvoiceQueueService.clearFailedItems();

      if (removedCount > 0) {
        Get.snackbar(
          '🧹 Limpieza Completada',
          'Se removieron $removedCount items fallidos',
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        // ✅ Recargar datos
        await _loadQueueData();
      }

      return removedCount;
    } catch (e) {
      print('Error limpiando items fallidos: $e');
      Get.snackbar(
        '❌ Error',
        'No se pudieron limpiar los items fallidos: $e',
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return 0;
    }
  }

  // ✅ Obtener items por estado
  List<PendingInvoiceItem> getItemsByStatus(QueueStatus status) {
    return _queueItems.where((item) => item.status == status).toList();
  }

  // ✅ Obtener items que necesitan reintento
  List<PendingInvoiceItem> getItemsNeedingRetry() {
    return _queueItems.where((item) => item.canRetryNow).toList();
  }

  // ✅ Obtener items con reintentos agotados
  List<PendingInvoiceItem> getItemsExhaustedRetries() {
    return _queueItems.where((item) => item.hasExhaustedRetries).toList();
  }

  // ✅ Obtener items recientes (últimas 24 horas)
  List<PendingInvoiceItem> getRecentItems() {
    final now = DateTime.now();
    return _queueItems.where((item) {
      final difference = now.difference(item.createdAt);
      return difference.inHours < 24;
    }).toList();
  }

  // ✅ Filtrar items por texto
  List<PendingInvoiceItem> filterItemsByText(String searchTerm) {
    if (searchTerm.isEmpty) return _queueItems;

    final term = searchTerm.toLowerCase();
    return _queueItems.where((item) {
      return item.documentNumber.toLowerCase().contains(term) ||
          item.clientName.toLowerCase().contains(term) ||
          (item.lastError?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  // ✅ Obtener resumen del estado de la cola
  String get queueStatusSummary {
    if (totalItems == 0) return 'Cola vacía';

    final parts = <String>[];

    if (pendingCount > 0) parts.add('$pendingCount pendientes');
    if (processingCount > 0) parts.add('$processingCount procesando');
    if (failedCount > 0) parts.add('$failedCount fallidos');
    if (retryingCount > 0) parts.add('$retryingCount reintentando');
    if (completedCount > 0) parts.add('$completedCount completados');

    return parts.join(', ');
  }

  // ✅ Obtener mensaje de estado
  String get statusMessage {
    if (totalItems == 0) return 'No hay facturas en la cola de pendientes';

    if (hasItemsNeedingRetry) {
      return '⚠️ Hay $itemsNeedingRetry facturas listas para reintento';
    }

    if (hasFailedItems) {
      return '❌ Hay $failedCount facturas con errores';
    }

    if (hasCompletedItems) {
      return '✅ Hay $completedCount facturas enviadas exitosamente';
    }

    return '🔄 Procesando facturas en la cola';
  }

  // ✅ Verificar si se puede realizar reintentos
  bool get canPerformRetries {
    return !_isProcessing.value && hasItemsNeedingRetry;
  }

  // ✅ Verificar si se puede limpiar
  bool get canClearItems {
    return hasCompletedItems || hasFailedItems;
  }

  // ✅ Obtener configuración de reintentos como texto
  String get retryConfigText {
    final config = _retryConfig.value;
    if (config == null) return 'Configuración no disponible';

    return 'Máx: ${config.maxRetries} | Delay: ${config.initialDelay.inMinutes}min | Multiplicador: ${config.backoffMultiplier}x';
  }

  // ✅ Exportar datos de la cola
  Future<String> exportQueueData() async {
    try {
      return await PendingInvoiceQueueService.exportQueueData();
    } catch (e) {
      print('Error exportando datos de la cola: $e');
      return '{}';
    }
  }

  // ✅ Obtener estadísticas detalladas
  Map<String, dynamic> getDetailedStatistics() {
    return {
      'totalItems': totalItems,
      'pending': pendingCount,
      'processing': processingCount,
      'failed': failedCount,
      'retrying': retryingCount,
      'completed': completedCount,
      'needingRetry': itemsNeedingRetry,
      'exhaustedRetries': itemsExhaustedRetries,
      'autoRetryActive': autoRetryActive,
      'retryConfig': retryConfigText,
      'statusMessage': statusMessage,
      'canPerformRetries': canPerformRetries,
      'canClearItems': canClearItems,
    };
  }
}
