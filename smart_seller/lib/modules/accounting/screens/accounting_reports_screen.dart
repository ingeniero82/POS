// Pantalla para reportes contables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/accounting_reports.dart';
import '../services/accounting_reports_service.dart';

class AccountingReportsScreen extends StatefulWidget {
  const AccountingReportsScreen({super.key});

  @override
  State<AccountingReportsScreen> createState() => _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  
  Map<String, dynamic> _quickSummary = {};
  IncomeStatement? _incomeStatement;
  CashFlowReport? _cashFlowReport;
  CashSessionReport? _cashSessionReport;
  TransactionAuditReport? _auditReport;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadQuickSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuickSummary() async {
    setState(() => _isLoading = true);
    
    try {
      final summary = await AccountingReportsService.getQuickSummary(_fromDate, _toDate);
      setState(() {
        _quickSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo cargar el resumen: $e');
    }
  }

  Future<void> _loadIncomeStatement() async {
    setState(() => _isLoading = true);
    
    try {
      final statement = await AccountingReportsService.generateIncomeStatement(_fromDate, _toDate);
      setState(() {
        _incomeStatement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo generar el estado de resultados: $e');
    }
  }

  Future<void> _loadCashFlowReport() async {
    setState(() => _isLoading = true);
    
    try {
      final report = await AccountingReportsService.generateCashFlowReport(_fromDate, _toDate);
      setState(() {
        _cashFlowReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo generar el reporte de flujo de caja: $e');
    }
  }

  Future<void> _loadCashSessionReport() async {
    setState(() => _isLoading = true);
    
    try {
      final report = await AccountingReportsService.generateCashSessionReport(_fromDate, _toDate);
      setState(() {
        _cashSessionReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo generar el reporte de sesiones: $e');
    }
  }

  Future<void> _loadAuditReport() async {
    setState(() => _isLoading = true);
    
    try {
      final report = await AccountingReportsService.generateTransactionAuditReport(_fromDate, _toDate);
      setState(() {
        _auditReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo generar el reporte de auditoría: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadQuickSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Contables'),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Seleccionar rango de fechas',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Estado de Resultados'),
            Tab(text: 'Flujo de Caja'),
            Tab(text: 'Sesiones de Caja'),
            Tab(text: 'Auditoría'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Rango de fechas seleccionado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit),
                  label: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          
          // Contenido de las pestañas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildIncomeStatementTab(),
                      _buildCashFlowTab(),
                      _buildCashSessionTab(),
                      _buildAuditTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarjetas de resumen
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Ingresos',
                  '\$${(_quickSummary['total_income'] ?? 0).toStringAsFixed(2)}',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Total Egresos',
                  '\$${(_quickSummary['total_expenses'] ?? 0).toStringAsFixed(2)}',
                  Colors.red,
                  Icons.trending_down,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Utilidad Neta',
                  '\$${(_quickSummary['net_income'] ?? 0).toStringAsFixed(2)}',
                  (_quickSummary['net_income'] ?? 0) >= 0 ? Colors.green : Colors.red,
                  Icons.account_balance,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Transacciones',
                  '${_quickSummary['transaction_count'] ?? 0}',
                  Colors.blue,
                  Icons.receipt,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Botones para generar reportes detallados
          Text(
            'Reportes Detallados',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildReportButton(
                'Estado de Resultados',
                Icons.bar_chart,
                Colors.blue,
                _loadIncomeStatement,
              ),
              _buildReportButton(
                'Flujo de Caja',
                Icons.account_balance_wallet,
                Colors.green,
                _loadCashFlowReport,
              ),
              _buildReportButton(
                'Sesiones de Caja',
                Icons.point_of_sale,
                Colors.orange,
                _loadCashSessionReport,
              ),
              _buildReportButton(
                'Auditoría',
                Icons.security,
                Colors.purple,
                _loadAuditReport,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildIncomeStatementTab() {
    if (_incomeStatement == null) {
      return const Center(
        child: Text('Haz clic en "Estado de Resultados" para generar el reporte'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen del estado de resultados
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Estado de Resultados',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Ingresos', _incomeStatement!.totalIncome, Colors.green),
                      _buildSummaryItem('Total Egresos', _incomeStatement!.totalExpenses, Colors.red),
                      _buildSummaryItem('Utilidad Neta', _incomeStatement!.netIncome, 
                          _incomeStatement!.netIncome >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Ingresos por categoría
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresos por Categoría',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._incomeStatement!.incomeCategories.map((category) => 
                    _buildCategoryItem(category.category, category.amount, category.percentage, Colors.green)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Egresos por categoría
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Egresos por Categoría',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._incomeStatement!.expenseCategories.map((category) => 
                    _buildCategoryItem(category.category, category.amount, category.percentage, Colors.red)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String category, double amount, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(category),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowTab() {
    if (_cashFlowReport == null) {
      return const Center(
        child: Text('Haz clic en "Flujo de Caja" para generar el reporte'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Resumen del flujo de caja
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Flujo de Caja',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Efectivo Inicial', _cashFlowReport!.initialCash, Colors.blue),
                      _buildSummaryItem('Efectivo Final', _cashFlowReport!.finalCash, Colors.green),
                      _buildSummaryItem('Flujo Neto', _cashFlowReport!.netCashFlow, 
                          _cashFlowReport!.netCashFlow >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Flujo diario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flujo Diario',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._cashFlowReport!.dailyFlows.map((flow) => 
                    _buildDailyFlowItem(flow)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFlowItem(DailyCashFlow flow) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(DateFormat('dd/MM/yyyy').format(flow.date)),
          Text('\$${flow.income.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
          Text('\$${flow.expenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
          Text('\$${flow.netFlow.toStringAsFixed(2)}', 
              style: TextStyle(color: flow.netFlow >= 0 ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  Widget _buildCashSessionTab() {
    if (_cashSessionReport == null) {
      return const Center(
        child: Text('Haz clic en "Sesiones de Caja" para generar el reporte'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Resumen de sesiones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Resumen de Sesiones de Caja',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Sesiones', _cashSessionReport!.totalSessions.toDouble(), Colors.blue),
                      _buildSummaryItem('Total Ingresos', _cashSessionReport!.totalIncome, Colors.green),
                      _buildSummaryItem('Total Egresos', _cashSessionReport!.totalExpenses, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Lista de sesiones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesiones de Caja',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._cashSessionReport!.sessions.map((session) => 
                    _buildSessionItem(session)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(CashSessionSummary session) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sesión #${session.sessionId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: session.status == 'closed' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  session.status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          Text('Usuario: ${session.userName}'),
          Text('Apertura: ${DateFormat('dd/MM/yyyy HH:mm').format(session.openDate)}'),
          if (session.closeDate != null)
            Text('Cierre: ${DateFormat('dd/MM/yyyy HH:mm').format(session.closeDate!)}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inicial: \$${session.initialAmount.toStringAsFixed(2)}'),
              Text('Final: \$${session.finalAmount.toStringAsFixed(2)}'),
              Text('Diferencia: \$${session.difference.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    if (_auditReport == null) {
      return const Center(
        child: Text('Haz clic en "Auditoría" para generar el reporte'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Resumen de auditoría
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Auditoría de Transacciones',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Transacciones', _auditReport!.totalTransactions.toDouble(), Colors.blue),
                      _buildSummaryItem('Monto Total', _auditReport!.totalAmount, Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Lista de transacciones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transacciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._auditReport!.entries.take(50).map((entry) => 
                    _buildAuditItem(entry)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditItem(TransactionAuditEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: entry.type == 'income' ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${entry.category} - ${entry.userName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '\$${entry.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: entry.type == 'income' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
