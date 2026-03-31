// Servicio para gestión de cuentas por cobrar y pagar

import '../../../services/sqlite_database_service.dart';
import '../models/accounts_receivable.dart';
import '../models/accounts_payable.dart';
import '../models/receivable_payment.dart';
import '../models/payable_payment.dart';

/// Un cliente con todas sus cuentas por cobrar agregadas (lista sin duplicar nombre).
class ReceivableCustomerSummary {
  final int customerId;
  final String customerName;
  final String customerDocument;
  final double totalPending;
  final double totalPaid;
  final double totalInvoiced;
  final int documentCount;
  final List<AccountsReceivable> accounts;

  ReceivableCustomerSummary({
    required this.customerId,
    required this.customerName,
    required this.customerDocument,
    required this.totalPending,
    required this.totalPaid,
    required this.totalInvoiced,
    required this.documentCount,
    required this.accounts,
  });
}

/// Un proveedor con todas sus cuentas por pagar agregadas.
class PayableSupplierSummary {
  final int supplierId;
  final String supplierName;
  final String supplierDocument;
  final double totalPending;
  final double totalPaid;
  final double totalInvoiced;
  final int documentCount;
  final List<AccountsPayable> accounts;

  PayableSupplierSummary({
    required this.supplierId,
    required this.supplierName,
    required this.supplierDocument,
    required this.totalPending,
    required this.totalPaid,
    required this.totalInvoiced,
    required this.documentCount,
    required this.accounts,
  });
}

class AccountsReceivablePayableService {
  static const String _receivableTableName = 'accounts_receivable';
  static const String _payableTableName = 'accounts_payable';
  static const String _receivablePaymentsTableName = 'receivable_payments';
  static const String _payablePaymentsTableName = 'payable_payments';
  static const double _pendingEpsilon = 0.009;

  // ==================== CUENTAS POR COBRAR ====================

  // Crear cuenta por cobrar
  static Future<int> createAccountsReceivable(AccountsReceivable account) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final id = await db.insert(_receivableTableName, account.toMap());
      print('✅ Cuenta por cobrar creada: ID $id');
      return id;
    } catch (e) {
      print('❌ Error al crear cuenta por cobrar: $e');
      rethrow;
    }
  }

  // Obtener todas las cuentas por cobrar
  static Future<List<AccountsReceivable>> getAllAccountsReceivable() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _receivableTableName,
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsReceivable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas por cobrar: $e');
      return [];
    }
  }

  // Obtener cuentas por cobrar por estado
  static Future<List<AccountsReceivable>> getAccountsReceivableByStatus(String status) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _receivableTableName,
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsReceivable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas por cobrar por estado: $e');
      return [];
    }
  }

  // Obtener cuentas vencidas
  static Future<List<AccountsReceivable>> getOverdueAccountsReceivable() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final now = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> maps = await db.query(
        _receivableTableName,
        where: 'due_date < ? AND status != ?',
        whereArgs: [now, 'paid'],
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsReceivable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas vencidas: $e');
      return [];
    }
  }

  // Registrar pago de cuenta por cobrar
  static Future<void> recordReceivablePayment(ReceivablePayment payment) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Insertar el pago
      await db.insert(_receivablePaymentsTableName, payment.toMap());

      // Actualizar la cuenta por cobrar
      final account = await getAccountsReceivableById(payment.accountsReceivableId);
      if (account == null) throw Exception('Cuenta por cobrar no encontrada');

      final newPaidAmount = account.paidAmount + payment.amount;
      final newPendingAmount = account.totalAmount - newPaidAmount;
      final newStatus = newPendingAmount <= 0 ? 'paid' : 
                       newPaidAmount > 0 ? 'partial' : 'pending';

      await db.update(
        _receivableTableName,
        {
          'paid_amount': newPaidAmount,
          'pending_amount': newPendingAmount,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [payment.accountsReceivableId],
      );

      print('✅ Pago registrado: \$${payment.amount}');
    } catch (e) {
      print('❌ Error al registrar pago: $e');
      rethrow;
    }
  }

  /// Suma de `pending_amount` de cuentas por cobrar del cliente (excluye pagadas).
  static Future<double> getPendingTotalForCustomer(int customerId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return 0.0;

      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(pending_amount), 0) AS t FROM $_receivableTableName WHERE customer_id = ? AND status != ?',
        [customerId, 'paid'],
      );
      if (rows.isEmpty) return 0.0;
      return (rows.first['t'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('❌ Error sumando saldo por cobrar del cliente: $e');
      return 0.0;
    }
  }

  /// Pagos registrados contra una cuenta por cobrar (abonos).
  static Future<List<ReceivablePayment>> getPaymentsForReceivable(
      int accountsReceivableId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return [];

      final maps = await db.query(
        _receivablePaymentsTableName,
        where: 'accounts_receivable_id = ?',
        whereArgs: [accountsReceivableId],
        orderBy: 'payment_date DESC',
      );
      return maps.map((m) => ReceivablePayment.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error obteniendo pagos de cuenta por cobrar: $e');
      return [];
    }
  }

  /// Pagos de múltiples cuentas por cobrar en una sola consulta.
  static Future<Map<int, List<ReceivablePayment>>> getPaymentsForReceivables(
      List<int> accountsReceivableIds) async {
    try {
      if (accountsReceivableIds.isEmpty) return {};
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};

      final placeholders =
          List.filled(accountsReceivableIds.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM $_receivablePaymentsTableName '
        'WHERE accounts_receivable_id IN ($placeholders) '
        'ORDER BY payment_date DESC',
        accountsReceivableIds,
      );

      final out = <int, List<ReceivablePayment>>{};
      for (final id in accountsReceivableIds) {
        out[id] = <ReceivablePayment>[];
      }
      for (final m in maps) {
        final p = ReceivablePayment.fromMap(m);
        out.putIfAbsent(p.accountsReceivableId, () => <ReceivablePayment>[])
            .add(p);
      }
      return out;
    } catch (e) {
      print('❌ Error obteniendo pagos agrupados por cuentas por cobrar: $e');
      return {};
    }
  }

  /// Pagos registrados contra una cuenta por pagar.
  static Future<List<PayablePayment>> getPaymentsForPayable(
      int accountsPayableId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return [];

      final maps = await db.query(
        _payablePaymentsTableName,
        where: 'accounts_payable_id = ?',
        whereArgs: [accountsPayableId],
        orderBy: 'payment_date DESC',
      );
      return maps.map((m) => PayablePayment.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error obteniendo pagos de cuenta por pagar: $e');
      return [];
    }
  }

  /// Pagos de múltiples cuentas por pagar en una sola consulta.
  static Future<Map<int, List<PayablePayment>>> getPaymentsForPayables(
      List<int> accountsPayableIds) async {
    try {
      if (accountsPayableIds.isEmpty) return {};
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};

      final placeholders = List.filled(accountsPayableIds.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM $_payablePaymentsTableName '
        'WHERE accounts_payable_id IN ($placeholders) '
        'ORDER BY payment_date DESC',
        accountsPayableIds,
      );

      final out = <int, List<PayablePayment>>{};
      for (final id in accountsPayableIds) {
        out[id] = <PayablePayment>[];
      }
      for (final m in maps) {
        final p = PayablePayment.fromMap(m);
        out.putIfAbsent(p.accountsPayableId, () => <PayablePayment>[]).add(p);
      }
      return out;
    } catch (e) {
      print('❌ Error obteniendo pagos agrupados por cuentas por pagar: $e');
      return {};
    }
  }

  /// Agrupa cuentas por cobrar por [customerId] (un renglón por cliente).
  static Future<List<ReceivableCustomerSummary>>
      getReceivablesGroupedByCustomer() async {
    final all = await getAllAccountsReceivable();
    final byCustomer = <int, List<AccountsReceivable>>{};
    for (final a in all) {
      if (a.pendingAmount <= _pendingEpsilon) continue;
      byCustomer.putIfAbsent(a.customerId, () => []).add(a);
    }
    final out = <ReceivableCustomerSummary>[];
    for (final e in byCustomer.entries) {
      final list = List<AccountsReceivable>.from(e.value)
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      final first = list.first;
      double pending = 0, paid = 0, invoiced = 0;
      for (final x in list) {
        pending += x.pendingAmount;
        paid += x.paidAmount;
        invoiced += x.totalAmount;
      }
      out.add(ReceivableCustomerSummary(
        customerId: e.key,
        customerName: first.customerName,
        customerDocument: first.customerDocument,
        totalPending: pending,
        totalPaid: paid,
        totalInvoiced: invoiced,
        documentCount: list.length,
        accounts: list,
      ));
    }
    out.sort((a, b) => b.totalPending.compareTo(a.totalPending));
    return out;
  }

  /// Agrupa cuentas por pagar por proveedor.
  static Future<List<PayableSupplierSummary>> getPayablesGroupedBySupplier() async {
    final all = await getAllAccountsPayable();
    final bySup = <int, List<AccountsPayable>>{};
    for (final a in all) {
      if (a.pendingAmount <= _pendingEpsilon) continue;
      bySup.putIfAbsent(a.supplierId, () => []).add(a);
    }
    final out = <PayableSupplierSummary>[];
    for (final e in bySup.entries) {
      final list = List<AccountsPayable>.from(e.value)
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      final first = list.first;
      double pending = 0, paid = 0, invoiced = 0;
      for (final x in list) {
        pending += x.pendingAmount;
        paid += x.paidAmount;
        invoiced += x.totalAmount;
      }
      out.add(PayableSupplierSummary(
        supplierId: e.key,
        supplierName: first.supplierName,
        supplierDocument: first.supplierDocument,
        totalPending: pending,
        totalPaid: paid,
        totalInvoiced: invoiced,
        documentCount: list.length,
        accounts: list,
      ));
    }
    out.sort((a, b) => b.totalPending.compareTo(a.totalPending));
    return out;
  }

  // Obtener cuenta por cobrar por ID
  static Future<AccountsReceivable?> getAccountsReceivableById(int id) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _receivableTableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return AccountsReceivable.fromMap(maps.first);
    } catch (e) {
      print('❌ Error al obtener cuenta por cobrar: $e');
      return null;
    }
  }

  // ==================== CUENTAS POR PAGAR ====================

  // Crear cuenta por pagar
  static Future<int> createAccountsPayable(AccountsPayable account) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final id = await db.insert(_payableTableName, account.toMap());
      print('✅ Cuenta por pagar creada: ID $id');
      return id;
    } catch (e) {
      print('❌ Error al crear cuenta por pagar: $e');
      rethrow;
    }
  }

  // Obtener todas las cuentas por pagar
  static Future<List<AccountsPayable>> getAllAccountsPayable() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _payableTableName,
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsPayable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas por pagar: $e');
      return [];
    }
  }

  // Obtener cuentas por pagar por estado
  static Future<List<AccountsPayable>> getAccountsPayableByStatus(String status) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _payableTableName,
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsPayable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas por pagar por estado: $e');
      return [];
    }
  }

  // Obtener cuentas vencidas
  static Future<List<AccountsPayable>> getOverdueAccountsPayable() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final now = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> maps = await db.query(
        _payableTableName,
        where: 'due_date < ? AND status != ?',
        whereArgs: [now, 'paid'],
        orderBy: 'due_date ASC',
      );

      return List.generate(maps.length, (i) => AccountsPayable.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener cuentas vencidas: $e');
      return [];
    }
  }

  // Registrar pago de cuenta por pagar
  static Future<void> recordPayablePayment(PayablePayment payment) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Insertar el pago
      await db.insert(_payablePaymentsTableName, payment.toMap());

      // Actualizar la cuenta por pagar
      final account = await getAccountsPayableById(payment.accountsPayableId);
      if (account == null) throw Exception('Cuenta por pagar no encontrada');

      final newPaidAmount = account.paidAmount + payment.amount;
      final newPendingAmount = account.totalAmount - newPaidAmount;
      final newStatus = newPendingAmount <= 0 ? 'paid' : 
                       newPaidAmount > 0 ? 'partial' : 'pending';

      await db.update(
        _payableTableName,
        {
          'paid_amount': newPaidAmount,
          'pending_amount': newPendingAmount,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [payment.accountsPayableId],
      );

      print('✅ Pago registrado: \$${payment.amount}');
    } catch (e) {
      print('❌ Error al registrar pago: $e');
      rethrow;
    }
  }

  // Obtener cuenta por pagar por ID
  static Future<AccountsPayable?> getAccountsPayableById(int id) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _payableTableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return AccountsPayable.fromMap(maps.first);
    } catch (e) {
      print('❌ Error al obtener cuenta por pagar: $e');
      return null;
    }
  }

  // ==================== RESUMENES ====================

  // Obtener resumen de cuentas por cobrar
  static Future<Map<String, dynamic>> getReceivableSummary() async {
    try {
      final accounts = await getAllAccountsReceivable();
      
      double totalPending = 0;
      double totalPaid = 0;
      int overdueCount = 0;
      int pendingCount = 0;
      int paidCount = 0;

      for (final account in accounts) {
        totalPending += account.pendingAmount;
        totalPaid += account.paidAmount;
        
        if (account.isOverdue) overdueCount++;
        if (account.status == 'pending') pendingCount++;
        if (account.status == 'paid') paidCount++;
      }

      return {
        'totalPending': totalPending,
        'totalPaid': totalPaid,
        'overdueCount': overdueCount,
        'pendingCount': pendingCount,
        'paidCount': paidCount,
        'totalAccounts': accounts.length,
      };
    } catch (e) {
      print('❌ Error al obtener resumen de cuentas por cobrar: $e');
      return {};
    }
  }

  // Obtener resumen de cuentas por pagar
  static Future<Map<String, dynamic>> getPayableSummary() async {
    try {
      final accounts = await getAllAccountsPayable();
      
      double totalPending = 0;
      double totalPaid = 0;
      int overdueCount = 0;
      int pendingCount = 0;
      int paidCount = 0;

      for (final account in accounts) {
        totalPending += account.pendingAmount;
        totalPaid += account.paidAmount;
        
        if (account.isOverdue) overdueCount++;
        if (account.status == 'pending') pendingCount++;
        if (account.status == 'paid') paidCount++;
      }

      return {
        'totalPending': totalPending,
        'totalPaid': totalPaid,
        'overdueCount': overdueCount,
        'pendingCount': pendingCount,
        'paidCount': paidCount,
        'totalAccounts': accounts.length,
      };
    } catch (e) {
      print('❌ Error al obtener resumen de cuentas por pagar: $e');
      return {};
    }
  }
}
