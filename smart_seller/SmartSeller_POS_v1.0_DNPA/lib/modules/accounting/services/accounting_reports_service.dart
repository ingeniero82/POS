// Servicio para generar reportes contables

import 'dart:convert';
import '../../../services/sqlite_database_service.dart';
import '../models/accounting_reports.dart';

class AccountingReportsService {
  // ==================== ESTADO DE RESULTADOS ====================

  static Future<IncomeStatement> generateIncomeStatement(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener ingresos por categoría
      const incomeQuery = '''
        SELECT 
          category,
          SUM(amount) as total_amount,
          COUNT(*) as transaction_count
        FROM accounting_entries 
        WHERE type = 'income' 
        AND date BETWEEN ? AND ?
        GROUP BY category
        ORDER BY total_amount DESC
      ''';

      final incomeResults = await db.rawQuery(incomeQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Obtener egresos por categoría
      const expenseQuery = '''
        SELECT 
          category,
          SUM(amount) as total_amount,
          COUNT(*) as transaction_count
        FROM accounting_entries 
        WHERE type = 'expense' 
        AND date BETWEEN ? AND ?
        GROUP BY category
        ORDER BY total_amount DESC
      ''';

      final expenseResults = await db.rawQuery(expenseQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Calcular totales
      final totalIncome = incomeResults.fold<double>(
          0,
          (sum, row) =>
              sum +
              (row['total_amount'] is int
                  ? (row['total_amount'] as int).toDouble()
                  : (row['total_amount'] as double)));
      final totalExpenses = expenseResults.fold<double>(
          0,
          (sum, row) =>
              sum +
              (row['total_amount'] is int
                  ? (row['total_amount'] as int).toDouble()
                  : (row['total_amount'] as double)));
      final netIncome = totalIncome - totalExpenses;

      // Crear categorías de ingresos
      final incomeCategories = incomeResults.map((row) {
        final amount = row['total_amount'] is int
            ? (row['total_amount'] as int).toDouble()
            : (row['total_amount'] as double);
        return IncomeCategory(
          category: _translateCategory(
              row['category'] as String), // ✅ Traducir categorías
          amount: amount,
          transactionCount: row['transaction_count'] as int,
          percentage: totalIncome > 0 ? (amount / totalIncome) * 100 : 0,
        );
      }).toList();

      // Crear categorías de egresos
      final expenseCategories = expenseResults.map((row) {
        final amount = row['total_amount'] is int
            ? (row['total_amount'] as int).toDouble()
            : (row['total_amount'] as double);
        return ExpenseCategory(
          category: _translateCategory(
              row['category'] as String), // ✅ Traducir categorías
          amount: amount,
          transactionCount: row['transaction_count'] as int,
          percentage: totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0,
        );
      }).toList();

      return IncomeStatement(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netIncome: netIncome,
        incomeCategories: incomeCategories,
        expenseCategories: expenseCategories,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      print('❌ Error al generar estado de resultados: $e');
      rethrow;
    }
  }

  // ==================== FLUJO DE CAJA ====================

  static Future<CashFlowReport> generateCashFlowReport(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener flujo diario
      const dailyQuery = '''
        SELECT 
          DATE(date) as flow_date,
          SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as daily_income,
          SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as daily_expenses,
          COUNT(*) as transaction_count
        FROM accounting_entries 
        WHERE date BETWEEN ? AND ?
        GROUP BY DATE(date)
        ORDER BY flow_date
      ''';

      final dailyResults = await db.rawQuery(dailyQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Calcular totales
      final totalIncome = dailyResults.fold<double>(
          0,
          (sum, row) =>
              sum +
              (row['daily_income'] is int
                  ? (row['daily_income'] as int).toDouble()
                  : (row['daily_income'] as double)));
      final totalExpenses = dailyResults.fold<double>(
          0,
          (sum, row) =>
              sum +
              (row['daily_expenses'] is int
                  ? (row['daily_expenses'] as int).toDouble()
                  : (row['daily_expenses'] as double)));
      final netCashFlow = totalIncome - totalExpenses;

      // Crear flujos diarios
      final dailyFlows = dailyResults.map((row) {
        final income = row['daily_income'] is int
            ? (row['daily_income'] as int).toDouble()
            : (row['daily_income'] as double);
        final expenses = row['daily_expenses'] is int
            ? (row['daily_expenses'] as int).toDouble()
            : (row['daily_expenses'] as double);
        return DailyCashFlow(
          date: DateTime.parse(row['flow_date'] as String),
          income: income,
          expenses: expenses,
          netFlow: income - expenses,
          transactionCount: row['transaction_count'] as int,
        );
      }).toList();

      // Obtener efectivo inicial y final (aproximado)
      final initialCash = await _getInitialCashForPeriod(fromDate);
      final finalCash = initialCash + netCashFlow;

      return CashFlowReport(
        initialCash: initialCash,
        finalCash: finalCash,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netCashFlow: netCashFlow,
        dailyFlows: dailyFlows,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      print('❌ Error al generar reporte de flujo de caja: $e');
      rethrow;
    }
  }

  // ==================== REPORTE DE SESIONES DE CAJA ====================

  static Future<CashSessionReport> generateCashSessionReport(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final startDay =
          DateTime(fromDate.year, fromDate.month, fromDate.day);
      final endDay = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      // Sesiones que solapan el período (incluye turnos de varios cajeros el mismo día).
      const sessionQuery = '''
        SELECT cs.*
        FROM cash_sessions cs
        WHERE (cs.is_active IS NULL OR cs.is_active = 1)
          AND cs.open_date < ?
          AND (cs.close_date IS NULL OR trim(cs.close_date) = ''
               OR cs.close_date >= ?)
        ORDER BY cs.open_date DESC
      ''';

      final sessionResults = await db.rawQuery(sessionQuery, [
        endDay.toIso8601String(),
        startDay.toIso8601String(),
      ]);

      // Crear resúmenes de sesiones (totales desde accounting_entries para precisión)
      final sessions = <CashSessionSummary>[];
      for (final row in sessionResults) {
        final sessionId = row['id'] as int;
        final transactionCount =
            await _getTransactionCountForSession(sessionId);

        // Totales reales desde transacciones (así el reporte muestra datos reales)
        final computed = await _getSessionTotalsFromEntries(db, sessionId);

        // Obtener el nombre del usuario por separado
        String userName = 'Usuario desconocido';
        if (row['user_id'] != null) {
          final userRow = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [row['user_id']],
          );
          if (userRow.isNotEmpty) {
            userName =
                userRow.first['fullName'] as String? ?? 'Usuario desconocido';
          }
        }

        // Valores numéricos pueden ser null (sesión abierta o sin cerrar)
        final initialAmount = (row['initial_amount'] is num)
            ? (row['initial_amount'] as num).toDouble()
            : 0.0;
        final totalIncome = computed['income'] ?? 0.0;
        final totalExpense = computed['expense'] ?? 0.0;
        final finalAmount = (row['final_amount'] is num)
            ? (row['final_amount'] as num).toDouble()
            : (initialAmount + totalIncome - totalExpense);
        final difference = finalAmount - initialAmount;
        final status = row['status'] != null ? row['status'] as String : 'open';

        sessions.add(CashSessionSummary(
          sessionId: row['id'] as int,
          userName: userName,
          openDate: DateTime.parse(row['open_date'] as String),
          closeDate: row['close_date'] != null
              ? DateTime.parse(row['close_date'] as String)
              : null,
          initialAmount: initialAmount,
          finalAmount: finalAmount,
          totalIncome: totalIncome,
          totalExpenses: totalExpense,
          difference: difference,
          status: status,
          transactionCount: transactionCount,
        ));
      }

      // Calcular totales
      final totalInitialCash = sessions.fold<double>(
          0, (sum, session) => sum + session.initialAmount);
      final totalFinalCash =
          sessions.fold<double>(0, (sum, session) => sum + session.finalAmount);
      final totalIncome =
          sessions.fold<double>(0, (sum, session) => sum + session.totalIncome);
      final totalExpenses = sessions.fold<double>(
          0, (sum, session) => sum + session.totalExpenses);

      return CashSessionReport(
        sessions: sessions,
        totalInitialCash: totalInitialCash,
        totalFinalCash: totalFinalCash,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        totalSessions: sessions.length,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      print('❌ Error al generar reporte de sesiones de caja: $e');
      rethrow;
    }
  }

  // ==================== AUDITORÍA DE TRANSACCIONES ====================

  static Future<TransactionAuditReport> generateTransactionAuditReport(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener todas las transacciones sin JOIN
      const transactionQuery = '''
        SELECT ae.*
        FROM accounting_entries ae
        WHERE ae.date BETWEEN ? AND ?
        ORDER BY ae.date DESC, ae.id DESC
      ''';

      final transactionResults = await db.rawQuery(transactionQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Crear entradas de auditoría
      final entries = <TransactionAuditEntry>[];
      for (final row in transactionResults) {
        // Obtener el nombre del usuario por separado
        String userName = 'Usuario desconocido';
        if (row['user_id'] != null) {
          final userRow = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [row['user_id']],
          );
          if (userRow.isNotEmpty) {
            userName =
                userRow.first['fullName'] as String? ?? 'Usuario desconocido';
          }
        }

        entries.add(TransactionAuditEntry(
          id: row['id'] as int,
          type: row['type'] as String,
          amount: (row['amount'] as num).toDouble(),
          description: row['description'] as String,
          category: _translateCategory(
              row['category'] as String), // ✅ Traducir categorías
          paymentMethod: _translatePaymentMethod(
              row['payment_method'] as String? ??
                  'N/A'), // ✅ Traducir métodos de pago
          userName: userName,
          date: DateTime.parse(row['date'] as String),
          reference: row['reference'] as String?,
          documentNumber: row['document_number'] as String?,
          notes: row['notes'] as String?,
        ));
      }

      // Calcular estadísticas
      final totalTransactions = entries.length;
      final totalAmount =
          entries.fold<double>(0, (sum, entry) => sum + entry.amount);

      final transactionsByType = <String, int>{};
      final transactionsByUser = <String, int>{};

      for (final entry in entries) {
        transactionsByType[entry.type] =
            (transactionsByType[entry.type] ?? 0) + 1;
        transactionsByUser[entry.userName] =
            (transactionsByUser[entry.userName] ?? 0) + 1;
      }

      return TransactionAuditReport(
        entries: entries,
        totalTransactions: totalTransactions,
        totalAmount: totalAmount,
        transactionsByType: transactionsByType,
        transactionsByUser: transactionsByUser,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      print('❌ Error al generar reporte de auditoría: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS AUXILIARES ====================

  static Future<double> _getInitialCashForPeriod(DateTime fromDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return 0.0;

      // Obtener la última sesión cerrada antes del período
      const query = '''
        SELECT final_amount 
        FROM cash_sessions 
        WHERE status = 'closed' 
        AND close_date < ?
        ORDER BY close_date DESC 
        LIMIT 1
      ''';

      final result = await db.rawQuery(query, [fromDate.toIso8601String()]);

      if (result.isNotEmpty) {
        final val = result.first['final_amount'];
        return (val is num) ? val.toDouble() : 0.0;
      }

      return 0.0;
    } catch (e) {
      print('❌ Error al obtener efectivo inicial: $e');
      return 0.0;
    }
  }

  // ✅ NUEVO: Función para traducir categorías de inglés a español
  static String _translateCategory(String category) {
    switch (category.toUpperCase()) {
      case 'SALES':
      case 'VENTAS':
      case 'PURCHASES':
      case 'COMPRAS':
        return 'Ventas';
      case 'SUPPLIER_PAYMENT':
      case 'PAGO_PROVEEDORES':
      case 'PAGO A PROVEEDORES':
      case 'SUPPLIER_PAYMENTS':
        return 'Pago a Proveedores';
      case 'SUPPLIER_RETURNS':
      case 'DEVOLUCIONES A PROVEEDORES':
        return 'Devoluciones a Proveedores';
      case 'INCOME':
      case 'INGRESOS':
        return 'Ingresos';
      case 'EXPENSE':
      case 'GASTOS':
      case 'GASTOS OPERATIVOS':
        return 'Gastos Operativos';
      case 'CUSTOMER_PAYMENTS':
      case 'PAGOS DE CLIENTES':
      case 'PAYMENTS':
      case 'PAGOS':
        return 'Pagos de Clientes';
      case 'OTHER_INCOME':
        return 'Otros ingresos';
      case 'ELECTRONIC_INVOICE':
        return 'Facturas electrónicas';
      case 'INVOICE_PAYMENT':
        return 'Pagos de facturas';
      case 'OPERATIONAL':
        return 'Gastos operativos';
      case 'ADMINISTRATIVE':
        return 'Gastos administrativos';
      case 'REFUNDS':
        return 'Devoluciones';
      case 'CASH':
      case 'EFECTIVO':
        return 'Efectivo';
      case 'OTHER':
      case 'OTROS':
      case 'SIN_CATEGORIA':
        return 'Otros';
      default:
        return category; // Si ya está en español, dejarlo igual
    }
  }

  // ✅ NUEVO: Función para traducir métodos de pago
  static String _translatePaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
      case 'EFECTIVO':
        return 'Efectivo';
      case 'CARD':
      case 'TARJETA':
      case 'CREDIT_CARD':
      case 'TARJETA_CREDITO':
        return 'Tarjeta';
      case 'TRANSFER':
      case 'TRANSFERENCIA':
        return 'Transferencia';
      case 'DEBIT_CARD':
      case 'TARJETA_DEBITO':
        return 'Tarjeta Débito';
      case 'CREDIT':
      case 'CREDITO':
        return 'Crédito';
      case 'ADJUSTMENT':
      case 'AJUSTE':
        return 'Ajuste';
      case 'N/A':
      case 'NO_APLICA':
        return 'N/A';
      default:
        return method; // Si ya está en español, dejarlo igual
    }
  }

  /// Totales de ingresos y egresos de una sesión desde accounting_entries.
  static Future<Map<String, double>> _getSessionTotalsFromEntries(
      dynamic db, int sessionId) async {
    try {
      final incomeResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM accounting_entries WHERE cash_session_id = ? AND type = ?',
        [sessionId, 'income'],
      );
      final expenseResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM accounting_entries WHERE cash_session_id = ? AND type = ?',
        [sessionId, 'expense'],
      );
      final income =
          (incomeResult.isNotEmpty && incomeResult.first['total'] is num)
              ? (incomeResult.first['total'] as num).toDouble()
              : 0.0;
      final expense =
          (expenseResult.isNotEmpty && expenseResult.first['total'] is num)
              ? (expenseResult.first['total'] as num).toDouble()
              : 0.0;
      return {'income': income, 'expense': expense};
    } catch (e) {
      print('❌ Error al obtener totales de sesión: $e');
      return {'income': 0.0, 'expense': 0.0};
    }
  }

  static Future<int> _getTransactionCountForSession(int sessionId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return 0;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM accounting_entries WHERE cash_session_id = ?',
        [sessionId],
      );

      return result.first['count'] as int;
    } catch (e) {
      print('❌ Error al obtener conteo de transacciones: $e');
      return 0;
    }
  }

  // ==================== REPORTES RÁPIDOS ====================

  /// Ingresos del período agrupados por medio de pago (Efectivo, Tarjeta, etc.).
  static Future<Map<String, double>> getIncomeByPaymentMethod(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};

      final endOfDay =
          DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      final result = await db.rawQuery(
        '''SELECT COALESCE(payment_method, 'Efectivo') as method, SUM(amount) as total
           FROM accounting_entries
           WHERE type = ? AND date >= ? AND date <= ?
           GROUP BY COALESCE(payment_method, 'Efectivo')''',
        ['income', fromDate.toIso8601String(), endOfDay.toIso8601String()],
      );

      final map = <String, double>{};
      for (final row in result) {
        final method = row['method'] as String? ?? 'Efectivo';
        final total =
            (row['total'] is num) ? (row['total'] as num).toDouble() : 0.0;
        if (total > 0) map[method] = total;
      }
      return map;
    } catch (e) {
      print('❌ Error al obtener ingresos por método de pago: $e');
      return {};
    }
  }

  /// Egresos del período agrupados por medio de pago.
  static Future<Map<String, double>> getExpensesByPaymentMethod(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};

      final endOfDay =
          DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      final result = await db.rawQuery(
        '''SELECT COALESCE(payment_method, 'Efectivo') as method, SUM(amount) as total
           FROM accounting_entries
           WHERE type = ? AND date >= ? AND date <= ?
           GROUP BY COALESCE(payment_method, 'Efectivo')''',
        ['expense', fromDate.toIso8601String(), endOfDay.toIso8601String()],
      );

      final map = <String, double>{};
      for (final row in result) {
        final method = row['method'] as String? ?? 'Efectivo';
        final total =
            (row['total'] is num) ? (row['total'] as num).toDouble() : 0.0;
        if (total > 0) map[method] = total;
      }
      return map;
    } catch (e) {
      print('❌ Error al obtener egresos por método de pago: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getQuickSummary(
      DateTime fromDate, DateTime toDate) async {
    try {
      final incomeStatement = await generateIncomeStatement(fromDate, toDate);
      final cashFlow = await generateCashFlowReport(fromDate, toDate);
      final incomeByPaymentMethod =
          await getIncomeByPaymentMethod(fromDate, toDate);
      final expensesByPaymentMethod =
          await getExpensesByPaymentMethod(fromDate, toDate);

      return {
        'period':
            '${fromDate.day}/${fromDate.month}/${fromDate.year} - ${toDate.day}/${toDate.month}/${toDate.year}',
        'total_income': incomeStatement.totalIncome,
        'total_expenses': incomeStatement.totalExpenses,
        'net_income': incomeStatement.netIncome,
        'balance': incomeStatement.netIncome,
        'cash_flow': cashFlow.netCashFlow,
        'transaction_count': incomeStatement.incomeCategories
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount) +
            incomeStatement.expenseCategories
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount),
        'income_by_payment_method': incomeByPaymentMethod,
        'expenses_by_payment_method': expensesByPaymentMethod,
      };
    } catch (e) {
      print('❌ Error al generar resumen rápido: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _aggregateSalesForCierre(
    dynamic db,
    List<Map<String, dynamic>> salesRows,
  ) async {
    int numVentas = 0;
    int numAnuladas = 0;
    double montoAnuladas = 0.0;
    double ventaBruta = 0, descuentos = 0, devoluciones = 0;
    double ivaIncluido = 0.0;
    final byMethod = <String, Map<String, dynamic>>{};
    final ventasPorTarifaIva = <String, double>{};
    final ivaPorTarifa = <String, double>{};
    final ivaByProductIdCache = <int, int>{};
    final ivaByNameUnitCache = <String, int>{};

    for (final s in salesRows) {
      final anulada = (s['anulada'] as int? ?? 0) == 1;
      if (anulada) {
        numAnuladas++;
        montoAnuladas += (s['total'] as num?)?.toDouble() ?? 0;
        continue;
      }
      final isReturn = (s['isReturn'] as int? ?? 0) == 1;
      final total = (s['total'] as num?)?.toDouble() ?? 0;
      final discount = (s['discount'] as num?)?.toDouble() ?? 0;
      final returned = (s['returnedAmount'] as num?)?.toDouble();

      if (isReturn) {
        devoluciones += (returned ?? total);
        continue;
      }
      numVentas++;
      ventaBruta += total;
      descuentos += discount;

      try {
        final itemsStr = s['items'] as String?;
        if (itemsStr != null &&
            itemsStr.isNotEmpty &&
            itemsStr.contains('[')) {
          final list = jsonDecode(itemsStr) as List<dynamic>?;
          if (list != null) {
            for (final e in list) {
              if (e is! Map) continue;
              final item = Map<String, dynamic>.from(e);
              final price = (item['price'] is num)
                  ? (item['price'] as num).toDouble()
                  : 0.0;
              final qty = (item['quantity'] is int)
                  ? item['quantity'] as int
                  : (item['quantity'] as num?)?.toInt() ?? 0;
              int? ivaPct = (item['ivaPercentage'] is int)
                  ? item['ivaPercentage'] as int
                  : (item['ivaPercentage'] as num?)?.toInt();
              if (ivaPct == null) {
                final productId = (item['productId'] is int)
                    ? item['productId'] as int
                    : (item['productId'] as num?)?.toInt();
                if (productId != null) {
                  ivaPct = ivaByProductIdCache[productId];
                  if (ivaPct == null) {
                    final productRows = await db.query(
                      'products',
                      columns: ['ivaPercentage'],
                      where: 'id = ?',
                      whereArgs: [productId],
                      limit: 1,
                    );
                    ivaPct = productRows.isNotEmpty
                        ? (productRows.first['ivaPercentage'] as num?)
                                ?.toInt() ??
                            0
                        : 0;
                    ivaByProductIdCache[productId] = ivaPct;
                  }
                } else {
                  final name = (item['name'] as String? ?? '').trim();
                  final unit = (item['unit'] as String? ?? '').trim();
                  final key = '${name.toLowerCase()}|${unit.toLowerCase()}';
                  ivaPct = ivaByNameUnitCache[key];
                  if (ivaPct == null && name.isNotEmpty) {
                    final productRows = await db.query(
                      'products',
                      columns: ['ivaPercentage'],
                      where: 'LOWER(name) = ? AND LOWER(unit) = ?',
                      whereArgs: [name.toLowerCase(), unit.toLowerCase()],
                      limit: 1,
                    );
                    ivaPct = productRows.isNotEmpty
                        ? (productRows.first['ivaPercentage'] as num?)
                                ?.toInt() ??
                            0
                        : 0;
                    ivaByNameUnitCache[key] = ivaPct;
                  }
                  ivaPct ??= 0;
                }
              }
              final revenue = price * qty;
              final rateKey = ivaPct.toString();
              ventasPorTarifaIva[rateKey] =
                  (ventasPorTarifaIva[rateKey] ?? 0.0) + revenue;
              if (ivaPct > 0) {
                final ivaAmount =
                    revenue * (ivaPct / 100) / (1 + ivaPct / 100);
                ivaPorTarifa[rateKey] =
                    (ivaPorTarifa[rateKey] ?? 0.0) + ivaAmount;
                ivaIncluido += revenue * (ivaPct / 100) / (1 + ivaPct / 100);
              } else {
                ivaPorTarifa.putIfAbsent(rateKey, () => 0.0);
              }
            }
          }
        }
      } catch (_) {}

      final pbStr = s['payment_breakdown'] as String?;
      if (pbStr != null && pbStr.isNotEmpty) {
        try {
          final list = (jsonDecode(pbStr) as List<dynamic>?);
          if (list != null) {
            for (final e in list) {
              final m = e as Map<String, dynamic>;
              final method = m['method'] as String? ?? 'Efectivo';
              final amount =
                  (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0;
              byMethod.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
              byMethod[method]!['amount'] =
                  (byMethod[method]!['amount'] as double) + amount;
              byMethod[method]!['count'] =
                  (byMethod[method]!['count'] as int) + 1;
            }
          }
        } catch (_) {}
      } else {
        final method = s['paymentMethod'] as String? ?? 'Efectivo';
        byMethod.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
        byMethod[method]!['amount'] =
            (byMethod[method]!['amount'] as double) + total;
        byMethod[method]!['count'] = (byMethod[method]!['count'] as int) + 1;
      }
    }

    final ventaNeta = ventaBruta - descuentos - devoluciones;
    final ticketPromedio = numVentas > 0 ? ventaBruta / numVentas : 0.0;

    return {
      'numVentas': numVentas,
      'numAnuladas': numAnuladas,
      'montoAnuladas': montoAnuladas,
      'ticketPromedio': ticketPromedio,
      'ventaBruta': ventaBruta,
      'descuentos': descuentos,
      'devoluciones': devoluciones,
      'ventaNeta': ventaNeta,
      'ivaIncluido': ivaIncluido,
      'ventasPorTarifaIva': ventasPorTarifaIva,
      'ivaPorTarifa': ivaPorTarifa,
      'byMethod': byMethod,
    };
  }

  static Map<String, dynamic> _aggregateCashEntriesForCierre(
    List<Map<String, dynamic>> entries,
  ) {
    double otrosIngresos = 0,
        retiros = 0,
        gastos = 0,
        devolucionesEfectivo = 0;
    final retirosList = <Map<String, dynamic>>[];
    final cashIncomeDetails = <Map<String, dynamic>>[];
    final cashExpenseDetails = <Map<String, dynamic>>[];

    for (final e in entries) {
      final type = e['type'] as String? ?? '';
      final category = (e['category'] as String? ?? '').toUpperCase();
      final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
      final desc = e['description'] as String? ?? '';
      final paymentMethod = e['payment_method'] as String?;
      final reference = e['reference'] as String?;
      final documentNumber = e['document_number'] as String?;
      final date =
          e['date'] != null ? DateTime.parse(e['date'] as String) : null;
      final isCashMovement = _isCashPaymentMethod(paymentMethod);

      Map<String, dynamic> detailEntry() => {
            'time': date != null
                ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                : '',
            'description': desc,
            'category': _translateCategory(e['category'] as String? ?? ''),
            'amount': amount,
            'paymentMethod': paymentMethod ?? 'N/A',
            'reference': reference,
            'documentNumber': documentNumber,
          };

      if (type == 'income') {
        if (category.contains('VENTA') || category.contains('SALES')) {
          continue;
        }
        if (isCashMovement) {
          otrosIngresos += amount;
          cashIncomeDetails.add(detailEntry());
        }
      } else if (type == 'expense') {
        if (category.contains('RETIRO') ||
            desc.toLowerCase().contains('retiro')) {
          if (isCashMovement) {
            retiros += amount;
            retirosList.add({
              'time': date != null
                  ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                  : '',
              'description': desc,
              'amount': amount,
            });
            cashExpenseDetails.add(detailEntry());
          }
        } else if (category.contains('DEVOLUCIÓN') ||
            category.contains('RETURN')) {
          if (isCashMovement) {
            devolucionesEfectivo += amount;
            cashExpenseDetails.add(detailEntry());
          }
        } else {
          if (isCashMovement) {
            gastos += amount;
            cashExpenseDetails.add(detailEntry());
          }
        }
      }
    }

    return {
      'otrosIngresos': otrosIngresos,
      'retiros': retiros,
      'gastos': gastos,
      'devolucionesEfectivo': devolucionesEfectivo,
      'retirosList': retirosList,
      'cashIncomeDetails': cashIncomeDetails,
      'cashExpenseDetails': cashExpenseDetails,
    };
  }

  /// Cierre consolidado del período: todas las sesiones y ventas de todos los cajeros.
  /// Alineado con «Movimientos del día» (filtro por fechas, no por un solo usuario).
  static Future<Map<String, dynamic>?> getCierreDeCajaDataForPeriod(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return null;

      final startDay =
          DateTime(fromDate.year, fromDate.month, fromDate.day);
      final endDay = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      // Comparación directa ISO8601 (datetime() en SQLite falla con formato ...T...).
      final sessionRows = await db.rawQuery(
        '''
        SELECT cs.* FROM cash_sessions cs
        WHERE (cs.is_active IS NULL OR cs.is_active = 1)
          AND cs.open_date < ?
          AND (cs.close_date IS NULL OR trim(cs.close_date) = ''
               OR cs.close_date >= ?)
        ORDER BY cs.open_date ASC
        ''',
        [endDay.toIso8601String(), startDay.toIso8601String()],
      );

      double initialAmount = 0;
      final sessionsBreakdown = <Map<String, dynamic>>[];
      final userNames = <String>{};
      DateTime? firstOpen;
      DateTime? lastClose;

      for (final row in sessionRows) {
        final openDate = DateTime.parse(row['open_date'] as String);
        final hasClose = row['close_date'] != null &&
            (row['close_date'] as String).trim().isNotEmpty;
        final closeDate = hasClose
            ? DateTime.parse(row['close_date'] as String)
            : DateTime.now();
        final init = (row['initial_amount'] as num?)?.toDouble() ?? 0.0;
        initialAmount += init;
        firstOpen ??= openDate;
        lastClose = closeDate;

        String sessionUser = 'Cajero';
        final uid = row['user_id'] as int?;
        if (uid != null) {
          final u = await db.query('users',
              columns: ['fullName', 'username'],
              where: 'id = ?',
              whereArgs: [uid]);
          if (u.isNotEmpty) {
            final full = (u.first['fullName'] as String?)?.trim();
            final login = (u.first['username'] as String?)?.trim();
            if (full != null && full.isNotEmpty) {
              sessionUser = full;
            } else if (login != null && login.isNotEmpty) {
              sessionUser = login;
            }
            userNames.add(sessionUser);
          }
        }

        sessionsBreakdown.add({
          'sessionId': row['id'],
          'userName': sessionUser,
          'openDate': openDate,
          'closeDate': hasClose ? closeDate : null,
          'initialAmount': init,
          'status': row['status'] as String? ?? 'open',
        });
      }

      final userName = userNames.isEmpty
          ? 'Sin sesión registrada'
          : userNames.length == 1
              ? userNames.first
              : 'Varios cajeros (${userNames.length})';

      final salesRows = await db.rawQuery(
        "SELECT id, date, total, items, paymentMethod, payment_breakdown, discount, isReturn, returnedAmount, anulada, user "
        "FROM sales WHERE date >= ? AND date < ? ORDER BY date",
        [startDay.toIso8601String(), endDay.toIso8601String()],
      );

      final salesAgg = await _aggregateSalesForCierre(db, salesRows);
      final salesByCashierDay = _aggregateSalesByCashier(salesRows);

      // Arqueo físico: solo el ÚLTIMO turno (sesión). Las ventas del día van aparte.
      final int? arqueoSessionId = sessionRows.isNotEmpty
          ? sessionRows.last['id'] as int?
          : null;
      Map<String, dynamic>? arqueoTurno;
      if (arqueoSessionId != null) {
        arqueoTurno = await getCierreDeCajaData(arqueoSessionId);
      }

      final arqueoInitial =
          (arqueoTurno?['initialAmount'] as num?)?.toDouble() ?? initialAmount;
      final arqueoVentasEfectivo =
          (arqueoTurno?['ventasEfectivo'] as num?)?.toDouble() ?? 0.0;
      final arqueoSaldoEsperado =
          (arqueoTurno?['saldoEsperado'] as num?)?.toDouble() ?? arqueoInitial;
      final arqueoSaldoReal = (arqueoTurno?['saldoReal'] as num?)?.toDouble() ??
          (arqueoTurno?['finalAmount'] as num?)?.toDouble() ??
          arqueoSaldoEsperado;
      final arqueoDiferencia =
          (arqueoTurno?['diferencia'] as num?)?.toDouble() ??
          (arqueoSaldoReal - arqueoSaldoEsperado);

      return {
        'sessionId': arqueoSessionId,
        'arqueoSessionId': arqueoSessionId,
        'sessionCount': sessionRows.length,
        'sessionsBreakdown': sessionsBreakdown,
        'consolidated': true,
        'openDate': arqueoTurno?['openDate'] as DateTime? ?? firstOpen ?? fromDate,
        'closeDate': arqueoTurno?['closeDate'] as DateTime? ?? lastClose ?? toDate,
        'periodFrom': fromDate,
        'periodTo': toDate,
        'userName': arqueoTurno?['userName'] as String? ?? userName,
        'openedByUserName': arqueoTurno?['openedByUserName'],
        'closedByUserName': arqueoTurno?['closedByUserName'],
        'salesByCashier': arqueoTurno?['salesByCashier'] ?? salesByCashierDay,
        'salesByCashierDia': salesByCashierDay,
        'salesByCashierTurno': arqueoTurno?['salesByCashier'],
        // Resumen de ventas = día completo (varios turnos).
        ...salesAgg,
        // Arqueo de caja = solo el turno que se está cerrando / último del período.
        'initialAmount': arqueoInitial,
        'finalAmount': arqueoTurno?['finalAmount'],
        'ventasEfectivo': arqueoVentasEfectivo,
        'otrosIngresos': (arqueoTurno?['otrosIngresos'] as num?)?.toDouble() ?? 0.0,
        'retiros': (arqueoTurno?['retiros'] as num?)?.toDouble() ?? 0.0,
        'gastos': (arqueoTurno?['gastos'] as num?)?.toDouble() ?? 0.0,
        'devolucionesEfectivo':
            (arqueoTurno?['devolucionesEfectivo'] as num?)?.toDouble() ?? 0.0,
        'retirosList': arqueoTurno?['retirosList'] ?? <Map<String, dynamic>>[],
        'cashIncomeDetails':
            arqueoTurno?['cashIncomeDetails'] ?? <Map<String, dynamic>>[],
        'cashExpenseDetails':
            arqueoTurno?['cashExpenseDetails'] ?? <Map<String, dynamic>>[],
        'saldoEsperado': arqueoSaldoEsperado,
        'saldoReal': arqueoSaldoReal,
        'diferencia': arqueoDiferencia,
      };
    } catch (e) {
      print('❌ Error getCierreDeCajaDataForPeriod: $e');
      return null;
    }
  }

  static Future<String> _resolveUserDisplayName(
    dynamic db,
    int? userId,
  ) async {
    if (userId == null) return 'Cajero';
    final userRows = await db.query(
      'users',
      columns: ['fullName', 'username'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (userRows.isEmpty) return 'Cajero';
    final full = (userRows.first['fullName'] as String?)?.trim();
    final login = (userRows.first['username'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    if (login != null && login.isNotEmpty) return login;
    return 'Cajero';
  }

  static List<MapEntry<String, double>> _paymentAmountsFromSale(
    Map<String, dynamic> s,
  ) {
    final total = (s['total'] as num?)?.toDouble() ?? 0.0;
    final pbStr = s['payment_breakdown'] as String?;
    if (pbStr != null && pbStr.isNotEmpty) {
      try {
        final list = jsonDecode(pbStr) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          return list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final method = (m['method'] as String?)?.trim().isNotEmpty == true
                ? (m['method'] as String).trim()
                : 'Efectivo';
            final amount = (m['amount'] is num)
                ? (m['amount'] as num).toDouble()
                : 0.0;
            return MapEntry(method, amount);
          }).toList();
        }
      } catch (_) {}
    }
    final method = (s['paymentMethod'] as String?)?.trim().isNotEmpty == true
        ? (s['paymentMethod'] as String).trim()
        : 'Efectivo';
    return [MapEntry(method, total)];
  }

  static List<Map<String, dynamic>> _aggregateSalesByCashier(
    List<Map<String, dynamic>> salesRows,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final s in salesRows) {
      if ((s['anulada'] as int? ?? 0) == 1) continue;
      if ((s['isReturn'] as int? ?? 0) == 1) continue;
      final raw = (s['user'] as String?)?.trim();
      final key =
          (raw == null || raw.isEmpty) ? 'Sin cajero registrado' : raw;
      map.putIfAbsent(
        key,
        () => {
          'userName': key,
          'count': 0,
          'total': 0.0,
          'byMethod': <String, Map<String, dynamic>>{},
        },
      );
      map[key]!['count'] = (map[key]!['count'] as int) + 1;
      map[key]!['total'] = (map[key]!['total'] as double) +
          ((s['total'] as num?)?.toDouble() ?? 0.0);

      final methodsMap =
          map[key]!['byMethod'] as Map<String, Map<String, dynamic>>;
      for (final pay in _paymentAmountsFromSale(s)) {
        methodsMap.putIfAbsent(
          pay.key,
          () => {'amount': 0.0, 'count': 0},
        );
        methodsMap[pay.key]!['amount'] =
            (methodsMap[pay.key]!['amount'] as double) + pay.value;
        methodsMap[pay.key]!['count'] =
            (methodsMap[pay.key]!['count'] as int) + 1;
      }
    }
    final list = map.values.toList()
      ..sort(
          (a, b) => (a['userName'] as String).compareTo(b['userName'] as String));
    for (final row in list) {
      final methodsMap =
          row['byMethod'] as Map<String, Map<String, dynamic>>;
      row['byMethod'] = methodsMap.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
      );
    }
    return list;
  }

  /// Cabecera del ticket: quién abrió la caja vs quién cierra/arquea.
  static void writeCierreTicketSessionInfo(
    StringBuffer sb,
    Map<String, dynamic> data, {
    required void Function(String left, String right) lineLR,
    required String Function(DateTime) fmtTime,
  }) {
    final sessionId = data['sessionId'] as int? ?? 0;
    final openDate = data['openDate'] as DateTime?;
    final openedBy = data['openedByUserName'] as String?;
    final closedBy = data['closedByUserName'] as String? ??
        data['userName'] as String? ??
        'Cajero';
    final samePerson = openedBy != null &&
        openedBy.toLowerCase().trim() == closedBy.toLowerCase().trim();

    if (openedBy != null && !samePerson) {
      lineLR('Sesion caja #${sessionId.toString().padLeft(2, '0')}', '');
      lineLR('Caja abierta por:', openedBy);
      lineLR('Cierre / arqueo:', closedBy);
      if (openDate != null) {
        lineLR('Hora apertura:', fmtTime(openDate));
      }
      lineLR('Nota:', 'Misma caja fisica del turno');
    } else {
      lineLR('Caja: ${sessionId.toString().padLeft(2, '0')}',
          'Cajero: $closedBy');
      if (openDate != null) {
        lineLR('Turno:', 'Apertura ${fmtTime(openDate)}');
      }
    }
  }

  static void writeCierreTicketSalesByCashier(
    StringBuffer sb,
    Map<String, dynamic> data, {
    required void Function(String label, String value) lineVal,
    required String dashW,
    required String Function(double) fmtNum,
  }) {
    final list = data['salesByCashier'] as List<dynamic>? ?? [];
    if (list.isEmpty) return;
    sb.writeln('');
    sb.writeln('VENTAS POR CAJERO Y MEDIO DE PAGO');
    sb.writeln(dashW);
    for (final raw in list) {
      if (raw is! Map) continue;
      final name = raw['userName'] as String? ?? '?';
      final count = raw['count'] as int? ?? 0;
      final total = (raw['total'] as num?)?.toDouble() ?? 0.0;
      final ventas = count == 1 ? '1 venta' : '$count ventas';
      lineVal('  $name', '$ventas · \$${fmtNum(total)}');
      final byMethod = raw['byMethod'] as Map<String, dynamic>? ?? {};
      if (byMethod.isEmpty) continue;
      final methods = byMethod.keys.toList()..sort();
      for (final method in methods) {
        final bucket = byMethod[method];
        if (bucket is! Map) continue;
        final amt = (bucket['amount'] as num?)?.toDouble() ?? 0.0;
        final cnt = bucket['count'] as int? ?? 0;
        final cntStr = cnt == 1 ? '1 venta' : '$cnt ventas';
        lineVal('    · $method', '\$${fmtNum(amt)} ($cntStr)');
      }
    }
  }

  /// Datos para imprimir reporte de Cierre de Caja (una sesión).
  /// Requiere: ventas del período de la sesión, sesión, y movimientos contables de la sesión.
  static Future<Map<String, dynamic>?> getCierreDeCajaData(
      int sessionId) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return null;

      final sessionRows = await db
          .query('cash_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionRows.isEmpty) return null;
      final row = sessionRows.first;

      final openDate = DateTime.parse(row['open_date'] as String);
      final hasCloseDate = row['close_date'] != null &&
          (row['close_date'] as String).trim().isNotEmpty;
      // Si la sesión está abierta (sin cierre), incluir ventas hasta hoy para que anulaciones del día se vean
      final closeDate = hasCloseDate
          ? DateTime.parse(row['close_date'] as String)
          : DateTime.now();
      final initialAmount = (row['initial_amount'] as num?)?.toDouble() ?? 0.0;
      final finalAmount = (row['final_amount'] as num?)?.toDouble();
      final openedByUserId = row['user_id'] as int?;
      final closedByUserId = row['closed_by_user_id'] as int?;

      final openedByUserName =
          await _resolveUserDisplayName(db, openedByUserId);
      final closedByUserName =
          await _resolveUserDisplayName(db, closedByUserId ?? openedByUserId);
      final userName = closedByUserName;

      // Ventas solo dentro del intervalo real de la sesión (apertura → cierre).
      final salesRows = await db.rawQuery(
        "SELECT id, date, total, items, paymentMethod, payment_breakdown, discount, isReturn, returnedAmount, anulada, user "
        "FROM sales WHERE date >= ? AND date <= ? ORDER BY date",
        [openDate.toIso8601String(), closeDate.toIso8601String()],
      );

      final salesByCashier = _aggregateSalesByCashier(salesRows);

      final salesAgg = await _aggregateSalesForCierre(db, salesRows);
      final byMethod = salesAgg['byMethod'] as Map<String, dynamic>;

      final entries = await db.rawQuery(
        'SELECT type, category, amount, description, date, payment_method, reference, document_number '
        'FROM accounting_entries WHERE cash_session_id = ? ORDER BY date',
        [sessionId],
      );

      final cashAgg = _aggregateCashEntriesForCierre(entries);
      final otrosIngresos = cashAgg['otrosIngresos'] as double;
      final retiros = cashAgg['retiros'] as double;
      final gastos = cashAgg['gastos'] as double;
      final devolucionesEfectivo = cashAgg['devolucionesEfectivo'] as double;
      final retirosList = cashAgg['retirosList'] as List<Map<String, dynamic>>;
      final cashIncomeDetails =
          cashAgg['cashIncomeDetails'] as List<Map<String, dynamic>>;
      final cashExpenseDetails =
          cashAgg['cashExpenseDetails'] as List<Map<String, dynamic>>;

      final ventasEfectivo =
          (byMethod['Efectivo']?['amount'] as num?)?.toDouble() ?? 0.0;
      final saldoEsperado = initialAmount +
          ventasEfectivo +
          otrosIngresos -
          retiros -
          gastos -
          devolucionesEfectivo;
      final saldoReal = finalAmount ?? saldoEsperado;
      final diferencia = (saldoReal - saldoEsperado);

      return {
        'sessionId': sessionId,
        'consolidated': false,
        'sessionCount': 1,
        'openDate': openDate,
        'closeDate': closeDate,
        'userName': userName,
        'openedByUserName': openedByUserName,
        'closedByUserName': closedByUserName,
        'salesByCashier': salesByCashier,
        'initialAmount': initialAmount,
        'finalAmount': finalAmount,
        ...salesAgg,
        'byMethod': byMethod,
        'ventasEfectivo': ventasEfectivo,
        'otrosIngresos': otrosIngresos,
        'retiros': retiros,
        'gastos': gastos,
        'devolucionesEfectivo': devolucionesEfectivo,
        'saldoEsperado': saldoEsperado,
        'saldoReal': saldoReal,
        'diferencia': diferencia,
        'retirosList': retirosList,
        'cashIncomeDetails': cashIncomeDetails,
        'cashExpenseDetails': cashExpenseDetails,
      };
    } catch (e) {
      print('❌ Error getCierreDeCajaData: $e');
      return null;
    }
  }

  static bool _isCashPaymentMethod(String? method) {
    final normalized = (method ?? '')
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
    return normalized.isEmpty ||
        normalized == 'cash' ||
        normalized == 'efectivo' ||
        normalized == 'caja';
  }

  /// Ventas del día (excluye devoluciones): lista de ventas con totales.
  static Future<Map<String, dynamic>> getVentasDiaData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT id, date, total, paymentMethod, discount, user
           FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)
           ORDER BY date''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double ventaBruta = 0;
      double descuentos = 0;

      for (final r in rows) {
        final total = (r['total'] as num?)?.toDouble() ?? 0.0;
        final discount = (r['discount'] as num?)?.toDouble() ?? 0.0;
        ventaBruta += total;
        descuentos += discount;
        list.add({
          'id': r['id'],
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'total': total,
          'paymentMethod': r['paymentMethod'] as String? ?? 'Efectivo',
          'discount': discount,
          'user': r['user'] as String? ?? '',
        });
      }

      final ventaNeta = ventaBruta - descuentos;
      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'ventas': list,
        'cantidad': list.length,
        'ventaBruta': ventaBruta,
        'descuentos': descuentos,
        'ventaNeta': ventaNeta,
      };
    } catch (e) {
      print('❌ Error getVentasDiaData: $e');
      return {
        'ventas': <Map<String, dynamic>>[],
        'cantidad': 0,
        'ventaBruta': 0.0,
        'descuentos': 0.0,
        'ventaNeta': 0.0,
      };
    }
  }

  /// Movimientos del día: entradas contables (ingresos y egresos).
  static Future<Map<String, dynamic>> getMovimientosDiaData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.type, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id
           FROM accounting_entries ae
           WHERE ae.date >= ? AND ae.date < ?
           ORDER BY ae.date''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double totalIngresos = 0;
      double totalEgresos = 0;

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final type = r['type'] as String? ?? '';
        if (type == 'income') {
          totalIngresos += amount;
        } else if (type == 'expense') totalEgresos += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [r['user_id']],
          );
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        list.add({
          'id': r['id'],
          'type': type,
          'amount': amount,
          'description': r['description'] as String? ?? '',
          'category': _translateCategory(r['category'] as String? ?? ''),
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod':
              _translatePaymentMethod(r['payment_method'] as String? ?? 'N/A'),
          'userName': userName,
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'movimientos': list,
        'totalIngresos': totalIngresos,
        'totalEgresos': totalEgresos,
        'saldo': totalIngresos - totalEgresos,
      };
    } catch (e) {
      print('❌ Error getMovimientosDiaData: $e');
      return {
        'movimientos': <Map<String, dynamic>>[],
        'totalIngresos': 0.0,
        'totalEgresos': 0.0,
        'saldo': 0.0,
      };
    }
  }

  /// Movimientos del día (transacciones): todas las ventas y devoluciones del período para el reporte tipo ticket.
  static Future<Map<String, dynamic>> getTransaccionesDiaData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT id, date, total, paymentMethod, user, isReturn
           FROM sales
           WHERE date >= ? AND date < ? AND (anulada IS NULL OR anulada = 0)
           ORDER BY date''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double totalVentas = 0;
      double totalDevoluciones = 0;
      int countVentas = 0;
      int countDevoluciones = 0;

      for (final r in rows) {
        final isReturn = (r['isReturn'] as int?) == 1;
        final total = (r['total'] as num?)?.toDouble() ?? 0.0;
        final amount = isReturn ? -total.abs() : total;
        if (isReturn) {
          countDevoluciones++;
          totalDevoluciones += total.abs();
        } else {
          countVentas++;
          totalVentas += total;
        }
        final payRaw = r['paymentMethod'] as String? ?? 'Efectivo';
        final paymentMethod = _translatePaymentMethod(payRaw);
        list.add({
          'id': r['id'],
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'tipo': isReturn ? 'Devolución' : 'Venta',
          'userName': r['user'] as String? ?? '',
          'paymentMethod': paymentMethod,
          'amount': amount,
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'transacciones': list,
        'totalVentas': totalVentas,
        'totalDevoluciones': totalDevoluciones,
        'neto': totalVentas - totalDevoluciones,
        'countVentas': countVentas,
        'countDevoluciones': countDevoluciones,
      };
    } catch (e) {
      print('❌ Error getTransaccionesDiaData: $e');
      return {
        'transacciones': <Map<String, dynamic>>[],
        'totalVentas': 0.0,
        'totalDevoluciones': 0.0,
        'neto': 0.0,
        'countVentas': 0,
        'countDevoluciones': 0,
      };
    }
  }

  /// Devoluciones: ventas con isReturn = 1. Incluye ticket, hora, cajero, motivo y totales por efectivo/tarjeta.
  static Future<Map<String, dynamic>> getDevolucionesData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT id, date, total, returnedAmount, user, originalSaleId, paymentMethod, payment_breakdown
           FROM sales
           WHERE date >= ? AND date < ? AND isReturn = 1 AND (anulada IS NULL OR anulada = 0)
           ORDER BY date''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double totalDevoluciones = 0;
      double totalEfectivo = 0;
      double totalTarjeta = 0;
      double totalSaldoAfavor = 0;

      for (final r in rows) {
        final amount = (r['returnedAmount'] as num?)?.toDouble() ??
            (r['total'] as num?)?.toDouble() ??
            0.0;
        totalDevoluciones += amount;

        double efectivo = 0.0;
        double tarjeta = 0.0;
        double saldoRow = 0.0;
        final pbStr = r['payment_breakdown'] as String?;
        if (pbStr != null && pbStr.isNotEmpty && pbStr.contains('[')) {
          try {
            final breakdown = jsonDecode(pbStr) as List<dynamic>?;
            if (breakdown != null) {
              for (final e in breakdown) {
                final m = e as Map<String, dynamic>;
                final method =
                    (m['method'] as String? ?? 'Efectivo').toUpperCase();
                final amt = (m['amount'] is num)
                    ? (m['amount'] as num).toDouble()
                    : 0.0;
                if (method.contains('EFECTIVO')) {
                  efectivo += amt;
                } else if (method.contains('SALDO') && method.contains('FAVOR')) {
                  saldoRow += amt;
                } else {
                  tarjeta += amt;
                }
              }
            }
          } catch (_) {}
        }
        if (saldoRow > 0) {
          totalSaldoAfavor += saldoRow;
        }
        if (efectivo == 0 && tarjeta == 0 && saldoRow == 0) {
          final method =
              (r['paymentMethod'] as String? ?? 'Efectivo').toUpperCase();
          if (method.contains('SALDO') && method.contains('FAVOR')) {
            totalSaldoAfavor += amount;
          } else if (method.contains('TARJETA') || method.contains('CARD')) {
            totalTarjeta += amount;
          } else {
            totalEfectivo += amount;
          }
        } else {
          totalEfectivo += efectivo;
          totalTarjeta += tarjeta;
        }

        final date =
            r['date'] != null ? DateTime.parse(r['date'] as String) : null;
        final ticket = (r['id'] as int?).toString().padLeft(5, '0');
        final hora = date != null
            ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
            : '—';
        final cajero = r['user'] as String? ?? '';
        final pm = (r['paymentMethod'] as String?)?.trim();
        final liquidacion = (pm == null || pm.isEmpty) ? '—' : pm;

        list.add({
          'id': r['id'],
          'ticket': ticket,
          'date': date,
          'hora': hora,
          'cajero': cajero,
          'motivo': liquidacion,
          'amount': amount,
          'user': cajero,
          'originalSaleId': r['originalSaleId'],
          'paymentMethod': pm,
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'devoluciones': list,
        'cantidad': list.length,
        'totalDevoluciones': totalDevoluciones,
        'totalEfectivo': totalEfectivo,
        'totalTarjeta': totalTarjeta,
        'totalSaldoAfavor': totalSaldoAfavor,
      };
    } catch (e) {
      print('❌ Error getDevolucionesData: $e');
      return {
        'devoluciones': <Map<String, dynamic>>[],
        'cantidad': 0,
        'totalDevoluciones': 0.0,
        'totalEfectivo': 0.0,
        'totalTarjeta': 0.0,
        'totalSaldoAfavor': 0.0,
      };
    }
  }

  /// Gastos: entradas contables tipo expense.
  static Future<Map<String, dynamic>> getGastosData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id
           FROM accounting_entries ae
           WHERE ae.type = 'expense' AND ae.date >= ? AND ae.date < ?
           ORDER BY ae.date DESC''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double total = 0;

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [r['user_id']],
          );
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        list.add({
          'id': r['id'],
          'amount': amount,
          'description': r['description'] as String? ?? '',
          'category': _translateCategory(r['category'] as String? ?? ''),
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod':
              _translatePaymentMethod(r['payment_method'] as String? ?? 'N/A'),
          'userName': userName,
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'gastos': list,
        'cantidad': list.length,
        'total': total,
      };
    } catch (e) {
      print('❌ Error getGastosData: $e');
      return {
        'gastos': <Map<String, dynamic>>[],
        'cantidad': 0,
        'total': 0.0,
      };
    }
  }

  /// Egresos por método: todos los egresos del período, con resumen por método
  /// y total específico por banco/transferencia.
  static Future<Map<String, dynamic>> getSupplierPaymentsData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id, ae.document_number
           FROM accounting_entries ae
           WHERE ae.type = 'expense'
             AND ae.date >= ? AND ae.date < ?
           ORDER BY ae.date DESC''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      final totalsByMethod = <String, double>{};
      double total = 0.0;
      double totalBanco = 0.0;

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [r['user_id']],
          );
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        final paymentMethodRaw = r['payment_method'] as String? ?? 'N/A';
        final paymentMethod = _translatePaymentMethod(paymentMethodRaw);
        totalsByMethod[paymentMethod] =
            (totalsByMethod[paymentMethod] ?? 0.0) + amount;
        if (_isBankLikePaymentMethod(paymentMethodRaw)) {
          totalBanco += amount;
        }

        list.add({
          'id': r['id'],
          'amount': amount,
          'description': r['description'] as String? ?? '',
          'category': _translateCategory(r['category'] as String? ?? ''),
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod': paymentMethod,
          'paymentMethodRaw': paymentMethodRaw,
          'userName': userName,
          'documentNumber': r['document_number'] as String? ?? '',
          'isBank': _isBankLikePaymentMethod(paymentMethodRaw),
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'pagos': list,
        'egresos': list,
        'cantidad': list.length,
        'total': total,
        'totalBanco': totalBanco,
        'totalsByMethod': totalsByMethod,
      };
    } catch (e) {
      print('❌ Error getSupplierPaymentsData: $e');
      return {
        'pagos': <Map<String, dynamic>>[],
        'cantidad': 0,
        'total': 0.0,
        'totalBanco': 0.0,
        'totalsByMethod': <String, double>{},
      };
    }
  }

  /// Trazabilidad de egresos: detalla impacto operativo/contable por método.
  static Future<Map<String, dynamic>> getExpenseTraceabilityData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id, ae.cash_session_id, ae.reference, ae.document_number
           FROM accounting_entries ae
           WHERE ae.type = 'expense'
             AND ae.date >= ? AND ae.date < ?
           ORDER BY ae.date DESC''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double total = 0.0;
      double totalAfectaCaja = 0.0;
      double totalNoAfectaCaja = 0.0;
      int countAfectaCaja = 0;
      int countNoAfectaCaja = 0;
      final totalsByMethod = <String, double>{};
      final totalsByCategory = <String, double>{};
      final totalsByModule = <String, double>{};

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [r['user_id']],
          );
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        final methodRaw = r['payment_method'] as String? ?? 'N/A';
        final method = _translatePaymentMethod(methodRaw);
        final category = _translateCategory(r['category'] as String? ?? '');
        final reference = r['reference'] as String? ?? '';
        final description = r['description'] as String? ?? '';
        final origenModulo =
            _inferExpenseOriginModule(category, reference, description);
        totalsByMethod[method] = (totalsByMethod[method] ?? 0.0) + amount;
        totalsByCategory[category] = (totalsByCategory[category] ?? 0.0) + amount;
        totalsByModule[origenModulo] = (totalsByModule[origenModulo] ?? 0.0) + amount;
        final afectaCaja = _isCashPaymentMethod(methodRaw);
        if (afectaCaja) {
          totalAfectaCaja += amount;
          countAfectaCaja++;
        } else {
          totalNoAfectaCaja += amount;
          countNoAfectaCaja++;
        }

        list.add({
          'id': r['id'],
          'amount': amount,
          'description': description,
          'category': category,
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod': method,
          'paymentMethodRaw': methodRaw,
          'userName': userName,
          'cashSessionId': r['cash_session_id'],
          'reference': reference,
          'documentNumber': r['document_number'] as String? ?? '',
          'origenModulo': origenModulo,
          'afectaCaja': afectaCaja,
          'afectaFlujoContable': true,
          'afectaEstadoResultados': true,
          'afectaArqueoEfectivo': afectaCaja,
          'impacto': afectaCaja
              ? 'Afecta cierre de caja (efectivo)'
              : 'No afecta cierre de caja (banco/externo)',
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'egresos': list,
        'cantidad': list.length,
        'total': total,
        'totalAfectaCaja': totalAfectaCaja,
        'totalNoAfectaCaja': totalNoAfectaCaja,
        'countAfectaCaja': countAfectaCaja,
        'countNoAfectaCaja': countNoAfectaCaja,
        'totalsByMethod': totalsByMethod,
        'totalsByCategory': totalsByCategory,
        'totalsByModule': totalsByModule,
      };
    } catch (e) {
      print('❌ Error getExpenseTraceabilityData: $e');
      return {
        'egresos': <Map<String, dynamic>>[],
        'cantidad': 0,
        'total': 0.0,
        'totalAfectaCaja': 0.0,
        'totalNoAfectaCaja': 0.0,
        'countAfectaCaja': 0,
        'countNoAfectaCaja': 0,
        'totalsByMethod': <String, double>{},
        'totalsByCategory': <String, double>{},
        'totalsByModule': <String, double>{},
      };
    }
  }

  /// Trazabilidad de ingresos: impacto en cierre de caja (efectivo) vs solo contable.
  static Future<Map<String, dynamic>> getIncomeTraceabilityData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id, ae.cash_session_id, ae.reference, ae.document_number
           FROM accounting_entries ae
           WHERE ae.type = 'income'
             AND ae.date >= ? AND ae.date < ?
           ORDER BY ae.date DESC''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double total = 0.0;
      double totalAfectaCaja = 0.0;
      double totalNoAfectaCaja = 0.0;
      int countAfectaCaja = 0;
      int countNoAfectaCaja = 0;
      final totalsByMethod = <String, double>{};
      final totalsByCategory = <String, double>{};
      final totalsByModule = <String, double>{};

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query(
            'users',
            columns: ['fullName'],
            where: 'id = ?',
            whereArgs: [r['user_id']],
          );
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        final methodRaw = r['payment_method'] as String? ?? 'N/A';
        final method = _translatePaymentMethod(methodRaw);
        final rawCategory = r['category'] as String? ?? '';
        final category = _translateCategory(rawCategory);
        final reference = r['reference'] as String? ?? '';
        final description = r['description'] as String? ?? '';
        final origenModulo =
            _inferIncomeOriginModule(rawCategory, reference, description);
        totalsByMethod[method] = (totalsByMethod[method] ?? 0.0) + amount;
        totalsByCategory[category] =
            (totalsByCategory[category] ?? 0.0) + amount;
        totalsByModule[origenModulo] =
            (totalsByModule[origenModulo] ?? 0.0) + amount;
        final afectaCaja = _isCashPaymentMethod(methodRaw);
        if (afectaCaja) {
          totalAfectaCaja += amount;
          countAfectaCaja++;
        } else {
          totalNoAfectaCaja += amount;
          countNoAfectaCaja++;
        }

        list.add({
          'id': r['id'],
          'amount': amount,
          'description': description,
          'category': category,
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod': method,
          'paymentMethodRaw': methodRaw,
          'userName': userName,
          'cashSessionId': r['cash_session_id'],
          'reference': reference,
          'documentNumber': r['document_number'] as String? ?? '',
          'origenModulo': origenModulo,
          'afectaCaja': afectaCaja,
          'afectaFlujoContable': true,
          'afectaEstadoResultados': true,
          'afectaArqueoEfectivo': afectaCaja,
          'impacto': afectaCaja
              ? 'Suma en «Otros ingresos» del cierre de caja (efectivo), si no es venta POS'
              : 'Ingreso contable; no entra al arqueo de efectivo del cierre',
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'ingresos': list,
        'cantidad': list.length,
        'total': total,
        'totalAfectaCaja': totalAfectaCaja,
        'totalNoAfectaCaja': totalNoAfectaCaja,
        'countAfectaCaja': countAfectaCaja,
        'countNoAfectaCaja': countNoAfectaCaja,
        'totalsByMethod': totalsByMethod,
        'totalsByCategory': totalsByCategory,
        'totalsByModule': totalsByModule,
      };
    } catch (e) {
      print('❌ Error getIncomeTraceabilityData: $e');
      return {
        'ingresos': <Map<String, dynamic>>[],
        'cantidad': 0,
        'total': 0.0,
        'totalAfectaCaja': 0.0,
        'totalNoAfectaCaja': 0.0,
        'countAfectaCaja': 0,
        'countNoAfectaCaja': 0,
        'totalsByMethod': <String, double>{},
        'totalsByCategory': <String, double>{},
        'totalsByModule': <String, double>{},
      };
    }
  }

  static String _inferIncomeOriginModule(
      String rawCategory, String reference, String description) {
    final u = rawCategory.toUpperCase();
    final r = reference.toLowerCase();
    final d = description.toLowerCase();
    if (u.contains('SALES') || u.contains('VENTA')) {
      return 'Ventas / POS';
    }
    if (u.contains('CUSTOMER')) {
      return 'Abonos / clientes';
    }
    if (u.contains('ELECTRONIC_INVOICE')) {
      return 'Facturación electrónica';
    }
    if (u.contains('INVOICE_PAYMENT')) {
      return 'Cobro de facturas';
    }
    if (u.contains('OTHER_INCOME')) {
      return 'Ingresos manuales';
    }
    if (r.contains('electronic') ||
        r.contains('invoice') ||
        d.contains('factura electronica')) {
      return 'Facturación';
    }
    return 'Otros ingresos';
  }

  static bool _isBankLikePaymentMethod(String? method) {
    final normalized = (method ?? '')
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
    return normalized.contains('banco') || normalized.contains('transfer');
  }

  static String _inferExpenseOriginModule(
      String category, String reference, String description) {
    final c = category.toLowerCase();
    final r = reference.toLowerCase();
    final d = description.toLowerCase();

    if (c.contains('proveedor') || c.contains('supplier')) {
      return 'Proveedores';
    }
    if (c.contains('servicios publicos') ||
        d.contains('servicios publicos') ||
        d.contains('servicio publico')) {
      return 'Servicios Publicos';
    }
    if (c.contains('mantenimiento') || d.contains('mantenimiento')) {
      return 'Mantenimiento';
    }
    if (r.contains('electronic') ||
        r.contains('invoice') ||
        d.contains('factura electronica')) {
      return 'Facturacion Electronica';
    }
    if (c.contains('gasto')) {
      return 'Gastos Operativos';
    }
    if (r.contains('account') ||
        r.contains('receivable') ||
        r.contains('cxp')) {
      return 'Cuentas por Cobrar/Pagar';
    }
    return 'Otros Egresos';
  }

  // ==================== REPORTES DE VENTAS ====================

  /// Ventas por producto: agrupa ítems de ventas por nombre+unidad e incluye código del producto.
  static Future<Map<String, dynamic>> getVentasPorProductoData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      // Mapa nombre|unidad -> código del producto (desde products)
      final productRows =
          await db.query('products', columns: ['name', 'unit', 'code']);
      final nameUnitToCode = <String, String>{};
      for (final r in productRows) {
        final name = r['name'] as String? ?? '';
        final unit = r['unit'] as String? ?? 'und';
        nameUnitToCode['$name|$unit'] = r['code'] as String? ?? '';
      }

      final rows = await db.rawQuery(
        '''SELECT items FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final map = <String,
          Map<String,
              dynamic>>{}; // key: name|unit -> {code, name, unit, quantity, revenue}
      for (final r in rows) {
        final itemsStr = r['items'] as String?;
        if (itemsStr == null || itemsStr.isEmpty || !itemsStr.contains('[')) {
          continue;
        }
        try {
          final list = jsonDecode(itemsStr) as List<dynamic>?;
          if (list == null) continue;
          for (final e in list) {
            final m = e as Map<String, dynamic>;
            final name = m['name'] as String? ?? '';
            final unit = m['unit'] as String? ?? 'und';
            final qty = (m['quantity'] is int)
                ? (m['quantity'] as int)
                : ((m['quantity'] as num?)?.toInt() ?? 0);
            final price =
                (m['price'] is num) ? (m['price'] as num).toDouble() : 0.0;
            final revenue = qty * price;
            final key = '$name|$unit';
            map.putIfAbsent(
                key,
                () => {
                      'code': nameUnitToCode[key] ?? '',
                      'productName': name,
                      'unit': unit,
                      'quantity': 0,
                      'revenue': 0.0,
                    });
            map[key]!['quantity'] = (map[key]!['quantity'] as int) + qty;
            map[key]!['revenue'] = (map[key]!['revenue'] as double) + revenue;
          }
        } catch (_) {}
      }

      final list = map.values.toList();
      list.sort(
          (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      final totalRevenue =
          list.fold<double>(0, (s, e) => s + (e['revenue'] as double));
      final totalQuantity =
          list.fold<int>(0, (s, e) => s + (e['quantity'] as int));

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'porProducto': list,
        'totalRevenue': totalRevenue,
        'totalQuantity': totalQuantity,
      };
    } catch (e) {
      print('❌ Error getVentasPorProductoData: $e');
      return {
        'porProducto': <Map<String, dynamic>>[],
        'totalRevenue': 0.0,
        'totalQuantity': 0
      };
    }
  }

  /// Ventas por categoría: agrupa por categoría del producto (nombre+unidad -> products.category).
  static Future<Map<String, dynamic>> getVentasPorCategoriaData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final productRows =
          await db.query('products', columns: ['name', 'unit', 'category']);
      final nameToCategory = <String, String>{};
      for (final r in productRows) {
        final name = r['name'] as String? ?? '';
        final unit = r['unit'] as String? ?? 'und';
        nameToCategory['$name|$unit'] =
            r['category'] as String? ?? 'Sin categoría';
      }

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT items FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final map =
          <String, Map<String, dynamic>>{}; // category -> {quantity, revenue}
      for (final r in rows) {
        final itemsStr = r['items'] as String?;
        if (itemsStr == null || !itemsStr.contains('[')) continue;
        try {
          final list = jsonDecode(itemsStr) as List<dynamic>?;
          if (list == null) continue;
          for (final e in list) {
            final m = e as Map<String, dynamic>;
            final name = m['name'] as String? ?? '';
            final unit = m['unit'] as String? ?? 'und';
            final qty = (m['quantity'] is int)
                ? (m['quantity'] as int)
                : ((m['quantity'] as num?)?.toInt() ?? 0);
            final price =
                (m['price'] is num) ? (m['price'] as num).toDouble() : 0.0;
            final revenue = qty * price;
            final cat = nameToCategory['$name|$unit'] ?? 'Sin categoría';
            map.putIfAbsent(
                cat, () => {'category': cat, 'quantity': 0, 'revenue': 0.0});
            map[cat]!['quantity'] = (map[cat]!['quantity'] as int) + qty;
            map[cat]!['revenue'] = (map[cat]!['revenue'] as double) + revenue;
          }
        } catch (_) {}
      }

      final list = map.values.toList();
      list.sort(
          (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      final totalRevenue =
          list.fold<double>(0, (s, e) => s + (e['revenue'] as double));

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'porCategoria': list,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      print('❌ Error getVentasPorCategoriaData: $e');
      return {'porCategoria': <Map<String, dynamic>>[], 'totalRevenue': 0.0};
    }
  }

  /// Ventas por hora: cantidad y monto por hora del día (0-23).
  static Future<Map<String, dynamic>> getVentasPorHoraData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT date, total FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final porHora = List<Map<String, dynamic>>.generate(
          24, (i) => {'hour': i, 'count': 0, 'revenue': 0.0});
      for (final r in rows) {
        final dateStr = r['date'] as String?;
        if (dateStr == null) continue;
        final dt = DateTime.parse(dateStr);
        final total = (r['total'] as num?)?.toDouble() ?? 0.0;
        porHora[dt.hour]['count'] = (porHora[dt.hour]['count'] as int) + 1;
        porHora[dt.hour]['revenue'] =
            (porHora[dt.hour]['revenue'] as double) + total;
      }

      final totalVentas =
          porHora.fold<int>(0, (s, e) => s + (e['count'] as int));
      final totalRevenue =
          porHora.fold<double>(0, (s, e) => s + (e['revenue'] as double));

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'porHora': porHora,
        'totalVentas': totalVentas,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      print('❌ Error getVentasPorHoraData: $e');
      return {
        'porHora': List<Map<String, dynamic>>.generate(
            24, (i) => {'hour': i, 'count': 0, 'revenue': 0.0}),
        'totalVentas': 0,
        'totalRevenue': 0.0,
      };
    }
  }

  /// Resumen semanal/mensual: ventas por día con diferencias % respecto al primer día y mejor/peor día.
  static Future<Map<String, dynamic>> getResumenSemanalMensualData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final porDia = <Map<String, dynamic>>[];
      double totalVentas = 0;
      int totalTransacciones = 0;
      double? baseVentas;
      DateTime? mejorDiaDate;
      double mejorDiaVentas = -1;
      DateTime? peorDiaDate;
      double peorDiaVentas = -1;

      for (DateTime d = start;
          d.isBefore(end);
          d = d.add(const Duration(days: 1))) {
        final dayEnd = d.add(const Duration(days: 1));
        final rows = await db.rawQuery(
          '''SELECT COALESCE(SUM(total), 0) as ventas, COUNT(*) as transacciones
             FROM sales
             WHERE date >= ? AND date < ?
               AND (isReturn IS NULL OR isReturn = 0)
               AND (anulada IS NULL OR anulada = 0)''',
          [d.toIso8601String(), dayEnd.toIso8601String()],
        );
        final ventas = (rows.isNotEmpty && rows.first['ventas'] is num)
            ? (rows.first['ventas'] as num).toDouble()
            : 0.0;
        final transacciones =
            (rows.isNotEmpty && rows.first['transacciones'] is int)
                ? rows.first['transacciones'] as int
                : (rows.isNotEmpty && rows.first['transacciones'] is num)
                    ? (rows.first['transacciones'] as num).toInt()
                    : 0;

        baseVentas ??= ventas;
        if (ventas > 0 && (peorDiaVentas < 0 || ventas < peorDiaVentas)) {
          peorDiaVentas = ventas;
          peorDiaDate = d;
        }
        if (ventas > mejorDiaVentas) {
          mejorDiaVentas = ventas;
          mejorDiaDate = d;
        }

        final ticketProm = transacciones > 0 ? ventas / transacciones : 0.0;
        String diferenciaStr = 'Base';
        if (porDia.isNotEmpty && baseVentas > 0) {
          final pct = ((ventas - baseVentas) / baseVentas) * 100;
          diferenciaStr = pct >= 0
              ? '+${pct.toStringAsFixed(1)}%'
              : '${pct.toStringAsFixed(1)}%';
        }
        final weekdayIndex = d.weekday - 1;
        final diaLabel =
            '${diasSemana[weekdayIndex]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

        porDia.add({
          'date': d,
          'diaLabel': diaLabel,
          'ventas': ventas,
          'transacciones': transacciones,
          'ticketPromedio': ticketProm,
          'diferencia': diferenciaStr,
        });
        totalVentas += ventas;
        totalTransacciones += transacciones;
      }

      final numDias = porDia.isEmpty ? 1 : porDia.length;
      final ticketPromedioGlobal =
          totalTransacciones > 0 ? totalVentas / totalTransacciones : 0.0;
      final promedioVentas = totalVentas / numDias;
      final promedioTransacciones = totalTransacciones / numDias;

      double diferenciaMejorPeor = 0.0;
      if (peorDiaVentas > 0) {
        diferenciaMejorPeor =
            ((mejorDiaVentas - peorDiaVentas) / peorDiaVentas) * 100;
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'porDia': porDia,
        'totalVentas': totalVentas,
        'totalTransacciones': totalTransacciones,
        'ticketPromedioGlobal': ticketPromedioGlobal,
        'promedioVentas': promedioVentas,
        'promedioTransacciones': promedioTransacciones,
        'mejorDiaDate': mejorDiaDate,
        'mejorDiaVentas': mejorDiaVentas,
        'peorDiaDate': peorDiaDate,
        'peorDiaVentas': peorDiaVentas,
        'diferenciaMejorPeor': diferenciaMejorPeor,
      };
    } catch (e) {
      print('❌ Error getResumenSemanalMensualData: $e');
      return {
        'porDia': <Map<String, dynamic>>[],
        'totalVentas': 0.0,
        'totalTransacciones': 0,
        'ticketPromedioGlobal': 0.0,
        'promedioVentas': 0.0,
        'promedioTransacciones': 0.0,
        'mejorDiaDate': null,
        'mejorDiaVentas': 0.0,
        'peorDiaDate': null,
        'peorDiaVentas': 0.0,
        'diferenciaMejorPeor': 0.0,
      };
    }
  }

  /// Top productos más vendidos (por cantidad, límite 30).
  static Future<Map<String, dynamic>> getTopProductosData(
      DateTime fromDate, DateTime toDate,
      {int limit = 30}) async {
    final data = await getVentasPorProductoData(fromDate, toDate);
    final list = data['porProducto'] as List<dynamic>? ?? [];
    list.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
    final top = list.take(limit).toList();
    return {
      'fromDate': data['fromDate'],
      'toDate': data['toDate'],
      'top': top,
      'totalRevenue': data['totalRevenue'],
      'totalQuantity': data['totalQuantity'],
    };
  }

  /// Productos sin movimiento (no vendidos en el período).
  static Future<Map<String, dynamic>> getProductosSinMovimientoData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT items FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final soldKeys = <String>{};
      for (final r in rows) {
        final itemsStr = r['items'] as String?;
        if (itemsStr == null || !itemsStr.contains('[')) continue;
        try {
          final list = jsonDecode(itemsStr) as List<dynamic>?;
          if (list == null) continue;
          for (final e in list) {
            final m = e as Map<String, dynamic>;
            final name = m['name'] as String? ?? '';
            final unit = m['unit'] as String? ?? 'und';
            soldKeys.add('$name|$unit');
          }
        } catch (_) {}
      }

      final productRows = await db.query(
        'products',
        columns: ['id', 'name', 'code', 'unit', 'category', 'stock'],
        where: 'isActive = 1',
      );

      final list = <Map<String, dynamic>>[];
      for (final r in productRows) {
        final name = r['name'] as String? ?? '';
        final unit = r['unit'] as String? ?? 'und';
        if (soldKeys.contains('$name|$unit')) continue;
        list.add({
          'id': r['id'],
          'name': name,
          'code': r['code'] as String? ?? '',
          'unit': unit,
          'category': r['category'] as String? ?? '',
          'stock': r['stock'] as int? ?? 0,
        });
      }

      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'productos': list,
        'cantidad': list.length,
      };
    } catch (e) {
      print('❌ Error getProductosSinMovimientoData: $e');
      return {'productos': <Map<String, dynamic>>[], 'cantidad': 0};
    }
  }

  // ==================== REPORTES DE PAGOS ====================

  /// Ventas por forma de pago en el período (agregado desde sales).
  static Future<Map<String, dynamic>> getVentasPorFormaDePagoData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT total, paymentMethod, payment_breakdown FROM sales
           WHERE date >= ? AND date < ?
             AND (isReturn IS NULL OR isReturn = 0)
             AND (anulada IS NULL OR anulada = 0)''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final byMethod = <String, Map<String, dynamic>>{};
      int totalVentas = 0;

      for (final r in rows) {
        final total = (r['total'] as num?)?.toDouble() ?? 0.0;
        totalVentas++;

        final pbStr = r['payment_breakdown'] as String?;
        if (pbStr != null && pbStr.isNotEmpty && pbStr.contains('[')) {
          try {
            final list = jsonDecode(pbStr) as List<dynamic>?;
            if (list != null) {
              for (final e in list) {
                final m = e as Map<String, dynamic>;
                final method = m['method'] as String? ?? 'Efectivo';
                final amount = (m['amount'] is num)
                    ? (m['amount'] as num).toDouble()
                    : 0.0;
                byMethod.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
                byMethod[method]!['amount'] =
                    (byMethod[method]!['amount'] as double) + amount;
                byMethod[method]!['count'] =
                    (byMethod[method]!['count'] as int) + 1;
              }
            }
          } catch (_) {}
        } else {
          final method = r['paymentMethod'] as String? ?? 'Efectivo';
          byMethod.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
          byMethod[method]!['amount'] =
              (byMethod[method]!['amount'] as double) + total;
          byMethod[method]!['count'] = (byMethod[method]!['count'] as int) + 1;
        }
      }

      final list = byMethod.entries
          .map((e) => {
                'method': e.key,
                'amount': e.value['amount'],
                'count': e.value['count'],
              })
          .toList();
      list.sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      final totalCobrado =
          list.fold<double>(0, (s, e) => s + (e['amount'] as double));

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'porFormaPago': list,
        'totalVentas': totalVentas,
        'totalCobrado': totalCobrado,
      };
    } catch (e) {
      print('❌ Error getVentasPorFormaDePagoData: $e');
      return {
        'porFormaPago': <Map<String, dynamic>>[],
        'totalVentas': 0,
        'totalCobrado': 0.0
      };
    }
  }

  /// Movimientos de efectivo: entradas contables del período (ingresos y egresos) con método de pago.
  static Future<Map<String, dynamic>> getMovimientosDeEfectivoData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final end = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final rows = await db.rawQuery(
        '''SELECT ae.id, ae.type, ae.amount, ae.description, ae.category, ae.date, ae.payment_method, ae.user_id
           FROM accounting_entries ae
           WHERE ae.date >= ? AND ae.date < ?
           ORDER BY ae.date''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final list = <Map<String, dynamic>>[];
      double totalIngresos = 0;
      double totalEgresos = 0;

      for (final r in rows) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final type = r['type'] as String? ?? '';
        final method =
            _translatePaymentMethod(r['payment_method'] as String? ?? 'N/A');
        if (type == 'income') {
          totalIngresos += amount;
        } else if (type == 'expense') totalEgresos += amount;

        String userName = '';
        if (r['user_id'] != null) {
          final u = await db.query('users',
              columns: ['fullName'],
              where: 'id = ?',
              whereArgs: [r['user_id']]);
          if (u.isNotEmpty && u.first['fullName'] != null) {
            userName = u.first['fullName'] as String;
          }
        }

        list.add({
          'id': r['id'],
          'type': type,
          'amount': amount,
          'description': r['description'] as String? ?? '',
          'category': _translateCategory(r['category'] as String? ?? ''),
          'date':
              r['date'] != null ? DateTime.parse(r['date'] as String) : null,
          'paymentMethod': method,
          'userName': userName,
        });
      }

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'movimientos': list,
        'totalIngresos': totalIngresos,
        'totalEgresos': totalEgresos,
        'saldo': totalIngresos - totalEgresos,
      };
    } catch (e) {
      print('❌ Error getMovimientosDeEfectivoData: $e');
      return {
        'movimientos': <Map<String, dynamic>>[],
        'totalIngresos': 0.0,
        'totalEgresos': 0.0,
        'saldo': 0.0,
      };
    }
  }

  /// Arqueo de caja: resumen de sesiones de caja en el período (fondo, cierre, diferencia).
  static Future<Map<String, dynamic>> getArqueoDeCajaData(
      DateTime fromDate, DateTime toDate) async {
    try {
      final report = await generateCashSessionReport(fromDate, toDate);
      final sesiones = report.sessions
          .map((s) => {
                'sessionId': s.sessionId,
                'userName': s.userName,
                'openDate': s.openDate,
                'closeDate': s.closeDate,
                'initialAmount': s.initialAmount,
                'finalAmount': s.finalAmount,
                'totalIncome': s.totalIncome,
                'totalExpenses': s.totalExpenses,
                'difference': s.difference,
                'status': s.status,
                'transactionCount': s.transactionCount,
              })
          .toList();

      return {
        'fromDate': fromDate,
        'toDate': toDate,
        'sesiones': sesiones,
        'totalSesiones': sesiones.length,
        'totalInicial': report.totalInitialCash,
        'totalFinal': report.totalFinalCash,
        'totalIngresos': report.totalIncome,
        'totalEgresos': report.totalExpenses,
      };
    } catch (e) {
      print('❌ Error getArqueoDeCajaData: $e');
      return {
        'sesiones': <Map<String, dynamic>>[],
        'totalSesiones': 0,
        'totalInicial': 0.0,
        'totalFinal': 0.0,
        'totalIngresos': 0.0,
        'totalEgresos': 0.0,
      };
    }
  }
}
