import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sqlite_database_service.dart';
import '../services/reports_service.dart';
import '../models/report_models.dart';
import '../models/group.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../services/pdf_reports_service.dart';
import '../services/company_config_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  DateTime? endDate;
  ReportType selectedReport = ReportType.sales;
  ReportPeriod selectedPeriod = ReportPeriod.today;
  String? selectedGroup;
  String? selectedPaymentMethod;
  bool isLoading = false;
  
  // Controlador para pestañas
  late TabController _tabController;
  
  // Datos de reportes
  SalesReport? salesReport;
  InventoryReport? inventoryReport;
  ProfitabilityReport? profitabilityReport;
  List<Group> availableGroups = [];
  
  // Filtros avanzados
  bool showAdvancedFilters = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroups();
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
          );
          break;
        case ReportType.inventory:
          inventoryReport = await ReportsService.generateInventoryReport(
            groupFilter: selectedGroup,
            onlyLowStock: false,
          );
          break;
        case ReportType.profitability:
          profitabilityReport = await ReportsService.generateProfitabilityReport(
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
          );
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
            onPressed: () => setState(() => showAdvancedFilters = !showAdvancedFilters),
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
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF22315B)),
              const SizedBox(width: 8),
              const Text(
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
                  value: selectedReport,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Reporte',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assessment),
                  ),
                  items: const [
                    DropdownMenuItem(value: ReportType.sales, child: Text('📊 Ventas')),
                    DropdownMenuItem(value: ReportType.products, child: Text('🏆 Productos Top')),
                    DropdownMenuItem(value: ReportType.inventory, child: Text('📦 Inventario')),
                    DropdownMenuItem(value: ReportType.profitability, child: Text('💰 Rentabilidad')),
                    DropdownMenuItem(value: ReportType.payments, child: Text('💳 Métodos de Pago')),
                    DropdownMenuItem(value: ReportType.groups, child: Text('📂 Por Grupos')),
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
                  value: selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: const [
                    DropdownMenuItem(value: ReportPeriod.today, child: Text('Hoy')),
                    DropdownMenuItem(value: ReportPeriod.yesterday, child: Text('Ayer')),
                    DropdownMenuItem(value: ReportPeriod.thisWeek, child: Text('Esta Semana')),
                    DropdownMenuItem(value: ReportPeriod.lastWeek, child: Text('Semana Pasada')),
                    DropdownMenuItem(value: ReportPeriod.thisMonth, child: Text('Este Mes')),
                    DropdownMenuItem(value: ReportPeriod.lastMonth, child: Text('Mes Pasado')),
                    DropdownMenuItem(value: ReportPeriod.custom, child: Text('Personalizado')),
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
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
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
                  value: selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Grupo de Productos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los grupos')),
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
                  value: selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos los métodos')),
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedPaymentMethod = value);
                    _loadReportData();
                  },
                ),
              ),
            ],
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
                          method.method == 'Efectivo' ? Colors.green :
                          method.method == 'Tarjeta' ? Colors.blue : Colors.orange,
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(product.productName),
                subtitle: Text('${product.groupName} • ${product.quantitySold} unidades'),
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
              return ExpansionTile(
                title: Text('${transaction.time} - \$${NumberFormat('#,###').format(transaction.total)}'),
                subtitle: Text('${transaction.paymentMethod} • ${transaction.user}'),
                children: transaction.items.map((item) {
                  return ListTile(
                    leading: const Icon(Icons.shopping_cart, size: 16),
                    title: Text(item.productName),
                    subtitle: Text('${item.groupName} • ${item.quantity} unidades'),
                    trailing: Text('\$${NumberFormat('#,###').format(item.totalPrice)}'),
                  );
                }).toList(),
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
                subtitle: Text('${item.groupName} • ${item.currentStock}/${item.minStock}'),
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
                  backgroundColor: product.profitMargin > 30 ? Colors.green :
                                  product.profitMargin > 15 ? Colors.orange : Colors.red,
                  child: Text(
                    '${product.profitMargin.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                title: Text(product.productName),
                subtitle: Text('${product.groupName} • ${product.quantitySold} unidades vendidas'),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
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
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
    
    final maxSales = salesReport!.salesByHour.map((h) => h.amount).reduce((a, b) => a > b ? a : b);
    
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
  
  Future<void> _exportReport() async {
    try {
      setState(() => isLoading = true);
      
      // Obtener configuración de la empresa
      final companyConfig = await CompanyConfigService.getCompanyConfig();
      final companyName = companyConfig.companyName;
      
      // Generar período del reporte
      String reportPeriod = _getReportPeriodText();
      
      // Seleccionar ubicación para guardar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte como PDF',
        fileName: 'reporte_${selectedReport.name}_${DateFormat('yyyyMMdd').format(selectedDate)}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        Get.snackbar(
          'Información',
          'Operación cancelada',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      Uint8List pdfBytes;
      
      // Generar PDF según el tipo de reporte
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
          // Estos se manejan como sub-reportes de ventas
          if (salesReport == null) {
            throw Exception('No hay datos de ventas para exportar');
          }
          pdfBytes = await PDFReportsService.generateSalesReportPDF(
            report: salesReport!,
            companyName: companyName,
            reportPeriod: reportPeriod,
          );
          break;
      }
      
      // Guardar archivo PDF en la ubicación seleccionada
      final file = File(outputFile);
      await file.writeAsBytes(pdfBytes);
      
      Get.snackbar(
        '✅ Reporte PDF Exportado',
        'Archivo guardado correctamente como PDF profesional',
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
} 