import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/report_models.dart';

class PDFReportsService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  // Generar reporte de ventas en PDF
  static Future<Uint8List> generateSalesReportPDF({
    required SalesReport report,
    required String companyName,
    required String reportPeriod,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            _buildHeader(companyName, 'Reporte de Ventas', reportPeriod),
            pw.SizedBox(height: 20),
            
            // Resumen ejecutivo
            _buildExecutiveSummary(report),
            pw.SizedBox(height: 20),
            
            // Métricas principales
            _buildKeyMetrics(report),
            pw.SizedBox(height: 20),
            
            // Ventas por hora
            _buildSalesByHour(report.salesByHour),
            pw.SizedBox(height: 20),
            
            // Métodos de pago
            _buildPaymentMethods(report.salesByPaymentMethod),
            pw.SizedBox(height: 20),
            
            // Top productos
            _buildTopProducts(report.topProducts),
            pw.SizedBox(height: 20),
            
            // Ventas por grupo
            _buildSalesByGroup(report.salesByGroup),
            pw.SizedBox(height: 20),
            
            // Transacciones detalladas
            _buildDetailedTransactions(report.transactions),
            
            // Pie de página
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generar reporte de inventario en PDF
  static Future<Uint8List> generateInventoryReportPDF({
    required InventoryReport report,
    required String companyName,
    required String reportPeriod,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            _buildHeader(companyName, 'Reporte de Inventario', reportPeriod),
            pw.SizedBox(height: 20),
            
            // Resumen del inventario
            _buildInventorySummary(report),
            pw.SizedBox(height: 20),
            
            // Productos con stock bajo
            if (report.lowStockProducts > 0) ...[
              _buildLowStockAlert(report.items.where((item) => item.status == 'LOW' || item.status == 'OUT').toList()),
              pw.SizedBox(height: 20),
            ],
            
            // Detalle completo del inventario
            _buildInventoryDetails(report.items),
            
            // Pie de página
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generar reporte de rentabilidad en PDF
  static Future<Uint8List> generateProfitabilityReportPDF({
    required ProfitabilityReport report,
    required String companyName,
    required String reportPeriod,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Encabezado
            _buildHeader(companyName, 'Reporte de Rentabilidad', reportPeriod),
            pw.SizedBox(height: 20),
            
            // Resumen financiero
            _buildFinancialSummary(report),
            pw.SizedBox(height: 20),
            
            // Análisis de rentabilidad por producto
            _buildProfitabilityAnalysis(report.products),
            pw.SizedBox(height: 20),
            
            // Productos más rentables
            _buildMostProfitableProducts(report.products),
            pw.SizedBox(height: 20),
            
            // Productos menos rentables
            _buildLeastProfitableProducts(report.products),
            
            // Pie de página
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Encabezado del reporte
  static pw.Widget _buildHeader(String companyName, String reportTitle, String period) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Sistema POS Smart Seller',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.blue700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Período: $period',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Text(
                    'Generado: ${_dateFormat.format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Resumen ejecutivo de ventas
  static pw.Widget _buildExecutiveSummary(SalesReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📊 Resumen Ejecutivo',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard(
                'Total Ventas',
                _currencyFormat.format(report.totalSales),
                PdfColors.green700,
              ),
              _buildSummaryCard(
                'Transacciones',
                report.totalTransactions.toString(),
                PdfColors.blue700,
              ),
              _buildSummaryCard(
                'Ticket Promedio',
                _currencyFormat.format(report.averageTicket),
                PdfColors.purple700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Métricas clave
  static pw.Widget _buildKeyMetrics(SalesReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📈 Métricas Clave',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Hora pico de ventas:', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                _getPeakHour(report.salesByHour),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Método de pago principal:', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                _getMainPaymentMethod(report.salesByPaymentMethod),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Producto más vendido:', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                report.topProducts.isNotEmpty ? report.topProducts.first.productName : 'N/A',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Ventas por hora
  static pw.Widget _buildSalesByHour(List<SalesByHour> salesByHour) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🕐 Ventas por Hora',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blue300),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),
              1: const pw.FixedColumnWidth(100),
              2: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _buildTableHeader('Hora'),
                  _buildTableHeader('Monto'),
                  _buildTableHeader('Transacciones'),
                ],
              ),
              ...salesByHour.map((hour) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${hour.hour}:00', style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(hour.amount), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(hour.transactions.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Métodos de pago
  static pw.Widget _buildPaymentMethods(List<SalesByPaymentMethod> paymentMethods) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        border: pw.Border.all(color: PdfColors.purple200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '💳 Métodos de Pago',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.purple300),
            columnWidths: {
              0: const pw.FixedColumnWidth(120),
              1: const pw.FixedColumnWidth(100),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                children: [
                  _buildTableHeader('Método'),
                  _buildTableHeader('Monto'),
                  _buildTableHeader('Transacciones'),
                  _buildTableHeader('%'),
                ],
              ),
              ...paymentMethods.map((method) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(method.method, style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(method.amount), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(method.transactions.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${method.percentage.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Top productos
  static pw.Widget _buildTopProducts(List<TopProduct> topProducts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🏆 Top Productos',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.orange300),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FixedColumnWidth(150),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(100),
              4: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                children: [
                  _buildTableHeader('#'),
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Cantidad'),
                  _buildTableHeader('Total'),
                  _buildTableHeader('Grupo'),
                ],
              ),
              ...topProducts.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final product = entry.value;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(index.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.productName, style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.quantitySold.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(product.totalAmount), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.groupName, style: pw.TextStyle(fontSize: 10)),
                  ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Ventas por grupo
  static pw.Widget _buildSalesByGroup(List<SalesByGroup> salesByGroup) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📂 Ventas por Grupo',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.teal300),
            columnWidths: {
              0: const pw.FixedColumnWidth(150),
              1: const pw.FixedColumnWidth(100),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal100),
                children: [
                  _buildTableHeader('Grupo'),
                  _buildTableHeader('Monto'),
                  _buildTableHeader('Transacciones'),
                  _buildTableHeader('%'),
                ],
              ),
              ...salesByGroup.map((group) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(group.groupName, style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(group.amount), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(group.transactions.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${group.percentage.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Transacciones detalladas
  static pw.Widget _buildDetailedTransactions(List<SalesTransaction> transactions) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📋 Transacciones Detalladas',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('ID'),
                  _buildTableHeader('Hora'),
                  _buildTableHeader('Total'),
                  _buildTableHeader('Pago'),
                  _buildTableHeader('Usuario'),
                ],
              ),
              ...transactions.take(20).map((transaction) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(transaction.id.toString(), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(transaction.time, style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_currencyFormat.format(transaction.total), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(transaction.paymentMethod, style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(transaction.user, style: pw.TextStyle(fontSize: 9)),
                  ),
                ],
              )),
            ],
          ),
          if (transactions.length > 20)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '... y ${transactions.length - 20} transacciones más',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // Resumen del inventario
  static pw.Widget _buildInventorySummary(InventoryReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📦 Resumen del Inventario',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard(
                'Total Productos',
                report.items.length.toString(),
                PdfColors.blue700,
              ),
              _buildSummaryCard(
                'Valor Total',
                _currencyFormat.format(report.totalInventoryValue),
                PdfColors.green700,
              ),
              _buildSummaryCard(
                'Stock Bajo',
                report.lowStockProducts.toString(),
                PdfColors.red700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Alerta de stock bajo
  static pw.Widget _buildLowStockAlert(List<InventoryItem> lowStockItems) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '⚠️ Productos con Stock Bajo',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.red300),
            columnWidths: {
              0: const pw.FixedColumnWidth(150),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red100),
                children: [
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Stock'),
                  _buildTableHeader('Mínimo'),
                  _buildTableHeader('Estado'),
                ],
              ),
              ...lowStockItems.map((item) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.productName, style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.currentStock.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.minStock.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      item.status == 'OUT' ? 'AGOTADO' : 'BAJO',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: item.status == 'OUT' ? PdfColors.red : PdfColors.orange,
                      ),
                    ),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Detalles del inventario
  static pw.Widget _buildInventoryDetails(List<InventoryItem> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📋 Detalle Completo del Inventario',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(120),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(100),
              4: const pw.FixedColumnWidth(100),
              5: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Stock'),
                  _buildTableHeader('Mínimo'),
                  _buildTableHeader('Precio'),
                  _buildTableHeader('Costo'),
                  _buildTableHeader('Valor Total'),
                ],
              ),
              ...items.map((item) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(item.productName, style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(item.currentStock.toString(), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(item.minStock.toString(), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_currencyFormat.format(item.unitPrice), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_currencyFormat.format(item.unitCost), style: pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_currencyFormat.format(item.totalValue), style: pw.TextStyle(fontSize: 9)),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Resumen financiero
  static pw.Widget _buildFinancialSummary(ProfitabilityReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '💰 Resumen Financiero',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard(
                'Ingresos Totales',
                _currencyFormat.format(report.totalRevenue),
                PdfColors.green700,
              ),
              _buildSummaryCard(
                'Costos Totales',
                _currencyFormat.format(report.totalCost),
                PdfColors.red700,
              ),
              _buildSummaryCard(
                'Utilidad Neta',
                _currencyFormat.format(report.totalProfit),
                PdfColors.blue700,
              ),
              _buildSummaryCard(
                'Margen %',
                '${report.profitMargin.toStringAsFixed(1)}%',
                PdfColors.purple700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Análisis de rentabilidad por producto
  static pw.Widget _buildProfitabilityAnalysis(List<ProductProfitability> products) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        border: pw.Border.all(color: PdfColors.purple200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📊 Análisis de Rentabilidad por Producto',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.purple300),
            columnWidths: {
              0: const pw.FixedColumnWidth(120),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(100),
              4: const pw.FixedColumnWidth(100),
              5: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                children: [
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Vendidos'),
                  _buildTableHeader('Ingresos'),
                  _buildTableHeader('Costos'),
                  _buildTableHeader('Utilidad'),
                  _buildTableHeader('Margen %'),
                ],
              ),
              ...products.map((product) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.productName, style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.quantitySold.toString(), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(product.revenue), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(product.cost), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(product.profit), style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${product.profitMargin.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Productos más rentables
  static pw.Widget _buildMostProfitableProducts(List<ProductProfitability> products) {
    final sortedProducts = List<ProductProfitability>.from(products)
      ..sort((a, b) => b.profitMargin.compareTo(a.profitMargin));
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🏆 Productos Más Rentables',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.green300),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  _buildTableHeader('#'),
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Utilidad'),
                  _buildTableHeader('Margen %'),
                ],
              ),
              ...sortedProducts.take(10).toList().asMap().entries.map((entry) {
                final index = entry.key + 1;
                final product = entry.value;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(index.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(product.productName, style: pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(product.profit), style: pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${product.profitMargin.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Productos menos rentables
  static pw.Widget _buildLeastProfitableProducts(List<ProductProfitability> products) {
    final sortedProducts = List<ProductProfitability>.from(products)
      ..sort((a, b) => a.profitMargin.compareTo(b.profitMargin));
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '⚠️ Productos Menos Rentables',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.red300),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(100),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red100),
                children: [
                  _buildTableHeader('#'),
                  _buildTableHeader('Producto'),
                  _buildTableHeader('Utilidad'),
                  _buildTableHeader('Margen %'),
                ],
              ),
              ...sortedProducts.take(10).toList().asMap().entries.map((entry) {
                final index = entry.key + 1;
                final product = entry.value;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(index.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(product.productName, style: pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(product.profit), style: pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${product.profitMargin.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Widgets auxiliares
  static pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, color: color),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Smart Seller POS - Sistema Profesional',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Smart Seller POS - Sistema Profesional',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares
  static String _getPeakHour(List<SalesByHour> salesByHour) {
    if (salesByHour.isEmpty) return 'N/A';
    final peakHour = salesByHour.reduce((a, b) => a.amount > b.amount ? a : b);
    return '${peakHour.hour}:00';
  }

  static String _getMainPaymentMethod(List<SalesByPaymentMethod> paymentMethods) {
    if (paymentMethods.isEmpty) return 'N/A';
    final mainMethod = paymentMethods.reduce((a, b) => a.amount > b.amount ? a : b);
    return mainMethod.method;
  }
}
