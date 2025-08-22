import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_invoice_queue.dart';
import '../models/electronic_document.dart';
import '../models/invoice_status.dart';
import 'invoice_status_service.dart';

class PendingInvoiceQueueService {
  static const String _queueKey = 'pending_invoice_queue';
  static const String _retryConfigKey = 'retry_config';
  
  // ✅ Configuración por defecto
  static RetryConfig _retryConfig = RetryConfig.defaultConfig;
  
  // ✅ Timer para reintentos automáticos
  static Timer? _autoRetryTimer;
  
  // ✅ Obtener configuración de reintentos
  static RetryConfig get retryConfig => _retryConfig;
  
  // ✅ Establecer configuración de reintentos
  static Future<void> setRetryConfig(RetryConfig config) async {
    _retryConfig = config;
    await _saveRetryConfig();
  }
  
  // ✅ Cargar configuración de reintentos
  static Future<void> loadRetryConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_retryConfigKey);
      
      if (configJson != null) {
        final configMap = jsonDecode(configJson);
        _retryConfig = RetryConfig(
          maxRetries: configMap['maxRetries'] ?? 3,
          initialDelay: Duration(minutes: configMap['initialDelayMinutes'] ?? 1),
          maxDelay: Duration(hours: configMap['maxDelayHours'] ?? 24),
          backoffMultiplier: configMap['backoffMultiplier'] ?? 2.0,
          exponentialBackoff: configMap['exponentialBackoff'] ?? true,
        );
      }
    } catch (e) {
      print('Error cargando configuración de reintentos: $e');
      // ✅ Mantener configuración por defecto
    }
  }
  
  // ✅ Guardar configuración de reintentos
  static Future<void> _saveRetryConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configMap = {
        'maxRetries': _retryConfig.maxRetries,
        'initialDelayMinutes': _retryConfig.initialDelay.inMinutes,
        'maxDelayHours': _retryConfig.maxDelay.inHours,
        'backoffMultiplier': _retryConfig.backoffMultiplier,
        'exponentialBackoff': _retryConfig.exponentialBackoff,
      };
      
      await prefs.setString(_retryConfigKey, jsonEncode(configMap));
    } catch (e) {
      print('Error guardando configuración de reintentos: $e');
    }
  }
  
  // ✅ Agregar factura a la cola de pendientes
  static Future<bool> addToQueue({
    required ElectronicDocument invoice,
    String? userId,
    String? error,
    String? errorDetails,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      // ✅ Verificar si ya existe en la cola
      final existingIndex = queueJson.indexWhere((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.invoiceId == invoice.id?.toString();
      });
      
      if (existingIndex != -1) {
        // ✅ Actualizar item existente
        final existingItem = PendingInvoiceItem.fromMap(
          jsonDecode(queueJson[existingIndex])
        );
        
        final updatedItem = existingItem.copyWith(
          lastAttempt: DateTime.now(),
          attemptCount: existingItem.attemptCount + 1,
          status: error != null ? QueueStatus.failed : QueueStatus.pending,
          lastError: error,
          errorDetails: errorDetails,
          nextRetryAt: error != null 
              ? DateTime.now().add(_retryConfig.calculateNextRetryDelay(existingItem.attemptCount + 1))
              : null,
        );
        
        queueJson[existingIndex] = jsonEncode(updatedItem.toMap());
      } else {
        // ✅ Crear nuevo item
        final newItem = PendingInvoiceItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          invoiceId: invoice.id?.toString() ?? '',
          documentNumber: invoice.documentNumber,
          clientName: invoice.clientBusinessName ?? 'Cliente sin nombre',
          createdAt: DateTime.now(),
          lastAttempt: DateTime.now(),
          attemptCount: 0,
          maxRetries: _retryConfig.maxRetries,
          status: error != null ? QueueStatus.failed : QueueStatus.pending,
          lastError: error,
          errorDetails: errorDetails,
          userId: userId,
        );
        
        queueJson.add(jsonEncode(newItem.toMap()));
      }
      
      await prefs.setStringList(_queueKey, queueJson);
      
      // ✅ Iniciar timer de reintentos automáticos si no está activo
      _startAutoRetryTimer();
      
      return true;
    } catch (e) {
      print('Error agregando a la cola: $e');
      return false;
    }
  }
  
  // ✅ Obtener todas las facturas en la cola
  static Future<List<PendingInvoiceItem>> getQueueItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      return queueJson
          .map((json) => PendingInvoiceItem.fromMap(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Más reciente primero
    } catch (e) {
      print('Error obteniendo items de la cola: $e');
      return [];
    }
  }
  
  // ✅ Obtener items por estado
  static Future<List<PendingInvoiceItem>> getItemsByStatus(QueueStatus status) async {
    try {
      final allItems = await getQueueItems();
      return allItems.where((item) => item.status == status).toList();
    } catch (e) {
      print('Error filtrando items por estado: $e');
      return [];
    }
  }
  
  // ✅ Obtener items que requieren reintento
  static Future<List<PendingInvoiceItem>> getItemsNeedingRetry() async {
    try {
      final allItems = await getQueueItems();
      return allItems.where((item) => item.canRetryNow).toList();
    } catch (e) {
      print('Error obteniendo items que necesitan reintento: $e');
      return [];
    }
  }
  
  // ✅ Obtener estadísticas de la cola
  static Future<Map<QueueStatus, int>> getQueueStatistics() async {
    try {
      final allItems = await getQueueItems();
      final statistics = <QueueStatus, int>{};
      
      // ✅ Inicializar contadores
      for (final status in QueueStatus.values) {
        statistics[status] = 0;
      }
      
      // ✅ Contar items por estado
      for (final item in allItems) {
        statistics[item.status] = (statistics[item.status] ?? 0) + 1;
      }
      
      return statistics;
    } catch (e) {
      print('Error obteniendo estadísticas de la cola: $e');
      return {};
    }
  }
  
  // ✅ Reintentar envío de una factura
  static Future<bool> retryInvoice(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final itemIndex = queueJson.indexWhere((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.id == itemId;
      });
      
      if (itemIndex == -1) return false;
      
      final item = PendingInvoiceItem.fromMap(jsonDecode(queueJson[itemIndex]));
      
      if (!item.canRetryNow) return false;
      
      // ✅ Actualizar item para reintento
      final updatedItem = item.copyWith(
        status: QueueStatus.retrying,
        lastAttempt: DateTime.now(),
        attemptCount: item.attemptCount + 1,
        nextRetryAt: null, // Inmediato
      );
      
      queueJson[itemIndex] = jsonEncode(updatedItem.toMap());
      await prefs.setStringList(_queueKey, queueJson);
      
      // ✅ Intentar envío
      final success = await _attemptInvoiceSend(updatedItem);
      
      if (success) {
        // ✅ Marcar como completado
        await _markItemCompleted(itemId);
      } else {
        // ✅ Marcar como fallido
        await _markItemFailed(itemId, 'Error en reintento');
      }
      
      return success;
    } catch (e) {
      print('Error en reintento: $e');
      return false;
    }
  }
  
  // ✅ Reintentar todos los items disponibles
  static Future<int> retryAllAvailable() async {
    try {
      final itemsToRetry = await getItemsNeedingRetry();
      int successCount = 0;
      
      for (final item in itemsToRetry) {
        final success = await retryInvoice(item.id);
        if (success) successCount++;
        
        // ✅ Pequeña pausa entre reintentos para no sobrecargar
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      return successCount;
    } catch (e) {
      print('Error en reintentos masivos: $e');
      return 0;
    }
  }
  
  // ✅ Remover item de la cola
  static Future<bool> removeFromQueue(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final newQueue = queueJson.where((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.id != itemId;
      }).toList();
      
      await prefs.setStringList(_queueKey, newQueue);
      return true;
    } catch (e) {
      print('Error removiendo de la cola: $e');
      return false;
    }
  }
  
  // ✅ Limpiar cola completada
  static Future<int> clearCompletedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final newQueue = queueJson.where((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.status != QueueStatus.completed;
      }).toList();
      
      final removedCount = queueJson.length - newQueue.length;
      await prefs.setStringList(_queueKey, newQueue);
      
      return removedCount;
    } catch (e) {
      print('Error limpiando items completados: $e');
      return 0;
    }
  }
  
  // ✅ Limpiar cola fallida
  static Future<int> clearFailedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final newQueue = queueJson.where((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.status != QueueStatus.failed;
      }).toList();
      
      final removedCount = queueJson.length - newQueue.length;
      await prefs.setStringList(_queueKey, newQueue);
      
      return removedCount;
    } catch (e) {
      print('Error limpiando items fallidos: $e');
      return 0;
    }
  }
  
  // ✅ Iniciar timer de reintentos automáticos
  static void _startAutoRetryTimer() {
    if (_autoRetryTimer?.isActive == true) return;
    
    _autoRetryTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final itemsToRetry = await getItemsNeedingRetry();
        
        if (itemsToRetry.isNotEmpty) {
          print('🔄 Reintentos automáticos: ${itemsToRetry.length} items disponibles');
          await retryAllAvailable();
        }
        
        // ✅ Detener timer si no hay items para reintentar
        if (itemsToRetry.isEmpty) {
          timer.cancel();
          _autoRetryTimer = null;
        }
      } catch (e) {
        print('Error en reintentos automáticos: $e');
      }
    });
  }
  
  // ✅ Detener timer de reintentos automáticos
  static void stopAutoRetryTimer() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
  }
  
  // ✅ Intentar envío de factura
  static Future<bool> _attemptInvoiceSend(PendingInvoiceItem item) async {
    try {
      // ✅ Simular envío a DIAN
      // En una implementación real, aquí se conectaría con el servicio DIAN
      await Future.delayed(const Duration(seconds: 2));
      
      // ✅ Simular éxito/fallo (90% éxito para testing)
      final random = DateTime.now().millisecond % 10;
      final success = random < 9; // 90% éxito
      
      if (success) {
        // ✅ Actualizar estado de la factura
        await InvoiceStatusService.sendInvoiceToDIAN(
          invoiceId: item.invoiceId,
          userId: item.userId ?? 'sistema',
          notes: 'Enviado desde cola de pendientes',
        );
      }
      
      return success;
    } catch (e) {
      print('Error en intento de envío: $e');
      return false;
    }
  }
  
  // ✅ Marcar item como completado
  static Future<bool> _markItemCompleted(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final itemIndex = queueJson.indexWhere((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.id == itemId;
      });
      
      if (itemIndex == -1) return false;
      
      final item = PendingInvoiceItem.fromMap(jsonDecode(queueJson[itemIndex]));
      
      final updatedItem = item.copyWith(
        status: QueueStatus.completed,
        lastAttempt: DateTime.now(),
      );
      
      queueJson[itemIndex] = jsonEncode(updatedItem.toMap());
      await prefs.setStringList(_queueKey, queueJson);
      
      return true;
    } catch (e) {
      print('Error marcando item como completado: $e');
      return false;
    }
  }
  
  // ✅ Marcar item como fallido
  static Future<bool> _markItemFailed(String itemId, String error) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];
      
      final itemIndex = queueJson.indexWhere((itemJson) {
        final item = PendingInvoiceItem.fromMap(jsonDecode(itemJson));
        return item.id == itemId;
      });
      
      if (itemIndex == -1) return false;
      
      final item = PendingInvoiceItem.fromMap(jsonDecode(queueJson[itemIndex]));
      
      final updatedItem = item.copyWith(
        status: QueueStatus.failed,
        lastAttempt: DateTime.now(),
        lastError: error,
        nextRetryAt: _retryConfig.shouldRetry(item.attemptCount, error)
            ? DateTime.now().add(_retryConfig.calculateNextRetryDelay(item.attemptCount))
            : null,
      );
      
      queueJson[itemIndex] = jsonEncode(updatedItem.toMap());
      await prefs.setStringList(_queueKey, queueJson);
      
      return true;
    } catch (e) {
      print('Error marcando item como fallido: $e');
      return false;
    }
  }
  
  // ✅ Obtener resumen de la cola
  static Future<Map<String, dynamic>> getQueueSummary() async {
    try {
      final allItems = await getQueueItems();
      final statistics = await getQueueStatistics();
      
      final pendingCount = statistics[QueueStatus.pending] ?? 0;
      final processingCount = statistics[QueueStatus.processing] ?? 0;
      final failedCount = statistics[QueueStatus.failed] ?? 0;
      final retryingCount = statistics[QueueStatus.retrying] ?? 0;
      final completedCount = statistics[QueueStatus.completed] ?? 0;
      
      final itemsNeedingRetry = allItems.where((item) => item.canRetryNow).length;
      final itemsExhaustedRetries = allItems.where((item) => item.hasExhaustedRetries).length;
      
      return {
        'totalItems': allItems.length,
        'pending': pendingCount,
        'processing': processingCount,
        'failed': failedCount,
        'retrying': retryingCount,
        'completed': completedCount,
        'needingRetry': itemsNeedingRetry,
        'exhaustedRetries': itemsExhaustedRetries,
        'autoRetryActive': _autoRetryTimer?.isActive ?? false,
        'retryConfig': {
          'maxRetries': _retryConfig.maxRetries,
          'initialDelayMinutes': _retryConfig.initialDelay.inMinutes,
          'backoffMultiplier': _retryConfig.backoffMultiplier,
        },
      };
    } catch (e) {
      print('Error obteniendo resumen de la cola: $e');
      return {};
    }
  }
  
  // ✅ Exportar datos de la cola
  static Future<String> exportQueueData() async {
    try {
      final allItems = await getQueueItems();
      final summary = await getQueueSummary();
      
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'summary': summary,
        'items': allItems.map((item) => item.toMap()).toList(),
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print('Error exportando datos de la cola: $e');
      return '{}';
    }
  }
}
