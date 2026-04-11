import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sqlite_database_service.dart';
import '../services/reports_service.dart';
import '../services/print_service.dart';
import '../models/report_models.dart';
import '../models/group.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/pdf_reports_service.dart';
import '../services/company_config_service.dart';
import '../models/user.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  DateTime? endDate;
  ReportType selectedReport = ReportType.sales;
  ReportPeriod selectedPeriod = ReportPeriod.today;
  String? selectedGroup;
  String? selectedPaymentMethod;
  String? selectedCashier;
  bool isLoading = false;

  // Controlador para pestañas
  late TabController _tabController;

  // Datos de reportes
  SalesReport? salesReport;
  InventoryReport? inventoryReport;
  ProfitabilityReport? profitabilityReport;
  List<Group> availableGroups = [];
  List<User> availableUsers = [];

  // Filtros avanzados
  bool showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 5,
        vsync:
            this); // ✅ Corregido: 5 tabs (ventas, productos, inventario, rentabilidad, grupos)
    _loadGroups();
    _loadUsers();
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await SQLiteDatabaseService.getAllGroups();
      setState(() {
        availableGroups = groups;
      });
    } catch (e) {
      print('Error cargando grupos: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await SQLiteDatabaseService.getAllUsers();
      setState(() {
        availableUsers =
            users.where((u) => u.isActive).toList()
              ..sort((a, b) => a.username.compareTo(b.username));
      });
    } catch (e) {
      print('Error cargando usuarios: $e');
    }
  }

  Future<void> _loadReportData() async {
    setState(() => isLoading = true);
    try {
      switch (selectedReport) {
        case ReportType.sales:
          salesReport = await ReportsService.generateSalesReport(
            date: selectedDate,
            endDate: endDate,
            groupFilter: selectedGroup,
            paymentMethodFilter: selectedPaymentMethod,
            userFilter: selectedCashier,
          );
          break;
        case ReportType.inventory:
          inventoryReport = await ReportsService.generateInventoryReport(
            groupFilter: selectedGroup,
            onlyLowStock: false,
          );
          break;
        case ReportType.profitability:
          profitabilityReport =
              await ReportsService.generateProfitabilityReport(
            date: selectedDate,
            endDate: endDate,
            groupFilter: selectedGroup,
          );
          break;
        case ReportType.products:
        case ReportType.payments:
        case ReportType.groups:
          // Estos se manejan como sub-reportes de ventas
          salesReport = await ReportsService.generateSalesReport(
            date: selectedDate,
            endDate: endDate,
            groupFilter: selectedGroup,
            paymentMethodFilter: selectedPaymentMethod,
            userFilter: selectedCashier,
          );
          break;
        case ReportType.suppliers:
          // TODO: Implementar carga de reporte de proveedores
          break;
        case ReportType.accounting:
          // TODO: Implementar carga de reporte contable
          break;
      }
    } catch (e) {
      Get.snackbar('Error', 'Error cargando reporte: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF22315B)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Reportes Profesionales',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.download, color: Color(0xFF22315B)),
            tooltip: 'Exportar Reporte',
          ),
          IconButton(
            onPressed: _showPrintReportDialog,
            icon: const Icon(Icons.print, color: Color(0xFF22315B)),
            tooltip: 'Imprimir reporte (POS u otra impresora)',
          ),
          IconButton(
            onPressed: () =>
                setState(() => showAdvancedFilters = !showAdvancedFilters),
            icon: Icon(
              showAdvancedFilters ? Icons.filter_list_off : Icons.filter_list,
              color: const Color(0xFF22315B),
            ),
            tooltip: 'Filtros Avanzados',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros principales
          _buildMainFilters(),

          // Filtros avanzados (condicionales)
          if (showAdvancedFilters) _buildAdvancedFilters(),

          // Contenido del reporte con pestañas
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF22315B)),
              SizedBox(width: 8),
              Text(
                'Filtros Principales',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Tipo de Reporte
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ReportType>(
                  initialValue: selectedReport,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Reporte',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assessment),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: ReportType.sales, child: Text('📊 Ventas')),
                    DropdownMenuItem(
                        value: ReportType.products,
                        child: Text('🏆 Productos Top')),
                    DropdownMenuItem(
                        value: ReportType.inventory,
                        child: Text('📦 Inventario')),
                    DropdownMenuItem(
                        value: ReportType.profitability,
                        child: Text('💰 Rentabilidad')),
                    DropdownMenuItem(
                        value: ReportType.payments,
                        child: Text('💳 Métodos de Pago')),
                    DropdownMenuItem(
                        value: ReportType.groups, child: Text('📂 Por Grupos')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedReport = value!);
                    _loadReportData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Período
              Expanded(
                child: DropdownButtonFormField<ReportPeriod>(
                  initialValue: selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: ReportPeriod.today, child: Text('Hoy')),
                    DropdownMenuItem(
                        value: ReportPeriod.yesterday, child: Text('Ayer')),
                    DropdownMenuItem(
                        value: ReportPeriod.thisWeek,
                        child: Text('Esta Semana')),
                    DropdownMenuItem(
                        value: ReportPeriod.lastWeek,
                        child: Text('Semana Pasada')),
                    DropdownMenuItem(
                        value: ReportPeriod.thisMonth, child: Text('Este Mes')),
                    DropdownMenuItem(
                        value: ReportPeriod.lastMonth,
                        child: Text('Mes Pasado')),
                    DropdownMenuItem(
                        value: ReportPeriod.custom,
                        child: Text('Personalizado')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedPeriod = value!);
                    _updateDateRange();
                    _loadReportData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Fecha
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Filtros Avanzados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Filtro por Grupo
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Grupo de Productos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos los grupos')),
                    ...availableGroups.map((group) => DropdownMenuItem(
                          value: group.name,
                          child: Text(group.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => selectedGroup = value);
                    _loadReportData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Filtro por Método de Pago
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('Todos los métodos')),
                    DropdownMenuItem(
                        value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(
                        value: 'Transferencia', child: Text('Transferencia')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedPaymentMethod = value);
                    _loadReportData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedCashier,
            decoration: const InputDecoration(
              labelText: 'Cajero',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todos los cajeros'),
              ),
              ...availableUsers.map((u) => DropdownMenuItem(
                    value: u.username,
                    child: Text('${u.username} (${u.fullName})'),
                  )),
            ],
            onChanged: (value) {
              setState(() => selectedCashier = value);
              _loadReportData();
            },
          ),
        ],
      ),
    );
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case ReportPeriod.today:
        selectedDate = now;
        endDate = null;
        break;
      case ReportPeriod.yesterday:
        selectedDate = now.subtract(const Duration(days: 1));
        endDate = null;
        break;
      case ReportPeriod.thisWeek:
        selectedDate = now.subtract(Duration(days: now.weekday - 1));
        endDate = now;
        break;
      case ReportPeriod.lastWeek:
        final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
        selectedDate = lastWeekStart;
        endDate = lastWeekStart.add(const Duration(days: 6));
        break;
      case ReportPeriod.thisMonth:
        selectedDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case ReportPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        selectedDate = lastMonth;
        endDate = DateTime(now.year, now.month, 0);
        break;
      case ReportPeriod.thisYear:
        selectedDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
      case ReportPeriod.lastYear:
        selectedDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31);
        break;
      case ReportPeriod.custom:
        // Mantener fechas actuales para selección manual
        break;
    }
  }

  Widget _buildReportContent() {
    switch (selectedReport) {
      case ReportType.sales:
        return _buildSalesReport();
      case ReportType.products:
        return _buildProductsReport();
      case ReportType.inventory:
        return _buildInventoryReport();
      case ReportType.profitability:
        return _buildProfitabilityReport();
      case ReportType.payments:
        return _buildPaymentsReport();
      case ReportType.groups:
        return _buildGroupsReport();
      case ReportType.suppliers:
        return _buildSuppliersReport();
      case ReportType.accounting:
        return _buildAccountingReport();
    }
  }

  Widget _buildSalesReport() {
    if (salesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen principal
          _buildSalesSummaryCards(),
          const SizedBox(height: 24),

          // Gráfico de ventas por hora
          _buildSalesChart(),
          const SizedBox(height: 24),

          // Métodos de pago
          _buildPaymentMethodsChart(),
          const SizedBox(height: 24),

          // Top productos
          _buildTopProductsSection(),
          const SizedBox(height: 24),

          // Transacciones detalladas
          _buildTransactionsSection(),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'Total Ventas',
          '\$${NumberFormat('#,###').format(salesReport!.totalSales)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildSummaryCard(
          'Transacciones',
          '${salesReport!.totalTransactions}',
          Icons.receipt,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Ticket Promedio',
          '\$${NumberFormat('#,###').format(salesReport!.averageTicket)}',
          Icons.trending_up,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Productos Vendidos',
          '${salesReport!.topProducts.fold(0, (sum, p) => sum + p.quantitySold)}',
          Icons.inventory,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métodos de Pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...salesReport!.salesByPaymentMethod.map((method) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(method.method),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: method.percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          method.method == 'Efectivo'
                              ? Colors.green
                              : method.method == 'Tarjeta'
                                  ? Colors.blue
                                  : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${NumberFormat('#,###').format(method.amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${method.percentage.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 Productos Más Vendidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...salesReport!.topProducts.take(10).map((product) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    '${product.rank}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(product.productName),
                subtitle: Text(
                    '${product.groupName} • ${product.quantitySold} unidades'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${NumberFormat('#,###').format(product.totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${product.profitMargin.toStringAsFixed(1)}% margen',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transacciones Detalladas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...salesReport!.transactions.map((transaction) {
              final nf = NumberFormat('#,###', 'es_CO');
              final pct = transaction.globalDiscountPercent;
              final hasGlobal = transaction.globalDiscountAmount != null &&
                  transaction.globalDiscountAmount! > 0;
              String? discSubtitle;
              if (hasGlobal) {
                final amt = transaction.globalDiscountAmount!;
                if (pct != null && pct > 0) {
                  final pStr = pct == pct.roundToDouble()
                      ? pct.round().toString()
                      : pct.toStringAsFixed(1);
                  discSubtitle =
                      'Descuento % al total: $pStr% (−\$${nf.format(amt)})';
                } else {
                  discSubtitle = 'Descuento al total: −\$${nf.format(amt)}';
                }
              }
              return ExpansionTile(
                title: Text(
                    '${transaction.time} - \$${nf.format(transaction.total)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '${transaction.paymentMethod} • ${transaction.user}'),
                    if (discSubtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          discSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                children: [
                  ...transaction.items.map((item) {
                    final modNote = item.priceModifiedVsList &&
                            item.listUnitPrice != null
                        ? 'Lista \$${nf.format(item.listUnitPrice!)} → vendido \$${nf.format(item.unitPrice)}'
                        : null;
                    return ListTile(
                      leading: const Icon(Icons.shopping_cart, size: 16),
                      title: Text(item.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${item.groupName} • ${item.quantity} u. @ \$${nf.format(item.unitPrice)}'),
                          if (modNote != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                modNote,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepOrange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text('\$${nf.format(item.totalPrice)}'),
                    );
                  }),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsReport() {
    if (salesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopProductsSection(),
        ],
      ),
    );
  }

  Widget _buildInventoryReport() {
    if (inventoryReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de inventario
          _buildInventorySummaryCards(),
          const SizedBox(height: 24),

          // Lista de productos
          _buildInventoryList(),
        ],
      ),
    );
  }

  Widget _buildProfitabilityReport() {
    if (profitabilityReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de rentabilidad
          _buildProfitabilitySummaryCards(),
          const SizedBox(height: 24),

          // Lista de productos por rentabilidad
          _buildProfitabilityList(),
        ],
      ),
    );
  }

  Widget _buildPaymentsReport() {
    if (salesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentMethodsChart(),
        ],
      ),
    );
  }

  Widget _buildGroupsReport() {
    if (salesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupsChart(),
        ],
      ),
    );
  }

  Widget _buildInventorySummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'Total Productos',
          '${inventoryReport!.totalProducts}',
          Icons.inventory,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Stock Bajo',
          '${inventoryReport!.lowStockProducts}',
          Icons.warning,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Sin Stock',
          '${inventoryReport!.outOfStockProducts}',
          Icons.error,
          Colors.red,
        ),
        _buildSummaryCard(
          'Valor Total',
          '\$${NumberFormat('#,###').format(inventoryReport!.totalInventoryValue)}',
          Icons.attach_money,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado del Inventario',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...inventoryReport!.items.map((item) {
              Color statusColor = Colors.green;
              IconData statusIcon = Icons.check_circle;

              if (item.status == 'LOW') {
                statusColor = Colors.orange;
                statusIcon = Icons.warning;
              } else if (item.status == 'OUT') {
                statusColor = Colors.red;
                statusIcon = Icons.error;
              }

              return ListTile(
                leading: Icon(statusIcon, color: statusColor),
                title: Text(item.productName),
                subtitle: Text(
                    '${item.groupName} • ${item.currentStock}/${item.minStock}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${NumberFormat('#,###').format(item.totalValue)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${item.profitMargin.toStringAsFixed(1)}% margen',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitabilitySummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'Ingresos Totales',
          '\$${NumberFormat('#,###').format(profitabilityReport!.totalRevenue)}',
          Icons.trending_up,
          Colors.green,
        ),
        _buildSummaryCard(
          'Costos Totales',
          '\$${NumberFormat('#,###').format(profitabilityReport!.totalCost)}',
          Icons.trending_down,
          Colors.red,
        ),
        _buildSummaryCard(
          'Utilidad Total',
          '\$${NumberFormat('#,###').format(profitabilityReport!.totalProfit)}',
          Icons.attach_money,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Margen Promedio',
          '${profitabilityReport!.profitMargin.toStringAsFixed(1)}%',
          Icons.percent,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildProfitabilityList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rentabilidad por Producto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...profitabilityReport!.products.map((product) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.profitMargin > 30
                      ? Colors.green
                      : product.profitMargin > 15
                          ? Colors.orange
                          : Colors.red,
                  child: Text(
                    '${product.profitMargin.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ),
                title: Text(product.productName),
                subtitle: Text(
                    '${product.groupName} • ${product.quantitySold} unidades vendidas'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${NumberFormat('#,###').format(product.profit)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ROI: ${product.roi.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Grupo de Productos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...salesReport!.salesByGroup.map((group) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(group.groupName),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: group.percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${NumberFormat('#,###').format(group.amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${group.quantity}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    if (salesReport == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Hora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (salesReport == null) return const SizedBox();

    final maxSales = salesReport!.salesByHour
        .map((h) => h.amount)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: salesReport!.salesByHour.map((hourData) {
        final height = maxSales > 0 ? (hourData.amount / maxSales) * 150 : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 8,
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${hourData.hour}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadReportData();
    }
  }

  /// Guarda el PDF: intenta diálogo "Guardar como"; si falla, guarda en Documentos.
  Future<String?> _saveReportPdf(
      Uint8List pdfBytes, String baseFileName) async {
    final fileName = '$baseFileName.pdf';
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte como PDF',
        fileName: fileName,
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );
      if (outputFile == null || outputFile.trim().isEmpty) return null;
      String finalPath = outputFile.trim();
      if (!finalPath.toLowerCase().endsWith('.pdf')) {
        finalPath = '$finalPath.pdf';
      }
      final file = File(finalPath);
      await file.writeAsBytes(pdfBytes);
      return finalPath;
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = baseFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final finalPath = path.join(dir.path, '$safeName.pdf');
      final file = File(finalPath);
      await file.writeAsBytes(pdfBytes);
      return finalPath;
    }
  }

  Future<void> _exportReport() async {
    try {
      setState(() => isLoading = true);

      // Obtener configuración de la empresa
      final companyConfig = await CompanyConfigService.getCompanyConfig();
      final companyName = companyConfig.companyName;

      // Generar período del reporte
      String reportPeriod = _getReportPeriodText();

      Uint8List pdfBytes;
      switch (selectedReport) {
        case ReportType.sales:
          if (salesReport == null) {
            throw Exception('No hay datos de ventas para exportar');
          }
          pdfBytes = await PDFReportsService.generateSalesReportPDF(
            report: salesReport!,
            companyName: companyName,
            reportPeriod: reportPeriod,
          );
          break;
        case ReportType.inventory:
          if (inventoryReport == null) {
            throw Exception('No hay datos de inventario para exportar');
          }
          pdfBytes = await PDFReportsService.generateInventoryReportPDF(
            report: inventoryReport!,
            companyName: companyName,
            reportPeriod: reportPeriod,
          );
          break;
        case ReportType.profitability:
          if (profitabilityReport == null) {
            throw Exception('No hay datos de rentabilidad para exportar');
          }
          pdfBytes = await PDFReportsService.generateProfitabilityReportPDF(
            report: profitabilityReport!,
            companyName: companyName,
            reportPeriod: reportPeriod,
          );
          break;
        case ReportType.products:
        case ReportType.payments:
        case ReportType.groups:
          if (salesReport == null) {
            throw Exception('No hay datos de ventas para exportar');
          }
          pdfBytes = await PDFReportsService.generateSalesReportPDF(
            report: salesReport!,
            companyName: companyName,
            reportPeriod: reportPeriod,
          );
          break;
        case ReportType.suppliers:
          throw Exception(
              'Exportación de reporte de proveedores no implementada aún');
        case ReportType.accounting:
          throw Exception(
              'Exportación de reporte contable no implementada aún');
      }

      final baseFileName =
          'reporte_${selectedReport.name}_${DateFormat('yyyyMMdd').format(selectedDate)}'
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savedPath = await _saveReportPdf(pdfBytes, baseFileName);
      if (savedPath == null) {
        Get.snackbar('Información', 'Operación cancelada',
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      Get.snackbar(
        '✅ Reporte PDF Exportado',
        'Archivo guardado: $savedPath',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Error exportando reporte PDF: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Diálogo para imprimir reporte: impresora POS o elegir otra.
  Future<void> _showPrintReportDialog() async {
    final hasSalesData = salesReport != null;
    if (!hasSalesData &&
        (selectedReport == ReportType.sales ||
            selectedReport == ReportType.products ||
            selectedReport == ReportType.payments ||
            selectedReport == ReportType.groups)) {
      Get.snackbar(
        'Aviso',
        'Genere el reporte primero (filtros y tipo de reporte) y vuelva a pulsar Imprimir.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedReport != ReportType.sales &&
        selectedReport != ReportType.products &&
        selectedReport != ReportType.payments &&
        selectedReport != ReportType.groups) {
      Get.snackbar(
        'Aviso',
        'Impresión disponible solo para reportes de ventas / productos / métodos de pago / grupos.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    List<Map<String, dynamic>> printers = [];
    try {
      printers = await PrintService.instance.listPrinters();
    } catch (_) {}

    if (!mounted) return;

    bool usePosPrinter = true;
    String? selectedPrinterName =
        printers.isNotEmpty ? printers.first['name'] as String? : null;

    final choice = await Get.dialog<Map<String, dynamic>>(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Imprimir reporte de ventas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Dónde imprimir?'),
                  const SizedBox(height: 12),
                  RadioListTile<bool>(
                    title: const Text(
                        'Impresora POS (la configurada para tickets)'),
                    value: true,
                    groupValue: usePosPrinter,
                    onChanged: (v) =>
                        setStateDialog(() => usePosPrinter = true),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Otra impresora'),
                    value: false,
                    groupValue: usePosPrinter,
                    onChanged: (v) =>
                        setStateDialog(() => usePosPrinter = false),
                  ),
                  if (!usePosPrinter) ...[
                    const SizedBox(height: 8),
                    if (printers.isEmpty)
                      const Text('No se detectaron impresoras.',
                          style: TextStyle(fontSize: 12))
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedPrinterName,
                        decoration: const InputDecoration(
                            labelText: 'Impresora',
                            border: OutlineInputBorder()),
                        items: printers
                            .map((p) {
                              final n = p['name'] as String?;
                              return n != null
                                  ? DropdownMenuItem<String>(
                                      value: n, child: Text(n))
                                  : null;
                            })
                            .whereType<DropdownMenuItem<String>>()
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => selectedPrinterName = v),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: null),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Get.back(result: {
                  'usePos': usePosPrinter,
                  'printerName': usePosPrinter ? null : selectedPrinterName,
                }),
                child: const Text('Imprimir'),
              ),
            ],
          );
        },
      ),
    );
    if (choice == null || !mounted) return;

    final usePos = choice['usePos'] as bool? ?? true;
    final printerName = choice['printerName'] as String?;

    setState(() => isLoading = true);
    try {
      final text = _buildSalesReportText();
      final bytes = utf8.encode(text);
      final ok = await PrintService.instance.printRawToPrinter(
        bytes,
        printerName: usePos ? null : printerName,
      );
      if (ok) {
        Get.snackbar('Éxito', 'Reporte enviado a la impresora',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'No se pudo imprimir. Compruebe la impresora.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al imprimir: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Construye el reporte de ventas en texto plano para impresora.
  String _buildSalesReportText() {
    if (salesReport == null) return '';
    final r = salesReport!;
    final nf = NumberFormat('#,##0', 'es_CO');
    const w = 48;
    final sep = '=' * w;
    final dash = '-' * w;
    final period = _getReportPeriodText();
    final sb = StringBuffer();
    sb.writeln(sep);
    sb.writeln('REPORTE DE VENTAS'.padLeft((w + 15) ~/ 2).padRight(w));
    sb.writeln(period.length > w
        ? period.substring(0, w)
        : period.padLeft((w + period.length) ~/ 2).padRight(w));
    sb.writeln(sep);
    sb.writeln('');
    sb.writeln('Total ventas:      \$${nf.format(r.totalSales)}');
    sb.writeln('Ventas netas:      \$${nf.format(r.netSales)}');
    sb.writeln('Transacciones:     ${r.totalTransactions}');
    sb.writeln('Ticket promedio:   \$${nf.format(r.averageTicket)}');
    if (r.totalDiscounts != null && r.totalDiscounts! > 0)
      sb.writeln('Descuentos:        \$${nf.format(r.totalDiscounts)}');
    if (r.totalReturns != null && r.totalReturns! > 0)
      sb.writeln('Devoluciones:      \$${nf.format(r.totalReturns)}');
    sb.writeln(dash);
    sb.writeln('Por método de pago:');
    for (final m in r.salesByPaymentMethod) {
      sb.writeln('  ${m.method}: \$${nf.format(m.amount)} (${m.transactions})');
    }
    sb.writeln(dash);
    sb.writeln('Transacciones:');
    for (final t in r.transactions.take(50)) {
      var line =
          '  ${DateFormat('HH:mm').format(t.date)} \$${nf.format(t.total)} ${t.paymentMethod}';
      if (t.globalDiscountAmount != null && t.globalDiscountAmount! > 0) {
        final p = t.globalDiscountPercent;
        if (p != null && p > 0) {
          final ps = p == p.roundToDouble() ? '${p.round()}' : p.toStringAsFixed(1);
          line += ' | Dcto ${ps}% (−\$${nf.format(t.globalDiscountAmount!)})';
        } else {
          line += ' | Dcto −\$${nf.format(t.globalDiscountAmount!)}';
        }
      }
      sb.writeln(line);
      for (final it in t.items) {
        if (it.priceModifiedVsList && it.listUnitPrice != null) {
          sb.writeln(
              '      · ${it.productName}: lista \$${nf.format(it.listUnitPrice!)} → \$${nf.format(it.unitPrice)}');
        }
      }
    }
    if (r.transactions.length > 50)
      sb.writeln('  ... y ${r.transactions.length - 50} más');
    sb.writeln(sep);
    sb.writeln('Smart Seller POS');
    sb.writeln('');
    return sb.toString();
  }

  String _getReportPeriodText() {
    switch (selectedPeriod) {
      case ReportPeriod.today:
        return 'Hoy - ${DateFormat('dd/MM/yyyy').format(selectedDate)}';
      case ReportPeriod.yesterday:
        return 'Ayer - ${DateFormat('dd/MM/yyyy').format(selectedDate)}';
      case ReportPeriod.thisWeek:
        return 'Esta Semana - ${DateFormat('dd/MM/yyyy').format(selectedDate)} a ${DateFormat('dd/MM/yyyy').format(endDate ?? selectedDate)}';
      case ReportPeriod.lastWeek:
        return 'Semana Pasada - ${DateFormat('dd/MM/yyyy').format(selectedDate)} a ${DateFormat('dd/MM/yyyy').format(endDate ?? selectedDate)}';
      case ReportPeriod.thisMonth:
        return 'Este Mes - ${DateFormat('dd/MM/yyyy').format(selectedDate)} a ${DateFormat('dd/MM/yyyy').format(endDate ?? selectedDate)}';
      case ReportPeriod.lastMonth:
        return 'Mes Pasado - ${DateFormat('dd/MM/yyyy').format(selectedDate)} a ${DateFormat('dd/MM/yyyy').format(endDate ?? selectedDate)}';
      case ReportPeriod.thisYear:
        return 'Este Año - ${selectedDate.year}';
      case ReportPeriod.lastYear:
        return 'Año Pasado - ${selectedDate.year}';
      case ReportPeriod.custom:
        return 'Personalizado - ${DateFormat('dd/MM/yyyy').format(selectedDate)} a ${DateFormat('dd/MM/yyyy').format(endDate ?? selectedDate)}';
    }
  }

  // ✅ NUEVO: Widget para reporte de proveedores
  Widget _buildSuppliersReport() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Reporte de Proveedores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Funcionalidad en desarrollo',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Widget para reporte contable
  Widget _buildAccountingReport() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Reporte Contable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Funcionalidad en desarrollo',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
