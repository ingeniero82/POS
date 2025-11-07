import 'package:flutter/foundation.dart';

// ✅ Tipos de acciones auditables
enum AuditActionType {
  // ✅ Configuración del sistema
  systemConfigCreated('CREATED', 'Configuración creada'),
  systemConfigUpdated('UPDATED', 'Configuración actualizada'),
  systemConfigDeleted('DELETED', 'Configuración eliminada'),
  
  // ✅ Facturas
  invoiceCreated('CREATED', 'Factura creada'),
  invoiceUpdated('UPDATED', 'Factura actualizada'),
  invoiceDeleted('DELETED', 'Factura eliminada'),
  invoiceGenerated('GENERATED', 'Documentos generados'),
  invoiceSent('SENT', 'Factura enviada a DIAN'),
  invoiceRejected('REJECTED', 'Factura rechazada por DIAN'),
  
  // ✅ Cola de pendientes
  queueItemAdded('ADDED', 'Item agregado a cola'),
  queueItemRetried('RETRIED', 'Reintento de envío'),
  queueItemCompleted('COMPLETED', 'Item completado'),
  queueItemRemoved('REMOVED', 'Item removido de cola'),
  
  // ✅ Acceso y seguridad
  userLogin('LOGIN', 'Usuario autenticado'),
  userLogout('LOGOUT', 'Usuario desconectado'),
  accessDenied('ACCESS_DENIED', 'Acceso denegado'),
  permissionChanged('PERMISSION_CHANGED', 'Permisos modificados'),
  
  // ✅ Respaldos
  backupCreated('BACKUP_CREATED', 'Respaldo creado'),
  backupRestored('BACKUP_RESTORED', 'Respaldo restaurado'),
  backupFailed('BACKUP_FAILED', 'Error en respaldo'),
  
  // ✅ Certificados
  certificateInstalled('INSTALLED', 'Certificado instalado'),
  certificateExpired('EXPIRED', 'Certificado expirado'),
  certificateRevoked('REVOKED', 'Certificado revocado');

  const AuditActionType(this.code, this.description);

  final String code;
  final String description;

  // ✅ Obtener tipo desde código
  static AuditActionType fromCode(String code) {
    return AuditActionType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => AuditActionType.invoiceCreated,
    );
  }

  // ✅ Obtener nivel de seguridad
  String get securityLevel {
    switch (this) {
      case AuditActionType.systemConfigCreated:
      case AuditActionType.systemConfigUpdated:
      case AuditActionType.systemConfigDeleted:
      case AuditActionType.permissionChanged:
      case AuditActionType.certificateInstalled:
      case AuditActionType.certificateExpired:
      case AuditActionType.certificateRevoked:
        return 'HIGH';
      case AuditActionType.invoiceCreated:
      case AuditActionType.invoiceUpdated:
      case AuditActionType.invoiceDeleted:
      case AuditActionType.invoiceGenerated:
      case AuditActionType.invoiceSent:
      case AuditActionType.invoiceRejected:
        return 'MEDIUM';
      case AuditActionType.queueItemAdded:
      case AuditActionType.queueItemRetried:
      case AuditActionType.queueItemCompleted:
      case AuditActionType.queueItemRemoved:
      case AuditActionType.backupCreated:
      case AuditActionType.backupRestored:
      case AuditActionType.backupFailed:
        return 'LOW';
      case AuditActionType.userLogin:
      case AuditActionType.userLogout:
      case AuditActionType.accessDenied:
        return 'INFO';
    }
  }

  // ✅ Verificar si requiere notificación
  bool get requiresNotification {
    return securityLevel == 'HIGH' || 
           this == AuditActionType.accessDenied ||
           this == AuditActionType.invoiceRejected ||
           this == AuditActionType.certificateExpired ||
           this == AuditActionType.certificateRevoked;
  }
}

// ✅ Entrada del log de auditoría
class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String userEmail;
  final AuditActionType actionType;
  final String resourceType;
  final String resourceId;
  final String resourceName;
  final String? description;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final bool success;
  final String? errorMessage;
  final String? stackTrace;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.actionType,
    required this.resourceType,
    required this.resourceId,
    required this.resourceName,
    this.description,
    this.details,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    required this.success,
    this.errorMessage,
    this.stackTrace,
  });

  // ✅ Factory constructor desde Map
  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      userEmail: map['user_email'] ?? '',
      actionType: AuditActionType.fromCode(map['action_type'] ?? ''),
      resourceType: map['resource_type'] ?? '',
      resourceId: map['resource_id'] ?? '',
      resourceName: map['resource_name'] ?? '',
      description: map['description'],
      details: map['details'] != null 
          ? Map<String, dynamic>.from(map['details'])
          : null,
      ipAddress: map['ip_address'],
      userAgent: map['user_agent'],
      sessionId: map['session_id'],
      success: map['success'] ?? false,
      errorMessage: map['error_message'],
      stackTrace: map['stack_trace'],
    );
  }

  // ✅ Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'action_type': actionType.code,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'resource_name': resourceName,
      'description': description,
      'details': details,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'session_id': sessionId,
      'success': success,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
    };
  }

  // ✅ Copiar con cambios
  AuditLogEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? userId,
    String? userName,
    String? userEmail,
    AuditActionType? actionType,
    String? resourceType,
    String? resourceId,
    String? resourceName,
    String? description,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    bool? success,
    String? errorMessage,
    String? stackTrace,
  }) {
    return AuditLogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      actionType: actionType ?? this.actionType,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      resourceName: resourceName ?? this.resourceName,
      description: description ?? this.description,
      details: details ?? this.details,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      sessionId: sessionId ?? this.sessionId,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  // ✅ Obtener resumen de la entrada
  String get summary {
    final action = actionType.description;
    final resource = '$resourceType: $resourceName';
    final status = success ? '✅' : '❌';
    
    if (errorMessage != null) {
      return '$status $action - $resource - Error: $errorMessage';
    }
    
    return '$status $action - $resource';
  }

  // ✅ Obtener nivel de seguridad como texto
  String get securityLevelText => actionType.securityLevel;

  // ✅ Verificar si requiere notificación
  bool get requiresNotification => actionType.requiresNotification;

  // ✅ Obtener tiempo transcurrido
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} día(s)';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hora(s)';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuto(s)';
    } else {
      return '${difference.inSeconds} segundo(s)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuditLogEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AuditLogEntry(id: $id, action: ${actionType.description}, resource: $resourceName, success: $success)';
  }
}

// ✅ Filtros para búsqueda de auditoría
class AuditFilterCriteria {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? userId;
  final String? userName;
  final AuditActionType? actionType;
  final String? resourceType;
  final String? resourceId;
  final bool? success;
  final String? securityLevel;
  final String? searchTerm;

  const AuditFilterCriteria({
    this.startDate,
    this.endDate,
    this.userId,
    this.userName,
    this.actionType,
    this.resourceType,
    this.resourceId,
    this.success,
    this.securityLevel,
    this.searchTerm,
  });

  // ✅ Convertir a Map para consultas
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (startDate != null) map['start_date'] = startDate!.toIso8601String();
    if (endDate != null) map['end_date'] = endDate!.toIso8601String();
    if (userId != null) map['user_id'] = userId;
    if (userName != null) map['user_name'] = userName;
    if (actionType != null) map['action_type'] = actionType!.code;
    if (resourceType != null) map['resource_type'] = resourceType;
    if (resourceId != null) map['resource_id'] = resourceId;
    if (success != null) map['success'] = success;
    if (securityLevel != null) map['security_level'] = securityLevel;
    if (searchTerm != null) map['search_term'] = searchTerm;
    
    return map;
  }

  // ✅ Verificar si hay filtros activos
  bool get hasActiveFilters {
    return startDate != null ||
           endDate != null ||
           userId != null ||
           userName != null ||
           actionType != null ||
           resourceType != null ||
           resourceId != null ||
           success != null ||
           securityLevel != null ||
           searchTerm != null;
  }

  // ✅ Obtener descripción de filtros
  String get filtersDescription {
    if (!hasActiveFilters) return 'Sin filtros';

    final filters = <String>[];
    
    if (startDate != null) filters.add('Desde: ${_formatDate(startDate!)}');
    if (endDate != null) filters.add('Hasta: ${_formatDate(endDate!)}');
    if (userId != null) filters.add('Usuario ID: $userId');
    if (userName != null) filters.add('Usuario: $userName');
    if (actionType != null) filters.add('Acción: ${actionType!.description}');
    if (resourceType != null) filters.add('Recurso: $resourceType');
    if (resourceId != null) filters.add('ID Recurso: $resourceId');
    if (success != null) filters.add('Éxito: ${success! ? 'Sí' : 'No'}');
    if (securityLevel != null) filters.add('Nivel: $securityLevel');
    if (searchTerm != null) filters.add('Búsqueda: $searchTerm');
    
    return filters.join(' | ');
  }

  // ✅ Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
