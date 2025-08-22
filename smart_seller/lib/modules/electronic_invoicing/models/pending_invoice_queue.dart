import 'package:flutter/foundation.dart';
import 'dart:math';

// ✅ Estado de la cola de pendientes
enum QueueStatus {
  pending('PENDIENTE', 'Pendiente de envío'),
  processing('PROCESANDO', 'En proceso de envío'),
  failed('FALLIDO', 'Error en el envío'),
  retrying('REINTENTANDO', 'Reintentando envío'),
  completed('COMPLETADO', 'Envío exitoso');

  const QueueStatus(this.code, this.description);

  final String code;
  final String description;

  // ✅ Obtener estado desde código
  static QueueStatus fromCode(String code) {
    return QueueStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => QueueStatus.pending,
    );
  }

  // ✅ Obtener color del estado
  String get color {
    switch (this) {
      case QueueStatus.pending:
        return 'orange';
      case QueueStatus.processing:
        return 'blue';
      case QueueStatus.failed:
        return 'red';
      case QueueStatus.retrying:
        return 'yellow';
      case QueueStatus.completed:
        return 'green';
    }
  }

  // ✅ Obtener icono del estado
  String get icon {
    switch (this) {
      case QueueStatus.pending:
        return 'schedule';
      case QueueStatus.processing:
        return 'sync';
      case QueueStatus.failed:
        return 'error';
      case QueueStatus.retrying:
        return 'refresh';
      case QueueStatus.completed:
        return 'check_circle';
    }
  }

  // ✅ Verificar si se puede reintentar
  bool get canRetry => this == QueueStatus.failed;

  // ✅ Verificar si está en proceso
  bool get isProcessing => this == QueueStatus.processing || this == QueueStatus.retrying;

  // ✅ Verificar si está completado
  bool get isCompleted => this == QueueStatus.completed;
}

// ✅ Item en la cola de pendientes
class PendingInvoiceItem {
  final String id;
  final String invoiceId;
  final String documentNumber;
  final String clientName;
  final DateTime createdAt;
  final DateTime lastAttempt;
  final int attemptCount;
  final int maxRetries;
  final QueueStatus status;
  final String? lastError;
  final String? errorDetails;
  final Map<String, dynamic>? retryData;
  final DateTime? nextRetryAt;
  final String? userId;

  const PendingInvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.documentNumber,
    required this.clientName,
    required this.createdAt,
    required this.lastAttempt,
    required this.attemptCount,
    this.maxRetries = 3,
    this.status = QueueStatus.pending,
    this.lastError,
    this.errorDetails,
    this.retryData,
    this.nextRetryAt,
    this.userId,
  });

  // ✅ Factory constructor desde Map
  factory PendingInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PendingInvoiceItem(
      id: map['id'] ?? '',
      invoiceId: map['invoice_id'] ?? '',
      documentNumber: map['document_number'] ?? '',
      clientName: map['client_name'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      lastAttempt: DateTime.tryParse(map['last_attempt'] ?? '') ?? DateTime.now(),
      attemptCount: map['attempt_count'] ?? 0,
      maxRetries: map['max_retries'] ?? 3,
      status: QueueStatus.fromCode(map['status'] ?? 'PENDIENTE'),
      lastError: map['last_error'],
      errorDetails: map['error_details'],
      retryData: map['retry_data'] != null 
          ? Map<String, dynamic>.from(map['retry_data'])
          : null,
      nextRetryAt: map['next_retry_at'] != null 
          ? DateTime.tryParse(map['next_retry_at'])
          : null,
      userId: map['user_id'],
    );
  }

  // ✅ Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'document_number': documentNumber,
      'client_name': clientName,
      'created_at': createdAt.toIso8601String(),
      'last_attempt': lastAttempt.toIso8601String(),
      'attempt_count': attemptCount,
      'max_retries': maxRetries,
      'status': status.code,
      'last_error': lastError,
      'error_details': errorDetails,
      'retry_data': retryData,
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'user_id': userId,
    };
  }

  // ✅ Copiar con cambios
  PendingInvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? documentNumber,
    String? clientName,
    DateTime? createdAt,
    DateTime? lastAttempt,
    int? attemptCount,
    int? maxRetries,
    QueueStatus? status,
    String? lastError,
    String? errorDetails,
    Map<String, dynamic>? retryData,
    DateTime? nextRetryAt,
    String? userId,
  }) {
    return PendingInvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      documentNumber: documentNumber ?? this.documentNumber,
      clientName: clientName ?? this.clientName,
      createdAt: createdAt ?? this.createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      attemptCount: attemptCount ?? this.attemptCount,
      maxRetries: maxRetries ?? this.maxRetries,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      errorDetails: errorDetails ?? this.errorDetails,
      retryData: retryData ?? this.retryData,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      userId: userId ?? this.userId,
    );
  }

  // ✅ Verificar si se puede reintentar
  bool get canRetryNow {
    if (!status.canRetry) return false;
    if (attemptCount >= maxRetries) return false;
    if (nextRetryAt != null && DateTime.now().isBefore(nextRetryAt!)) return false;
    return true;
  }

  // ✅ Verificar si se agotaron los reintentos
  bool get hasExhaustedRetries => attemptCount >= maxRetries;

  // ✅ Obtener tiempo transcurrido desde el último intento
  String get timeSinceLastAttempt {
    final now = DateTime.now();
    final difference = now.difference(lastAttempt);

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

  // ✅ Obtener tiempo hasta el próximo reintento
  String get timeUntilNextRetry {
    if (nextRetryAt == null) return 'Inmediato';
    
    final now = DateTime.now();
    if (now.isAfter(nextRetryAt!)) return 'Inmediato';
    
    final difference = nextRetryAt!.difference(now);
    
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

  // ✅ Obtener resumen del estado
  String get statusSummary {
    final base = 'Estado: ${status.description}';
    final attempts = 'Intentos: $attemptCount/$maxRetries';
    
    if (status == QueueStatus.failed && lastError != null) {
      return '$base | $attempts | Error: $lastError';
    }
    
    if (status == QueueStatus.retrying && nextRetryAt != null) {
      return '$base | $attempts | Próximo intento: ${_formatDateTime(nextRetryAt!)}';
    }
    
    return '$base | $attempts';
  }

  // ✅ Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingInvoiceItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PendingInvoiceItem(id: $id, invoiceId: $invoiceId, status: $status, attempts: $attemptCount/$maxRetries)';
  }
}

// ✅ Configuración de reintentos
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool exponentialBackoff;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(minutes: 1),
    this.maxDelay = const Duration(hours: 24),
    this.backoffMultiplier = 2.0,
    this.exponentialBackoff = true,
  });

  // ✅ Calcular delay para el próximo reintento
  Duration calculateNextRetryDelay(int attemptCount) {
    if (attemptCount <= 0) return initialDelay;
    
    if (!exponentialBackoff) return initialDelay;
    
    final delay = initialDelay * pow(backoffMultiplier, attemptCount - 1);
    
    if (delay > maxDelay) return maxDelay;
    
    return delay;
  }

  // ✅ Verificar si se debe reintentar
  bool shouldRetry(int attemptCount, String? error) {
    if (attemptCount >= maxRetries) return false;
    
    // ✅ Aquí se pueden agregar lógicas específicas de error
    // Por ejemplo, no reintentar en ciertos tipos de error
    if (error != null) {
      final lowerError = error.toLowerCase();
      
      // ✅ No reintentar en errores de validación
      if (lowerError.contains('validación') || 
          lowerError.contains('validation') ||
          lowerError.contains('datos inválidos')) {
        return false;
      }
      
      // ✅ No reintentar en errores de configuración
      if (lowerError.contains('configuración') || 
          lowerError.contains('configuration') ||
          lowerError.contains('no configurado')) {
        return false;
      }
    }
    
    return true;
  }

  // ✅ Obtener configuración por defecto
  static const RetryConfig defaultConfig = RetryConfig();
  
  // ✅ Obtener configuración agresiva (más reintentos)
  static const RetryConfig aggressiveConfig = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(minutes: 30),
    maxDelay: Duration(hours: 12),
    backoffMultiplier: 1.5,
  );
  
  // ✅ Obtener configuración conservadora (menos reintentos)
  static const RetryConfig conservativeConfig = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(hours: 1),
    maxDelay: Duration(hours: 48),
    backoffMultiplier: 3.0,
  );
}
