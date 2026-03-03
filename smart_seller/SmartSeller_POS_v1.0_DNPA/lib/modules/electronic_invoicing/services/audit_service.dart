import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log.dart';

class AuditService {
  static const String _auditLogKey = 'audit_log_entries';
  static const String _maxEntriesKey = 'audit_max_entries';
  static const String _retentionDaysKey = 'audit_retention_days';
  
  // ✅ Configuración por defecto
  static const int _defaultMaxEntries = 10000;
  static const int _defaultRetentionDays = 365;

  // ✅ Registrar acción de auditoría
  static Future<bool> logAction({
    required String userId,
    required String userName,
    required String userEmail,
    required AuditActionType actionType,
    required String resourceType,
    required String resourceId,
    required String resourceName,
    String? description,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    bool success = true,
    String? errorMessage,
    String? stackTrace,
  }) async {
    try {
      final entry = AuditLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        actionType: actionType,
        resourceType: resourceType,
        resourceId: resourceId,
        resourceName: resourceName,
        description: description,
        details: details,
        ipAddress: ipAddress,
        userAgent: userAgent,
        sessionId: sessionId,
        success: success,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
      );

      // ✅ Agregar entrada al log
      await _addEntry(entry);

      // ✅ Limpiar entradas antiguas
      await _cleanupOldEntries();

      // ✅ Verificar si requiere notificación
      if (entry.requiresNotification) {
        await _notifySecurityEvent(entry);
      }

      return true;
    } catch (e) {
      print('Error registrando acción de auditoría: $e');
      return false;
    }
  }

  // ✅ Agregar entrada al log
  static Future<void> _addEntry(AuditLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList(_auditLogKey) ?? [];
      
      // ✅ Agregar nueva entrada
      entriesJson.add(jsonEncode(entry.toMap()));
      
      // ✅ Obtener límite de entradas
      final maxEntries = prefs.getInt(_maxEntriesKey) ?? _defaultMaxEntries;
      
      // ✅ Si excede el límite, remover las más antiguas
      if (entriesJson.length > maxEntries) {
        final excess = entriesJson.length - maxEntries;
        entriesJson.removeRange(0, excess);
      }
      
      await prefs.setStringList(_auditLogKey, entriesJson);
    } catch (e) {
      print('Error agregando entrada de auditoría: $e');
    }
  }

  // ✅ Limpiar entradas antiguas
  static Future<void> _cleanupOldEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final retentionDays = prefs.getInt(_retentionDaysKey) ?? _defaultRetentionDays;
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      
      final entriesJson = prefs.getStringList(_auditLogKey) ?? [];
      final validEntries = <String>[];
      
      for (final entryJson in entriesJson) {
        try {
          final entry = AuditLogEntry.fromMap(jsonDecode(entryJson));
          if (entry.timestamp.isAfter(cutoffDate)) {
            validEntries.add(entryJson);
          }
        } catch (e) {
          // ✅ Si hay error parseando, mantener la entrada
          validEntries.add(entryJson);
        }
      }
      
      if (validEntries.length != entriesJson.length) {
        await prefs.setStringList(_auditLogKey, validEntries);
        print('🧹 Limpieza de auditoría: ${entriesJson.length - validEntries.length} entradas removidas');
      }
    } catch (e) {
      print('Error limpiando entradas antiguas: $e');
    }
  }

  // ✅ Obtener todas las entradas del log
  static Future<List<AuditLogEntry>> getAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList(_auditLogKey) ?? [];
      
      return entriesJson
          .map((json) => AuditLogEntry.fromMap(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Más reciente primero
    } catch (e) {
      print('Error obteniendo log de auditoría: $e');
      return [];
    }
  }

  // ✅ Obtener entradas filtradas
  static Future<List<AuditLogEntry>> getFilteredAuditLog(AuditFilterCriteria criteria) async {
    try {
      final allEntries = await getAuditLog();
      final filteredEntries = <AuditLogEntry>[];
      
      for (final entry in allEntries) {
        if (_matchesCriteria(entry, criteria)) {
          filteredEntries.add(entry);
        }
      }
      
      return filteredEntries;
    } catch (e) {
      print('Error filtrando log de auditoría: $e');
      return [];
    }
  }

  // ✅ Verificar si una entrada coincide con los criterios
  static bool _matchesCriteria(AuditLogEntry entry, AuditFilterCriteria criteria) {
    // ✅ Filtro por fecha
    if (criteria.startDate != null && entry.timestamp.isBefore(criteria.startDate!)) {
      return false;
    }
    if (criteria.endDate != null && entry.timestamp.isAfter(criteria.endDate!)) {
      return false;
    }
    
    // ✅ Filtro por usuario
    if (criteria.userId != null && entry.userId != criteria.userId) {
      return false;
    }
    if (criteria.userName != null && !entry.userName.toLowerCase().contains(criteria.userName!.toLowerCase())) {
      return false;
    }
    
    // ✅ Filtro por tipo de acción
    if (criteria.actionType != null && entry.actionType != criteria.actionType) {
      return false;
    }
    
    // ✅ Filtro por tipo de recurso
    if (criteria.resourceType != null && entry.resourceType != criteria.resourceType) {
      return false;
    }
    
    // ✅ Filtro por ID de recurso
    if (criteria.resourceId != null && entry.resourceId != criteria.resourceId) {
      return false;
    }
    
    // ✅ Filtro por éxito
    if (criteria.success != null && entry.success != criteria.success) {
      return false;
    }
    
    // ✅ Filtro por nivel de seguridad
    if (criteria.securityLevel != null && entry.securityLevelText != criteria.securityLevel) {
      return false;
    }
    
    // ✅ Filtro por término de búsqueda
    if (criteria.searchTerm != null && criteria.searchTerm!.isNotEmpty) {
      final term = criteria.searchTerm!.toLowerCase();
      final matches = entry.userName.toLowerCase().contains(term) ||
                     entry.resourceName.toLowerCase().contains(term) ||
                     entry.description?.toLowerCase().contains(term) == true ||
                     entry.actionType.description.toLowerCase().contains(term);
      
      if (!matches) return false;
    }
    
    return true;
  }

  // ✅ Obtener estadísticas del log
  static Future<Map<String, dynamic>> getAuditStatistics() async {
    try {
      final allEntries = await getAuditLog();
      final statistics = <String, dynamic>{};
      
      // ✅ Contadores por tipo de acción
      final actionCounts = <String, int>{};
      for (final entry in allEntries) {
        final actionType = entry.actionType.code;
        actionCounts[actionType] = (actionCounts[actionType] ?? 0) + 1;
      }
      statistics['actionCounts'] = actionCounts;
      
      // ✅ Contadores por nivel de seguridad
      final securityCounts = <String, int>{};
      for (final entry in allEntries) {
        final level = entry.securityLevelText;
        securityCounts[level] = (securityCounts[level] ?? 0) + 1;
      }
      statistics['securityCounts'] = securityCounts;
      
      // ✅ Contadores por éxito/fallo
      int successCount = 0;
      int failureCount = 0;
      for (final entry in allEntries) {
        if (entry.success) {
          successCount++;
        } else {
          failureCount++;
        }
      }
      statistics['successCount'] = successCount;
      statistics['failureCount'] = failureCount;
      
      // ✅ Contadores por usuario
      final userCounts = <String, int>{};
      for (final entry in allEntries) {
        final user = entry.userName;
        userCounts[user] = (userCounts[user] ?? 0) + 1;
      }
      statistics['userCounts'] = userCounts;
      
      // ✅ Contadores por recurso
      final resourceCounts = <String, int>{};
      for (final entry in allEntries) {
        final resource = entry.resourceType;
        resourceCounts[resource] = (resourceCounts[resource] ?? 0) + 1;
      }
      statistics['resourceCounts'] = resourceCounts;
      
      // ✅ Información general
      statistics['totalEntries'] = allEntries.length;
      statistics['oldestEntry'] = allEntries.isNotEmpty ? allEntries.last.timestamp.toIso8601String() : null;
      statistics['newestEntry'] = allEntries.isNotEmpty ? allEntries.first.timestamp.toIso8601String() : null;
      
      // ✅ Entradas que requieren notificación
      final notificationEntries = allEntries.where((entry) => entry.requiresNotification).length;
      statistics['notificationEntries'] = notificationEntries;
      
      return statistics;
    } catch (e) {
      print('Error obteniendo estadísticas de auditoría: $e');
      return {};
    }
  }

  // ✅ Buscar entradas por texto
  static Future<List<AuditLogEntry>> searchAuditLog(String searchTerm) async {
    try {
      final allEntries = await getAuditLog();
      final term = searchTerm.toLowerCase();
      
      return allEntries.where((entry) {
        return entry.userName.toLowerCase().contains(term) ||
               entry.resourceName.toLowerCase().contains(term) ||
               entry.description?.toLowerCase().contains(term) == true ||
               entry.actionType.description.toLowerCase().contains(term) ||
               entry.userEmail.toLowerCase().contains(term) ||
               entry.resourceType.toLowerCase().contains(term) ||
               entry.resourceId.toLowerCase().contains(term);
      }).toList();
    } catch (e) {
      print('Error buscando en log de auditoría: $e');
      return [];
    }
  }

  // ✅ Obtener entradas recientes
  static Future<List<AuditLogEntry>> getRecentEntries({int limit = 50}) async {
    try {
      final allEntries = await getAuditLog();
      return allEntries.take(limit).toList();
    } catch (e) {
      print('Error obteniendo entradas recientes: $e');
      return [];
    }
  }

  // ✅ Obtener entradas por usuario
  static Future<List<AuditLogEntry>> getEntriesByUser(String userId) async {
    try {
      final allEntries = await getAuditLog();
      return allEntries.where((entry) => entry.userId == userId).toList();
    } catch (e) {
      print('Error obteniendo entradas por usuario: $e');
      return [];
    }
  }

  // ✅ Obtener entradas por recurso
  static Future<List<AuditLogEntry>> getEntriesByResource(String resourceType, String resourceId) async {
    try {
      final allEntries = await getAuditLog();
      return allEntries.where((entry) => 
        entry.resourceType == resourceType && entry.resourceId == resourceId
      ).toList();
    } catch (e) {
      print('Error obteniendo entradas por recurso: $e');
      return [];
    }
  }

  // ✅ Obtener entradas de alto nivel de seguridad
  static Future<List<AuditLogEntry>> getHighSecurityEntries() async {
    try {
      final allEntries = await getAuditLog();
      return allEntries.where((entry) => entry.securityLevelText == 'HIGH').toList();
    } catch (e) {
      print('Error obteniendo entradas de alto nivel de seguridad: $e');
      return [];
    }
  }

  // ✅ Obtener entradas que requieren notificación
  static Future<List<AuditLogEntry>> getNotificationEntries() async {
    try {
      final allEntries = await getAuditLog();
      return allEntries.where((entry) => entry.requiresNotification).toList();
    } catch (e) {
      print('Error obteniendo entradas que requieren notificación: $e');
      return [];
    }
  }

  // ✅ Configurar parámetros del log
  static Future<bool> configureLog({
    int? maxEntries,
    int? retentionDays,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (maxEntries != null) {
        await prefs.setInt(_maxEntriesKey, maxEntries);
      }
      
      if (retentionDays != null) {
        await prefs.setInt(_retentionDaysKey, retentionDays);
      }
      
      return true;
    } catch (e) {
      print('Error configurando log de auditoría: $e');
      return false;
    }
  }

  // ✅ Obtener configuración del log
  static Future<Map<String, dynamic>> getLogConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'maxEntries': prefs.getInt(_maxEntriesKey) ?? _defaultMaxEntries,
        'retentionDays': prefs.getInt(_retentionDaysKey) ?? _defaultRetentionDays,
      };
    } catch (e) {
      print('Error obteniendo configuración del log: $e');
      return {
        'maxEntries': _defaultMaxEntries,
        'retentionDays': _defaultRetentionDays,
      };
    }
  }

  // ✅ Exportar log de auditoría
  static Future<String> exportAuditLog() async {
    try {
      final allEntries = await getAuditLog();
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalEntries': allEntries.length,
        'entries': allEntries.map((entry) => entry.toMap()).toList(),
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print('Error exportando log de auditoría: $e');
      return '{}';
    }
  }

  // ✅ Limpiar log completo
  static Future<bool> clearAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_auditLogKey);
      return true;
    } catch (e) {
      print('Error limpiando log de auditoría: $e');
      return false;
    }
  }

  // ✅ Notificar evento de seguridad
  static Future<void> _notifySecurityEvent(AuditLogEntry entry) async {
    try {
      // ✅ Por ahora solo imprimimos en consola
      // En una implementación real, aquí se enviarían notificaciones
      print('🚨 EVENTO DE SEGURIDAD DETECTADO:');
      print('   Acción: ${entry.actionType.description}');
      print('   Usuario: ${entry.userName} (${entry.userEmail})');
      print('   Recurso: ${entry.resourceType} - ${entry.resourceName}');
      print('   Éxito: ${entry.success}');
      if (entry.errorMessage != null) {
        print('   Error: ${entry.errorMessage}');
      }
      print('   Nivel: ${entry.securityLevelText}');
      print('   Timestamp: ${entry.timestamp}');
      print('   ---');
    } catch (e) {
      print('Error notificando evento de seguridad: $e');
    }
  }

  // ✅ Métodos de conveniencia para acciones comunes
  
  // ✅ Registrar cambio en configuración del sistema
  static Future<bool> logSystemConfigChange({
    required String userId,
    required String userName,
    required String userEmail,
    required String configName,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    bool success = true,
    String? errorMessage,
  }) {
    return logAction(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      actionType: action == 'created' ? AuditActionType.systemConfigCreated :
                 action == 'updated' ? AuditActionType.systemConfigUpdated :
                 AuditActionType.systemConfigDeleted,
      resourceType: 'SystemConfiguration',
      resourceId: configName,
      resourceName: configName,
      description: 'Configuración del sistema $action',
      details: {
        'action': action,
        'oldValues': oldValues,
        'newValues': newValues,
      },
      success: success,
      errorMessage: errorMessage,
    );
  }

  // ✅ Registrar operación de factura
  static Future<bool> logInvoiceOperation({
    required String userId,
    required String userName,
    required String userEmail,
    required String action,
    required String invoiceNumber,
    Map<String, dynamic>? details,
    bool success = true,
    String? errorMessage,
  }) {
    AuditActionType actionType;
    switch (action) {
      case 'created':
        actionType = AuditActionType.invoiceCreated;
        break;
      case 'updated':
        actionType = AuditActionType.invoiceUpdated;
        break;
      case 'deleted':
        actionType = AuditActionType.invoiceDeleted;
        break;
      case 'generated':
        actionType = AuditActionType.invoiceGenerated;
        break;
      case 'sent':
        actionType = AuditActionType.invoiceSent;
        break;
      case 'rejected':
        actionType = AuditActionType.invoiceRejected;
        break;
      default:
        actionType = AuditActionType.invoiceUpdated;
    }

    return logAction(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      actionType: actionType,
      resourceType: 'Invoice',
      resourceId: invoiceNumber,
      resourceName: 'Factura $invoiceNumber',
      description: 'Factura $action',
      details: details,
      success: success,
      errorMessage: errorMessage,
    );
  }

  // ✅ Registrar operación de cola de pendientes
  static Future<bool> logQueueOperation({
    required String userId,
    required String userName,
    required String userEmail,
    required String action,
    required String invoiceNumber,
    Map<String, dynamic>? details,
    bool success = true,
    String? errorMessage,
  }) {
    AuditActionType actionType;
    switch (action) {
      case 'added':
        actionType = AuditActionType.queueItemAdded;
        break;
      case 'retried':
        actionType = AuditActionType.queueItemRetried;
        break;
      case 'completed':
        actionType = AuditActionType.queueItemCompleted;
        break;
      case 'removed':
        actionType = AuditActionType.queueItemRemoved;
        break;
      default:
        actionType = AuditActionType.queueItemAdded;
    }

    return logAction(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      actionType: actionType,
      resourceType: 'QueueItem',
      resourceId: invoiceNumber,
      resourceName: 'Item de cola $invoiceNumber',
      description: 'Item de cola $action',
      details: details,
      success: success,
      errorMessage: errorMessage,
    );
  }

  // ✅ Registrar acceso denegado
  static Future<bool> logAccessDenied({
    required String userId,
    required String userName,
    required String userEmail,
    required String resourceType,
    required String resourceName,
    String? reason,
    String? ipAddress,
    String? userAgent,
  }) {
    return logAction(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      actionType: AuditActionType.accessDenied,
      resourceType: resourceType,
      resourceId: resourceName,
      resourceName: resourceName,
      description: 'Acceso denegado${reason != null ? ': $reason' : ''}',
      ipAddress: ipAddress,
      userAgent: userAgent,
      success: false,
      errorMessage: 'Acceso denegado',
    );
  }
}
