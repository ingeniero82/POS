// Modelos de datos para reportes profesionales

class SalesReport {
  final DateTime date;
  final double totalSales;
  final int totalTransactions;
  final double averageTicket;
  final List<SalesByHour> salesByHour;
  final List<SalesByPaymentMethod> salesByPaymentMethod;
  final List<SalesByGroup> salesByGroup;
  final List<TopProduct> topProducts;
  final List<SalesTransaction> transactions;
  
  // ✅ NUEVOS CAMPOS PARA REPORTE PROFESIONAL
  final double? otherIncome; // Ingresos adicionales no asociados a venta
  final double? expenses; // Egresos/gastos operativos
  final double? netProfit; // Utilidad neta
  final double? profitMargin; // Margen de ganancia %
  final double? initialBalance; // Saldo inicial de caja
  final double? finalBalance; // Saldo final de caja
  final double? theoreticalBalance; // Saldo teórico calculado
  final double? actualBalance; // Saldo real en caja
  final double? cashDifference; // Diferencia de caja
  final List<AdditionalIncome>? additionalIncomes; // Ingresos adicionales detallados
  final List<ExpenseDetail>? expenseDetails; // Egresos detallados
  
  // ✅ NUEVO: Descuentos y devoluciones para reporte profesional
  final double? totalDiscounts; // Total de descuentos aplicados
  final double? totalReturns; // Total de devoluciones
  final int? returnTransactions; // Número de devoluciones
  final double netSales; // Ventas netas (bruto - descuentos - devoluciones)

  SalesReport({
    required this.date,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageTicket,
    required this.salesByHour,
    required this.salesByPaymentMethod,
    required this.salesByGroup,
    required this.topProducts,
    required this.transactions,
    // ✅ NUEVOS CAMPOS OPCIONALES (retrocompatible)
    this.otherIncome,
    this.expenses,
    this.netProfit,
    this.profitMargin,
    this.initialBalance,
    this.finalBalance,
    this.theoreticalBalance,
    this.actualBalance,
    this.cashDifference,
    this.additionalIncomes,
    this.expenseDetails,
    // ✅ NUEVO: Descuentos y devoluciones
    this.totalDiscounts,
    this.totalReturns,
    this.returnTransactions,
    required this.netSales,
  });
}

// ✅ NUEVO: Modelo para ingresos adicionales
class AdditionalIncome {
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? paymentMethod;

  AdditionalIncome({
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.paymentMethod,
  });
}

// ✅ NUEVO: Modelo para egresos detallados
class ExpenseDetail {
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? paymentMethod;

  ExpenseDetail({
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.paymentMethod,
  });
}

class SalesByHour {
  final int hour;
  final double amount;
  final int transactions;

  SalesByHour({
    required this.hour,
    required this.amount,
    required this.transactions,
  });
}

class SalesByPaymentMethod {
  final String method;
  final double amount;
  final int transactions;
  final double percentage;

  SalesByPaymentMethod({
    required this.method,
    required this.amount,
    required this.transactions,
    required this.percentage,
  });
}

class SalesByGroup {
  final String groupName;
  final double amount;
  final int quantity;
  final double percentage;
  final int transactions;

  SalesByGroup({
    required this.groupName,
    required this.amount,
    required this.quantity,
    required this.percentage,
    required this.transactions,
  });
}

class TopProduct {
  final String productName;
  final String groupName;
  final int quantitySold;
  final double totalAmount;
  final double unitPrice;
  final double profit;
  final double profitMargin;
  final int rank;

  TopProduct({
    required this.productName,
    required this.groupName,
    required this.quantitySold,
    required this.totalAmount,
    required this.unitPrice,
    required this.profit,
    required this.profitMargin,
    required this.rank,
  });
}

class SalesTransaction {
  final int id;
  final DateTime date;
  final String time;
  final double total;
  final String paymentMethod;
  final String user;
  final List<TransactionItem> items;
  final String? clientName;

  SalesTransaction({
    required this.id,
    required this.date,
    required this.time,
    required this.total,
    required this.paymentMethod,
    required this.user,
    required this.items,
    this.clientName,
  });
}

class TransactionItem {
  final String productName;
  final String groupName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double profit;
  final double profitMargin;

  TransactionItem({
    required this.productName,
    required this.groupName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.profit,
    required this.profitMargin,
  });
}

class InventoryReport {
  final DateTime date;
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double totalInventoryValue;
  final double totalCostValue;
  final List<InventoryItem> items;

  InventoryReport({
    required this.date,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalInventoryValue,
    required this.totalCostValue,
    required this.items,
  });
}

class InventoryItem {
  final String productName;
  final String groupName;
  final String code;
  final int currentStock;
  final int minStock;
  final double unitCost;
  final double unitPrice;
  final double totalValue;
  final String status; // 'OK', 'LOW', 'OUT'
  final double profitMargin;

  InventoryItem({
    required this.productName,
    required this.groupName,
    required this.code,
    required this.currentStock,
    required this.minStock,
    required this.unitCost,
    required this.unitPrice,
    required this.totalValue,
    required this.status,
    required this.profitMargin,
  });
}

class ProfitabilityReport {
  final DateTime date;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double profitMargin;
  final List<ProductProfitability> products;

  ProfitabilityReport({
    required this.date,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
    required this.products,
  });
}

class ProductProfitability {
  final String productName;
  final String groupName;
  final int quantitySold;
  final double revenue;
  final double cost;
  final double profit;
  final double profitMargin;
  final double roi; // Return on Investment

  ProductProfitability({
    required this.productName,
    required this.groupName,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.profitMargin,
    required this.roi,
  });
}

// Enums para filtros
enum ReportPeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

enum ReportType {
  sales,
  products,
  inventory,
  profitability,
  payments,
  groups,
  suppliers, // ✅ NUEVO: Reporte de proveedores
  accounting, // ✅ NUEVO: Reporte contable
}

enum ExportFormat {
  excel,
  pdf,
  csv,
}

// ========== NUEVOS MODELOS PARA REPORTES DE PROVEEDORES Y CONTABILIDAD ==========

// Reporte de Proveedores
class SuppliersReport {
  final DateTime date;
  final DateTime? endDate;
  final int totalSuppliers;
  final double totalPayments;
  final int totalPaymentTransactions;
  final List<SupplierPaymentSummary> supplierPayments;
  final List<PaymentByMethod> paymentsByMethod;
  final List<SupplierActivity> supplierActivity;

  SuppliersReport({
    required this.date,
    this.endDate,
    required this.totalSuppliers,
    required this.totalPayments,
    required this.totalPaymentTransactions,
    required this.supplierPayments,
    required this.paymentsByMethod,
    required this.supplierActivity,
  });
}

class SupplierPaymentSummary {
  final String supplierName;
  final int paymentCount;
  final double totalAmount;
  final DateTime lastPayment;
  final double averagePayment;

  SupplierPaymentSummary({
    required this.supplierName,
    required this.paymentCount,
    required this.totalAmount,
    required this.lastPayment,
    required this.averagePayment,
  });
}

class PaymentByMethod {
  final String method;
  final double amount;
  final int transactions;
  final double percentage;

  PaymentByMethod({
    required this.method,
    required this.amount,
    required this.transactions,
    required this.percentage,
  });
}

class SupplierActivity {
  final String supplierName;
  final DateTime paymentDate;
  final double amount;
  final String paymentMethod;
  final String? description;

  SupplierActivity({
    required this.supplierName,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    this.description,
  });
}

// Reporte Contable
class AccountingReport {
  final DateTime date;
  final DateTime? endDate;
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;
  final List<AccountingEntry> incomeEntries;
  final List<AccountingEntry> expenseEntries;
  final List<AccountingByCategory> accountingByCategory;
  final List<DailyCashFlow> dailyCashFlow;

  AccountingReport({
    required this.date,
    this.endDate,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.incomeEntries,
    required this.expenseEntries,
    required this.accountingByCategory,
    required this.dailyCashFlow,
  });
}

class AccountingEntry {
  final DateTime date;
  final String type; // 'income' o 'expense'
  final double amount;
  final String description;
  final String? category;
  final String userName;

  AccountingEntry({
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    required this.userName,
  });
}

class AccountingByCategory {
  final String category;
  final double income;
  final double expenses;
  final double net;

  AccountingByCategory({
    required this.category,
    required this.income,
    required this.expenses,
    required this.net,
  });
}

class DailyCashFlow {
  final DateTime date;
  final double income;
  final double expenses;
  final double net;
  final double cumulativeNet;

  DailyCashFlow({
    required this.date,
    required this.income,
    required this.expenses,
    required this.net,
    required this.cumulativeNet,
  });
}


