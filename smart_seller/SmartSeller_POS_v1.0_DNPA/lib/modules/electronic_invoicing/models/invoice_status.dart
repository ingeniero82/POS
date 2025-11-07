enum InvoiceStatus {
  pending('PENDIENTE', 'Pendiente de envío a DIAN'),
  sent('ENVIADA', 'Enviada a DIAN'),
  accepted('ACEPTADA', 'Aceptada por DIAN'),
  rejected('RECHAZADA', 'Rechazada por DIAN'),
  cancelled('ANULADA', 'Factura anulada');
  
  const InvoiceStatus(this.code, this.description);
  
  final String code;
  final String description;
  
  // ✅ Obtener estado desde código
  static InvoiceStatus fromCode(String code) {
    return InvoiceStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => InvoiceStatus.pending,
    );
  }
  
  // ✅ Obtener color del estado
  String get color {
    switch (this) {
      case InvoiceStatus.pending:
        return 'orange';
      case InvoiceStatus.sent:
        return 'blue';
      case InvoiceStatus.accepted:
        return 'green';
      case InvoiceStatus.rejected:
        return 'red';
      case InvoiceStatus.cancelled:
        return 'grey';
    }
  }
  
  // ✅ Obtener icono del estado
  String get icon {
    switch (this) {
      case InvoiceStatus.pending:
        return 'schedule';
      case InvoiceStatus.sent:
        return 'send';
      case InvoiceStatus.accepted:
        return 'check_circle';
      case InvoiceStatus.rejected:
        return 'error';
      case InvoiceStatus.cancelled:
        return 'cancel';
    }
  }
  
  // ✅ Verificar si se puede enviar
  bool get canBeSent => this == InvoiceStatus.pending;
  
  // ✅ Verificar si se puede anular
  bool get canBeCancelled => this == InvoiceStatus.pending || this == InvoiceStatus.sent;
  
  // ✅ Verificar si es final
  bool get isFinal => this == InvoiceStatus.accepted || this == InvoiceStatus.rejected || this == InvoiceStatus.cancelled;
  
  // ✅ Verificar si requiere acción
  bool get requiresAction => this == InvoiceStatus.rejected;
}

// ✅ Clase para el seguimiento de estado
class InvoiceStatusTracking {
  final String id;
  final String invoiceId;
  final InvoiceStatus status;
  final String? reason;
  final String? dianResponse;
  final DateTime timestamp;
  final String? userId;
  final String? notes;
  
  const InvoiceStatusTracking({
    required this.id,
    required this.invoiceId,
    required this.status,
    this.reason,
    this.dianResponse,
    required this.timestamp,
    this.userId,
    this.notes,
  });
  
  // ✅ Factory constructor desde Map
  factory InvoiceStatusTracking.fromMap(Map<String, dynamic> map) {
    return InvoiceStatusTracking(
      id: map['id'] ?? '',
      invoiceId: map['invoice_id'] ?? '',
      status: InvoiceStatus.fromCode(map['status'] ?? 'PENDIENTE'),
      reason: map['reason'],
      dianResponse: map['dian_response'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      userId: map['user_id'],
      notes: map['notes'],
    );
  }
  
  // ✅ Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'status': status.code,
      'reason': reason,
      'dian_response': dianResponse,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'notes': notes,
    };
  }
  
  // ✅ Copiar con cambios
  InvoiceStatusTracking copyWith({
    String? id,
    String? invoiceId,
    InvoiceStatus? status,
    String? reason,
    String? dianResponse,
    DateTime? timestamp,
    String? userId,
    String? notes,
  }) {
    return InvoiceStatusTracking(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      dianResponse: dianResponse ?? this.dianResponse,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
    );
  }
  
  // ✅ Obtener resumen del estado
  String get statusSummary {
    final base = 'Estado: ${status.description}';
    if (reason != null && reason!.isNotEmpty) {
      return '$base - Motivo: $reason';
    }
    return base;
  }
  
  // ✅ Obtener tiempo transcurrido
  String get timeElapsed {
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
  
  // ✅ Verificar si es reciente (últimas 24 horas)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 24;
  }
}

// ✅ Clase para filtros de búsqueda
class InvoiceFilterCriteria {
  final InvoiceStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? clientId;
  final String? clientName;
  final String? documentNumber;
  final String? userId;
  final bool? isRecent;
  
  const InvoiceFilterCriteria({
    this.status,
    this.startDate,
    this.endDate,
    this.clientId,
    this.clientName,
    this.documentNumber,
    this.userId,
    this.isRecent,
  });
  
  // ✅ Verificar si hay filtros activos
  bool get hasActiveFilters {
    return status != null ||
           startDate != null ||
           endDate != null ||
           clientId != null ||
           clientName != null ||
           documentNumber != null ||
           userId != null ||
           isRecent != null;
  }
  
  // ✅ Obtener descripción de filtros
  String get filterDescription {
    final filters = <String>[];
    
    if (status != null) filters.add('Estado: ${status!.description}');
    if (startDate != null) filters.add('Desde: ${_formatDate(startDate!)}');
    if (endDate != null) filters.add('Hasta: ${_formatDate(endDate!)}');
    if (clientName != null) filters.add('Cliente: $clientName');
    if (documentNumber != null) filters.add('Documento: $documentNumber');
    if (isRecent == true) filters.add('Recientes (24h)');
    
    if (filters.isEmpty) return 'Sin filtros';
    return filters.join(', ');
  }
  
  // ✅ Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // ✅ Limpiar filtros
  InvoiceFilterCriteria clear() {
    return const InvoiceFilterCriteria();
  }
  
  // ✅ Copiar con cambios
  InvoiceFilterCriteria copyWith({
    InvoiceStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? clientId,
    String? clientName,
    String? documentNumber,
    String? userId,
    bool? isRecent,
  }) {
    return InvoiceFilterCriteria(
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      documentNumber: documentNumber ?? this.documentNumber,
      userId: userId ?? this.userId,
      isRecent: isRecent ?? this.isRecent,
    );
  }
}
