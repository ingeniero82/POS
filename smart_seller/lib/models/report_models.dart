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
}

enum ExportFormat {
  excel,
  pdf,
  csv,
}


