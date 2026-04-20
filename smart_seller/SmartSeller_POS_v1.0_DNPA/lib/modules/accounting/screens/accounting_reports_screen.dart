// Pantalla para reportes contables

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../services/print_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import '../../../models/sale.dart';
import '../../../services/sqlite_database_service.dart';
import '../models/accounting_reports.dart';
import '../services/accounting_reports_service.dart';

class AccountingReportsScreen extends StatefulWidget {
  const AccountingReportsScreen({super.key});

  @override
  State<AccountingReportsScreen> createState() =>
      _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  /// Reporte seleccionado: solo 1 = Cierre de Caja (por ahora).
  int? _selectedDailyReport;

  CashSessionReport? _cashSessionReport;
  Map<String, dynamic>? _cierreDeCajaData;

  // Sin uso en menú actual (solo Cierre de Caja); mantienen compilables los builders legacy.
  Map<String, dynamic>? _ventasDiaData;
  Map<String, dynamic>? _movimientosDiaData;
  Map<String, dynamic>? _devolucionesData;
  Map<String, dynamic>? _resumenSemanalData;
  Map<String, dynamic>? _gastosData;
  Map<String, dynamic>? _ventasPorProductoData;
  Map<String, dynamic>? _ventasPorCategoriaData;
  Map<String, dynamic>? _transaccionesDiaData;
  Map<String, dynamic>? _ventasPorHoraData;
  Map<String, dynamic>? _topProductosData;
  Map<String, dynamic>? _productosSinMovimientoData;
  Map<String, dynamic>? _ventasPorFormaDePagoData;
  Map<String, dynamic>? _movimientosDeEfectivoData;
  Map<String, dynamic>? _arqueoDeCajaData;

  bool _isLoading = false;

  // Legacy (sin uso en menú actual)
  Map<String, dynamic> _quickSummary = {};
  IncomeStatement? _incomeStatement;
  CashFlowReport? _cashFlowReport;
  TransactionAuditReport? _auditReport;

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadCashSessionReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await AccountingReportsService.generateCashSessionReport(
          _fromDate, _toDate);
      setState(() {
        _cashSessionReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudo generar el reporte de sesiones: $e');
    }
  }

  /// Sesión a usar para Cierre de Caja: la que cubre hoy (para ver anulaciones del día) o la primera.
  int? _getCierreDeCajaSessionId() {
    final sessions = _cashSessionReport?.sessions ?? [];
    if (sessions.isEmpty) return null;
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Preferir la sesión que incluye hoy (apertura <= hoy y (sin cierre o cierre >= hoy))
    for (final s in sessions) {
      final openDay =
          DateTime(s.openDate.year, s.openDate.month, s.openDate.day);
      final closeDay = s.closeDate != null
          ? DateTime(s.closeDate!.year, s.closeDate!.month, s.closeDate!.day)
          : today;
      if (!openDay.isAfter(today) && !closeDay.isBefore(today)) {
        return s.sessionId;
      }
    }
    return sessions.first.sessionId;
  }

  /// Selecciona un reporte y carga sus datos. 1-5 + 6 = Devoluciones.
  Future<void> _selectDailyReport(int index) async {
    setState(() => _selectedDailyReport = index);
    if (index == 1) {
      await _loadCashSessionReport();
      final sessionId = _getCierreDeCajaSessionId();
      if (sessionId != null) {
        final data =
            await AccountingReportsService.getCierreDeCajaData(sessionId);
        if (mounted) setState(() => _cierreDeCajaData = data);
      } else if (mounted) setState(() => _cierreDeCajaData = null);
    } else if (index == 2) {
      setState(() => _ventasPorProductoData = null);
      final data = await AccountingReportsService.getVentasPorProductoData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorProductoData = data);
    } else if (index == 3) {
      setState(() => _ventasPorCategoriaData = null);
      final data = await AccountingReportsService.getVentasPorCategoriaData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorCategoriaData = data);
    } else if (index == 4) {
      setState(() => _transaccionesDiaData = null);
      final data = await AccountingReportsService.getTransaccionesDiaData(
          _fromDate, _toDate);
      if (mounted) setState(() => _transaccionesDiaData = data);
    } else if (index == 5) {
      setState(() => _ventasPorHoraData = null);
      final data = await AccountingReportsService.getVentasPorHoraData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorHoraData = data);
    } else if (index == 6) {
      setState(() => _devolucionesData = null);
      final data = await AccountingReportsService.getDevolucionesData(
          _fromDate, _toDate);
      if (mounted) setState(() => _devolucionesData = data);
    } else if (index == 7) {
      setState(() => _resumenSemanalData = null);
      final data = await AccountingReportsService.getResumenSemanalMensualData(
          _fromDate, _toDate);
      if (mounted) setState(() => _resumenSemanalData = data);
    }
  }

  Future<void> _loadQuickSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary =
          await AccountingReportsService.getQuickSummary(_fromDate, _toDate);
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
      final statement = await AccountingReportsService.generateIncomeStatement(
          _fromDate, _toDate);
      setState(() {
        _incomeStatement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCashFlowReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await AccountingReportsService.generateCashFlowReport(
          _fromDate, _toDate);
      setState(() {
        _cashFlowReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAuditReport() async {
    setState(() => _isLoading = true);
    try {
      final report =
          await AccountingReportsService.generateTransactionAuditReport(
              _fromDate, _toDate);
      setState(() {
        _auditReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
        _cierreDeCajaData = null;
        _ventasPorProductoData = null;
        _ventasPorCategoriaData = null;
        _transaccionesDiaData = null;
        _ventasPorHoraData = null;
        _devolucionesData = null;
        _resumenSemanalData = null;
      });
      if (_selectedDailyReport != null) {
        _selectDailyReport(_selectedDailyReport!);
      }
    }
  }

  /// Imprimir: Cierre de Caja o Ventas por Producto. 1) Elegir reporte 2) Elegir impresora 3) Imprimir.
  Future<void> _showPrintReportDialog() async {
    if (_cierreDeCajaData == null &&
        (_cashSessionReport == null || _cashSessionReport!.sessions.isEmpty)) {
      await _loadCashSessionReport();
    }
    final sessionId = _getCierreDeCajaSessionId();
    if (_cierreDeCajaData == null && sessionId != null) {
      final data =
          await AccountingReportsService.getCierreDeCajaData(sessionId);
      if (mounted) setState(() => _cierreDeCajaData = data);
    }
    Map<String, dynamic>? cierreData = _cierreDeCajaData;
    if (cierreData == null && sessionId != null) {
      cierreData =
          await AccountingReportsService.getCierreDeCajaData(sessionId);
    }
    if (_ventasPorProductoData == null) {
      final data = await AccountingReportsService.getVentasPorProductoData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorProductoData = data);
    }
    if (_ventasPorCategoriaData == null) {
      final data = await AccountingReportsService.getVentasPorCategoriaData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorCategoriaData = data);
    }
    if (_transaccionesDiaData == null) {
      final data = await AccountingReportsService.getTransaccionesDiaData(
          _fromDate, _toDate);
      if (mounted) setState(() => _transaccionesDiaData = data);
    }
    if (_ventasPorHoraData == null) {
      final data = await AccountingReportsService.getVentasPorHoraData(
          _fromDate, _toDate);
      if (mounted) setState(() => _ventasPorHoraData = data);
    }
    if (_devolucionesData == null) {
      final data = await AccountingReportsService.getDevolucionesData(
          _fromDate, _toDate);
      if (mounted) setState(() => _devolucionesData = data);
    }
    if (_resumenSemanalData == null) {
      final data = await AccountingReportsService.getResumenSemanalMensualData(
          _fromDate, _toDate);
      if (mounted) setState(() => _resumenSemanalData = data);
    }
    if (!mounted) return;

    List<Map<String, dynamic>> printers = [];
    try {
      printers = await PrintService.instance.listPrinters();
    } catch (_) {}
    if (!mounted) return;

    final reportValue = <String>['cierre_caja'];
    final usePosValue = <bool>[true];
    String? selectedPrinterName =
        printers.isNotEmpty ? printers.first['name'] as String? : null;

    final printerChoice = await Get.dialog<Map<String, dynamic>>(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Imprimir reporte'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de reporte',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile<String>(
                    title: const Text('Cierre de Caja'),
                    value: 'cierre_caja',
                    groupValue: reportValue[0],
                    onChanged: (v) =>
                        setStateDialog(() => reportValue[0] = 'cierre_caja'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Ventas por Producto'),
                    value: 'ventas_producto',
                    groupValue: reportValue[0],
                    onChanged: (v) => setStateDialog(
                        () => reportValue[0] = 'ventas_producto'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Ventas por Categoría'),
                    value: 'ventas_categoria',
                    groupValue: reportValue[0],
                    onChanged: (v) => setStateDialog(
                        () => reportValue[0] = 'ventas_categoria'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Movimientos del Día'),
                    value: 'movimientos_dia',
                    groupValue: reportValue[0],
                    onChanged: (v) => setStateDialog(
                        () => reportValue[0] = 'movimientos_dia'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Ventas por Hora'),
                    value: 'ventas_hora',
                    groupValue: reportValue[0],
                    onChanged: (v) =>
                        setStateDialog(() => reportValue[0] = 'ventas_hora'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Devoluciones'),
                    value: 'devoluciones',
                    groupValue: reportValue[0],
                    onChanged: (v) =>
                        setStateDialog(() => reportValue[0] = 'devoluciones'),
                  ),
                  RadioListTile<String>(
                    title: const Text('Resumen Semanal/Mensual'),
                    value: 'resumen_semanal',
                    groupValue: reportValue[0],
                    onChanged: (v) => setStateDialog(
                        () => reportValue[0] = 'resumen_semanal'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Impresora',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioListTile<bool>(
                    title: const Text('Impresora POS (tickets)'),
                    value: true,
                    groupValue: usePosValue[0],
                    onChanged: (v) =>
                        setStateDialog(() => usePosValue[0] = true),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Otra impresora'),
                    value: false,
                    groupValue: usePosValue[0],
                    onChanged: (v) =>
                        setStateDialog(() => usePosValue[0] = false),
                  ),
                  if (!usePosValue[0]) ...[
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
                  'report': reportValue[0],
                  'usePos': usePosValue[0],
                  'printerName': usePosValue[0] ? null : selectedPrinterName
                }),
                child: const Text('Imprimir'),
              ),
            ],
          );
        },
      ),
    );
    if (printerChoice == null || !mounted) return;

    final report = printerChoice['report'] as String? ?? 'cierre_caja';
    final usePos = printerChoice['usePos'] as bool? ?? true;
    final printerName = printerChoice['printerName'] as String?;

    setState(() => _isLoading = true);
    try {
      String text;
      String successMsg;
      if (report == 'ventas_producto') {
        final data = _ventasPorProductoData ??
            await AccountingReportsService.getVentasPorProductoData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildVentasPorProductoText(data);
        successMsg = 'Ventas por producto enviado a la impresora';
      } else if (report == 'ventas_categoria') {
        final data = _ventasPorCategoriaData ??
            await AccountingReportsService.getVentasPorCategoriaData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildVentasPorCategoriaText(data);
        successMsg = 'Ventas por categoría enviado a la impresora';
      } else if (report == 'movimientos_dia') {
        final data = _transaccionesDiaData ??
            await AccountingReportsService.getTransaccionesDiaData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildMovimientosDelDiaText(data);
        successMsg = 'Movimientos del día enviado a la impresora';
      } else if (report == 'ventas_hora') {
        final data = _ventasPorHoraData ??
            await AccountingReportsService.getVentasPorHoraData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildVentasPorHoraText(data);
        successMsg = 'Ventas por hora enviado a la impresora';
      } else if (report == 'devoluciones') {
        final data = _devolucionesData ??
            await AccountingReportsService.getDevolucionesData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildDevolucionesText(data);
        successMsg = 'Devoluciones enviado a la impresora';
      } else if (report == 'resumen_semanal') {
        final data = _resumenSemanalData ??
            await AccountingReportsService.getResumenSemanalMensualData(
                _fromDate, _toDate);
        if (!mounted) return;
        text = _buildResumenSemanalText(data);
        successMsg = 'Resumen semanal/mensual enviado a la impresora';
      } else {
        if (cierreData == null) {
          Get.snackbar(
              'Aviso', 'No hay sesión de caja en el período seleccionado.',
              backgroundColor: Colors.orange, colorText: Colors.white);
          return;
        }
        text = _buildCierreDeCajaText(cierreData);
        successMsg = 'Cierre de caja enviado a la impresora';
      }
      final printService = PrintService.instance;
      await printService.initialize();
      final bool ok;
      if (usePos) {
        ok = await printService.printTextTicket(text);
      } else {
        final bytes = utf8.encode(text);
        ok = await printService.printRawToPrinter(bytes,
            printerName: printerName);
      }
      if (ok) {
        Get.snackbar('Éxito', successMsg,
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'No se pudo imprimir. Compruebe la impresora.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al imprimir: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Genera el texto del Cierre de Caja (modelo 80 columnas) para vista previa e impresión.
  String _buildCierreDeCajaText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final openDate = data['openDate'] as DateTime;
    final closeDate = data['closeDate'] as DateTime;
    final userName = data['userName'] as String? ?? 'Cajero';
    final initialAmount = (data['initialAmount'] as num?)?.toDouble() ?? 0.0;
    final numVentas = data['numVentas'] as int? ?? 0;
    final ticketPromedio = (data['ticketPromedio'] as num?)?.toDouble() ?? 0.0;
    final ventaBruta = (data['ventaBruta'] as num?)?.toDouble() ?? 0.0;
    final descuentos = (data['descuentos'] as num?)?.toDouble() ?? 0.0;
    final devoluciones = (data['devoluciones'] as num?)?.toDouble() ?? 0.0;
    final ventaNeta = (data['ventaNeta'] as num?)?.toDouble() ?? 0.0;
    final ivaIncluido = (data['ivaIncluido'] as num?)?.toDouble() ?? 0.0;
    final ventasPorTarifaIva =
        (data['ventasPorTarifaIva'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
    final ivaPorTarifa = (data['ivaPorTarifa'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
    final byMethod = data['byMethod'] as Map<String, dynamic>? ?? {};
    final ventasEfectivo = (data['ventasEfectivo'] as num?)?.toDouble() ?? 0.0;
    final otrosIngresos = (data['otrosIngresos'] as num?)?.toDouble() ?? 0.0;
    final retiros = (data['retiros'] as num?)?.toDouble() ?? 0.0;
    final gastos = (data['gastos'] as num?)?.toDouble() ?? 0.0;
    final devolucionesEfectivo =
        (data['devolucionesEfectivo'] as num?)?.toDouble() ?? 0.0;
    final saldoEsperado = (data['saldoEsperado'] as num?)?.toDouble() ?? 0.0;
    final saldoReal = (data['saldoReal'] as num?)?.toDouble() ?? 0.0;
    final diferencia = (data['diferencia'] as num?)?.toDouble() ?? 0.0;
    final retirosList = data['retirosList'] as List<dynamic>? ?? [];
    final sessionId = data['sessionId'] as int? ?? 0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padL(String s, int len) =>
        s.length >= len ? s : ' ' * (len - s.length) + s;
    void lineLR(String left, String right) {
      final pad = w - left.length - right.length;
      sb.writeln(pad > 0
          ? left + (' ' * pad) + right
          : (left + right).substring(0, w));
    }

    void lineVal(String label, String value) =>
        sb.writeln(label + padL(value, w - label.length));
    void center(String s) {
      final len = s.length > w ? w : s.length;
      final pad = (w - len) ~/ 2;
      sb.writeln((' ' * pad) +
          (len == s.length ? s : s.substring(0, w)) +
          (' ' * (w - pad - len)));
    }

    sb.writeln(sepW);
    center('CIERRE DE CAJA');
    sb.writeln(sepW);
    lineLR('Fecha: ${DateFormat('dd/MM/yyyy').format(closeDate)}',
        'Hora cierre: ${DateFormat('HH:mm:ss').format(closeDate)}');
    lineLR(
        'Caja: ${sessionId.toString().padLeft(2, '0')}', 'Cajero: $userName');
    lineLR('Turno: Mañana-Noche',
        'Apertura: ${DateFormat('HH:mm:ss').format(openDate)}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln('RESUMEN DE VENTAS');
    sb.writeln(dashW);
    lineVal('Número de ventas:', '$numVentas');
    lineVal('Ticket promedio:', '\$${fmtNum(ticketPromedio)}');
    lineVal('Venta bruta:', '\$${fmtNum(ventaBruta)}');
    lineVal('Descuentos:', '-\$${fmtNum(descuentos)}');
    lineVal('Devoluciones:', '-\$${fmtNum(devoluciones)}');
    final numAnuladas = data['numAnuladas'] as int? ?? 0;
    final montoAnuladas = (data['montoAnuladas'] as num?)?.toDouble() ?? 0.0;
    lineVal('Facturas canceladas / anuladas:',
        '$numAnuladas factura(s) · -\$${fmtNum(montoAnuladas)}');
    sb.writeln(dashW);
    lineVal('VENTA NETA:', '\$${fmtNum(ventaNeta)}');
    lineVal('IVA incluido:', '\$${fmtNum(ivaIncluido)}');
    final orderedRates = ventasPorTarifaIva.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    for (final rate in orderedRates) {
      final ventaTarifa = ventasPorTarifaIva[rate] ?? 0.0;
      final ivaTarifa = ivaPorTarifa[rate] ?? 0.0;
      lineVal(
        '  IVA $rate%:',
        'Ventas \$${fmtNum(ventaTarifa)} | Imp \$${fmtNum(ivaTarifa)}',
      );
    }
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln('FORMAS DE PAGO');
    sb.writeln(dashW);
    double totalCobrado = 0;
    for (final e in byMethod.entries) {
      final amount = (e.value['amount'] is num)
          ? (e.value['amount'] as num).toDouble()
          : 0.0;
      final count = (e.value['count'] is int) ? e.value['count'] as int : 0;
      totalCobrado += amount;
      final ventaStr = count == 1 ? '1 venta' : '$count ventas';
      final metodo = '${e.key}:';
      sb.writeln((metodo.padRight(25) +
              padL('\$${fmtNum(amount)}', 20) +
              padL(ventaStr, 15))
          .padRight(w));
    }
    sb.writeln(dashW);
    sb.writeln(('TOTAL COBRADO:'.padRight(25) +
            padL('\$${fmtNum(totalCobrado)}', 20) +
            padL('$numVentas ventas', 15))
        .padRight(w));
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln('ARQUEO DE CAJA (EFECTIVO)');
    sb.writeln(dashW);
    lineVal('Fondo inicial:', '\$${fmtNum(initialAmount)}');
    lineVal('(+) Ventas efectivo:', '\$${fmtNum(ventasEfectivo)}');
    lineVal('(+) Otros ingresos:', '\$${fmtNum(otrosIngresos)}');
    lineVal('(-) Retiros:', '-\$${fmtNum(retiros)}');
    lineVal('(-) Gastos:', '-\$${fmtNum(gastos)}');
    lineVal('(-) Devoluciones efectivo:', '-\$${fmtNum(devolucionesEfectivo)}');
    sb.writeln(dashW);
    lineVal('SALDO ESPERADO:', '\$${fmtNum(saldoEsperado)}');
    lineVal('SALDO REAL:', '\$${fmtNum(saldoReal)}');
    final diffStr = diferencia < 0
        ? '-\$${fmtNum(-diferencia)}  ⚠️'
        : (diferencia > 0 ? '\$${fmtNum(diferencia)}' : '\$0');
    lineVal('DIFERENCIA:', diffStr);
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln('RETIROS DE EFECTIVO');
    sb.writeln(dashW);
    if (retirosList.isEmpty) {
      sb.writeln('(Ninguno)');
    } else {
      for (final r in retirosList) {
        final t = r is Map ? (r['time'] as String? ?? '') : '';
        final d = r is Map ? (r['description'] as String? ?? '') : '';
        final a = r is Map ? ((r['amount'] as num?)?.toDouble() ?? 0) : 0.0;
        lineLR('$t    $d', '\$${fmtNum(a)}');
      }
      sb.writeln(dashW);
      lineVal('Total retirado:', '\$${fmtNum(retiros)}');
    }
    sb.writeln(sepW);
    sb.writeln('');
    center('_________________________');
    center('Firma del Cajero');
    sb.writeln('');
    center('_________________________');
    center('Firma del Supervisor');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Ventas por Producto (80 columnas) para impresión.
  String _buildVentasPorProductoText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final fromDate = data['fromDate'] as DateTime? ?? _fromDate;
    final toDate = data['toDate'] as DateTime? ?? _toDate;
    final list = data['porProducto'] as List<dynamic>? ?? [];
    final totalRevenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalQuantity = data['totalQuantity'] as int? ?? 0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);
    void center(String s) {
      final len = s.length > w ? w : s.length;
      final pad = (w - len) ~/ 2;
      sb.writeln((' ' * pad) +
          (len == s.length ? s : s.substring(0, w)) +
          (' ' * (w - pad - len)));
    }

    sb.writeln(sepW);
    center('VENTAS POR PRODUCTO - DETALLE');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(
        'Fecha: ${DateFormat('dd/MM/yyyy').format(fromDate)}'.padRight(w));
    sb.writeln(
        'Desde: ${DateFormat('HH:mm:ss').format(DateTime(fromDate.year, fromDate.month, fromDate.day))}                      Hasta: ${DateFormat('HH:mm:ss').format(DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59))}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('CÓD.', 6) +
        padR('PRODUCTO', 26) +
        padR('CANT.', 7) +
        padR('PRECIO', 11) +
        padR('TOTAL', 12) +
        padR('IVA', 10));
    sb.writeln(dashW);

    double totalIva = 0.0;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final m = e as Map<String, dynamic>;
      final code = (m['code'] as String? ?? '').trim();
      final cod = code.isEmpty ? (i + 1).toString().padLeft(3, '0') : code;
      final name = (m['productName'] as String? ?? '').trim();
      final qty = m['quantity'] as int? ?? 0;
      final revenue = (m['revenue'] as num?)?.toDouble() ?? 0.0;
      final price = qty > 0 ? revenue / qty : 0.0;
      final iva = revenue * (0.19 / 1.19);
      totalIva += iva;
      final productStr = name.length > 24 ? name.substring(0, 24) : name;
      sb.writeln(
          '${padR(cod, 6)}${padR(productStr, 26)}${padR('$qty', 7)}${padR('\$${fmtNum(price)}', 11)}${padR('\$${fmtNum(revenue)}', 12)}${padR('\$${fmtNum(iva)}', 10)}');
    }

    sb.writeln(dashW);
    sb.writeln(padR('TOTAL PRODUCTOS:', 35) +
        padR('$totalQuantity', 7) +
        padR('', 11) +
        padR('\$${fmtNum(totalRevenue)}', 12) +
        padR('\$${fmtNum(totalIva)}', 10));
    sb.writeln(sepW);
    sb.writeln('Total de referencias vendidas: ${list.length}');
    sb.writeln('Total unidades vendidas: $totalQuantity');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Ventas por Categoría (80 columnas) para impresión.
  String _buildVentasPorCategoriaText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final fromDate = data['fromDate'] as DateTime? ?? _fromDate;
    final list = data['porCategoria'] as List<dynamic>? ?? [];
    final totalRevenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);
    void center(String s) {
      final len = s.length > w ? w : s.length;
      final pad = (w - len) ~/ 2;
      sb.writeln((' ' * pad) +
          (len == s.length ? s : s.substring(0, w)) +
          (' ' * (w - pad - len)));
    }

    sb.writeln(sepW);
    center('VENTAS POR CATEGORÍA');
    sb.writeln(sepW);
    sb.writeln('Fecha: ${DateFormat('dd/MM/yyyy').format(fromDate)}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('CATEGORÍA', 20) +
        padR('CANTIDAD', 10) +
        padR('SUBTOTAL', 13) +
        padR('IVA', 11) +
        padR('TOTAL', 13) +
        padR('%', 8));
    sb.writeln(dashW);

    int totalQty = 0;
    double totalSub = 0.0;
    double totalIva = 0.0;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final cat = (m['category'] as String? ?? '').trim();
      final qty = m['quantity'] as int? ?? 0;
      final revenue = (m['revenue'] as num?)?.toDouble() ?? 0.0;
      final subtotal = revenue / 1.19;
      final iva = revenue * (0.19 / 1.19);
      final pct = totalRevenue > 0 ? (revenue / totalRevenue) * 100 : 0.0;
      totalQty += qty;
      totalSub += subtotal;
      totalIva += iva;
      final catStr = cat.length > 18 ? cat.substring(0, 18) : cat;
      sb.writeln(
          '${padR(catStr, 20)}${padR('$qty', 10)}${padR('\$${fmtNum(subtotal)}', 13)}${padR('\$${fmtNum(iva)}', 11)}${padR('\$${fmtNum(revenue)}', 13)}${padR('${pct.toStringAsFixed(1)}%', 8)}');
    }

    sb.writeln(dashW);
    final totalSubStr = fmtNum(totalSub);
    final totalIvaStr = fmtNum(totalIva);
    final totalRevStr = fmtNum(totalRevenue);
    sb.writeln(
        '${padR('TOTAL:', 20)}${padR('$totalQty', 10)}${padR('\$$totalSubStr', 13)}${padR('\$$totalIvaStr', 11)}${padR('\$$totalRevStr', 13)}${padR('100.0%', 8)}');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Movimientos del Día (80 columnas) para impresión.
  String _buildMovimientosDelDiaText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final fromDate = data['fromDate'] as DateTime? ?? _fromDate;
    final list = data['transacciones'] as List<dynamic>? ?? [];
    final totalVentas = (data['totalVentas'] as num?)?.toDouble() ?? 0.0;
    final totalDevoluciones =
        (data['totalDevoluciones'] as num?)?.toDouble() ?? 0.0;
    final neto = (data['neto'] as num?)?.toDouble() ?? 0.0;
    final countVentas = data['countVentas'] as int? ?? 0;
    final countDevoluciones = data['countDevoluciones'] as int? ?? 0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);
    void center(String s) {
      final len = s.length > w ? w : s.length;
      final pad = (w - len) ~/ 2;
      sb.writeln((' ' * pad) +
          (len == s.length ? s : s.substring(0, w)) +
          (' ' * (w - pad - len)));
    }

    sb.writeln(sepW);
    center('MOVIMIENTOS DEL DÍA');
    sb.writeln(sepW);
    sb.writeln(
        'Fecha: ${DateFormat('dd/MM/yyyy').format(fromDate)}                    Caja: 01');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('TICKET', 8) +
        padR('HORA', 8) +
        padR('TIPO', 12) +
        padR('CAJERO', 16) +
        padR('FORMA PAGO', 14) +
        padR('MONTO', 14));
    sb.writeln(dashW);

    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as int? ?? 0;
      final date = m['date'] as DateTime?;
      final tipo = m['tipo'] as String? ?? 'Venta';
      final userName = (m['userName'] as String? ?? '').trim();
      final paymentMethod = (m['paymentMethod'] as String? ?? '').trim();
      final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
      final ticketStr = id.toString().padLeft(5, '0');
      final horaStr = date != null ? DateFormat('HH:mm').format(date) : '--:--';
      final userStr =
          userName.length > 14 ? userName.substring(0, 14) : userName;
      final payStr = paymentMethod.length > 12
          ? paymentMethod.substring(0, 12)
          : paymentMethod;
      final montoStr =
          amount >= 0 ? '\$${fmtNum(amount)}' : '-\$${fmtNum(-amount)}';
      sb.writeln(
          '${padR(ticketStr, 8)}${padR(horaStr, 8)}${padR(tipo, 12)}${padR(userStr, 16)}${padR(payStr, 14)}${padR(montoStr, 14)}');
    }

    sb.writeln(dashW);
    sb.writeln(
        'Total movimientos: ${list.length} ($countVentas ventas + $countDevoluciones devoluciones)');
    sb.writeln('Total ventas: \$${fmtNum(totalVentas)}');
    sb.writeln('Total devoluciones: -\$${fmtNum(totalDevoluciones)}');
    sb.writeln('Neto: \$${fmtNum(neto)}');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Ventas por Hora (80 columnas) para impresión.
  String _buildVentasPorHoraText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final fromDate = data['fromDate'] as DateTime? ?? _fromDate;
    final porHora = data['porHora'] as List<dynamic>? ?? [];
    final totalVentas = data['totalVentas'] as int? ?? 0;
    final totalRevenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);

    int hourMax = 0;
    double revenueMax = 0.0;
    for (final e in porHora) {
      final m = e as Map<String, dynamic>;
      final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
      if (rev > revenueMax) {
        revenueMax = rev;
        hourMax = m['hour'] as int? ?? 0;
      }
    }

    sb.writeln(sepW);
    const titulo = 'VENTAS POR HORA';
    const padLeft = (w - titulo.length) ~/ 2;
    sb.writeln(
        (' ' * padLeft) + titulo + (' ' * (w - padLeft - titulo.length)));
    sb.writeln(sepW);
    sb.writeln('Fecha: ${DateFormat('dd/MM/yyyy').format(fromDate)}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('HORA', 18) +
        padR('TRANSACCIONES', 16) +
        padR('MONTO', 15) +
        padR('%', 12));
    sb.writeln(dashW);

    for (final e in porHora) {
      final m = e as Map<String, dynamic>;
      final hour = m['hour'] as int? ?? 0;
      final count = m['count'] as int? ?? 0;
      final revenue = (m['revenue'] as num?)?.toDouble() ?? 0.0;
      final pct = totalRevenue > 0 ? (revenue / totalRevenue) * 100 : 0.0;
      final horaStr =
          '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00';
      final horaPico =
          (revenueMax > 0 && hour == hourMax) ? '  ⭐ Hora pico' : '';
      sb.writeln(
          '${padR(horaStr, 18)}${padR('$count', 16)}${padR('\$${fmtNum(revenue)}', 15)}${padR('${pct.toStringAsFixed(2)}%', 12)}$horaPico');
    }

    sb.writeln(dashW);
    final pctTotal = totalRevenue > 0 ? 100.0 : 0.0;
    sb.writeln(
        '${padR('TOTAL:', 18)}${padR('$totalVentas', 16)}${padR('\$${fmtNum(totalRevenue)}', 15)}${padR('${pctTotal.toStringAsFixed(2)}%', 12)}');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Devoluciones (80 columnas) para impresión.
  String _buildDevolucionesText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final toDate = data['toDate'] as DateTime? ?? _toDate;
    final devoluciones = data['devoluciones'] as List<dynamic>? ?? [];
    final totalDevoluciones =
        (data['totalDevoluciones'] as num?)?.toDouble() ?? 0.0;
    final totalEfectivo = (data['totalEfectivo'] as num?)?.toDouble() ?? 0.0;
    final totalTarjeta = (data['totalTarjeta'] as num?)?.toDouble() ?? 0.0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);

    sb.writeln(sepW);
    const titulo = 'DEVOLUCIONES';
    const padLeft = (w - titulo.length) ~/ 2;
    sb.writeln(
        (' ' * padLeft) + titulo + (' ' * (w - padLeft - titulo.length)));
    sb.writeln(sepW);
    sb.writeln('Fecha: ${DateFormat('dd/MM/yyyy').format(toDate)}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('TICKET', 6) +
        padR('HORA', 6) +
        padR('CAJERO', 14) +
        padR('MOTIVO', 24) +
        padR('MONTO', 14));
    sb.writeln(dashW);

    for (final e in devoluciones) {
      final m = e as Map<String, dynamic>;
      final ticket = m['ticket'] as String? ?? '${m['id']}';
      final hora = m['hora'] as String? ?? '—';
      final cajero = (m['cajero'] as String? ?? '').length > 14
          ? (m['cajero'] as String).substring(0, 14)
          : (m['cajero'] as String? ?? '');
      final motivo = (m['motivo'] as String? ?? '—').length > 24
          ? (m['motivo'] as String).substring(0, 24)
          : (m['motivo'] as String? ?? '—');
      final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
      sb.writeln(
          '${padR(ticket, 6)}${padR(hora, 6)}${padR(cajero, 14)}${padR(motivo, 24)}${padR('\$${fmtNum(amount)}', 14)}');
    }

    sb.writeln(dashW);
    sb.writeln(
        '${padR('TOTAL DEVOLUCIONES:', 54)}${padR('\$${fmtNum(totalDevoluciones)}', 14)}');
    sb.writeln('');
    sb.writeln('Devoluciones en efectivo:    \$${fmtNum(totalEfectivo)}');
    sb.writeln('Devoluciones a tarjeta:     \$${fmtNum(totalTarjeta)}');
    sb.writeln(sepW);
    return sb.toString();
  }

  /// Genera el texto del reporte Resumen Semanal/Mensual (80 columnas) para impresión.
  String _buildResumenSemanalText(Map<String, dynamic> data) {
    const w = 80;
    final sepW = '=' * w;
    final dashW = '-' * w;
    final fromDate = data['fromDate'] as DateTime? ?? _fromDate;
    final toDate = data['toDate'] as DateTime? ?? _toDate;
    final porDia = data['porDia'] as List<dynamic>? ?? [];
    final totalVentas = (data['totalVentas'] as num?)?.toDouble() ?? 0.0;
    final totalTransacciones = data['totalTransacciones'] as int? ?? 0;
    final ticketPromedioGlobal =
        (data['ticketPromedioGlobal'] as num?)?.toDouble() ?? 0.0;
    final promedioVentas = (data['promedioVentas'] as num?)?.toDouble() ?? 0.0;
    final promedioTransacciones =
        (data['promedioTransacciones'] as num?)?.toDouble() ?? 0.0;
    final mejorDiaDate = data['mejorDiaDate'] as DateTime?;
    final mejorDiaVentas = (data['mejorDiaVentas'] as num?)?.toDouble() ?? 0.0;
    final peorDiaDate = data['peorDiaDate'] as DateTime?;
    final peorDiaVentas = (data['peorDiaVentas'] as num?)?.toDouble() ?? 0.0;
    final diferenciaMejorPeor =
        (data['diferenciaMejorPeor'] as num?)?.toDouble() ?? 0.0;

    final sb = StringBuffer();
    String fmtNum(double n) => n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    String padR(String s, int len) =>
        s.length >= len ? s.substring(0, len) : s + ' ' * (len - s.length);

    sb.writeln(sepW);
    const titulo = 'RESUMEN SEMANAL DE VENTAS';
    const padLeft = (w - titulo.length) ~/ 2;
    sb.writeln(
        (' ' * padLeft) + titulo + (' ' * (w - padLeft - titulo.length)));
    sb.writeln(sepW);
    sb.writeln(
        'Período: ${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}');
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln(padR('DÍA', 14) +
        padR('VENTAS', 14) +
        padR('TRANSACCIONES', 16) +
        padR('TICKET PROM.', 14) +
        padR('DIFERENCIA', 12));
    sb.writeln(dashW);

    for (final e in porDia) {
      final m = e as Map<String, dynamic>;
      final diaLabel = m['diaLabel'] as String? ?? '—';
      final ventas = (m['ventas'] as num?)?.toDouble() ?? 0.0;
      final transacciones = m['transacciones'] as int? ?? 0;
      final ticketProm = (m['ticketPromedio'] as num?)?.toDouble() ?? 0.0;
      final diferencia = m['diferencia'] as String? ?? '—';
      sb.writeln(
          '${padR(diaLabel, 14)}${padR('\$${fmtNum(ventas)}', 14)}${padR('$transacciones', 16)}${padR('\$${fmtNum(ticketProm)}', 14)}${padR(diferencia, 12)}');
    }

    sb.writeln(dashW);
    sb.writeln(
        '${padR('TOTAL:', 14)}${padR('\$${fmtNum(totalVentas)}', 14)}${padR('$totalTransacciones', 16)}${padR('\$${fmtNum(ticketPromedioGlobal)}', 14)}');
    sb.writeln(
        '${padR('PROMEDIO:', 14)}${padR('\$${fmtNum(promedioVentas)}', 14)}${padR(promedioTransacciones.toStringAsFixed(0), 16)}');
    sb.writeln(sepW);
    sb.writeln('');
    const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    if (mejorDiaDate != null) {
      final lbl =
          '${diasSemana[mejorDiaDate.weekday - 1]} ${mejorDiaDate.day.toString().padLeft(2, '0')}/${mejorDiaDate.month.toString().padLeft(2, '0')}';
      sb.writeln('Mejor día: $lbl con \$${fmtNum(mejorDiaVentas)}');
    }
    if (peorDiaDate != null) {
      final lbl =
          '${diasSemana[peorDiaDate.weekday - 1]} ${peorDiaDate.day.toString().padLeft(2, '0')}/${peorDiaDate.month.toString().padLeft(2, '0')}';
      sb.writeln('Peor día: $lbl con \$${fmtNum(peorDiaVentas)}');
    }
    sb.writeln(
        'Diferencia: ${diferenciaMejorPeor >= 0 ? '+' : ''}${diferenciaMejorPeor.toStringAsFixed(1)}%');
    sb.writeln(sepW);
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Profesionales'),
        actions: [
          IconButton(
            onPressed: _showPrintReportDialog,
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir reporte (POS u otra impresora)',
          ),
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Seleccionar rango de fechas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Rango de fechas (calendario)
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

          // Menú lateral: solo Cierre de Caja
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 260,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(
                              right: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Text(
                                'REPORTES',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                              ),
                            ),
                            _buildDailyReportTile(
                                1, 'Cierre de Caja', Icons.point_of_sale),
                            _buildDailyReportTile(
                                2, 'Ventas por Producto', Icons.inventory_2),
                            _buildDailyReportTile(
                                3, 'Ventas por Categoría', Icons.category),
                            _buildDailyReportTile(
                                4, 'Movimientos del Día', Icons.swap_horiz),
                            _buildDailyReportTile(
                                5, 'Ventas por Hora', Icons.schedule),
                            _buildDailyReportTile(
                                6, 'Devoluciones', Icons.keyboard_return),
                            _buildDailyReportTile(7, 'Resumen Semanal/Mensual',
                                Icons.calendar_view_week),
                          ],
                        ),
                      ),
                      Expanded(child: _buildDailyReportContent()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportTile(int index, String title, IconData icon) {
    final selected = _selectedDailyReport == index;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: selected ? Colors.blue : Colors.grey.shade300,
        child: Text('$index',
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold)),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      trailing:
          Icon(icon, size: 20, color: selected ? Colors.blue : Colors.grey),
      selected: selected,
      onTap: () => _selectDailyReport(index),
    );
  }

  Widget _buildDailyReportContent() {
    if (_selectedDailyReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Seleccione un reporte del menú',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_selectedDailyReport == 1) return _buildCierreDeCajaContent();
    if (_selectedDailyReport == 2) return _buildVentasPorProductoContent();
    if (_selectedDailyReport == 3) return _buildVentasPorCategoriaContent();
    if (_selectedDailyReport == 4) return _buildTransaccionesDiaContent();
    if (_selectedDailyReport == 5) return _buildVentasPorHoraContent();
    if (_selectedDailyReport == 6) return _buildDevolucionesContent();
    if (_selectedDailyReport == 7) return _buildResumenSemanalContent();
    return const SizedBox.shrink();
  }

  Future<void> _onDescargarCierreDeCajaPdf() async {
    if (_cierreDeCajaData == null) {
      Get.snackbar('Aviso', 'No hay datos de cierre de caja para exportar.');
      return;
    }
    try {
      setState(() => _isLoading = true);
      final pdfBytes = await _generateCierreDeCajaPDF(_cierreDeCajaData!);
      final closeDate =
          _cierreDeCajaData!['closeDate'] as DateTime? ?? DateTime.now();
      final baseName =
          'cierre_de_caja_${DateFormat('yyyyMMdd').format(closeDate)}_sesion_${_cierreDeCajaData!['sessionId'] ?? ''}';
      final saved = await _saveCierreDeCajaPdf(pdfBytes, baseName);
      if (saved != null) {
        Get.snackbar('PDF guardado', 'Archivo: $saved',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
      } else {
        Get.snackbar('Información', 'Operación cancelada',
            backgroundColor: Colors.orange, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo guardar el PDF: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onExportarCierreDeCajaExcel() async {
    if (_cierreDeCajaData == null) {
      Get.snackbar('Aviso', 'No hay datos de cierre de caja para exportar.');
      return;
    }
    try {
      setState(() => _isLoading = true);
      final d = _cierreDeCajaData!;
      final closeDate = d['closeDate'] as DateTime? ?? DateTime.now();
      final baseName =
          'cierre_de_caja_${DateFormat('yyyyMMdd').format(closeDate)}_sesion_${d['sessionId'] ?? ''}';
      final fileName = '$baseName.xlsx';
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Cierre de Caja como Excel',
        fileName: fileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
      if (outputFile == null || outputFile.trim().isEmpty) {
        Get.snackbar('Información', 'Operación cancelada',
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }
      String path = outputFile.trim();
      if (!path.toLowerCase().endsWith('.xlsx')) path = '$path.xlsx';

      var excel = Excel.createExcel();
      var sheet = excel['Cierre de Caja'];

      int row = 0;
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Cierre de Caja';
      row++;
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value =
          '${DateFormat('dd/MM/yyyy').format(closeDate)} · ${d['userName'] ?? 'Cajero'} · Sesión #${d['sessionId']}';
      row += 2;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Resumen de ventas';
      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Concepto';
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = 'Valor';
      row++;
      final resumenLabels = [
        'Número de ventas',
        'Ticket promedio',
        'Venta bruta',
        'Descuentos',
        'Devoluciones',
        'Venta neta',
        'IVA incluido'
      ];
      final resumenKeys = [
        'numVentas',
        'ticketPromedio',
        'ventaBruta',
        'descuentos',
        'devoluciones',
        'ventaNeta',
        'ivaIncluido'
      ];
      for (int i = 0; i < resumenLabels.length; i++) {
        final v = d[resumenKeys[i]];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = resumenLabels[i];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = v is num ? v.toDouble() : v;
        row++;
      }
      row++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Formas de pago';
      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Forma de pago';
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = 'Monto';
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = 'Cant. ventas';
      row++;
      final byMethod = d['byMethod'] as Map<String, dynamic>? ?? {};
      for (final e in byMethod.entries) {
        final amount = (e.value['amount'] is num)
            ? (e.value['amount'] as num).toDouble()
            : 0.0;
        final count = e.value['count'] as int? ?? 0;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = e.key;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = amount;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = count;
        row++;
      }
      row++;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Arqueo de caja (efectivo)';
      row++;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = 'Concepto';
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = 'Valor';
      row++;
      final arqueoLabels = [
        'Fondo inicial',
        '(+) Ventas efectivo',
        '(+) Otros ingresos',
        '(-) Retiros',
        '(-) Gastos',
        'Saldo esperado',
        'Saldo real',
        'Diferencia'
      ];
      final arqueoKeys = [
        'initialAmount',
        'ventasEfectivo',
        'otrosIngresos',
        'retiros',
        'gastos',
        'saldoEsperado',
        'saldoReal',
        'diferencia'
      ];
      for (int i = 0; i < arqueoLabels.length; i++) {
        final v = (d[arqueoKeys[i]] as num?)?.toDouble() ?? 0.0;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = arqueoLabels[i];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = v;
        row++;
      }

      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(path);
        await file.writeAsBytes(bytes);
        Get.snackbar('Excel guardado', 'Archivo: $path',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
      } else {
        Get.snackbar('Error', 'No se pudo generar el archivo Excel.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'No se pudo exportar a Excel: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCierreDeCajaContent() {
    if (_cierreDeCajaData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay sesión de caja en el período seleccionado.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Seleccione un rango de fechas que incluya la fecha de cierre.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    final d = _cierreDeCajaData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cierre de Caja',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd/MM/yyyy').format(d['closeDate'] as DateTime)} · ${d['userName'] ?? 'Cajero'} · Sesión #${d['sessionId']}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await _loadCashSessionReport();
                        final sessionId = _getCierreDeCajaSessionId();
                        if (sessionId != null) {
                          final data = await AccountingReportsService
                              .getCierreDeCajaData(sessionId);
                          if (mounted) {
                            setState(() {
                              _cierreDeCajaData = data;
                              _isLoading = false;
                            });
                          }
                        } else if (mounted) setState(() => _isLoading = false);
                      },
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Actualizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _onDescargarCierreDeCajaPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text('Descargar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _onExportarCierreDeCajaExcel,
                icon: const Icon(Icons.table_chart, size: 20),
                label: const Text('Exportar Excel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de ventas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.blue.shade50),
                    columns: const [
                      DataColumn(
                          label: Text('Concepto',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Valor',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: [
                      _dataRow('Número de ventas', '${d['numVentas']}'),
                      _dataRow('Ticket promedio',
                          '\$${_currencyFormat.format((d['ticketPromedio'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Venta bruta',
                          '\$${_currencyFormat.format((d['ventaBruta'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Descuentos',
                          '-\$${_currencyFormat.format((d['descuentos'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Devoluciones',
                          '-\$${_currencyFormat.format((d['devoluciones'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Facturas canceladas / anuladas',
                          '${d['numAnuladas'] ?? 0} factura(s) · -\$${_currencyFormat.format((d['montoAnuladas'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Venta neta',
                          '\$${_currencyFormat.format((d['ventaNeta'] as num?)?.toDouble() ?? 0)}',
                          bold: true),
                      _dataRow('IVA incluido',
                          '\$${_currencyFormat.format((d['ivaIncluido'] as num?)?.toDouble() ?? 0)}'),
                      ...(() {
                        final ventasPorTarifaIva = (d['ventasPorTarifaIva']
                                    as Map<String, dynamic>? ??
                                {})
                            .map((k, v) =>
                                MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
                        final ivaPorTarifa = (d['ivaPorTarifa']
                                    as Map<String, dynamic>? ??
                                {})
                            .map((k, v) =>
                                MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
                        final orderedRates = ventasPorTarifaIva.keys.toList()
                          ..sort((a, b) => (int.tryParse(a) ?? 0)
                              .compareTo(int.tryParse(b) ?? 0));
                        return orderedRates
                            .map((rate) => _dataRow(
                                  'IVA $rate%',
                                  'Ventas \$${_currencyFormat.format(ventasPorTarifaIva[rate] ?? 0)} · Imp \$${_currencyFormat.format(ivaPorTarifa[rate] ?? 0)}',
                                ))
                            .toList();
                      })(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formas de pago',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final byMethod =
                          d['byMethod'] as Map<String, dynamic>? ?? {};
                      if (byMethod.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Sin datos.',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.blue.shade50),
                        columns: const [
                          DataColumn(
                              label: Text('Forma de pago',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Monto',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('Cant. ventas',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                        ],
                        rows: byMethod.entries.map<DataRow>((e) {
                          final amount = (e.value['amount'] is num)
                              ? (e.value['amount'] as num).toDouble()
                              : 0.0;
                          final count = e.value['count'] as int? ?? 0;
                          return DataRow(
                            cells: [
                              DataCell(Text(e.key)),
                              DataCell(
                                  Text('\$${_currencyFormat.format(amount)}')),
                              DataCell(Text('$count')),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arqueo de caja (efectivo)',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.blue.shade50),
                    columns: const [
                      DataColumn(
                          label: Text('Concepto',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Valor',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true),
                    ],
                    rows: [
                      _dataRow('Fondo inicial',
                          '\$${_currencyFormat.format((d['initialAmount'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('(+) Ventas efectivo',
                          '\$${_currencyFormat.format((d['ventasEfectivo'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('(+) Otros ingresos',
                          '\$${_currencyFormat.format((d['otrosIngresos'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('(-) Retiros',
                          '-\$${_currencyFormat.format((d['retiros'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('(-) Gastos',
                          '-\$${_currencyFormat.format((d['gastos'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Saldo esperado',
                          '\$${_currencyFormat.format((d['saldoEsperado'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Saldo real',
                          '\$${_currencyFormat.format((d['saldoReal'] as num?)?.toDouble() ?? 0)}'),
                      _dataRow('Diferencia',
                          '\$${_currencyFormat.format((d['diferencia'] as num?)?.toDouble() ?? 0)}',
                          bold: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Para imprimir el ticket de cierre use el botón de impresora en la barra superior.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  DataRow _dataRow(String concept, String value, {bool bold = false}) {
    return DataRow(
      cells: [
        DataCell(Text(concept,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        DataCell(Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      ],
    );
  }

  Widget _buildCierreCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.orange.shade300),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('En desarrollo. Próximamente.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildVentasDiaContent() {
    final d = _ventasDiaData;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ventas = d['ventas'] as List<dynamic>? ?? [];
    final cantidad = d['cantidad'] as int? ?? 0;
    final ventaBruta = (d['ventaBruta'] as num?)?.toDouble() ?? 0.0;
    final descuentos = (d['descuentos'] as num?)?.toDouble() ?? 0.0;
    final ventaNeta = (d['ventaNeta'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventas del Día',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Cantidad de ventas', '$cantidad'),
            _row('Venta bruta', '\$${_currencyFormat.format(ventaBruta)}'),
            _row('Descuentos', '-\$${_currencyFormat.format(descuentos)}'),
            _row('Venta neta', '\$${_currencyFormat.format(ventaNeta)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Detalle de ventas', [
            if (ventas.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay ventas en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...ventas.take(100).map<Widget>((v) {
                final m = v as Map<String, dynamic>;
                final date = m['date'] as DateTime?;
                final total = (m['total'] as num?)?.toDouble() ?? 0.0;
                final pay = m['paymentMethod'] as String? ?? '';
                return _row(
                  '#${m['id']} ${date != null ? DateFormat('HH:mm').format(date) : ''} · $pay',
                  '\$${_currencyFormat.format(total)}',
                );
              }),
            if (ventas.length > 100)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('... y ${ventas.length - 100} más',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12))),
          ]),
        ],
      ),
    );
  }

  Widget _buildMovimientosDiaContent() {
    final d = _movimientosDiaData;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final movs = d['movimientos'] as List<dynamic>? ?? [];
    final totalIngresos = (d['totalIngresos'] as num?)?.toDouble() ?? 0.0;
    final totalEgresos = (d['totalEgresos'] as num?)?.toDouble() ?? 0.0;
    final saldo = (d['saldo'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Movimientos del Día',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row(
                'Total ingresos', '\$${_currencyFormat.format(totalIngresos)}'),
            _row('Total egresos', '-\$${_currencyFormat.format(totalEgresos)}'),
            _row('Saldo', '\$${_currencyFormat.format(saldo)}', bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Detalle de movimientos', [
            if (movs.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay movimientos en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...movs.take(80).map<Widget>((m) {
                final map = m as Map<String, dynamic>;
                final type = map['type'] as String? ?? '';
                final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
                final desc = map['description'] as String? ?? '';
                final date = map['date'] as DateTime?;
                final isIncome = type == 'income';
                return _row(
                  '${date != null ? DateFormat('dd/MM HH:mm').format(date) : ''} ${desc.isNotEmpty ? desc : map['category'] ?? ''}',
                  '${isIncome ? '' : '-'}\$${_currencyFormat.format(amount)}',
                );
              }),
            if (movs.length > 80)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('... y ${movs.length - 80} más',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12))),
          ]),
        ],
      ),
    );
  }

  Widget _buildDevolucionesContent() {
    final d = _devolucionesData;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final devoluciones = d['devoluciones'] as List<dynamic>? ?? [];
    final total = (d['totalDevoluciones'] as num?)?.toDouble() ?? 0.0;
    final totalEfectivo = (d['totalEfectivo'] as num?)?.toDouble() ?? 0.0;
    final totalTarjeta = (d['totalTarjeta'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Devoluciones',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                columns: const [
                  DataColumn(
                      label: Text('TICKET',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('HORA',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('CAJERO',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('MOTIVO',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('MONTO',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                ],
                rows: devoluciones.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(Text('No hay devoluciones en el período.')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                        ]),
                      ]
                    : devoluciones.map<DataRow>((v) {
                        final m = v as Map<String, dynamic>;
                        final ticket = m['ticket'] as String? ?? '${m['id']}';
                        final hora = m['hora'] as String? ?? '—';
                        final cajero = m['cajero'] as String? ?? '';
                        final motivo = m['motivo'] as String? ?? '—';
                        final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
                        return DataRow(cells: [
                          DataCell(Text(ticket)),
                          DataCell(Text(hora)),
                          DataCell(Text(cajero)),
                          DataCell(Text(motivo)),
                          DataCell(Text('\$${_currencyFormat.format(amount)}')),
                        ]);
                      }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCierreCard('Totales', [
            _row('TOTAL DEVOLUCIONES', '\$${_currencyFormat.format(total)}',
                bold: true),
            _row('Devoluciones en efectivo',
                '\$${_currencyFormat.format(totalEfectivo)}'),
            _row('Devoluciones a tarjeta',
                '\$${_currencyFormat.format(totalTarjeta)}'),
          ]),
        ],
      ),
    );
  }

  Widget _buildResumenSemanalContent() {
    final d = _resumenSemanalData;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final porDia = d['porDia'] as List<dynamic>? ?? [];
    final totalVentas = (d['totalVentas'] as num?)?.toDouble() ?? 0.0;
    final totalTransacciones = d['totalTransacciones'] as int? ?? 0;
    final ticketPromedioGlobal =
        (d['ticketPromedioGlobal'] as num?)?.toDouble() ?? 0.0;
    final promedioVentas = (d['promedioVentas'] as num?)?.toDouble() ?? 0.0;
    final promedioTransacciones =
        (d['promedioTransacciones'] as num?)?.toDouble() ?? 0.0;
    final mejorDiaDate = d['mejorDiaDate'] as DateTime?;
    final mejorDiaVentas = (d['mejorDiaVentas'] as num?)?.toDouble() ?? 0.0;
    final peorDiaDate = d['peorDiaDate'] as DateTime?;
    final peorDiaVentas = (d['peorDiaVentas'] as num?)?.toDouble() ?? 0.0;
    final diferenciaMejorPeor =
        (d['diferenciaMejorPeor'] as num?)?.toDouble() ?? 0.0;
    const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen Semanal/Mensual',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                columns: const [
                  DataColumn(
                      label: Text('DÍA',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('VENTAS',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('TRANSACCIONES',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('TICKET PROM.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true),
                  DataColumn(
                      label: Text('DIFERENCIA',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: porDia.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(Text('No hay ventas en el período.')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                        ]),
                      ]
                    : porDia.map<DataRow>((e) {
                        final m = e as Map<String, dynamic>;
                        final diaLabel = m['diaLabel'] as String? ?? '—';
                        final ventas = (m['ventas'] as num?)?.toDouble() ?? 0.0;
                        final transacciones = m['transacciones'] as int? ?? 0;
                        final ticketProm =
                            (m['ticketPromedio'] as num?)?.toDouble() ?? 0.0;
                        final diferencia = m['diferencia'] as String? ?? '—';
                        return DataRow(cells: [
                          DataCell(Text(diaLabel)),
                          DataCell(Text('\$${_currencyFormat.format(ventas)}')),
                          DataCell(Text('$transacciones')),
                          DataCell(
                              Text('\$${_currencyFormat.format(ticketProm)}')),
                          DataCell(Text(diferencia)),
                        ]);
                      }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCierreCard('Totales', [
            _row('TOTAL',
                '\$${_currencyFormat.format(totalVentas)} · $totalTransacciones transacciones · Ticket prom. \$${_currencyFormat.format(ticketPromedioGlobal)}',
                bold: true),
            _row('PROMEDIO diario',
                '\$${_currencyFormat.format(promedioVentas)} · ${promedioTransacciones.toStringAsFixed(0)} transacciones'),
          ]),
          if (mejorDiaDate != null || peorDiaDate != null) ...[
            const SizedBox(height: 16),
            _buildCierreCard('Resumen', [
              if (mejorDiaDate != null)
                _row('Mejor día',
                    '${diasSemana[mejorDiaDate.weekday - 1]} ${mejorDiaDate.day.toString().padLeft(2, '0')}/${mejorDiaDate.month.toString().padLeft(2, '0')} con \$${_currencyFormat.format(mejorDiaVentas)}'),
              if (peorDiaDate != null)
                _row('Peor día',
                    '${diasSemana[peorDiaDate.weekday - 1]} ${peorDiaDate.day.toString().padLeft(2, '0')}/${peorDiaDate.month.toString().padLeft(2, '0')} con \$${_currencyFormat.format(peorDiaVentas)}'),
              _row('Diferencia',
                  '${diferenciaMejorPeor >= 0 ? '+' : ''}${diferenciaMejorPeor.toStringAsFixed(1)}%'),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildGastosContent() {
    final d = _gastosData;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final gastos = d['gastos'] as List<dynamic>? ?? [];
    final cantidad = d['cantidad'] as int? ?? 0;
    final total = (d['total'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gastos',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Cantidad de gastos', '$cantidad'),
            _row('Total gastos', '-\$${_currencyFormat.format(total)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Detalle', [
            if (gastos.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay gastos en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...gastos.take(80).map<Widget>((v) {
                final m = v as Map<String, dynamic>;
                final desc = m['description'] as String? ?? '';
                final date = m['date'] as DateTime?;
                final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
                return _row(
                    '${date != null ? DateFormat('dd/MM HH:mm').format(date) : ''} ${desc.isNotEmpty ? desc : m['category'] ?? ''}',
                    '-\$${_currencyFormat.format(amount)}');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildVentasPorProductoContent() {
    final d = _ventasPorProductoData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final list = d['porProducto'] as List<dynamic>? ?? [];
    final totalRevenue = (d['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalQuantity = d['totalQuantity'] as int? ?? 0;
    final fromDate = d['fromDate'] as DateTime? ?? _fromDate;
    final toDate = d['toDate'] as DateTime? ?? _toDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas por Producto',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total referencias vendidas', '${list.length}'),
            _row('Total unidades vendidas', '$totalQuantity'),
            _row('Total ingresos', '\$${_currencyFormat.format(totalRevenue)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle por producto',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No hay ventas en el período.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.blue.shade50),
                        columns: const [
                          DataColumn(
                              label: Text('Código',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Producto',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Cant.',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('Precio',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('Total',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('IVA',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                        ],
                        rows: list.take(200).map<DataRow>((e) {
                          final m = e as Map<String, dynamic>;
                          final code = m['code'] as String? ?? '';
                          final name = m['productName'] as String? ?? '';
                          final unit = m['unit'] as String? ?? '';
                          final qty = m['quantity'] as int? ?? 0;
                          final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
                          final price = qty > 0 ? rev / qty : 0.0;
                          final iva = rev * (0.19 / 1.19);
                          return DataRow(
                            cells: [
                              DataCell(Text(code.isEmpty ? '-' : code)),
                              DataCell(Text('$name ($unit)')),
                              DataCell(Text('$qty')),
                              DataCell(
                                  Text('\$${_currencyFormat.format(price)}')),
                              DataCell(
                                  Text('\$${_currencyFormat.format(rev)}')),
                              DataCell(
                                  Text('\$${_currencyFormat.format(iva)}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Para imprimir el reporte use el botón de impresora en la barra superior.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasPorCategoriaContent() {
    final d = _ventasPorCategoriaData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final list = d['porCategoria'] as List<dynamic>? ?? [];
    final totalRevenue = (d['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final fromDate = d['fromDate'] as DateTime? ?? _fromDate;
    final toDate = d['toDate'] as DateTime? ?? _toDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas por Categoría',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total ingresos', '\$${_currencyFormat.format(totalRevenue)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle por categoría',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No hay ventas en el período.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.blue.shade50),
                        columns: const [
                          DataColumn(
                              label: Text('Categoría',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Cantidad',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('Subtotal',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('IVA',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('Total',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                          DataColumn(
                              label: Text('%',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                        ],
                        rows: list.map<DataRow>((e) {
                          final m = e as Map<String, dynamic>;
                          final cat = m['category'] as String? ?? '';
                          final qty = m['quantity'] as int? ?? 0;
                          final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
                          final subtotal = rev / 1.19;
                          final iva = rev * (0.19 / 1.19);
                          final pct = totalRevenue > 0
                              ? (rev / totalRevenue) * 100
                              : 0.0;
                          return DataRow(
                            cells: [
                              DataCell(Text(cat)),
                              DataCell(Text('$qty')),
                              DataCell(Text(
                                  '\$${_currencyFormat.format(subtotal)}')),
                              DataCell(
                                  Text('\$${_currencyFormat.format(iva)}')),
                              DataCell(
                                  Text('\$${_currencyFormat.format(rev)}')),
                              DataCell(Text('${pct.toStringAsFixed(1)}%')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Para imprimir el reporte use el botón de impresora en la barra superior.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaccionesDiaContent() {
    final d = _transaccionesDiaData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final list = d['transacciones'] as List<dynamic>? ?? [];
    final totalVentas = (d['totalVentas'] as num?)?.toDouble() ?? 0.0;
    final totalDevoluciones =
        (d['totalDevoluciones'] as num?)?.toDouble() ?? 0.0;
    final neto = (d['neto'] as num?)?.toDouble() ?? 0.0;
    final countVentas = d['countVentas'] as int? ?? 0;
    final countDevoluciones = d['countDevoluciones'] as int? ?? 0;
    final fromDate = d['fromDate'] as DateTime? ?? _fromDate;
    final toDate = d['toDate'] as DateTime? ?? _toDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movimientos del Día',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total movimientos',
                '${list.length} ($countVentas ventas + $countDevoluciones devoluciones)'),
            _row('Total ventas', '\$${_currencyFormat.format(totalVentas)}'),
            _row('Total devoluciones',
                '-\$${_currencyFormat.format(totalDevoluciones)}'),
            _row('Neto', '\$${_currencyFormat.format(neto)}', bold: true),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle de transacciones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No hay movimientos en el período.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.blue.shade50),
                        columns: const [
                          DataColumn(
                              label: Text('Ticket',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Hora',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Tipo',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Cajero',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Forma pago',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Monto',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              numeric: true),
                        ],
                        rows: list.take(500).map<DataRow>((e) {
                          final m = e as Map<String, dynamic>;
                          final id = m['id'] as int? ?? 0;
                          final date = m['date'] as DateTime?;
                          final tipo = m['tipo'] as String? ?? 'Venta';
                          final userName = m['userName'] as String? ?? '';
                          final paymentMethod =
                              m['paymentMethod'] as String? ?? '';
                          final amount =
                              (m['amount'] as num?)?.toDouble() ?? 0.0;
                          return DataRow(
                            cells: [
                              DataCell(Text(id.toString().padLeft(5, '0'))),
                              DataCell(Text(date != null
                                  ? DateFormat('HH:mm').format(date)
                                  : '--:--')),
                              DataCell(Text(tipo)),
                              DataCell(Text(userName)),
                              DataCell(Text(paymentMethod)),
                              DataCell(Text(amount >= 0
                                  ? '\$${_currencyFormat.format(amount)}'
                                  : '-\$${_currencyFormat.format(-amount)}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Para imprimir el reporte use el botón de impresora en la barra superior.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasPorHoraContent() {
    final d = _ventasPorHoraData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final porHora = d['porHora'] as List<dynamic>? ?? [];
    final totalVentas = d['totalVentas'] as int? ?? 0;
    final totalRevenue = (d['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final fromDate = d['fromDate'] as DateTime? ?? _fromDate;
    final toDate = d['toDate'] as DateTime? ?? _toDate;

    int hourPico = 0;
    double revenueMax = 0.0;
    for (final e in porHora) {
      final m = e as Map<String, dynamic>;
      final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
      if (rev > revenueMax) {
        revenueMax = rev;
        hourPico = m['hour'] as int? ?? 0;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas por Hora',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total transacciones', '$totalVentas'),
            _row('Total ingresos', '\$${_currencyFormat.format(totalRevenue)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle por hora',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.blue.shade50),
                      columns: const [
                        DataColumn(
                            label: Text('Hora',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Transacciones',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true),
                        DataColumn(
                            label: Text('Monto',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true),
                        DataColumn(
                            label: Text('%',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true),
                        DataColumn(
                            label: Text('',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: porHora.map<DataRow>((e) {
                        final m = e as Map<String, dynamic>;
                        final hour = m['hour'] as int? ?? 0;
                        final count = m['count'] as int? ?? 0;
                        final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
                        final pct =
                            totalRevenue > 0 ? (rev / totalRevenue) * 100 : 0.0;
                        final isPico = revenueMax > 0 && hour == hourPico;
                        return DataRow(
                          cells: [
                            DataCell(Text(
                                '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00')),
                            DataCell(Text('$count')),
                            DataCell(Text('\$${_currencyFormat.format(rev)}')),
                            DataCell(Text('${pct.toStringAsFixed(2)}%')),
                            DataCell(isPico
                                ? Text('⭐ Hora pico',
                                    style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.bold))
                                : const Text('')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Para imprimir el reporte use el botón de impresora en la barra superior.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductosContent() {
    final d = _topProductosData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final top = d['top'] as List<dynamic>? ?? [];
    final totalQuantity = d['totalQuantity'] as int? ?? 0;
    final totalRevenue = (d['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Productos Más Vendidos',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total unidades', '$totalQuantity'),
            _row('Total ingresos', '\$${_currencyFormat.format(totalRevenue)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Top 30', [
            if (top.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay ventas en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...top.asMap().entries.map<Widget>((e) {
                final m = e.value as Map<String, dynamic>;
                final name = m['productName'] as String? ?? '';
                final qty = m['quantity'] as int? ?? 0;
                final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
                return _row('${e.key + 1}. $name',
                    '$qty und  \$${_currencyFormat.format(rev)}');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildProductosSinMovimientoContent() {
    final d = _productosSinMovimientoData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final productos = d['productos'] as List<dynamic>? ?? [];
    final cantidad = d['cantidad'] as int? ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Productos Sin Movimiento',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Productos que no tuvieron ventas en el período.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Cantidad de productos sin ventas', '$cantidad', bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Listado', [
            if (productos.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                      'Todos los productos tuvieron al menos una venta.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...productos.take(100).map<Widget>((e) {
                final m = e as Map<String, dynamic>;
                final name = m['name'] as String? ?? '';
                final code = m['code'] as String? ?? '';
                final stock = m['stock'] as int? ?? 0;
                return _row('$name [$code]', 'Stock: $stock');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildVentasPorFormaDePagoContent() {
    final d = _ventasPorFormaDePagoData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final list = d['porFormaPago'] as List<dynamic>? ?? [];
    final totalVentas = d['totalVentas'] as int? ?? 0;
    final totalCobrado = (d['totalCobrado'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventas por Forma de Pago',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row('Total ventas', '$totalVentas'),
            _row('Total cobrado', '\$${_currencyFormat.format(totalCobrado)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Por forma de pago', [
            if (list.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay ventas en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...list.map<Widget>((e) {
                final m = e as Map<String, dynamic>;
                final method = m['method'] as String? ?? '';
                final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
                final count = m['count'] as int? ?? 0;
                return _row('$method · $count ventas',
                    '\$${_currencyFormat.format(amount)}');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildMovimientosDeEfectivoContent() {
    final d = _movimientosDeEfectivoData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final movs = d['movimientos'] as List<dynamic>? ?? [];
    final totalIngresos = (d['totalIngresos'] as num?)?.toDouble() ?? 0.0;
    final totalEgresos = (d['totalEgresos'] as num?)?.toDouble() ?? 0.0;
    final saldo = (d['saldo'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Movimientos de Efectivo',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen', [
            _row(
                'Total ingresos', '\$${_currencyFormat.format(totalIngresos)}'),
            _row('Total egresos', '-\$${_currencyFormat.format(totalEgresos)}'),
            _row('Saldo', '\$${_currencyFormat.format(saldo)}', bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Detalle', [
            if (movs.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay movimientos en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...movs.take(80).map<Widget>((m) {
                final map = m as Map<String, dynamic>;
                final type = map['type'] as String? ?? '';
                final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
                final desc = map['description'] as String? ?? '';
                final date = map['date'] as DateTime?;
                final method = map['paymentMethod'] as String? ?? '';
                final isIncome = type == 'income';
                return _row(
                    '${date != null ? DateFormat('dd/MM HH:mm').format(date) : ''} $method ${desc.isNotEmpty ? desc : map['category'] ?? ''}',
                    '${isIncome ? '' : '-'}\$${_currencyFormat.format(amount)}');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildArqueoDeCajaContent() {
    final d = _arqueoDeCajaData;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final sesiones = d['sesiones'] as List<dynamic>? ?? [];
    final totalInicial = (d['totalInicial'] as num?)?.toDouble() ?? 0.0;
    final totalFinal = (d['totalFinal'] as num?)?.toDouble() ?? 0.0;
    final totalIngresos = (d['totalIngresos'] as num?)?.toDouble() ?? 0.0;
    final totalEgresos = (d['totalEgresos'] as num?)?.toDouble() ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arqueo de Caja',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
              '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          _buildCierreCard('Resumen del período', [
            _row('Sesiones', '${sesiones.length}'),
            _row('Fondo inicial total',
                '\$${_currencyFormat.format(totalInicial)}'),
            _row(
                'Fondo final total', '\$${_currencyFormat.format(totalFinal)}'),
            _row(
                'Total ingresos', '\$${_currencyFormat.format(totalIngresos)}'),
            _row('Total egresos', '-\$${_currencyFormat.format(totalEgresos)}',
                bold: true),
          ]),
          const SizedBox(height: 16),
          _buildCierreCard('Sesiones', [
            if (sesiones.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay sesiones en el período.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...sesiones.map<Widget>((s) {
                final m = s as Map<String, dynamic>;
                final id = m['sessionId'];
                final user = m['userName'] as String? ?? '';
                final open = m['openDate'] is DateTime
                    ? DateFormat('dd/MM HH:mm')
                        .format(m['openDate'] as DateTime)
                    : '';
                final close =
                    m['closeDate'] != null && m['closeDate'] is DateTime
                        ? DateFormat('dd/MM HH:mm')
                            .format(m['closeDate'] as DateTime)
                        : 'Abierta';
                final initial = (m['initialAmount'] as num?)?.toDouble() ?? 0.0;
                final finalAmt = (m['finalAmount'] as num?)?.toDouble() ?? 0.0;
                final diff = (m['difference'] as num?)?.toDouble() ?? 0.0;
                return _row('Sesión #$id · $user ($open - $close)',
                    'Inicial: \$${_currencyFormat.format(initial)}  Final: \$${_currencyFormat.format(finalAmt)}  Diff: \$${_currencyFormat.format(diff)}');
              }),
          ]),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                  (_quickSummary['net_income'] ?? 0) >= 0
                      ? Colors.green
                      : Colors.red,
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

          // Ingresos por medio de pago
          if (_quickSummary['income_by_payment_method'] != null &&
              (_quickSummary['income_by_payment_method'] as Map)
                  .isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ingresos por medio de pago',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: (_quickSummary['income_by_payment_method'] as Map)
                      .entries
                      .map<Widget>((e) {
                    final amount =
                        (e.value is num) ? (e.value as num).toDouble() : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '\$${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Egresos por medio de pago
          if (_quickSummary['expenses_by_payment_method'] != null &&
              (_quickSummary['expenses_by_payment_method'] as Map)
                  .isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Egresos por medio de pago',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: (_quickSummary['expenses_by_payment_method'] as Map)
                      .entries
                      .map<Widget>((e) {
                    final amount =
                        (e.value is num) ? (e.value as num).toDouble() : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '\$${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

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

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
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

  Widget _buildReportButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
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
        child:
            Text('Haz clic en "Estado de Resultados" para generar el reporte'),
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
                      _buildSummaryItem('Total Ingresos',
                          _incomeStatement!.totalIncome, Colors.green),
                      _buildSummaryItem('Total Egresos',
                          _incomeStatement!.totalExpenses, Colors.red),
                      _buildSummaryItem(
                          'Utilidad Neta',
                          _incomeStatement!.netIncome,
                          _incomeStatement!.netIncome >= 0
                              ? Colors.green
                              : Colors.red),
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
                      _buildCategoryItem(category.category, category.amount,
                          category.percentage, Colors.green)),
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
                      _buildCategoryItem(category.category, category.amount,
                          category.percentage, Colors.red)),
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

  Widget _buildCategoryItem(
      String category, double amount, double percentage, Color color) {
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
                      _buildSummaryItem('Efectivo Inicial',
                          _cashFlowReport!.initialCash, Colors.blue),
                      _buildSummaryItem('Efectivo Final',
                          _cashFlowReport!.finalCash, Colors.green),
                      _buildSummaryItem(
                          'Flujo Neto',
                          _cashFlowReport!.netCashFlow,
                          _cashFlowReport!.netCashFlow >= 0
                              ? Colors.green
                              : Colors.red),
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
                  ..._cashFlowReport!.dailyFlows
                      .map((flow) => _buildDailyFlowItem(flow)),
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
          Text('\$${flow.income.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green)),
          Text('\$${flow.expenses.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red)),
          Text('\$${flow.netFlow.toStringAsFixed(2)}',
              style: TextStyle(
                  color: flow.netFlow >= 0 ? Colors.green : Colors.red)),
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
                      _buildSummaryItem(
                          'Total Sesiones',
                          _cashSessionReport!.totalSessions.toDouble(),
                          Colors.blue),
                      _buildSummaryItem('Total Ingresos',
                          _cashSessionReport!.totalIncome, Colors.green),
                      _buildSummaryItem('Total Egresos',
                          _cashSessionReport!.totalExpenses, Colors.red),
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
                  ..._cashSessionReport!.sessions
                      .map((session) => _buildSessionItem(session)),
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
                  color:
                      session.status == 'closed' ? Colors.green : Colors.orange,
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
          Text(
              'Apertura: ${DateFormat('dd/MM/yyyy HH:mm').format(session.openDate)}'),
          if (session.closeDate != null)
            Text(
                'Cierre: ${DateFormat('dd/MM/yyyy HH:mm').format(session.closeDate!)}'),
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
                      _buildSummaryItem(
                          'Total Transacciones',
                          _auditReport!.totalTransactions.toDouble(),
                          Colors.blue),
                      _buildSummaryItem('Monto Total',
                          _auditReport!.totalAmount, Colors.green),
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
                  ..._auditReport!.entries
                      .take(50)
                      .map((entry) => _buildAuditItem(entry)),
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
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';

    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

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
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
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
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generateIncomeStatementPDF(
      IncomeStatement statement) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

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
            pw.Text('INGRESOS',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1)
              },
              children: [
                _buildPDFTableRow('Total Ingresos', statement.totalIncome),
                for (final category in statement.incomeCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),

            pw.SizedBox(height: 20),

            // Egresos
            pw.Text('EGRESOS',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1)
              },
              children: [
                _buildPDFTableRow('Total Egresos', statement.totalExpenses),
                for (final category in statement.expenseCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Text('RESULTADO',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Utilidad Neta', statement.netIncome,
                isImportant: true),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _generateCashFlowPDF(CashFlowReport report) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Flujo de Caja', period),
            pw.SizedBox(height: 20),
            pw.Text('ENTRADAS',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Ingresos Totales', report.totalIncome),
            pw.SizedBox(height: 20),
            pw.Text('SALIDAS',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCard('Egresos Totales', report.totalExpenses),
            pw.SizedBox(height: 20),
            pw.Text('SALDO',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900)),
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
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Sesiones de Caja', period),
            pw.SizedBox(height: 20),
            pw.Text('Resumen de Sesiones',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
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
                ...report.sessions.take(10).map((session) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(session.userName,
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(session.openDate),
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.totalIncome),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.green700)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.totalExpenses),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.red700)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.finalAmount),
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
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

  /// PDF del reporte detallado de Cierre de Caja (una sesión: ventas, formas de pago, arqueo).
  Future<Uint8List> _generateCierreDeCajaPDF(Map<String, dynamic> d) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final closeDate = d['closeDate'] as DateTime? ?? DateTime.now();
    final period = DateFormat('dd/MM/yyyy').format(closeDate);
    final subtitle =
        '${d['userName'] ?? 'Cajero'} · Sesión #${d['sessionId'] ?? '-'}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final rowsResumen = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('Concepto', isHeader: true),
                _buildPDFTableCell('Valor', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Número de ventas')),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${d['numVentas'] ?? 0}')),
              ],
            ),
            _buildPDFTableRow('Ticket promedio',
                (d['ticketPromedio'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Venta bruta', (d['ventaBruta'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Descuentos', (d['descuentos'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Devoluciones', (d['devoluciones'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Venta neta', (d['ventaNeta'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'IVA incluido', (d['ivaIncluido'] as num?)?.toDouble() ?? 0),
          ];
          final byMethod = d['byMethod'] as Map<String, dynamic>? ?? {};
          final rowsMetodos = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('Forma de pago', isHeader: true),
                _buildPDFTableCell('Monto', isHeader: true),
                _buildPDFTableCell('Cant. ventas', isHeader: true),
              ],
            ),
            ...byMethod.entries.map((e) {
              final amount = (e.value['amount'] is num)
                  ? (e.value['amount'] as num).toDouble()
                  : 0.0;
              final count = e.value['count'] as int? ?? 0;
              return pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(e.key,
                          style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_currencyFormat.format(amount),
                          style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('$count',
                          style: const pw.TextStyle(fontSize: 9))),
                ],
              );
            }),
          ];
          final rowsArqueo = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFTableCell('Concepto', isHeader: true),
                _buildPDFTableCell('Valor', isHeader: true),
              ],
            ),
            _buildPDFTableRow(
                'Fondo inicial', (d['initialAmount'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow('(+) Ventas efectivo',
                (d['ventasEfectivo'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow('(+) Otros ingresos',
                (d['otrosIngresos'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                '(-) Retiros', (d['retiros'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                '(-) Gastos', (d['gastos'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow('Saldo esperado',
                (d['saldoEsperado'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Saldo real', (d['saldoReal'] as num?)?.toDouble() ?? 0),
            _buildPDFTableRow(
                'Diferencia', (d['diferencia'] as num?)?.toDouble() ?? 0),
          ];
          return [
            _buildPDFTitle(companyName, 'Cierre de Caja', period),
            pw.SizedBox(height: 4),
            pw.Text(subtitle,
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            pw.Text('Resumen de ventas',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
              },
              children: rowsResumen,
            ),
            pw.SizedBox(height: 16),
            pw.Text('Formas de pago',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(0.8),
              },
              children: rowsMetodos.isEmpty
                  ? [
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Sin datos.',
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.grey600)),
                          ),
                        ],
                      )
                    ]
                  : rowsMetodos,
            ),
            pw.SizedBox(height: 16),
            pw.Text('Arqueo de caja (efectivo)',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
              },
              children: rowsArqueo,
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  /// Guarda el PDF de Cierre de Caja con FilePicker; si el usuario cancela, guarda en Documentos.
  Future<String?> _saveCierreDeCajaPdf(
      Uint8List pdfBytes, String baseFileName) async {
    final fileName = '$baseFileName.pdf';
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Cierre de Caja como PDF',
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

  Future<Uint8List> _generateAuditPDF(TransactionAuditReport report) async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildPDFTitle(companyName, 'Auditoría de Transacciones', period),
            pw.SizedBox(height: 20),
            pw.Text('Estadísticas',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _buildPDFCardCount(
                'Cantidad de transacciones', report.totalTransactions),
            pw.SizedBox(height: 8),
            _buildPDFCard('Monto total', report.totalAmount),
          ];
        },
      ),
    );
    return pdf.save();
  }

  // ✅ NUEVO: Generar PDF completo con TODAS las secciones
  Future<Uint8List> _generateCompleteReportPDF() async {
    final companyConfigs = await SQLiteDatabaseService.getCompanyConfig();
    final companyName = companyConfigs.isNotEmpty
        ? companyConfigs.first.companyName
        : 'SmartSeller POS';
    final period =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

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
            pw.SizedBox(height: 4),
            pw.Text(
              'Documento de control financiero para gestión del negocio',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Período del reporte: $period',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 40),

            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 30),

            // ========== 1. RESUMEN EJECUTIVO ==========
            pw.Text(
              '1. RESUMEN EJECUTIVO',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Vista consolidada de ingresos, egresos y resultado del período.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard('Total Ingresos',
                (_quickSummary['total_income'] as num? ?? 0).toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Total Egresos',
                (_quickSummary['total_expenses'] as num? ?? 0).toDouble()),
            pw.SizedBox(height: 8),
            _buildPDFCard('Utilidad Neta',
                (_quickSummary['net_income'] as num? ?? 0).toDouble(),
                isImportant: true),
            pw.SizedBox(height: 8),
            _buildPDFCardCount('Cantidad de transacciones',
                (_quickSummary['transaction_count'] as num?)?.toInt() ?? 0),

            pw.SizedBox(height: 16),
            pw.Text(
              'Ingresos por medio de pago',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 8),
            _buildIncomeByPaymentMethodSection(),
            pw.SizedBox(height: 16),
            pw.Text(
              'Egresos por medio de pago',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 8),
            _buildExpensesByPaymentMethodSection(),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),

            // ========== 2. ESTADO DE RESULTADOS ==========
            pw.Text(
              '2. ESTADO DE RESULTADOS',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Desglose de ingresos por categoría y total de egresos.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Text('INGRESOS',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1)
              },
              children: [
                _buildPDFTableRow(
                    'Total Ingresos', _incomeStatement!.totalIncome),
                for (final category
                    in _incomeStatement!.incomeCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('EGRESOS',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1)
              },
              children: [
                _buildPDFTableRow(
                    'Total Egresos', _incomeStatement!.totalExpenses),
                for (final category
                    in _incomeStatement!.expenseCategories.take(5))
                  _buildPDFTableRow(category.category, category.amount),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('RESULTADO',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildPDFCard('Utilidad Neta', _incomeStatement!.netIncome,
                isImportant: true),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),

            // ========== 3. FLUJO DE CAJA ==========
            pw.Text(
              '3. FLUJO DE CAJA',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Entradas, salidas y saldo de efectivo en el período.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCard('Efectivo Inicial', _cashFlowReport!.initialCash),
            pw.SizedBox(height: 8),
            _buildPDFCard('Ingresos Totales', _cashFlowReport!.totalIncome),
            pw.SizedBox(height: 8),
            _buildPDFCard('Egresos Totales', _cashFlowReport!.totalExpenses),
            pw.SizedBox(height: 8),
            _buildPDFCard('Flujo Neto', _cashFlowReport!.netCashFlow,
                isImportant: true),
            pw.SizedBox(height: 8),
            _buildPDFCard('Efectivo Final', _cashFlowReport!.finalCash),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),

            // ========== 4. SESIONES DE CAJA ==========
            pw.Text(
              '4. SESIONES DE CAJA',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Detalle por turno: ingresos, egresos y saldo final de cada cajero.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
                'Total de sesiones en el período: ${_cashSessionReport!.totalSessions}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 12),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
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
                ..._cashSessionReport!.sessions.take(10).map((session) =>
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(session.userName,
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(session.openDate),
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.totalIncome),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.green700)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.totalExpenses),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.red700)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              _currencyFormat.format(session.finalAmount),
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    )),
              ],
            ),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.grey300),
            pw.SizedBox(height: 40),

            // ========== 5. AUDITORÍA DE TRANSACCIONES ==========
            pw.Text(
              '5. AUDITORÍA DE TRANSACCIONES',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Registro de todas las operaciones del período.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            _buildPDFCardCount(
                'Cantidad de transacciones', _auditReport!.totalTransactions),
            pw.SizedBox(height: 8),
            _buildPDFCard('Monto total', _auditReport!.totalAmount),
            pw.SizedBox(height: 20),

            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 20),

            // ========== PIE Y FIRMAS ==========
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'Documento generado electrónicamente por Smart Seller POS. Este reporte es de carácter informativo.',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Smart Seller POS',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Sistema de punto de venta y contabilidad',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                    pw.SizedBox(height: 16),
                    pw.Divider(),
                    pw.SizedBox(height: 6),
                    pw.Text('Firma responsable',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Fecha de generación',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 16),
                    pw.Divider(),
                    pw.SizedBox(height: 6),
                    pw.Text('Fecha', style: const pw.TextStyle(fontSize: 10)),
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
        pw.Text(company,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Período: $period',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildPDFCard(String label, double value,
      {bool isImportant = false}) {
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
              fontWeight:
                  isImportant ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isImportant ? PdfColors.green700 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Para cantidades (ej. número de transacciones), no formato moneda.
  pw.Widget _buildIncomeByPaymentMethodSection() {
    return _buildPaymentMethodSection(
      _quickSummary['income_by_payment_method'],
      'No hay ingresos registrados por medio de pago en este período.',
    );
  }

  pw.Widget _buildExpensesByPaymentMethodSection() {
    return _buildPaymentMethodSection(
      _quickSummary['expenses_by_payment_method'],
      'No hay egresos registrados por medio de pago en este período.',
    );
  }

  pw.Widget _buildPaymentMethodSection(dynamic raw, String emptyMessage) {
    if (raw == null || raw is! Map) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(
          'No hay desglose por medio de pago en este período.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }
    final byMethod = Map<String, double>.fromEntries(
      raw.entries.map((e) => MapEntry(
            e.key.toString(),
            (e.value is num) ? (e.value as num).toDouble() : 0.0,
          )),
    );
    if (byMethod.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(
          emptyMessage,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildPDFTableCell('Medio de pago', isHeader: true),
              _buildPDFTableCell('Total', isHeader: true),
            ],
          ),
          ...byMethod.entries.map((e) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child:
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_currencyFormat.format(e.value),
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  pw.Widget _buildPDFCardCount(String label, int value) {
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
            value.toString(),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildPDFTableRow(String label, double value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(_currencyFormat.format(value))),
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
