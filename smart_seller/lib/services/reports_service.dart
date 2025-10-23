import '../models/report_models.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/group.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import 'sqlite_database_service.dart';
import 'supplier_service.dart';
import 'package:intl/intl.dart';

class ReportsService {
  // Generar reporte de ventas completo
  static Future<SalesReport> generateSalesReport({
    required DateTime date,
    DateTime? endDate,
    String? groupFilter,
    String? paymentMethodFilter,
  }) async {
    // Obtener ventas del período (día o rango)
    final sales = await SQLiteDatabaseService.getSales(
      date: date, 
      endDate: endDate
    );
    final products = await SQLiteDatabaseService.getAllProducts();
    final groups = await SQLiteDatabaseService.getAllGroups();

    // Calcular totales
    final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.total);
    final totalTransactions = sales.length;
    final averageTicket = totalTransactions > 0 ? totalSales / totalTransactions : 0.0;

    // Generar datos por hora
    final salesByHour = _generateSalesByHour(sales);

    // Generar datos por método de pago
    final salesByPaymentMethod = _generateSalesByPaymentMethod(sales);

    // Generar datos por grupo
    final salesByGroup = await _generateSalesByGroup(sales, products, groups, groupFilter);

    // Generar top productos
    final topProducts = await _generateTopProducts(sales, products, groups);

    // Generar transacciones detalladas
    final transactions = _generateTransactions(sales, products, groups);

    return SalesReport(
      date: date,
      totalSales: totalSales,
      totalTransactions: totalTransactions,
      averageTicket: averageTicket,
      salesByHour: salesByHour,
      salesByPaymentMethod: salesByPaymentMethod,
      salesByGroup: salesByGroup,
      topProducts: topProducts,
      transactions: transactions,
    );
  }

  // Generar reporte de inventario
  static Future<InventoryReport> generateInventoryReport({
    String? groupFilter,
    bool onlyLowStock = false,
  }) async {
    final products = await SQLiteDatabaseService.getAllProducts();
    final groups = await SQLiteDatabaseService.getAllGroups();

    // Filtrar por grupo si se especifica
    List<Product> filteredProducts = products;
    if (groupFilter != null && groupFilter.isNotEmpty) {
      filteredProducts = products.where((p) => p.category == groupFilter).toList();
    }

    // Filtrar solo stock bajo si se especifica
    if (onlyLowStock) {
      filteredProducts = filteredProducts.where((p) => p.stock <= p.minStock).toList();
    }

    // Calcular totales
    final totalProducts = filteredProducts.length;
    final lowStockProducts = filteredProducts.where((p) => p.stock <= p.minStock && p.stock > 0).length;
    final outOfStockProducts = filteredProducts.where((p) => p.stock == 0).length;
    final totalInventoryValue = filteredProducts.fold(0.0, (sum, p) => sum + (p.stock * p.price));
    final totalCostValue = filteredProducts.fold(0.0, (sum, p) => sum + (p.stock * p.cost));

    // Generar items de inventario
    final items = filteredProducts.map((product) {
      final group = groups.firstWhere(
        (g) => g.name == product.category,
        orElse: () => Group(name: 'Sin grupo', description: '', color: '#9E9E9E', icon: 'category', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );

      String status = 'OK';
      if (product.stock == 0) {
        status = 'OUT';
      } else if (product.stock <= product.minStock) {
        status = 'LOW';
      }

      return InventoryItem(
        productName: product.name,
        groupName: group.name,
        code: product.code,
        currentStock: product.stock,
        minStock: product.minStock,
        unitCost: product.cost,
        unitPrice: product.price,
        totalValue: product.stock * product.price,
        status: status,
        profitMargin: product.profitMargin,
      );
    }).toList();

    return InventoryReport(
      date: DateTime.now(),
      totalProducts: totalProducts,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
      totalInventoryValue: totalInventoryValue,
      totalCostValue: totalCostValue,
      items: items,
    );
  }

  // Generar reporte de rentabilidad
  static Future<ProfitabilityReport> generateProfitabilityReport({
    required DateTime date,
    DateTime? endDate,
    String? groupFilter,
  }) async {
    final sales = await SQLiteDatabaseService.getSales(date: date, endDate: endDate);
    final products = await SQLiteDatabaseService.getAllProducts();
    final groups = await SQLiteDatabaseService.getAllGroups();

    // Calcular totales
    double totalRevenue = 0.0;
    double totalCost = 0.0;
    Map<String, ProductProfitability> productProfits = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        // Buscar producto
        final product = products.firstWhere(
          (p) => p.name == item.name,
          orElse: () => Product(
            code: '',
            shortCode: '',
            name: item.name,
            description: '',
            price: item.price,
            cost: 0.0,
            stock: 0,
            minStock: 0,
            category: 'Sin grupo',
            unit: item.unit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final group = groups.firstWhere(
          (g) => g.name == product.category,
          orElse: () => Group(name: 'Sin grupo', description: '', color: '#9E9E9E', icon: 'category', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );

        final revenue = item.price * item.quantity;
        final cost = product.cost * item.quantity;
        final profit = revenue - cost;
        final profitMargin = revenue > 0 ? (profit / revenue) * 100 : 0.0;
        final roi = product.cost > 0 ? (profit / cost) * 100 : 0.0;

        totalRevenue += revenue;
        totalCost += cost;

        // Acumular por producto
        if (productProfits.containsKey(item.name)) {
          final existing = productProfits[item.name]!;
          productProfits[item.name] = ProductProfitability(
            productName: existing.productName,
            groupName: existing.groupName,
            quantitySold: existing.quantitySold + item.quantity,
            revenue: existing.revenue + revenue,
            cost: existing.cost + cost,
            profit: existing.profit + profit,
            profitMargin: existing.revenue + revenue > 0 ? ((existing.profit + profit) / (existing.revenue + revenue)) * 100 : 0.0,
            roi: existing.cost + cost > 0 ? ((existing.profit + profit) / (existing.cost + cost)) * 100 : 0.0,
          );
        } else {
          productProfits[item.name] = ProductProfitability(
            productName: item.name,
            groupName: group.name,
            quantitySold: item.quantity,
            revenue: revenue,
            cost: cost,
            profit: profit,
            profitMargin: profitMargin,
            roi: roi,
          );
        }
      }
    }

    // Filtrar por grupo si se especifica
    List<ProductProfitability> filteredProducts = productProfits.values.toList();
    if (groupFilter != null && groupFilter.isNotEmpty) {
      filteredProducts = productProfits.values.where((p) => p.groupName == groupFilter).toList();
    }

    // Ordenar por rentabilidad
    filteredProducts.sort((a, b) => b.profit.compareTo(a.profit));

    final totalProfit = totalRevenue - totalCost;
    final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    return ProfitabilityReport(
      date: date,
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      totalProfit: totalProfit,
      profitMargin: profitMargin,
      products: filteredProducts,
    );
  }

  // Métodos auxiliares privados
  static List<SalesByHour> _generateSalesByHour(List<Sale> sales) {
    final Map<int, double> hourlyAmounts = {};
    final Map<int, int> hourlyTransactions = {};

    for (final sale in sales) {
      final hour = sale.date.hour;
      hourlyAmounts[hour] = (hourlyAmounts[hour] ?? 0.0) + sale.total;
      hourlyTransactions[hour] = (hourlyTransactions[hour] ?? 0) + 1;
    }

    return List.generate(24, (hour) {
      return SalesByHour(
        hour: hour,
        amount: hourlyAmounts[hour] ?? 0.0,
        transactions: hourlyTransactions[hour] ?? 0,
      );
    });
  }

  static List<SalesByPaymentMethod> _generateSalesByPaymentMethod(List<Sale> sales) {
    final Map<String, double> methodAmounts = {};
    final Map<String, int> methodTransactions = {};
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + sale.total);

    for (final sale in sales) {
      final method = sale.paymentMethod ?? 'Efectivo';
      methodAmounts[method] = (methodAmounts[method] ?? 0.0) + sale.total;
      methodTransactions[method] = (methodTransactions[method] ?? 0) + 1;
    }

    return methodAmounts.entries.map((entry) {
      final method = entry.key;
      final amount = entry.value;
      final transactions = methodTransactions[method] ?? 0;
      final percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;

      return SalesByPaymentMethod(
        method: method,
        amount: amount,
        transactions: transactions,
        percentage: percentage,
      );
    }).toList();
  }

  static Future<List<SalesByGroup>> _generateSalesByGroup(
    List<Sale> sales,
    List<Product> products,
    List<Group> groups,
    String? groupFilter,
  ) async {
    final Map<String, double> groupAmounts = {};
    final Map<String, int> groupQuantities = {};
    final Map<String, int> groupTransactions = {};
    final totalAmount = sales.fold(0.0, (sum, sale) => sum + sale.total);

    for (final sale in sales) {
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.name == item.name,
          orElse: () => Product(
            code: '',
            shortCode: '',
            name: item.name,
            description: '',
            price: item.price,
            cost: 0.0,
            stock: 0,
            minStock: 0,
            category: 'Sin grupo',
            unit: item.unit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final groupName = product.category;
        final itemTotal = item.price * item.quantity;

        groupAmounts[groupName] = (groupAmounts[groupName] ?? 0.0) + itemTotal;
        groupQuantities[groupName] = (groupQuantities[groupName] ?? 0) + item.quantity;
        groupTransactions[groupName] = (groupTransactions[groupName] ?? 0) + 1;
      }
    }

    List<SalesByGroup> result = groupAmounts.entries.map((entry) {
      final groupName = entry.key;
      final amount = entry.value;
      final quantity = groupQuantities[groupName] ?? 0;
      final transactions = groupTransactions[groupName] ?? 0;
      final percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;

      return SalesByGroup(
        groupName: groupName,
        amount: amount,
        quantity: quantity,
        percentage: percentage,
        transactions: transactions,
      );
    }).toList();

    // Filtrar por grupo si se especifica
    if (groupFilter != null && groupFilter.isNotEmpty) {
      result = result.where((g) => g.groupName == groupFilter).toList();
    }

    // Ordenar por cantidad vendida
    result.sort((a, b) => b.quantity.compareTo(a.quantity));

    return result;
  }

  static Future<List<TopProduct>> _generateTopProducts(
    List<Sale> sales,
    List<Product> products,
    List<Group> groups,
  ) async {
    final Map<String, TopProduct> productSales = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        final product = products.firstWhere(
          (p) => p.name == item.name,
          orElse: () => Product(
            code: '',
            shortCode: '',
            name: item.name,
            description: '',
            price: item.price,
            cost: 0.0,
            stock: 0,
            minStock: 0,
            category: 'Sin grupo',
            unit: item.unit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final group = groups.firstWhere(
          (g) => g.name == product.category,
          orElse: () => Group(name: 'Sin grupo', description: '', color: '#9E9E9E', icon: 'category', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );

        final itemTotal = item.price * item.quantity;
        final profit = (item.price - product.cost) * item.quantity;
        final profitMargin = item.price > 0 ? ((item.price - product.cost) / item.price) * 100 : 0.0;

        if (productSales.containsKey(item.name)) {
          final existing = productSales[item.name]!;
          productSales[item.name] = TopProduct(
            productName: existing.productName,
            groupName: existing.groupName,
            quantitySold: existing.quantitySold + item.quantity,
            totalAmount: existing.totalAmount + itemTotal,
            unitPrice: item.price,
            profit: existing.profit + profit,
            profitMargin: profitMargin,
            rank: existing.rank,
          );
        } else {
          productSales[item.name] = TopProduct(
            productName: item.name,
            groupName: group.name,
            quantitySold: item.quantity,
            totalAmount: itemTotal,
            unitPrice: item.price,
            profit: profit,
            profitMargin: profitMargin,
            rank: 0, // Se asignará después
          );
        }
      }
    }

    List<TopProduct> result = productSales.values.toList();
    result.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    // Asignar ranking
    for (int i = 0; i < result.length; i++) {
      result[i] = TopProduct(
        productName: result[i].productName,
        groupName: result[i].groupName,
        quantitySold: result[i].quantitySold,
        totalAmount: result[i].totalAmount,
        unitPrice: result[i].unitPrice,
        profit: result[i].profit,
        profitMargin: result[i].profitMargin,
        rank: i + 1,
      );
    }

    return result.take(20).toList(); // Top 20 productos
  }

  static List<SalesTransaction> _generateTransactions(
    List<Sale> sales,
    List<Product> products,
    List<Group> groups,
  ) {
    return sales.map((sale) {
      final items = sale.items.map((item) {
        final product = products.firstWhere(
          (p) => p.name == item.name,
          orElse: () => Product(
            code: '',
            shortCode: '',
            name: item.name,
            description: '',
            price: item.price,
            cost: 0.0,
            stock: 0,
            minStock: 0,
            category: 'Sin grupo',
            unit: item.unit,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final group = groups.firstWhere(
          (g) => g.name == product.category,
          orElse: () => Group(name: 'Sin grupo', description: '', color: '#9E9E9E', icon: 'category', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        );

        final totalPrice = item.price * item.quantity;
        final profit = (item.price - product.cost) * item.quantity;
        final profitMargin = item.price > 0 ? ((item.price - product.cost) / item.price) * 100 : 0.0;

        return TransactionItem(
          productName: item.name,
          groupName: group.name,
          quantity: item.quantity,
          unitPrice: item.price,
          totalPrice: totalPrice,
          profit: profit,
          profitMargin: profitMargin,
        );
      }).toList();

      return SalesTransaction(
        id: sale.id ?? 0,
        date: sale.date,
        time: DateFormat('HH:mm:ss').format(sale.date),
        total: sale.total,
        paymentMethod: sale.paymentMethod ?? 'Efectivo',
        user: sale.user,
        items: items,
      );
    }).toList();
  }

  // ========== NUEVOS MÉTODOS PARA REPORTES DE PROVEEDORES Y CONTABILIDAD ==========

  // Generar reporte de proveedores
  static Future<SuppliersReport> generateSuppliersReport({
    required DateTime date,
    DateTime? endDate,
  }) async {
    try {
      final suppliers = await SupplierService.getAllSuppliers();
      final payments = await SupplierService.getAllSupplierPayments();
      
      // Filtrar pagos por fecha
      final filteredPayments = payments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (endDate != null) {
          return paymentDate.isAfter(date.subtract(const Duration(days: 1))) &&
                 paymentDate.isBefore(endDate.add(const Duration(days: 1)));
        } else {
          return paymentDate.year == date.year &&
                 paymentDate.month == date.month &&
                 paymentDate.day == date.day;
        }
      }).toList();

      // Calcular totales
      final totalPayments = filteredPayments.fold(0.0, (sum, payment) => sum + payment.amount);
      final totalPaymentTransactions = filteredPayments.length;

      // Generar resúmenes por proveedor
      final supplierPayments = _generateSupplierPaymentSummaries(suppliers, filteredPayments);
      
      // Generar pagos por método
      final paymentsByMethod = _generatePaymentsByMethod(filteredPayments);
      
      // Generar actividad de proveedores
      final supplierActivity = _generateSupplierActivity(suppliers, filteredPayments);

      return SuppliersReport(
        date: date,
        endDate: endDate,
        totalSuppliers: suppliers.length,
        totalPayments: totalPayments,
        totalPaymentTransactions: totalPaymentTransactions,
        supplierPayments: supplierPayments,
        paymentsByMethod: paymentsByMethod,
        supplierActivity: supplierActivity,
      );
    } catch (e) {
      print('Error generando reporte de proveedores: $e');
      rethrow;
    }
  }

  // Generar reporte contable
  static Future<AccountingReport> generateAccountingReport({
    required DateTime date,
    DateTime? endDate,
  }) async {
    try {
      // Obtener ventas para ingresos
      final sales = await SQLiteDatabaseService.getSales(
        date: date,
        endDate: endDate,
      );
      
      // Obtener pagos a proveedores para egresos
      final supplierPayments = await SupplierService.getAllSupplierPayments();
      
      // Filtrar pagos por fecha
      final filteredPayments = supplierPayments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (endDate != null) {
          return paymentDate.isAfter(date.subtract(const Duration(days: 1))) &&
                 paymentDate.isBefore(endDate.add(const Duration(days: 1)));
        } else {
          return paymentDate.year == date.year &&
                 paymentDate.month == date.month &&
                 paymentDate.day == date.day;
        }
      }).toList();

      // Calcular totales
      final totalIncome = sales.fold(0.0, (sum, sale) => sum + sale.total);
      final totalExpenses = filteredPayments.fold(0.0, (sum, payment) => sum + payment.amount);
      final netProfit = totalIncome - totalExpenses;

      // Generar entradas de ingresos
      final incomeEntries = _generateIncomeEntries(sales);
      
      // Generar entradas de egresos
      final expenseEntries = _generateExpenseEntries(filteredPayments);
      
      // Generar contabilidad por categoría
      final accountingByCategory = _generateAccountingByCategory(incomeEntries, expenseEntries);
      
      // Generar flujo de caja diario
      final dailyCashFlow = _generateDailyCashFlow(date, endDate, sales, filteredPayments);

      return AccountingReport(
        date: date,
        endDate: endDate,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        incomeEntries: incomeEntries,
        expenseEntries: expenseEntries,
        accountingByCategory: accountingByCategory,
        dailyCashFlow: dailyCashFlow,
      );
    } catch (e) {
      print('Error generando reporte contable: $e');
      rethrow;
    }
  }

  // Métodos auxiliares para reportes de proveedores
  static List<SupplierPaymentSummary> _generateSupplierPaymentSummaries(
    List<Supplier> suppliers,
    List<SupplierPayment> payments,
  ) {
    final Map<int, List<SupplierPayment>> paymentsBySupplier = {};
    
    for (final payment in payments) {
      paymentsBySupplier.putIfAbsent(payment.supplierId, () => []).add(payment);
    }

    return suppliers.map((supplier) {
      final supplierPayments = paymentsBySupplier[supplier.id] ?? [];
      final totalAmount = supplierPayments.fold(0.0, (sum, payment) => sum + payment.amount);
      final paymentCount = supplierPayments.length;
      final averagePayment = paymentCount > 0 ? totalAmount / paymentCount : 0.0;
      final lastPayment = supplierPayments.isNotEmpty 
          ? supplierPayments.map((p) => p.paymentDate).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now();

      return SupplierPaymentSummary(
        supplierName: supplier.name,
        paymentCount: paymentCount,
        totalAmount: totalAmount,
        lastPayment: lastPayment,
        averagePayment: averagePayment,
      );
    }).where((summary) => summary.paymentCount > 0).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  static List<PaymentByMethod> _generatePaymentsByMethod(List<SupplierPayment> payments) {
    final Map<String, List<SupplierPayment>> paymentsByMethod = {};
    
    for (final payment in payments) {
      paymentsByMethod.putIfAbsent(payment.paymentMethod, () => []).add(payment);
    }

    final totalAmount = payments.fold(0.0, (sum, payment) => sum + payment.amount);

    return paymentsByMethod.entries.map((entry) {
      final methodPayments = entry.value;
      final amount = methodPayments.fold(0.0, (sum, payment) => sum + payment.amount);
      final transactions = methodPayments.length;
      final percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;

      return PaymentByMethod(
        method: entry.key,
        amount: amount,
        transactions: transactions,
        percentage: percentage,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<SupplierActivity> _generateSupplierActivity(
    List<Supplier> suppliers,
    List<SupplierPayment> payments,
  ) {
    return payments.map((payment) {
      final supplier = suppliers.firstWhere(
        (s) => s.id == payment.supplierId,
        orElse: () => Supplier(
          name: 'Proveedor eliminado',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return SupplierActivity(
        supplierName: supplier.name,
        paymentDate: payment.paymentDate,
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        description: payment.description,
      );
    }).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  }

  // Métodos auxiliares para reportes contables
  static List<AccountingEntry> _generateIncomeEntries(List<Sale> sales) {
    return sales.map((sale) {
      return AccountingEntry(
        date: sale.date,
        type: 'income',
        amount: sale.total,
        description: 'Venta #${sale.id}',
        category: 'sales',
        userName: 'Sistema',
      );
    }).toList();
  }

  static List<AccountingEntry> _generateExpenseEntries(List<SupplierPayment> payments) {
    return payments.map((payment) {
      return AccountingEntry(
        date: payment.paymentDate,
        type: 'expense',
        amount: payment.amount,
        description: payment.description ?? 'Pago a proveedor',
        category: 'supplier_payment',
        userName: 'Sistema',
      );
    }).toList();
  }

  static List<AccountingByCategory> _generateAccountingByCategory(
    List<AccountingEntry> incomeEntries,
    List<AccountingEntry> expenseEntries,
  ) {
    final Map<String, double> incomeByCategory = {};
    final Map<String, double> expenseByCategory = {};

    for (final entry in incomeEntries) {
      final category = entry.category ?? 'sin_categoria';
      incomeByCategory[category] = (incomeByCategory[category] ?? 0.0) + entry.amount;
    }

    for (final entry in expenseEntries) {
      final category = entry.category ?? 'sin_categoria';
      expenseByCategory[category] = (expenseByCategory[category] ?? 0.0) + entry.amount;
    }

    final allCategories = {...incomeByCategory.keys, ...expenseByCategory.keys};

    return allCategories.map((category) {
      final income = incomeByCategory[category] ?? 0.0;
      final expenses = expenseByCategory[category] ?? 0.0;
      final net = income - expenses;

      return AccountingByCategory(
        category: category,
        income: income,
        expenses: expenses,
        net: net,
      );
    }).toList()
      ..sort((a, b) => b.net.compareTo(a.net));
  }

  static List<DailyCashFlow> _generateDailyCashFlow(
    DateTime startDate,
    DateTime? endDate,
    List<Sale> sales,
    List<SupplierPayment> payments,
  ) {
    final Map<String, double> dailyIncome = {};
    final Map<String, double> dailyExpenses = {};

    // Procesar ventas
    for (final sale in sales) {
      final date = sale.date;
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      dailyIncome[dateKey] = (dailyIncome[dateKey] ?? 0.0) + sale.total;
    }

    // Procesar pagos
    for (final payment in payments) {
      final dateKey = DateFormat('yyyy-MM-dd').format(payment.paymentDate);
      dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0.0) + payment.amount;
    }

    // Generar días
    final days = <DateTime>[];
    final current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = endDate ?? startDate;
    
    while (current.isBefore(end.add(const Duration(days: 1)))) {
      days.add(current);
      current.add(const Duration(days: 1));
    }

    double cumulativeNet = 0.0;
    return days.map((day) {
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final income = dailyIncome[dateKey] ?? 0.0;
      final expenses = dailyExpenses[dateKey] ?? 0.0;
      final net = income - expenses;
      cumulativeNet += net;

      return DailyCashFlow(
        date: day,
        income: income,
        expenses: expenses,
        net: net,
        cumulativeNet: cumulativeNet,
      );
    }).toList();
  }
}


