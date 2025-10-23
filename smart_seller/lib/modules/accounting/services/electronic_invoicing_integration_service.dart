// Servicio de integración entre facturación electrónica y módulo contable

import '../../../services/sqlite_database_service.dart';
import '../models/accounting_entry.dart';
import '../models/accounts_receivable.dart';
import '../models/receivable_payment.dart';
import '../../electronic_invoicing/models/electronic_document.dart';

class ElectronicInvoicingIntegrationService {
  
  // ==================== REGISTRO AUTOMÁTICO DE FACTURAS ====================
  
  /// Registra automáticamente una factura electrónica como ingreso en contabilidad
  static Future<bool> recordElectronicInvoice({
    required ElectronicDocument document,
    required int userId,
    required int? cashSessionId,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return false;

      // 1. Crear entrada contable de ingreso
      final accountingEntry = AccountingEntry(
        id: null,
        type: 'income',
        amount: document.total,
        description: 'Factura Electrónica ${document.documentNumber}',
        category: 'SALES',
        subcategory: 'ELECTRONIC_INVOICE',
        paymentMethod: _mapPaymentFormToAccounting(document.paymentForm),
        documentNumber: document.documentNumber,
        reference: document.consecutive,
        relatedEntity: 'electronic_document',
        relatedEntityId: document.id ?? 0,
        notes: 'Factura electrónica generada automáticamente',
        userId: userId,
        cashSessionId: cashSessionId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('accounting_entries', accountingEntry.toMap());
      
      print('✅ Factura electrónica registrada en contabilidad: ${document.documentNumber}');

      // 2. Si es factura a crédito, crear cuenta por cobrar
      if (document.paymentMethod == 'CREDITO') {
        await _createAccountsReceivableFromInvoice(
          document: document,
          userId: userId,
        );
      }

      return true;
    } catch (e) {
      print('❌ Error registrando factura electrónica en contabilidad: $e');
      return false;
    }
  }

  // ==================== CUENTAS POR COBRAR ====================
  
  /// Crea una cuenta por cobrar a partir de una factura electrónica
  static Future<bool> _createAccountsReceivableFromInvoice({
    required ElectronicDocument document,
    required int userId,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return false;

      final accountsReceivable = AccountsReceivable(
        id: null,
        customerId: 0, // Cliente no registrado
        customerName: document.clientBusinessName ?? 'Cliente No Registrado',
        customerDocument: document.clientDocumentNumber ?? 'N/A',
        totalAmount: document.total,
        paidAmount: 0.0,
        pendingAmount: document.total,
        invoiceNumber: document.documentNumber,
        invoiceDate: document.issueDate,
        dueDate: document.dueDate,
        status: 'pending',
        notes: 'Factura electrónica a crédito',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('accounts_receivable', accountsReceivable.toMap());
      
      print('✅ Cuenta por cobrar creada para factura: ${document.documentNumber}');
      return true;
    } catch (e) {
      print('❌ Error creando cuenta por cobrar: $e');
      return false;
    }
  }

  // ==================== REGISTRO DE PAGOS ====================
  
  /// Registra un pago recibido contra una factura electrónica
  static Future<bool> recordPaymentAgainstInvoice({
    required String invoiceNumber,
    required double amount,
    required String paymentMethod,
    required int userId,
    required int? cashSessionId,
    String? reference,
    String? notes,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return false;

      // 1. Buscar la cuenta por cobrar
      final receivableResult = await db.query(
        'accounts_receivable',
        where: 'invoice_number = ?',
        whereArgs: [invoiceNumber],
      );

      if (receivableResult.isEmpty) {
        print('❌ No se encontró cuenta por cobrar para factura: $invoiceNumber');
        return false;
      }

      final receivable = receivableResult.first;
      final receivableId = receivable['id'] as int;
      final currentPaidAmount = receivable['paid_amount'] as double;
      final totalAmount = receivable['total_amount'] as double;

      // 2. Crear entrada de pago
      final receivablePayment = ReceivablePayment(
        id: null,
        accountsReceivableId: receivableId,
        amount: amount,
        paymentDate: DateTime.now(),
        paymentMethod: paymentMethod,
        reference: reference ?? 'Pago contra factura $invoiceNumber',
        notes: notes,
        userId: userId,
        createdAt: DateTime.now(),
      );

      await db.insert('receivable_payments', receivablePayment.toMap());

      // 3. Actualizar cuenta por cobrar
      final newPaidAmount = currentPaidAmount + amount;
      final newPendingAmount = totalAmount - newPaidAmount;
      final newStatus = newPendingAmount <= 0 ? 'paid' : 'partial';

      await db.update(
        'accounts_receivable',
        {
          'paid_amount': newPaidAmount,
          'pending_amount': newPendingAmount,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [receivableId],
      );

      // 4. Crear entrada contable de ingreso por el pago
      final accountingEntry = AccountingEntry(
        id: null,
        type: 'income',
        amount: amount,
        description: 'Pago recibido - Factura $invoiceNumber',
        category: 'CUSTOMER_PAYMENTS',
        subcategory: 'INVOICE_PAYMENT',
        paymentMethod: paymentMethod,
        documentNumber: invoiceNumber,
        reference: reference ?? 'PAGO-${DateTime.now().millisecondsSinceEpoch}',
        relatedEntity: 'receivable_payment',
        relatedEntityId: receivablePayment.id ?? 0,
        notes: notes ?? 'Pago contra factura electrónica',
        userId: userId,
        cashSessionId: cashSessionId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('accounting_entries', accountingEntry.toMap());

      print('✅ Pago registrado contra factura: $invoiceNumber - Monto: \$${amount.toStringAsFixed(2)}');
      return true;
    } catch (e) {
      print('❌ Error registrando pago contra factura: $e');
      return false;
    }
  }

  // ==================== NOTAS CRÉDITO Y DÉBITO ====================
  
  /// Registra una nota crédito como ajuste contable
  static Future<bool> recordCreditNote({
    required ElectronicDocument document,
    required int userId,
    required int? cashSessionId,
    String? reason,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return false;

      // Crear entrada contable de ajuste (egreso)
      final accountingEntry = AccountingEntry(
        id: null,
        type: 'expense',
        amount: document.total,
        description: 'Nota Crédito ${document.documentNumber}',
        category: 'ADJUSTMENTS',
        subcategory: 'CREDIT_NOTE',
        paymentMethod: 'ADJUSTMENT',
        documentNumber: document.documentNumber,
        reference: document.consecutive,
        relatedEntity: 'electronic_document',
        relatedEntityId: document.id ?? 0,
        notes: reason ?? 'Nota crédito emitida',
        userId: userId,
        cashSessionId: cashSessionId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('accounting_entries', accountingEntry.toMap());
      
      print('✅ Nota crédito registrada en contabilidad: ${document.documentNumber}');
      return true;
    } catch (e) {
      print('❌ Error registrando nota crédito: $e');
      return false;
    }
  }

  /// Registra una nota débito como ajuste contable
  static Future<bool> recordDebitNote({
    required ElectronicDocument document,
    required int userId,
    required int? cashSessionId,
    String? reason,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return false;

      // Crear entrada contable de ajuste (ingreso)
      final accountingEntry = AccountingEntry(
        id: null,
        type: 'income',
        amount: document.total,
        description: 'Nota Débito ${document.documentNumber}',
        category: 'ADJUSTMENTS',
        subcategory: 'DEBIT_NOTE',
        paymentMethod: 'ADJUSTMENT',
        documentNumber: document.documentNumber,
        reference: document.consecutive,
        relatedEntity: 'electronic_document',
        relatedEntityId: document.id ?? 0,
        notes: reason ?? 'Nota débito emitida',
        userId: userId,
        cashSessionId: cashSessionId,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('accounting_entries', accountingEntry.toMap());
      
      print('✅ Nota débito registrada en contabilidad: ${document.documentNumber}');
      return true;
    } catch (e) {
      print('❌ Error registrando nota débito: $e');
      return false;
    }
  }

  // ==================== UTILIDADES ====================
  
  /// Mapea los métodos de pago de facturación electrónica a contabilidad
  static String _mapPaymentFormToAccounting(String paymentForm) {
    switch (paymentForm.toUpperCase()) {
      case 'EFECTIVO':
        return 'CASH';
      case 'TRANSFERENCIA':
        return 'TRANSFER';
      case 'TARJETA':
        return 'CARD';
      case 'CHEQUE':
        return 'CHECK';
      default:
        return 'OTHER';
    }
  }

  /// Obtiene el resumen de facturas electrónicas para reportes
  static Future<Map<String, dynamic>> getElectronicInvoicingSummary({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};

      // Consulta de ingresos por facturas electrónicas
      final invoiceResults = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_invoices,
          SUM(amount) as total_amount,
          category,
          subcategory
        FROM accounting_entries 
        WHERE type = 'income' 
          AND subcategory = 'ELECTRONIC_INVOICE'
          AND date BETWEEN ? AND ?
        GROUP BY category, subcategory
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      // Consulta de pagos recibidos
      final paymentResults = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_payments,
          SUM(amount) as total_paid_amount
        FROM accounting_entries 
        WHERE type = 'income' 
          AND subcategory = 'INVOICE_PAYMENT'
          AND date BETWEEN ? AND ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      // Consulta de cuentas por cobrar pendientes
      final pendingResults = await db.rawQuery('''
        SELECT 
          COUNT(*) as pending_invoices,
          SUM(pending_amount) as total_pending_amount
        FROM accounts_receivable 
        WHERE status IN ('pending', 'partial')
          AND invoice_date BETWEEN ? AND ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      return {
        'invoices': invoiceResults.isNotEmpty ? invoiceResults.first : {},
        'payments': paymentResults.isNotEmpty ? paymentResults.first : {},
        'pending': pendingResults.isNotEmpty ? pendingResults.first : {},
      };
    } catch (e) {
      print('❌ Error obteniendo resumen de facturación electrónica: $e');
      return {};
    }
  }
}
