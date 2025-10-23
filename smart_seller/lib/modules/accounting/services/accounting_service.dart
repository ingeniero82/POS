// Servicio principal de gestión contable
// Maneja todas las operaciones contables del sistema

import '../models/accounting_entry.dart';
import '../models/cash_movement.dart';
import '../models/cash_session.dart';
import '../models/payment_method.dart';
import '../models/transaction_category.dart';
import '../../../services/sqlite_database_service.dart';

class AccountingService {
  static const String _accountingTableName = 'accounting_entries';
  static const String _cashMovementsTableName = 'cash_movements';
  static const String _cashSessionsTableName = 'cash_sessions';
  static const String _paymentMethodsTableName = 'payment_methods';
  static const String _transactionCategoriesTableName = 'transaction_categories';

  // ==================== ENTRADAS CONTABLES ====================

  // Crear entrada contable
  static Future<int> createAccountingEntry(AccountingEntry entry) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final id = await db.insert(_accountingTableName, entry.toMap());
      
      // Crear movimiento de caja automáticamente si es necesario
      if (entry.paymentMethod != null) {
        await _createCashMovementFromEntry(entry, id);
      }

      print('✅ Entrada contable creada: $id');
      return id;
    } catch (e) {
      print('❌ Error al crear entrada contable: $e');
      rethrow;
    }
  }

  // Obtener entradas contables por fecha
  static Future<List<AccountingEntry>> getAccountingEntriesByDate(DateTime date) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final List<Map<String, dynamic>> maps = await db.query(
        _accountingTableName,
        where: 'date >= ? AND date <= ? AND is_active = ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String(), 1],
        orderBy: 'date DESC',
      );

      return List.generate(maps.length, (i) => AccountingEntry.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener entradas contables: $e');
      return [];
    }
  }

  // Obtener resumen de ingresos y egresos por fecha
  static Future<Map<String, double>> getIncomeExpenseSummary(DateTime date) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT type, SUM(amount) as total
        FROM $_accountingTableName
        WHERE date >= ? AND date <= ? AND is_active = ?
        GROUP BY type
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String(), 1]);

      double income = 0.0;
      double expense = 0.0;

      for (var map in maps) {
        if (map['type'] == 'income') {
          income = map['total']?.toDouble() ?? 0.0;
        } else if (map['type'] == 'expense') {
          expense = map['total']?.toDouble() ?? 0.0;
        }
      }

      return {
        'income': income,
        'expense': expense,
        'net': income - expense,
      };
    } catch (e) {
      print('❌ Error al obtener resumen contable: $e');
      return {'income': 0.0, 'expense': 0.0, 'net': 0.0};
    }
  }

  // ==================== MOVIMIENTOS DE CAJA ====================

  // Crear movimiento de caja
  static Future<int> createCashMovement(CashMovement movement) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final id = await db.insert(_cashMovementsTableName, movement.toMap());
      print('✅ Movimiento de caja creado: $id');
      return id;
    } catch (e) {
      print('❌ Error al crear movimiento de caja: $e');
      rethrow;
    }
  }

  // Crear movimiento de caja desde entrada contable
  static Future<void> _createCashMovementFromEntry(AccountingEntry entry, int entryId) async {
    try {
      final movement = CashMovement(
        type: entry.type,
        amount: entry.amount,
        description: entry.description,
        paymentMethod: entry.paymentMethod,
        date: entry.date,
        userId: entry.userId,
        cashSessionId: entry.cashSessionId,
        reference: 'accounting_entry',
        referenceId: entryId,
        category: entry.category,
        createdAt: DateTime.now(),
        notes: entry.notes,
        documentNumber: entry.documentNumber,
      );

      await createCashMovement(movement);
    } catch (e) {
      print('❌ Error al crear movimiento de caja desde entrada: $e');
    }
  }

  // Obtener movimientos de caja por sesión
  static Future<List<CashMovement>> getCashMovementsBySession(int sessionId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _cashMovementsTableName,
        where: 'cash_session_id = ? AND is_active = ?',
        whereArgs: [sessionId, 1],
        orderBy: 'date ASC',
      );

      return List.generate(maps.length, (i) => CashMovement.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener movimientos de caja: $e');
      return [];
    }
  }

  // ==================== SESIONES DE CAJA ====================

  // Abrir sesión de caja
  static Future<int> openCashSession(double initialAmount, int userId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Verificar si hay una sesión abierta
      final openSession = await getOpenCashSession();
      if (openSession != null) {
        throw Exception('Ya existe una sesión de caja abierta');
      }

      final session = CashSession(
        openDate: DateTime.now(),
        initialAmount: initialAmount,
        userId: userId,
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await db.insert(_cashSessionsTableName, session.toMap());
      print('✅ Sesión de caja abierta: $id');
      return id;
    } catch (e) {
      print('❌ Error al abrir sesión de caja: $e');
      rethrow;
    }
  }

  // Cerrar sesión de caja
  static Future<void> closeCashSession(int sessionId, double finalAmount, int userId, {String? notes}) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener la sesión actual
      final session = await getCashSessionById(sessionId);
      if (session == null) {
        throw Exception('Sesión de caja no encontrada');
      }

      if (session.isClosed) {
        throw Exception('La sesión de caja ya está cerrada');
      }

      // Calcular totales
      final movements = await getCashMovementsBySession(sessionId);
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (var movement in movements) {
        if (movement.type == 'income') {
          totalIncome += movement.amount;
        } else if (movement.type == 'expense') {
          totalExpense += movement.amount;
        }
      }

      final theoreticalBalance = session.initialAmount + totalIncome - totalExpense;
      final difference = finalAmount - theoreticalBalance;

      // Actualizar la sesión
      final updatedSession = session.copyWith(
        closeDate: DateTime.now(),
        finalAmount: finalAmount,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        difference: difference,
        closedByUserId: userId,
        status: 'closed',
        notes: notes,
        updatedAt: DateTime.now(),
      );

      await db.update(
        _cashSessionsTableName,
        updatedSession.toMap(),
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      print('✅ Sesión de caja cerrada: $sessionId');
    } catch (e) {
      print('❌ Error al cerrar sesión de caja: $e');
      rethrow;
    }
  }

  // Obtener sesión de caja abierta
  static Future<CashSession?> getOpenCashSession() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _cashSessionsTableName,
        where: 'status = ? AND is_active = ?',
        whereArgs: ['open', 1],
        orderBy: 'open_date DESC',
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return CashSession.fromMap(maps.first);
    } catch (e) {
      print('❌ Error al obtener sesión abierta: $e');
      return null;
    }
  }

  // Obtener sesión de caja por ID
  static Future<CashSession?> getCashSessionById(int id) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _cashSessionsTableName,
        where: 'id = ? AND is_active = ?',
        whereArgs: [id, 1],
      );

      if (maps.isEmpty) return null;
      return CashSession.fromMap(maps.first);
    } catch (e) {
      print('❌ Error al obtener sesión por ID: $e');
      return null;
    }
  }

  // ✅ NUEVO: Cerrar todas las sesiones abiertas (para limpieza)
  static Future<void> closeAllOpenSessions() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener todas las sesiones abiertas
      final List<Map<String, dynamic>> openSessions = await db.query(
        _cashSessionsTableName,
        where: 'status = ? AND is_active = ?',
        whereArgs: ['open', 1],
      );

      if (openSessions.isEmpty) {
        print('ℹ️ No hay sesiones abiertas para cerrar');
        return;
      }

      // Cerrar cada sesión abierta
      for (var sessionMap in openSessions) {
        final sessionId = sessionMap['id'] as int;
        final userId = sessionMap['user_id'] as int;
        
        await db.update(
          _cashSessionsTableName,
          {
            'status': 'closed',
            'close_date': DateTime.now().toIso8601String(),
            'final_amount': 0.0,
            'total_income': 0.0,
            'total_expense': 0.0,
            'difference': 0.0,
            'closed_by_user_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
            'notes': 'Cerrada automáticamente al iniciar aplicación',
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );
        
        print('✅ Sesión de caja cerrada automáticamente: $sessionId');
      }
      
      print('✅ Todas las sesiones abiertas han sido cerradas');
    } catch (e) {
      print('❌ Error cerrando sesiones abiertas: $e');
    }
  }

  // ==================== MÉTODOS DE PAGO ====================

  // Obtener métodos de pago activos
  static Future<List<PaymentMethod>> getActivePaymentMethods() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _paymentMethodsTableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) => PaymentMethod.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener métodos de pago: $e');
      return [];
    }
  }

  // ==================== CATEGORÍAS DE TRANSACCIONES ====================

  // Obtener categorías por tipo
  static Future<List<TransactionCategory>> getCategoriesByType(String type) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final List<Map<String, dynamic>> maps = await db.query(
        _transactionCategoriesTableName,
        where: 'type = ? AND is_active = ?',
        whereArgs: [type, 1],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) => TransactionCategory.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error al obtener categorías: $e');
      return [];
    }
  }

  // ==================== UTILIDADES ====================

  // Registrar ingreso automático desde venta
  static Future<void> recordSaleIncome(double amount, String description, int userId, {String? paymentMethod, String? reference}) async {
    try {
      final openSession = await getOpenCashSession();
      if (openSession == null) {
        throw Exception('No hay sesión de caja abierta');
      }

      final entry = AccountingEntry(
        type: 'income',
        amount: amount,
        description: description,
        category: 'ventas',
        date: DateTime.now(),
        paymentMethod: paymentMethod,
        userId: userId,
        cashSessionId: openSession.id,
        reference: reference,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createAccountingEntry(entry);
      print('✅ Ingreso por venta registrado: $amount');
    } catch (e) {
      print('❌ Error al registrar ingreso por venta: $e');
      rethrow;
    }
  }

  // Registrar egreso automático
  static Future<void> recordExpense(double amount, String description, int userId, {String? category, String? paymentMethod, String? reference}) async {
    try {
      final openSession = await getOpenCashSession();
      if (openSession == null) {
        throw Exception('No hay sesión de caja abierta');
      }

      final entry = AccountingEntry(
        type: 'expense',
        amount: amount,
        description: description,
        category: category ?? 'gastos',
        date: DateTime.now(),
        paymentMethod: paymentMethod,
        userId: userId,
        cashSessionId: openSession.id,
        reference: reference,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createAccountingEntry(entry);
      print('✅ Egreso registrado: $amount');
    } catch (e) {
      print('❌ Error al registrar egreso: $e');
      rethrow;
    }
  }

  // ✅ NUEVO: Registrar pago a proveedor
  static Future<void> recordSupplierPayment(double amount, String supplierName, int userId, {String? paymentMethod, String? reference, String? documentNumber}) async {
    try {
      final openSession = await getOpenCashSession();
      if (openSession == null) {
        throw Exception('No hay sesión de caja abierta');
      }

      final entry = AccountingEntry(
        type: 'expense',
        amount: amount,
        description: 'Pago a proveedor: $supplierName',
        category: 'SUPPLIER_PAYMENTS',
        date: DateTime.now(),
        paymentMethod: paymentMethod ?? 'CASH',
        userId: userId,
        cashSessionId: openSession.id,
        reference: reference,
        documentNumber: documentNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createAccountingEntry(entry);
      print('✅ Pago a proveedor registrado: \$${amount} - $supplierName');
    } catch (e) {
      print('❌ Error al registrar pago a proveedor: $e');
      rethrow;
    }
  }

  // ✅ NUEVO: Registrar gasto operativo
  static Future<void> recordOperationalExpense(double amount, String description, String category, int userId, {String? paymentMethod, String? reference, String? documentNumber}) async {
    try {
      final openSession = await getOpenCashSession();
      if (openSession == null) {
        throw Exception('No hay sesión de caja abierta');
      }

      final entry = AccountingEntry(
        type: 'expense',
        amount: amount,
        description: description,
        category: category,
        date: DateTime.now(),
        paymentMethod: paymentMethod ?? 'CASH',
        userId: userId,
        cashSessionId: openSession.id,
        reference: reference,
        documentNumber: documentNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createAccountingEntry(entry);
      print('✅ Gasto operativo registrado: \$${amount} - $description');
    } catch (e) {
      print('❌ Error al registrar gasto operativo: $e');
      rethrow;
    }
  }

  // ✅ NUEVO: Registrar devolución a proveedor
  static Future<void> recordSupplierReturn(double amount, String supplierName, int userId, {String? paymentMethod, String? reference, String? documentNumber}) async {
    try {
      final openSession = await getOpenCashSession();
      if (openSession == null) {
        throw Exception('No hay sesión de caja abierta');
      }

      final entry = AccountingEntry(
        type: 'expense',
        amount: amount,
        description: 'Devolución a proveedor: $supplierName',
        category: 'SUPPLIER_RETURNS',
        date: DateTime.now(),
        paymentMethod: paymentMethod ?? 'CASH',
        userId: userId,
        cashSessionId: openSession.id,
        reference: reference,
        documentNumber: documentNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createAccountingEntry(entry);
      print('✅ Devolución a proveedor registrada: \$${amount} - $supplierName');
    } catch (e) {
      print('❌ Error al registrar devolución a proveedor: $e');
      rethrow;
    }
  }
}
