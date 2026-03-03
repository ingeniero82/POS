// Servicio para generar reportes contables

import '../../../services/sqlite_database_service.dart';
import '../../../models/product.dart';
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

      // Obtener sesiones de caja sin JOIN primero
      const sessionQuery = '''
        SELECT cs.*
        FROM cash_sessions cs
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
        final transactionCount =
            await _getTransactionCountForSession(row['id'] as int);

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

        sessions.add(CashSessionSummary(
          sessionId: row['id'] as int,
          userName: userName,
          openDate: DateTime.parse(row['open_date'] as String),
          closeDate: row['close_date'] != null
              ? DateTime.parse(row['close_date'] as String)
              : null,
          // ✅ CORREGIDO: Manejar valores null de forma segura
          initialAmount: (row['initial_amount'] as num?)?.toDouble() ?? 0.0,
          finalAmount: (row['final_amount'] as num?)?.toDouble() ?? 0.0,
          totalIncome: (row['total_income'] as num?)?.toDouble() ?? 0.0,
          totalExpenses: (row['total_expense'] as num?)?.toDouble() ?? 0.0,
          difference: (row['difference'] as num?)?.toDouble() ?? 0.0,
          status: row['status'] as String,
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
        return (result.first['final_amount'] as num).toDouble();
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

  static Future<Map<String, dynamic>> getQuickSummary(
      DateTime fromDate, DateTime toDate) async {
    try {
      final incomeStatement = await generateIncomeStatement(fromDate, toDate);
      final cashFlow = await generateCashFlowReport(fromDate, toDate);

      return {
        'period':
            '${fromDate.day}/${fromDate.month}/${fromDate.year} - ${toDate.day}/${toDate.month}/${toDate.year}',
        'total_income': incomeStatement.totalIncome,
        'total_expenses': incomeStatement.totalExpenses,
        'net_income': incomeStatement.netIncome,
        'cash_flow': cashFlow.netCashFlow,
        'transaction_count': incomeStatement.incomeCategories
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount) +
            incomeStatement.expenseCategories
                .fold<int>(0, (sum, cat) => sum + cat.transactionCount),
      };
    } catch (e) {
      print('❌ Error al generar resumen rápido: $e');
      return {};
    }
  }

  // ✅ NUEVO: Obtener desglose de impuestos, descuentos y devoluciones
  static Future<Map<String, dynamic>> getTaxAndDiscountsBreakdown(
      DateTime fromDate, DateTime toDate) async {
    try {
      final sales =
          await SQLiteDatabaseService.getSales(date: fromDate, endDate: toDate);

      double totalDiscounts = 0.0;
      double totalReturns = 0.0;
      int returnTransactions = 0;
      double totalExempt = 0.0;
      double totalExcluded = 0.0;
      double totalTaxed = 0.0;
      double totalVatAt0 = 0.0;
      double totalVatAt5 = 0.0;
      double totalVatAt19 = 0.0;
      double totalVat = 0.0;
      double totalIpoConsumo = 0.0;
      double totalPlasticBagTax = 0.0;
      int totalPlasticBagCount = 0;
      double totalSubtotal = 0.0;

      for (final sale in sales) {
        if (sale.isReturn) {
          totalReturns += sale.returnedAmount ?? sale.total;
          returnTransactions++;
        } else {
          totalDiscounts += sale.discount ?? 0.0;
          totalExempt += sale.exemptAmount;
          totalExcluded += sale.excludedAmount;
          totalTaxed += sale.taxedAmount;
          totalVatAt0 += sale.vatAt0;
          totalVatAt5 += sale.vatAt5;
          totalVatAt19 += sale.vatAt19;
          totalVat += sale.totalVat;
          totalIpoConsumo += sale.ipoConsumoAmount;
          totalPlasticBagTax += sale.plasticBagTaxAmount;
          totalPlasticBagCount += sale.plasticBagCount;
          totalSubtotal += sale.subtotal;
        }
      }

      return {
        'totalDiscounts': totalDiscounts,
        'totalReturns': totalReturns,
        'returnTransactions': returnTransactions,
        'exemptAmount': totalExempt,
        'excludedAmount': totalExcluded,
        'taxedAmount': totalTaxed,
        'vatAt0': totalVatAt0,
        'vatAt5': totalVatAt5,
        'vatAt19': totalVatAt19,
        'totalVat': totalVat,
        'ipoConsumoAmount': totalIpoConsumo,
        'plasticBagTaxAmount': totalPlasticBagTax,
        'plasticBagCount': totalPlasticBagCount,
        'subtotalBeforeTaxes': totalSubtotal,
      };
    } catch (e) {
      print('❌ Error al obtener desglose de impuestos: $e');
      return {};
    }
  }

  // ✅ NUEVO: Obtener análisis por método de pago
  static Future<Map<String, double>> getPaymentMethodBreakdown(
      DateTime fromDate, DateTime toDate) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) throw Exception('Base de datos no inicializada');

      final sales =
          await SQLiteDatabaseService.getSales(date: fromDate, endDate: toDate);

      final Map<String, double> paymentMethods = {};
      final Map<String, int> paymentCounts = {};

      for (final sale in sales) {
        if (!sale.isReturn) {
          final method = sale.paymentMethod ?? 'Efectivo';
          paymentMethods[method] = (paymentMethods[method] ?? 0.0) + sale.total;
          paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
        }
      }

      return paymentMethods;
    } catch (e) {
      print('❌ Error al obtener análisis por método de pago: $e');
      return {};
    }
  }

  // ✅ NUEVO: Obtener top productos y grupos
  static Future<Map<String, dynamic>> getTopProductsAndGroups(
      DateTime fromDate, DateTime toDate,
      {int limit = 10}) async {
    try {
      final sales =
          await SQLiteDatabaseService.getSales(date: fromDate, endDate: toDate);
      final products = await SQLiteDatabaseService.getAllProducts();

      final Map<String, double> productSales = {};
      final Map<String, int> productQuantities = {};
      final Map<String, double> groupSales = {};
      final Map<String, int> groupQuantities = {};

      for (final sale in sales) {
        if (!sale.isReturn) {
          for (final item in sale.items) {
            // Productos
            productSales[item.name] =
                (productSales[item.name] ?? 0.0) + item.total;
            productQuantities[item.name] =
                (productQuantities[item.name] ?? 0) + item.quantity;

            // Grupos
            Product? product;
            try {
              product = products.firstWhere((p) => p.name == item.name);
            } catch (_) {
              try {
                product = products.firstWhere((p) => p.code == item.name);
              } catch (_) {
                product = products.isNotEmpty ? products.first : null;
              }
            }

            if (product != null) {
              final groupName = product.category;
              groupSales[groupName] =
                  (groupSales[groupName] ?? 0.0) + item.total;
              groupQuantities[groupName] =
                  (groupQuantities[groupName] ?? 0) + item.quantity;
            }
          }
        }
      }

      // Ordenar productos
      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Ordenar grupos
      final sortedGroups = groupSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'topProducts': sortedProducts
            .take(limit)
            .map((e) => {
                  'name': e.key,
                  'amount': e.value,
                  'quantity': productQuantities[e.key] ?? 0,
                })
            .toList(),
        'topGroups': sortedGroups
            .take(limit)
            .map((e) => {
                  'name': e.key,
                  'amount': e.value,
                  'quantity': groupQuantities[e.key] ?? 0,
                })
            .toList(),
      };
    } catch (e) {
      print('❌ Error al obtener top productos: $e');
      return {};
    }
  }
}
