// Servicio para gestión de cuentas por cobrar y pagar

import '../../../services/sqlite_database_service.dart';
import '../models/accounts_receivable.dart';
import '../models/accounts_payable.dart';
import '../models/receivable_payment.dart';
import '../models/payable_payment.dart';

class AccountsReceivablePayableService {
  static const String _receivableTableName = 'accounts_receivable';
  static const String _payableTableName = 'accounts_payable';
  static const String _receivablePaymentsTableName = 'receivable_payments';
  static const String _payablePaymentsTableName = 'payable_payments';

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
