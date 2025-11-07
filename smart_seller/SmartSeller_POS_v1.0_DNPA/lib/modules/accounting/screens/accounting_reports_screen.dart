// Pantalla para reportes contables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/sqlite_database_service.dart';
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
  
  static final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // ✅ Corregido: 5 tabs (Resumen, Estado, Flujo, Sesiones, Auditoría)
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

  // ✅ NUEVA FUNCIÓN: Exportar TODO en un solo PDF
  Future<void> _exportAllReports() async {
    final shouldExport = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Exportar Todos los Reportes'),
        content: const Text('¿Descargar TODOS los reportes (Resumen, Estado de Resultados, Flujo de Caja, Sesiones, Auditoría) en un solo PDF?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Descargar TODO'),
          ),
        ],
      ),
    );

    if (shouldExport != true) return;

    try {
      setState(() => _isLoading = true);
      Get.snackbar('Info', 'Generando reporte completo PDF...', backgroundColor: Colors.blue, colorText: Colors.white);
      
      // Cargar TODOS los reportes
      await _loadQuickSummary();
      await _loadIncomeStatement();
      await _loadCashFlowReport();
      await _loadCashSessionReport();
      await _loadAuditReport();
      
      if (_quickSummary.isEmpty || _incomeStatement == null || _cashFlowReport == null || 
          _cashSessionReport == null || _auditReport == null) {
        throw Exception('No se pudieron cargar todos los reportes');
      }
      
      // Crear nombre del archivo con fecha
      final fileName = 'reporte_completo_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      
      // Seleccionar ubicación para guardar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte completo como PDF',
        fileName: '$fileName.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        Get.snackbar('Información', 'Operación cancelada', backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      String finalPath = outputFile;
      if (!finalPath.toLowerCase().endsWith('.pdf')) {
        finalPath = '$finalPath.pdf';
      }

      // Generar PDF completo con TODAS las secciones
      Uint8List pdfBytes = await _generateCompleteReportPDF();
      
      // Guardar archivo
      final file = File(finalPath);
      await file.writeAsBytes(pdfBytes);
      
      Get.snackbar(
        '✅ Reporte Completo PDF Exportado',
        'Archivo guardado: $finalPath\nIncluye: Resumen, Estado, Flujo, Sesiones y Auditoría',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Error exportando reporte completo: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ NUEVA FUNCIÓN: Exportar reporte a PDF
  Future<void> _exportReport() async {
    // Mostrar diálogo de confirmación
    final shouldExport = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Exportar Reporte'),
        content: const Text('¿Descargar el reporte actual como PDF?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Descargar'),
          ),
        ],
      ),
    );

    if (shouldExport != true) return;

    try {
      setState(() => _isLoading = true);
      
      // Cargar el reporte necesario según la pestaña activa
      final tabIndex = _tabController.index;
      
      // Mostrar indicador de carga
      Get.snackbar('Info', 'Generando reporte PDF...', backgroundColor: Colors.blue, colorText: Colors.white, duration: const Duration(seconds: 1));
      
      switch (tabIndex) {
        case 0: // Resumen
          await _loadQuickSummary();
          if (_quickSummary.isEmpty) throw Exception('No hay datos de resumen para exportar');
          break;
        case 1: // Estado de Resultados
          await _loadIncomeStatement();
          if (_incomeStatement == null) throw Exception('No hay datos de estado de resultados');
          break;
        case 2: // Flujo de Caja
          await _loadCashFlowReport();
          if (_cashFlowReport == null) throw Exception('No hay datos de flujo de caja');
          break;
        case 3: // Sesiones
          await _loadCashSessionReport();
          if (_cashSessionReport == null) throw Exception('No hay datos de sesiones');
          break;
        case 4: // Auditoría
          await _loadAuditReport();
          if (_auditReport == null) throw Exception('No hay datos de auditoría');
          break;
      }
      
      // Crear nombre del archivo con fecha
      final fileName = 'reporte_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      
      // Seleccionar ubicación para guardar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte como PDF',
        fileName: '$fileName.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        Get.snackbar('Información', 'Operación cancelada', backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      // ✅ Asegurar que el archivo tenga extensión .pdf
      String finalPath = outputFile;
      if (!finalPath.toLowerCase().endsWith('.pdf')) {
        finalPath = '$finalPath.pdf';
      }

      // Generar PDF según la pestaña activa
      Uint8List pdfBytes;
      
      switch (tabIndex) {
        case 0: // Resumen
          pdfBytes = await _generateQuickSummaryPDF();
          break;
        case 1: // Estado de Resultados
          if (_incomeStatement == null) throw Exception('No hay datos de estado de resultados');
          pdfBytes = await _generateIncomeStatementPDF(_incomeStatement!);
          break;
        case 2: // Flujo de Caja
          if (_cashFlowReport == null) throw Exception('No hay datos de flujo de caja');
          pdfBytes = await _generateCashFlowPDF(_cashFlowReport!);
          break;
        case 3: // Sesiones
          if (_cashSessionReport == null) throw Exception('No hay datos de sesiones');
          pdfBytes = await _generateCashSessionPDF(_cashSessionReport!);
          break;
        case 4: // Auditoría
          if (_auditReport == null) throw Exception('No hay datos de auditoría');
          pdfBytes = await _generateAuditPDF(_auditReport!);
          break;
        default:
          throw Exception('Pestaña no reconocida');
      }
      
      // Guardar archivo
      final file = File(finalPath);
      await file.writeAsBytes(pdfBytes);
      
      Get.snackbar(
        '✅ Reporte PDF Exportado',
        'Archivo guardado correctamente: $finalPath',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Error exportando reporte: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Profesionales'),
        actions: [
          // ✅ NUEVO: Botón para descargar TODO en un PDF
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Opciones de Descarga',
            onSelected: (value) {
              if (value == 'current') {
                _exportReport();
              } else if (value == 'all') {
                _exportAllReports();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'current',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Descargar Pestaña Actual'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Descargar TODO en PDF'),
                  ],
                ),
              ),
            ],
          ),
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

  // ✅ FUNCIONES DE GENERACIÓN DE PDF
  Future<Uint8List> _generateQuickSummaryPDF() async {
    // Obtener información de la empresa
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    // Crear PDF
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Resumen de Reportes Contables',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Período: $period',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            
            // Resumen de cada reporte
            pw.Text(
              'Resumen Ejecutivo',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard(
              'Total Ingresos',
              (_quickSummary['total_income'] as num? ?? 0).toDouble(),
            ),
            pw.SizedBox(height: 8),
            _buildPDFCard(
              'Total Egresos',
              (_quickSummary['total_expenses'] as num? ?? 0).toDouble(),
            ),
            pw.SizedBox(height: 8),
            _buildPDFCard(
              'Balance Neto',
              (_quickSummary['balance'] as num? ?? 0).toDouble(),
            ),
            
            // Información adicional
            pw.SizedBox(height: 20),
            pw.Text(
              'Reporte generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );
    
    return pdf.save();
  }

  Future<Uint8List> _generateIncomeStatementPDF(IncomeStatement statement) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Estado de Resultados', period),
            pw.SizedBox(height: 20),
            
            // Ingresos
            pw.Text('INGRESOS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
              children: [
                _buildPDFTableRow('Total Ingresos', statement.totalIncome),
                for (final category in statement.incomeCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // Egresos
            pw.Text('EGRESOS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
              children: [
                _buildPDFTableRow('Total Egresos', statement.totalExpenses),
                for (final category in statement.expenseCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Text('RESULTADO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Utilidad Neta', statement.netIncome, isImportant: true),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _generateCashFlowPDF(CashFlowReport report) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Flujo de Caja', period),
            pw.SizedBox(height: 20),
            
            pw.Text('ENTRADAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Ingresos Totales', report.totalIncome),
            
            pw.SizedBox(height: 20),
            
            pw.Text('SALIDAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Egresos Totales', report.totalExpenses),
            
            pw.SizedBox(height: 20),
            
            pw.Text('SALDO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Flujo Neto', report.netCashFlow, isImportant: true),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _generateCashSessionPDF(CashSessionReport report) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Sesiones de Caja', period),
            pw.SizedBox(height: 20),
            
            pw.Text('Resumen de Sesiones', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _buildPDFTableCell('Cajero', isHeader: true),
                    _buildPDFTableCell('Fecha Apertura', isHeader: true),
                    _buildPDFTableCell('Saldo Final', isHeader: true),
                  ],
                ),
                ...report.sessions.take(10).map((session) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(session.userName, style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(DateFormat('dd/MM/yyyy').format(session.openDate), style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(session.finalAmount), style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                )),
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _generateAuditPDF(TransactionAuditReport report) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Auditoría de Transacciones', period),
            pw.SizedBox(height: 20),
            
            pw.Text('Estadísticas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Total Transacciones', report.totalTransactions.toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Monto Total', report.totalAmount),
          ];
        },
      ),
    );
    return pdf.save();
  }
  
  // ✅ NUEVO: Generar PDF completo con TODAS las secciones
  Future<Uint8List> _generateCompleteReportPDF() async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty ? companyConfigs.first.companyName : 'SmartSeller POS';
    final period = '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // ========== PORTADA ==========
            pw.Text(
              companyName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'REPORTE COMPLETO DE CONTABILIDAD',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Período: $period',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 40),
            
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 30),
            
            // ========== 1. RESUMEN EJECUTIVO ==========
            pw.Text(
              '1. RESUMEN EJECUTIVO',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard('Total Ingresos', (_quickSummary['total_income'] as num? ?? 0).toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Total Egresos', (_quickSummary['total_expenses'] as num? ?? 0).toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Utilidad Neta', (_quickSummary['net_income'] as num? ?? 0).toDouble(), isImportant: true),
            pw.SizedBox(height: 8),
            _buildPDFCard('Total Transacciones', (_quickSummary['transaction_count'] as num? ?? 0).toDouble()),
            
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),
            
            // ========== 2. ESTADO DE RESULTADOS ==========
            pw.Text(
              '2. ESTADO DE RESULTADOS',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 12),
            pw.Text('INGRESOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
              children: [
                _buildPDFTableRow('Total Ingresos', _incomeStatement!.totalIncome),
                for (final category in _incomeStatement!.incomeCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('EGRESOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
              children: [
                _buildPDFTableRow('Total Egresos', _incomeStatement!.totalExpenses),
                for (final category in _incomeStatement!.expenseCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('RESULTADO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildPDFCard('Utilidad Neta', _incomeStatement!.netIncome, isImportant: true),
            
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),
            
            // ========== 3. FLUJO DE CAJA ==========
            pw.Text(
              '3. FLUJO DE CAJA',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard('Efectivo Inicial', _cashFlowReport!.initialCash),
            pw.SizedBox(height: 8),
            _buildPDFCard('Ingresos Totales', _cashFlowReport!.totalIncome),
            pw.SizedBox(height: 8),
            _buildPDFCard('Egresos Totales', _cashFlowReport!.totalExpenses),
            pw.SizedBox(height: 8),
            _buildPDFCard('Flujo Neto', _cashFlowReport!.netCashFlow, isImportant: true),
            pw.SizedBox(height: 8),
            _buildPDFCard('Efectivo Final', _cashFlowReport!.finalCash),
            
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),
            
            // ========== 4. SESIONES DE CAJA ==========
            pw.Text(
              '4. SESIONES DE CAJA',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Total de Sesiones: ${_cashSessionReport!.totalSessions}',
                style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPDFTableCell('Cajero', isHeader: true),
                    _buildPDFTableCell('Fecha Apertura', isHeader: true),
                    _buildPDFTableCell('Ingresos', isHeader: true),
                    _buildPDFTableCell('Egresos', isHeader: true),
                    _buildPDFTableCell('Saldo Final', isHeader: true),
                  ],
                ),
                ..._cashSessionReport!.sessions.take(10).map((session) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(session.userName, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(DateFormat('dd/MM/yyyy').format(session.openDate), style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_currencyFormat.format(session.totalIncome), style: const pw.TextStyle(fontSize: 9, color: PdfColors.green700)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_currencyFormat.format(session.totalExpenses), style: const pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_currencyFormat.format(session.finalAmount), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                )),
              ],
            ),
            
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),
            
            // ========== 5. AUDITORÍA ==========
            pw.Text(
              '5. AUDITORÍA DE TRANSACCIONES',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard('Total Transacciones', _auditReport!.totalTransactions.toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Monto Total', _auditReport!.totalAmount),
            pw.SizedBox(height: 20),
            
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 20),
            
            // ========== FIRMAS Y REFERENCIAS ==========
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte generado por Smart Seller POS',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Text('Firma Administrador', style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Smart Seller POS v2.0',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Text('Fecha', style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    return pdf.save();
  }
  
  // ✅ HELPER METHODS PARA PDF
  pw.Widget _buildPDFTitle(String company, String title, String period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(company, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Período: $period', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
      ],
    );
  }
  
  pw.Widget _buildPDFCard(String label, double value, {bool isImportant = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            _currencyFormat.format(value),
            style: pw.TextStyle(
              fontSize: isImportant ? 18 : 12,
              fontWeight: isImportant ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isImportant ? PdfColors.green700 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.TableRow _buildPDFTableRow(String label, double value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_currencyFormat.format(value))),
      ],
    );
  }
  
  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
