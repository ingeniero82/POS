import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_status.dart';
import '../models/electronic_document.dart';
import '../../../models/client.dart';

class InvoiceStatusService {
  static const String _statusTrackingKey = 'invoice_status_tracking';
  static const String _invoicesKey = 'electronic_invoices';
  
  // ✅ Obtener todas las facturas
  static Future<List<ElectronicDocument>> getAllInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final invoicesJson = prefs.getStringList(_invoicesKey) ?? [];
      
      return invoicesJson
          .map((json) => ElectronicDocument.fromMap(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('Error obteniendo facturas: $e');
      return [];
    }
  }
  
  // ✅ Obtener facturas con filtros
  static Future<List<ElectronicDocument>> getInvoicesWithFilters(
    InvoiceFilterCriteria filters,
  ) async {
    try {
      final allInvoices = await getAllInvoices();
      final filteredInvoices = <ElectronicDocument>[];
      
      for (final invoice in allInvoices) {
        if (_matchesFilters(invoice, filters)) {
          filteredInvoices.add(invoice);
        }
      }
      
      return filteredInvoices;
    } catch (e) {
      print('Error filtrando facturas: $e');
      return [];
    }
  }
  
  // ✅ Obtener seguimiento de estado de una factura
  static Future<List<InvoiceStatusTracking>> getInvoiceStatusHistory(
    String invoiceId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingKey = '${_statusTrackingKey}_$invoiceId';
      final trackingJson = prefs.getStringList(trackingKey) ?? [];
      
      return trackingJson
          .map((json) => InvoiceStatusTracking.fromMap(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Más reciente primero
    } catch (e) {
      print('Error obteniendo historial de estado: $e');
      return [];
    }
  }
  
  // ✅ Obtener estado actual de una factura
  static Future<InvoiceStatus?> getCurrentInvoiceStatus(String invoiceId) async {
    try {
      final history = await getInvoiceStatusHistory(invoiceId);
      if (history.isNotEmpty) {
        return history.first.status;
      }
      return null;
    } catch (e) {
      print('Error obteniendo estado actual: $e');
      return null;
    }
  }
  
  // ✅ Cambiar estado de una factura
  static Future<bool> changeInvoiceStatus({
    required String invoiceId,
    required InvoiceStatus newStatus,
    String? reason,
    String? dianResponse,
    String? userId,
    String? notes,
  }) async {
    try {
      // ✅ Crear nuevo tracking
      final tracking = InvoiceStatusTracking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        invoiceId: invoiceId,
        status: newStatus,
        reason: reason,
        dianResponse: dianResponse,
        timestamp: DateTime.now(),
        userId: userId,
        notes: notes,
      );
      
      // ✅ Guardar en historial
      final history = await getInvoiceStatusHistory(invoiceId);
      history.insert(0, tracking);
      
      final prefs = await SharedPreferences.getInstance();
      final trackingKey = '${_statusTrackingKey}_$invoiceId';
      final trackingJson = history.map((t) => jsonEncode(t.toMap())).toList();
      
      await prefs.setStringList(trackingKey, trackingJson);
      
      // ✅ Actualizar estado en la factura
      await _updateInvoiceStatus(invoiceId, newStatus);
      
      return true;
    } catch (e) {
      print('Error cambiando estado: $e');
      return false;
    }
  }
  
  // ✅ Enviar factura a DIAN (cambiar a ENVIADA)
  static Future<bool> sendInvoiceToDIAN({
    required String invoiceId,
    required String userId,
    String? notes,
  }) async {
    try {
      final currentStatus = await getCurrentInvoiceStatus(invoiceId);
      
      if (currentStatus == null || !currentStatus.canBeSent) {
        print('La factura no puede ser enviada en su estado actual');
        return false;
      }
      
      return await changeInvoiceStatus(
        invoiceId: invoiceId,
        newStatus: InvoiceStatus.sent,
        userId: userId,
        notes: notes ?? 'Enviada a DIAN',
      );
    } catch (e) {
      print('Error enviando factura a DIAN: $e');
      return false;
    }
  }
  
  // ✅ Marcar factura como aceptada por DIAN
  static Future<bool> markInvoiceAsAccepted({
    required String invoiceId,
    required String dianResponse,
    String? userId,
    String? notes,
  }) async {
    try {
      return await changeInvoiceStatus(
        invoiceId: invoiceId,
        newStatus: InvoiceStatus.accepted,
        dianResponse: dianResponse,
        userId: userId,
        notes: notes ?? 'Aceptada por DIAN',
      );
    } catch (e) {
      print('Error marcando factura como aceptada: $e');
      return false;
    }
  }
  
  // ✅ Marcar factura como rechazada por DIAN
  static Future<bool> markInvoiceAsRejected({
    required String invoiceId,
    required String reason,
    required String dianResponse,
    String? userId,
    String? notes,
  }) async {
    try {
      return await changeInvoiceStatus(
        invoiceId: invoiceId,
        newStatus: InvoiceStatus.rejected,
        reason: reason,
        dianResponse: dianResponse,
        userId: userId,
        notes: notes ?? 'Rechazada por DIAN',
      );
    } catch (e) {
      print('Error marcando factura como rechazada: $e');
      return false;
    }
  }
  
  // ✅ Anular factura
  static Future<bool> cancelInvoice({
    required String invoiceId,
    required String reason,
    String? userId,
    String? notes,
  }) async {
    try {
      final currentStatus = await getCurrentInvoiceStatus(invoiceId);
      
      if (currentStatus == null || !currentStatus.canBeCancelled) {
        print('La factura no puede ser anulada en su estado actual');
        return false;
      }
      
      return await changeInvoiceStatus(
        invoiceId: invoiceId,
        newStatus: InvoiceStatus.cancelled,
        reason: reason,
        userId: userId,
        notes: notes ?? 'Factura anulada',
      );
    } catch (e) {
      print('Error anulando factura: $e');
      return false;
    }
  }
  
  // ✅ Obtener estadísticas de estados
  static Future<Map<InvoiceStatus, int>> getStatusStatistics() async {
    try {
      final allInvoices = await getAllInvoices();
      final statistics = <InvoiceStatus, int>{};
      
      // ✅ Inicializar contadores
      for (final status in InvoiceStatus.values) {
        statistics[status] = 0;
      }
      
      // ✅ Contar facturas por estado
      for (final invoice in allInvoices) {
        final status = await getCurrentInvoiceStatus(invoice.id?.toString() ?? '');
        if (status != null) {
          statistics[status] = (statistics[status] ?? 0) + 1;
        }
      }
      
      return statistics;
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }
  
  // ✅ Obtener facturas que requieren acción
  static Future<List<ElectronicDocument>> getInvoicesRequiringAction() async {
    try {
      final allInvoices = await getAllInvoices();
      final actionRequired = <ElectronicDocument>[];
      
      for (final invoice in allInvoices) {
        final status = await getCurrentInvoiceStatus(invoice.id?.toString() ?? '');
        if (status != null && status.requiresAction) {
          actionRequired.add(invoice);
        }
      }
      
      return actionRequired;
    } catch (e) {
      print('Error obteniendo facturas que requieren acción: $e');
      return [];
    }
  }
  
  // ✅ Obtener facturas recientes (últimas 24 horas)
  static Future<List<ElectronicDocument>> getRecentInvoices() async {
    try {
      final allInvoices = await getAllInvoices();
      final recent = <ElectronicDocument>[];
      final now = DateTime.now();
      
      for (final invoice in allInvoices) {
        final difference = now.difference(invoice.createdAt);
        if (difference.inHours < 24) {
          recent.add(invoice);
        }
      }
      
      return recent;
    } catch (e) {
      print('Error obteniendo facturas recientes: $e');
      return [];
    }
  }
  
  // ✅ Buscar facturas por texto
  static Future<List<ElectronicDocument>> searchInvoices(String searchTerm) async {
    try {
      final allInvoices = await getAllInvoices();
      final results = <ElectronicDocument>[];
      final term = searchTerm.toLowerCase();
      
      for (final invoice in allInvoices) {
        // ✅ Buscar en número de documento
        if (invoice.documentNumber.toLowerCase().contains(term)) {
          results.add(invoice);
          continue;
        }
        
        // ✅ Buscar en observaciones
        if (invoice.observations?.toLowerCase().contains(term) ?? false) {
          results.add(invoice);
          continue;
        }
        
        // ✅ Buscar en estado
        final status = await getCurrentInvoiceStatus(invoice.id?.toString() ?? '');
        if (status?.description.toLowerCase().contains(term) ?? false) {
          results.add(invoice);
          continue;
        }
      }
      
      return results;
    } catch (e) {
      print('Error buscando facturas: $e');
      return [];
    }
  }
  
  // ✅ Métodos auxiliares
  
  // ✅ Verificar si una factura coincide con los filtros
  static bool _matchesFilters(
    ElectronicDocument invoice,
    InvoiceFilterCriteria filters,
  ) {
    // ✅ Filtro por estado
    if (filters.status != null) {
      // Aquí necesitaríamos obtener el estado actual de la factura
      // Por ahora lo omitimos para evitar complejidad
    }
    
    // ✅ Filtro por fecha de inicio
    if (filters.startDate != null) {
      if (invoice.createdAt.isBefore(filters.startDate!)) {
        return false;
      }
    }
    
    // ✅ Filtro por fecha de fin
    if (filters.endDate != null) {
      if (invoice.createdAt.isAfter(filters.endDate!)) {
        return false;
      }
    }
    
    // ✅ Filtro por cliente
    if (filters.clientId != null) {
      if (invoice.clientDocumentNumber != filters.clientId) {
        return false;
      }
    }
    
    // ✅ Filtro por número de documento
    if (filters.documentNumber != null) {
      if (!invoice.documentNumber.toLowerCase().contains(
        filters.documentNumber!.toLowerCase(),
      )) {
        return false;
      }
    }
    
    // ✅ Filtro por usuario (por ahora omitido ya que no existe en el modelo)
    // if (filters.userId != null) {
    //   if (invoice.userId != filters.userId) {
    //     return false;
    //   }
    // }
    
    // ✅ Filtro por recientes
    if (filters.isRecent == true) {
      final now = DateTime.now();
      final difference = now.difference(invoice.createdAt);
      if (difference.inHours >= 24) {
        return false;
      }
    }
    
    return true;
  }
  
  // ✅ Actualizar estado en la factura
  static Future<bool> _updateInvoiceStatus(
    String invoiceId,
    InvoiceStatus newStatus,
  ) async {
    try {
      final allInvoices = await getAllInvoices();
      final invoiceIndex = allInvoices.indexWhere((inv) => inv.id == invoiceId);
      
      if (invoiceIndex == -1) {
        return false;
      }
      
      // ✅ Actualizar estado de la factura
      final updatedInvoice = allInvoices[invoiceIndex].copyWith(
        status: newStatus.code,
        updatedAt: DateTime.now(),
      );
      
      allInvoices[invoiceIndex] = updatedInvoice;
      
      // ✅ Guardar facturas actualizadas
      final prefs = await SharedPreferences.getInstance();
      final invoicesJson = allInvoices
          .map((inv) => jsonEncode(inv.toMap()))
          .toList();
      
      await prefs.setStringList(_invoicesKey, invoicesJson);
      
      return true;
    } catch (e) {
      print('Error actualizando estado en factura: $e');
      return false;
    }
  }
  
  // ✅ Limpiar datos de seguimiento
  static Future<bool> clearStatusTracking(String invoiceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingKey = '${_statusTrackingKey}_$invoiceId';
      await prefs.remove(trackingKey);
      return true;
    } catch (e) {
      print('Error limpiando seguimiento: $e');
      return false;
    }
  }
  
  // ✅ Exportar historial de estado
  static Future<String> exportStatusHistory(String invoiceId) async {
    try {
      final history = await getInvoiceStatusHistory(invoiceId);
      final exportData = {
        'invoiceId': invoiceId,
        'exportDate': DateTime.now().toIso8601String(),
        'history': history.map((h) => h.toMap()).toList(),
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print('Error exportando historial: $e');
      return '{}';
    }
  }
}
