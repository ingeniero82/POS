import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sqlite_database_service.dart';
import '../models/sale.dart';
import '../models/product.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedReport = 'sales';
  bool isLoading = false;
  
  // Datos de reportes
  List<Sale> sales = [];
  List<Product> topProducts = [];
  double totalSales = 0.0;
  int totalTransactions = 0;
  
  @override
  void initState() {
    super.initState();
    _loadReportData();
  }
  
  Future<void> _loadReportData() async {
    setState(() => isLoading = true);
    try {
      switch (selectedReport) {
        case 'sales':
          await _loadSalesReport();
          break;
        case 'products':
          await _loadProductsReport();
          break;
        case 'inventory':
          await _loadInventoryReport();
          break;
      }
    } catch (e) {
      Get.snackbar('Error', 'Error cargando reporte: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadSalesReport() async {
    sales = await SQLiteDatabaseService.getSales(date: selectedDate);
    totalSales = sales.fold(0.0, (sum, sale) => sum + sale.total);
    totalTransactions = sales.length;
  }
  
  Future<void> _loadProductsReport() async {
    // Cargar productos más vendidos
    topProducts = await SQLiteDatabaseService.getAllProducts();
  }
  
  Future<void> _loadInventoryReport() async {
    // Cargar reporte de inventario
    topProducts = await SQLiteDatabaseService.getAllProducts();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.download),
            tooltip: 'Exportar Reporte',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _buildFilters(),
          
          // Contenido del reporte
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedReport,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Reporte',
                      prefixIcon: Icon(Icons.assessment),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sales', child: Text('Ventas')),
                      DropdownMenuItem(value: 'products', child: Text('Productos')),
                      DropdownMenuItem(value: 'inventory', child: Text('Inventario')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedReport = value!);
                      _loadReportData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
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
      ),
    );
  }
  
  Widget _buildReportContent() {
    switch (selectedReport) {
      case 'sales':
        return _buildSalesReport();
      case 'products':
        return _buildProductsReport();
      case 'inventory':
        return _buildInventoryReport();
      default:
        return const Center(child: Text('Selecciona un reporte'));
    }
  }
  
  Widget _buildSalesReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen
          _buildSummaryCards(),
          const SizedBox(height: 24),
          
          // Gráfico de ventas por hora
          _buildSalesChart(),
          const SizedBox(height: 24),
          
          // Lista de ventas
          Text(
            'Ventas del ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          if (sales.isEmpty)
            _buildEmptyState('No hay ventas para esta fecha')
          else
            _buildSalesList(),
        ],
      ),
    );
  }
  
  Widget _buildProductsReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos Más Vendidos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          if (topProducts.isEmpty)
            _buildEmptyState('No hay datos de productos')
          else
            _buildProductsList(),
        ],
      ),
    );
  }
  
  Widget _buildInventoryReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos con Stock Bajo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          if (topProducts.isEmpty)
            _buildEmptyState('No hay productos con stock bajo')
          else
            _buildInventoryList(),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Ventas',
          '\$${NumberFormat('#,###').format(totalSales)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildSummaryCard(
          'Transacciones',
          '$totalTransactions',
          Icons.receipt,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Promedio',
          '\$${totalTransactions > 0 ? NumberFormat('#,###').format(totalSales / totalTransactions) : '0'}',
          Icons.trending_up,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Productos',
          '${topProducts.length}',
          Icons.inventory,
          Colors.purple,
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventas por Hora',
              style: Theme.of(context).textTheme.titleMedium,
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
    // Simulación de gráfico de barras
    final hours = List.generate(24, (index) => index);
    final salesByHour = List.generate(24, (index) {
      final hourSales = sales.where((sale) {
        final saleHour = sale.date.hour;
        return saleHour == index;
      }).toList();
      return hourSales.fold(0.0, (sum, sale) => sum + sale.total);
    });
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: hours.map((hour) {
        final sales = salesByHour[hour];
        final maxSales = salesByHour.reduce((a, b) => a > b ? a : b);
        final height = maxSales > 0 ? (sales / maxSales) * 150 : 0.0;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 8,
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$hour',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildSalesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              DateFormat('HH:mm').format(sale.date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${sale.items.length} productos'),
            trailing: Text(
              '\$${NumberFormat('#,###').format(sale.total)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProductsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProducts.length,
      itemBuilder: (context, index) {
        final product = topProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Stock: ${product.stock}'),
            trailing: Text(
              '\$${NumberFormat('#,###').format(product.price)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInventoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProducts.length,
      itemBuilder: (context, index) {
        final product = topProducts[index];
        final isLowStock = product.stock <= product.minStock;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLowStock ? Colors.red : Colors.green,
              child: Icon(
                isLowStock ? Icons.warning : Icons.check,
                color: Colors.white,
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Stock: ${product.stock} / Mín: ${product.minStock}'),
            trailing: Text(
              isLowStock ? 'BAJO' : 'OK',
              style: TextStyle(
                color: isLowStock ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
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
      final excel = Excel.createExcel();
      final sheet = excel['Reporte'];
      
      // Agregar datos según el tipo de reporte
      switch (selectedReport) {
        case 'sales':
          _exportSalesData(sheet);
          break;
        case 'products':
          _exportProductsData(sheet);
          break;
        case 'inventory':
          _exportInventoryData(sheet);
          break;
      }
      
      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_${selectedReport}_${DateFormat('yyyyMMdd').format(selectedDate)}.xlsx';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(excel.encode()!);
      
      Get.snackbar(
        'Éxito',
        'Reporte exportado: $fileName',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('Error', 'Error exportando reporte: $e');
    }
  }
  
  void _exportSalesData(Sheet sheet) {
    // Encabezados
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Hora';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Total';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = 'Productos';
    
    // Datos
    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = DateFormat('HH:mm').format(sale.date);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = sale.total;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = sale.items.length;
    }
  }
  
  void _exportProductsData(Sheet sheet) {
    // Encabezados
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Producto';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Precio';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = 'Stock';
    
    // Datos
    for (int i = 0; i < topProducts.length; i++) {
      final product = topProducts[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = product.name;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = product.price;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = product.stock;
    }
  }
  
  void _exportInventoryData(Sheet sheet) {
    // Encabezados
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Producto';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Stock Actual';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = 'Stock Mínimo';
    
    // Datos
    for (int i = 0; i < topProducts.length; i++) {
      final product = topProducts[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = product.name;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = product.stock;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = product.minStock;
    }
  }
} 