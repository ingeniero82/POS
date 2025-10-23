// Servicio para generar reportes contables

import '../../../services/sqlite_database_service.dart';
import '../models/accounting_reports.dart';

class AccountingReportsService {
  
  // ==================== ESTADO DE RESULTADOS ====================
  
  static Future<IncomeStatement> generateIncomeStatement(DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener ingresos por categoría
      final incomeQuery = '''
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
      final expenseQuery = '''
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
      final totalIncome = incomeResults.fold<double>(0, (sum, row) => sum + (row['total_amount'] as double));
      final totalExpenses = expenseResults.fold<double>(0, (sum, row) => sum + (row['total_amount'] as double));
      final netIncome = totalIncome - totalExpenses;

      // Crear categorías de ingresos
      final incomeCategories = incomeResults.map((row) {
        final amount = row['total_amount'] as double;
        return IncomeCategory(
          category: row['category'] as String,
          amount: amount,
          transactionCount: row['transaction_count'] as int,
          percentage: totalIncome > 0 ? (amount / totalIncome) * 100 : 0,
        );
      }).toList();

      // Crear categorías de egresos
      final expenseCategories = expenseResults.map((row) {
        final amount = row['total_amount'] as double;
        return ExpenseCategory(
          category: row['category'] as String,
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
  
  static Future<CashFlowReport> generateCashFlowReport(DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener flujo diario
      final dailyQuery = '''
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
      final totalIncome = dailyResults.fold<double>(0, (sum, row) => sum + (row['daily_income'] as double));
      final totalExpenses = dailyResults.fold<double>(0, (sum, row) => sum + (row['daily_expenses'] as double));
      final netCashFlow = totalIncome - totalExpenses;

      // Crear flujos diarios
      final dailyFlows = dailyResults.map((row) {
        final income = row['daily_income'] as double;
        final expenses = row['daily_expenses'] as double;
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
  
  static Future<CashSessionReport> generateCashSessionReport(DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener sesiones de caja con información de usuarios
      final sessionQuery = '''
        SELECT 
          cs.*,
          u.full_name as user_name
        FROM cash_sessions cs
        LEFT JOIN users u ON cs.user_id = u.id
        WHERE cs.open_date BETWEEN ? AND ?
        ORDER BY cs.open_date DESC
      ''';

      final sessionResults = await db.rawQuery(sessionQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Crear resúmenes de sesiones
      final sessions = <CashSessionSummary>[];
      for (final row in sessionResults) {
        final transactionCount = await _getTransactionCountForSession(row['id'] as int);
        sessions.add(CashSessionSummary(
          sessionId: row['id'] as int,
          userName: row['user_name'] as String? ?? 'Usuario desconocido',
          openDate: DateTime.parse(row['open_date'] as String),
          closeDate: row['close_date'] != null ? DateTime.parse(row['close_date'] as String) : null,
          initialAmount: (row['initial_amount'] as num).toDouble(),
          finalAmount: (row['final_amount'] as num).toDouble(),
          totalIncome: (row['total_income'] as num).toDouble(),
          totalExpenses: (row['total_expense'] as num).toDouble(),
          difference: (row['difference'] as num).toDouble(),
          status: row['status'] as String,
          transactionCount: transactionCount,
        ));
      }

      // Calcular totales
      final totalInitialCash = sessions.fold<double>(0, (sum, session) => sum + session.initialAmount);
      final totalFinalCash = sessions.fold<double>(0, (sum, session) => sum + session.finalAmount);
      final totalIncome = sessions.fold<double>(0, (sum, session) => sum + session.totalIncome);
      final totalExpenses = sessions.fold<double>(0, (sum, session) => sum + session.totalExpenses);

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
  
  static Future<TransactionAuditReport> generateTransactionAuditReport(DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      // Obtener todas las transacciones con información de usuarios
      final transactionQuery = '''
        SELECT 
          ae.*,
          u.full_name as user_name
        FROM accounting_entries ae
        LEFT JOIN users u ON ae.user_id = u.id
        WHERE ae.date BETWEEN ? AND ?
        ORDER BY ae.date DESC, ae.id DESC
      ''';

      final transactionResults = await db.rawQuery(transactionQuery, [
        fromDate.toIso8601String(),
        toDate.toIso8601String(),
      ]);

      // Crear entradas de auditoría
      final entries = transactionResults.map((row) {
        return TransactionAuditEntry(
          id: row['id'] as int,
          type: row['type'] as String,
          amount: (row['amount'] as num).toDouble(),
          description: row['description'] as String,
          category: row['category'] as String,
          paymentMethod: row['payment_method'] as String? ?? 'N/A',
          userName: row['user_name'] as String? ?? 'Usuario desconocido',
          date: DateTime.parse(row['date'] as String),
          reference: row['reference'] as String?,
          documentNumber: row['document_number'] as String?,
          notes: row['notes'] as String?,
        );
      }).toList();

      // Calcular estadísticas
      final totalTransactions = entries.length;
      final totalAmount = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
      
      final transactionsByType = <String, int>{};
      final transactionsByUser = <String, int>{};
      
      for (final entry in entries) {
        transactionsByType[entry.type] = (transactionsByType[entry.type] ?? 0) + 1;
        transactionsByUser[entry.userName] = (transactionsByUser[entry.userName] ?? 0) + 1;
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
      final query = '''
        SELECT final_amount 
        FROM cash_sessions 
        WHERE status = 'closed' 
        AND close_date < ?
        ORDER BY close_date DESC 
        LIMIT 1
      ''';

      final result = await db.rawQuery(query, [fromDate.toIso8601String()]);
      
      if (result.isNotEmpty) {
        return (result.first['final_amount'] as num).toDouble();
      }
      
      return 0.0;
    } catch (e) {
      print('❌ Error al obtener efectivo inicial: $e');
      return 0.0;
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
  
  static Future<Map<String, dynamic>> getQuickSummary(DateTime fromDate, DateTime toDate) async {
    try {
      final incomeStatement = await generateIncomeStatement(fromDate, toDate);
      final cashFlow = await generateCashFlowReport(fromDate, toDate);
      
      return {
        'period': '${fromDate.day}/${fromDate.month}/${fromDate.year} - ${toDate.day}/${toDate.month}/${toDate.year}',
        'total_income': incomeStatement.totalIncome,
        'total_expenses': incomeStatement.totalExpenses,
        'net_income': incomeStatement.netIncome,
        'cash_flow': cashFlow.netCashFlow,
        'transaction_count': incomeStatement.incomeCategories.fold<int>(0, (sum, cat) => sum + cat.transactionCount) +
                           incomeStatement.expenseCategories.fold<int>(0, (sum, cat) => sum + cat.transactionCount),
      };
    } catch (e) {
      print('❌ Error al generar resumen rápido: $e');
      return {};
    }
  }
}
