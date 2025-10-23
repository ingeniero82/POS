// Modelos para reportes contables

class AccountingReport {
  final String reportType;
  final DateTime fromDate;
  final DateTime toDate;
  final Map<String, dynamic> data;
  final DateTime generatedAt;
  final String generatedBy;

  AccountingReport({
    required this.reportType,
    required this.fromDate,
    required this.toDate,
    required this.data,
    required this.generatedAt,
    required this.generatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'report_type': reportType,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
      'data': data,
      'generated_at': generatedAt.toIso8601String(),
      'generated_by': generatedBy,
    };
  }
}

class IncomeStatement {
  final double totalIncome;
  final double totalExpenses;
  final double netIncome;
  final List<IncomeCategory> incomeCategories;
  final List<ExpenseCategory> expenseCategories;
  final DateTime fromDate;
  final DateTime toDate;

  IncomeStatement({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netIncome,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.fromDate,
    required this.toDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'net_income': netIncome,
      'income_categories': incomeCategories.map((c) => c.toMap()).toList(),
      'expense_categories': expenseCategories.map((c) => c.toMap()).toList(),
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
    };
  }
}

class IncomeCategory {
  final String category;
  final double amount;
  final int transactionCount;
  final double percentage;

  IncomeCategory({
    required this.category,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'transaction_count': transactionCount,
      'percentage': percentage,
    };
  }
}

class ExpenseCategory {
  final String category;
  final double amount;
  final int transactionCount;
  final double percentage;

  ExpenseCategory({
    required this.category,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'transaction_count': transactionCount,
      'percentage': percentage,
    };
  }
}

class CashFlowReport {
  final double initialCash;
  final double finalCash;
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;
  final List<DailyCashFlow> dailyFlows;
  final DateTime fromDate;
  final DateTime toDate;

  CashFlowReport({
    required this.initialCash,
    required this.finalCash,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.dailyFlows,
    required this.fromDate,
    required this.toDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'initial_cash': initialCash,
      'final_cash': finalCash,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'net_cash_flow': netCashFlow,
      'daily_flows': dailyFlows.map((d) => d.toMap()).toList(),
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
    };
  }
}

class DailyCashFlow {
  final DateTime date;
  final double income;
  final double expenses;
  final double netFlow;
  final int transactionCount;

  DailyCashFlow({
    required this.date,
    required this.income,
    required this.expenses,
    required this.netFlow,
    required this.transactionCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'income': income,
      'expenses': expenses,
      'net_flow': netFlow,
      'transaction_count': transactionCount,
    };
  }
}

class CashSessionReport {
  final List<CashSessionSummary> sessions;
  final double totalInitialCash;
  final double totalFinalCash;
  final double totalIncome;
  final double totalExpenses;
  final int totalSessions;
  final DateTime fromDate;
  final DateTime toDate;

  CashSessionReport({
    required this.sessions,
    required this.totalInitialCash,
    required this.totalFinalCash,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalSessions,
    required this.fromDate,
    required this.toDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'total_initial_cash': totalInitialCash,
      'total_final_cash': totalFinalCash,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'total_sessions': totalSessions,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
    };
  }
}

class CashSessionSummary {
  final int sessionId;
  final String userName;
  final DateTime openDate;
  final DateTime? closeDate;
  final double initialAmount;
  final double finalAmount;
  final double totalIncome;
  final double totalExpenses;
  final double difference;
  final String status;
  final int transactionCount;

  CashSessionSummary({
    required this.sessionId,
    required this.userName,
    required this.openDate,
    this.closeDate,
    required this.initialAmount,
    required this.finalAmount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.difference,
    required this.status,
    required this.transactionCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'user_name': userName,
      'open_date': openDate.toIso8601String(),
      'close_date': closeDate?.toIso8601String(),
      'initial_amount': initialAmount,
      'final_amount': finalAmount,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'difference': difference,
      'status': status,
      'transaction_count': transactionCount,
    };
  }
}

class TransactionAuditReport {
  final List<TransactionAuditEntry> entries;
  final int totalTransactions;
  final double totalAmount;
  final Map<String, int> transactionsByType;
  final Map<String, int> transactionsByUser;
  final DateTime fromDate;
  final DateTime toDate;

  TransactionAuditReport({
    required this.entries,
    required this.totalTransactions,
    required this.totalAmount,
    required this.transactionsByType,
    required this.transactionsByUser,
    required this.fromDate,
    required this.toDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'entries': entries.map((e) => e.toMap()).toList(),
      'total_transactions': totalTransactions,
      'total_amount': totalAmount,
      'transactions_by_type': transactionsByType,
      'transactions_by_user': transactionsByUser,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
    };
  }
}

class TransactionAuditEntry {
  final int id;
  final String type;
  final double amount;
  final String description;
  final String category;
  final String paymentMethod;
  final String userName;
  final DateTime date;
  final String? reference;
  final String? documentNumber;
  final String? notes;

  TransactionAuditEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.paymentMethod,
    required this.userName,
    required this.date,
    this.reference,
    this.documentNumber,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'payment_method': paymentMethod,
      'user_name': userName,
      'date': date.toIso8601String(),
      'reference': reference,
      'document_number': documentNumber,
      'notes': notes,
    };
  }
}
