// Modal contable integral para gestión de ingresos y egresos
// Reemplaza el modal de proveedores con funcionalidad contable completa

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/accounting_entry.dart';
import '../models/cash_session.dart';
import '../models/payment_method.dart';
import '../models/transaction_category.dart';
import '../services/accounting_service.dart';
import '../services/accounting_reports_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/print_service.dart';
import '../../../utils/puntos_miles_input_formatter.dart';
import 'electronic_invoice_payment_modal.dart';
import '../../../screens/pos_controller.dart';

class AccountingModal extends StatefulWidget {
  final Function(AccountingEntry)? onTransactionProcessed;
  final VoidCallback? onStartCashCount;

  const AccountingModal({
    super.key,
    this.onTransactionProcessed,
    this.onStartCashCount,
  });

  @override
  State<AccountingModal> createState() => _AccountingModalState();
}

class _AccountingModalState extends State<AccountingModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores para el formulario
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _documentNumberController =
      TextEditingController();

  // Variables de estado
  String _selectedTransactionType = 'income';
  String _selectedPaymentMethod = 'CASH';
  String? _selectedCategory;
  String? _selectedSubcategory;
  bool _isProcessing = false;
  bool _showInvoiceOptions = false;

  // Listas de datos
  List<PaymentMethod> _paymentMethods = [];
  List<TransactionCategory> _incomeCategories = [];
  List<TransactionCategory> _expenseCategories = [];
  CashSession? _currentSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Cargar métodos de pago
      _paymentMethods = await AccountingService.getActivePaymentMethods();

      // Cargar categorías
      _incomeCategories = await AccountingService.getCategoriesByType('income');
      _expenseCategories =
          await AccountingService.getCategoriesByType('expense');

      // Verificar sesión de caja
      _currentSession = await AccountingService.getOpenCashSession();

      setState(() {});
    } catch (e) {
      Get.snackbar('Error', 'Error al cargar datos: $e');
    }
  }

  Future<void> _processTransaction() async {
    // Bloquear registros si no hay sesión de caja abierta
    if (_currentSession == null) {
      Get.snackbar('Caja cerrada',
          'Debes abrir la caja antes de registrar ingresos o egresos');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Ingresa el monto de la transacción');
      return;
    }

    final amount = parseMontoPuntosMiles(_amountController.text);
    if (amount == null || amount <= 0) {
      Get.snackbar('Error', 'Monto inválido');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Ingresa una descripción');
      return;
    }

    if (_selectedCategory == null) {
      Get.snackbar('Error', 'Selecciona una categoría');
      return;
    }

    // Validar campos de facturación si está habilitada
    if (_showInvoiceOptions && _documentNumberController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Ingresa el número de documento');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentUser = AuthService.to.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'Usuario no autenticado');
        return;
      }

      // Crear descripción enriquecida
      String description = _descriptionController.text.trim();
      if (_showInvoiceOptions) {
        description += ' | Doc: ${_documentNumberController.text.trim()}';
      }

      final entry = AccountingEntry(
        type: _selectedTransactionType,
        amount: amount,
        description: description,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        date: DateTime.now(),
        paymentMethod: _selectedPaymentMethod,
        userId: currentUser.id!,
        cashSessionId: _currentSession?.id,
        documentNumber:
            _showInvoiceOptions ? _documentNumberController.text.trim() : null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await AccountingService.createAccountingEntry(entry);

      // Llamar callback si existe
      if (widget.onTransactionProcessed != null) {
        widget.onTransactionProcessed!(entry);
      }

      String successMessage =
          '${_selectedTransactionType == 'income' ? 'Ingreso' : 'Egreso'} registrado correctamente';
      if (_showInvoiceOptions) {
        successMessage +=
            '\nDocumento: ${_documentNumberController.text.trim()}';
      }

      Get.snackbar('Éxito', successMessage);

      // Limpiar formulario
      _clearForm();
    } catch (e) {
      Get.snackbar('Error', 'No se pudo procesar la transacción: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  static double? _parseMontoColombia(String text) =>
      parseMontoPuntosMiles(text);

  static String _formatMontoColombia(double value) =>
      formatMontoPuntosMiles(value);

  Future<void> _openCashSessionDialog() async {
    final TextEditingController initialAmountController =
        TextEditingController(text: '');
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Abrir caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Ingresa el monto inicial de la caja (ej: 10.000 o 10.050)'),
            const SizedBox(height: 12),
            TextField(
              controller: initialAmountController,
              decoration: const InputDecoration(
                labelText: 'Monto inicial (pesos)',
                hintText: 'Ej: 10.000 o 150.050',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                PuntosMilesInputFormatter(),
              ],
              onSubmitted: (value) {
                final parsed = _parseMontoColombia(value);
                if (parsed != null) {
                  initialAmountController.text = _formatMontoColombia(parsed);
                }
              },
              onEditingComplete: () {
                final parsed =
                    _parseMontoColombia(initialAmountController.text);
                if (parsed != null) {
                  initialAmountController.text = _formatMontoColombia(parsed);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = initialAmountController.text.trim();
              final parsed = _parseMontoColombia(text);
              if (parsed != null && parsed >= 0) {
                initialAmountController.text = _formatMontoColombia(parsed);
              }
              Get.back(result: true);
            },
            child: const Text('Abrir'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      final amount = _parseMontoColombia(initialAmountController.text) ?? 0.0;
      final user = AuthService.to.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Usuario no autenticado');
        return;
      }
      try {
        await AccountingService.openCashSession(amount, user.id!);
        _currentSession = await AccountingService.getOpenCashSession();
        if (!mounted) return;
        setState(() {});
        // Cerrar primero el modal de Gestión Contable para volver al punto de venta
        Navigator.of(context, rootNavigator: true).pop();
        Get.snackbar(
            'Éxito', 'Caja abierta con \$${_formatMontoColombia(amount)}');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo abrir la caja: $e');
      }
    }
  }

  Future<void> _closeCashSessionDialog() async {
    if (_currentSession == null || _currentSession!.id == null) return;
    final closingSessionId = _currentSession!.id!;
    // Abrir cajón al iniciar arqueo (si el POS provee callback)
    widget.onStartCashCount?.call();
    final amountController = TextEditingController(text: '');
    final notesController = TextEditingController(text: '');
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Cerrar caja'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el monto que hay en caja (arqueo). El sistema comparará con el saldo esperado.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto en caja (pesos) *',
                  hintText: 'Ej: 250.000',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  PuntosMilesInputFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Ej: Faltante por contar',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = _parseMontoColombia(amountController.text.trim());
              if (parsed == null || parsed < 0) {
                Get.snackbar('Error', 'Ingresa un monto válido');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      final finalAmount =
          _parseMontoColombia(amountController.text.trim()) ?? 0.0;
      final user = AuthService.to.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Usuario no autenticado');
        return;
      }
      try {
        await AccountingService.closeCashSession(
          _currentSession!.id!,
          finalAmount,
          user.id!,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
        // Al cerrar caja manualmente, limpiar carritos y carritos en espera del POS (si el POS está cargado).
        if (Get.isRegistered<PosController>()) {
          try {
            await Get.find<PosController>().clearAllCartsOnCashClose();
          } catch (_) {}
        }
        _currentSession = await AccountingService.getOpenCashSession();
        if (!mounted) return;
        setState(() {});
        Get.snackbar('Éxito',
            'Caja cerrada correctamente. Monto registrado: \$${_formatMontoColombia(finalAmount)}');
        final shouldPrint = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Cierre completado'),
            content: const Text(
                '¿Deseas imprimir el ticket de cierre de caja ahora?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Sí, imprimir'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
        if (shouldPrint == true) {
          await _printCashCloseTicket(closingSessionId);
        }
      } catch (e) {
        Get.snackbar('Error', 'No se pudo cerrar la caja: $e');
      }
    }
  }

  Future<void> _printCashCloseTicket(int sessionId) async {
    try {
      final data =
          await AccountingReportsService.getCierreDeCajaData(sessionId);
      if (data == null) {
        Get.snackbar(
            'Aviso', 'No se encontraron datos del cierre para imprimir.');
        return;
      }
      final text = _buildCierreTicketText(data);
      final ok = await PrintService.instance
          .printRawToPrinter(utf8.encode(text), printerName: null);
      if (ok) {
        Get.snackbar('Éxito', 'Ticket de cierre enviado a impresión',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'No se pudo imprimir el cierre',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Error imprimiendo cierre: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  String _buildCierreTicketText(Map<String, dynamic> data) {
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
    final cashIncomeDetails = data['cashIncomeDetails'] as List<dynamic>? ?? [];
    final cashExpenseDetails =
        data['cashExpenseDetails'] as List<dynamic>? ?? [];
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

    String extractEntity(String description) {
      final d = description.trim();
      if (d.isEmpty) return 'Sin detalle';
      if (d.contains(':')) {
        final right = d.split(':').skip(1).join(':').trim();
        if (right.contains('·')) {
          return right.split('·').first.trim();
        }
        if (right.isNotEmpty) return right;
      }
      if (d.contains('·')) {
        return d.split('·').first.trim();
      }
      return d.length > 28 ? d.substring(0, 28) : d;
    }

    Map<String, List<Map<String, dynamic>>> groupByEntity(List<dynamic> raw) {
      final out = <String, List<Map<String, dynamic>>>{};
      for (final item in raw) {
        final m =
            item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
        final desc = m['description'] as String? ?? '';
        final key = extractEntity(desc);
        out.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(m);
      }
      return out;
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
    sb.writeln('DETALLE ENTRADAS DE CAJA (EFECTIVO)');
    sb.writeln(dashW);
    if (cashIncomeDetails.isEmpty) {
      sb.writeln('(Sin entradas adicionales en efectivo)');
    } else {
      final grouped = groupByEntity(cashIncomeDetails);
      for (final entry in grouped.entries) {
        sb.writeln('[${entry.key}]');
        double subtotal = 0.0;
        for (final m in entry.value) {
          final t = m['time'] as String? ?? '';
          final d = m['description'] as String? ?? '';
          final pm = m['paymentMethod'] as String? ?? 'N/A';
          final a = (m['amount'] as num?)?.toDouble() ?? 0.0;
          subtotal += a;
          lineLR('  $t  $pm  $d', '\$${fmtNum(a)}');
        }
        lineVal('  Subtotal ${entry.key}:', '\$${fmtNum(subtotal)}');
        sb.writeln(dashW);
      }
      lineVal('Total entradas caja:', '\$${fmtNum(otrosIngresos)}');
    }
    sb.writeln(sepW);
    sb.writeln('');
    sb.writeln('DETALLE SALIDAS DE CAJA (EFECTIVO)');
    sb.writeln(dashW);
    if (cashExpenseDetails.isEmpty) {
      sb.writeln('(Sin salidas en efectivo)');
    } else {
      final grouped = groupByEntity(cashExpenseDetails);
      for (final entry in grouped.entries) {
        sb.writeln('[${entry.key}]');
        double subtotal = 0.0;
        for (final m in entry.value) {
          final t = m['time'] as String? ?? '';
          final d = m['description'] as String? ?? '';
          final pm = m['paymentMethod'] as String? ?? 'N/A';
          final a = (m['amount'] as num?)?.toDouble() ?? 0.0;
          subtotal += a;
          lineLR('  $t  $pm  $d', '-\$${fmtNum(a)}');
        }
        lineVal('  Subtotal ${entry.key}:', '-\$${fmtNum(subtotal)}');
        sb.writeln(dashW);
      }
      lineVal('Total salidas caja:', '-\$${fmtNum(retiros + gastos + devolucionesEfectivo)}');
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

  void _clearForm() {
    _amountController.clear();
    _descriptionController.clear();
    _notesController.clear();
    _documentNumberController.clear();
    _selectedCategory = null;
    _selectedSubcategory = null;
    _showInvoiceOptions = false;
  }

  // ✅ NUEVO: Widget para botones rápidos de egresos
  Widget _buildQuickExpenseButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Diálogo para pago a proveedor
  void _showSupplierPaymentDialog() {
    final supplierController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final documentController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Pago a Proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Proveedor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [PuntosMilesInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: 'Ej: 10.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: documentController,
              decoration: const InputDecoration(
                labelText: 'Número de Documento (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = parseMontoPuntosMiles(amountController.text);
              final supplier = supplierController.text.trim();

              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }

              if (supplier.isEmpty) {
                Get.snackbar('Error', 'Ingrese el nombre del proveedor');
                return;
              }

              final user = AuthService.to.currentUser;
              if (user == null) {
                Get.snackbar('Error', 'Usuario no autenticado');
                return;
              }

              try {
                await AccountingService.recordSupplierPayment(
                  amount,
                  supplier,
                  user.id!,
                  paymentMethod: _selectedPaymentMethod,
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                  documentNumber: documentController.text.trim().isEmpty
                      ? null
                      : documentController.text.trim(),
                );

                Get.back();
                Get.snackbar('Éxito',
                    'Pago a proveedor registrado: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar('Error', 'No se pudo registrar el pago: $e');
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para gasto operativo
  void _showOperationalExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Gasto Operativo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción del Gasto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [PuntosMilesInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: 'Ej: 10.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = parseMontoPuntosMiles(amountController.text);
              final description = descriptionController.text.trim();

              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }

              if (description.isEmpty) {
                Get.snackbar('Error', 'Ingrese la descripción del gasto');
                return;
              }

              final user = AuthService.to.currentUser;
              if (user == null) {
                Get.snackbar('Error', 'Usuario no autenticado');
                return;
              }

              try {
                await AccountingService.recordOperationalExpense(
                  amount,
                  description,
                  'OPERATIONAL',
                  user.id!,
                  paymentMethod: _selectedPaymentMethod,
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                );

                Get.back();
                Get.snackbar('Éxito',
                    'Gasto operativo registrado: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar('Error', 'No se pudo registrar el gasto: $e');
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para servicios públicos
  void _showUtilitiesDialog() {
    final serviceController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Servicios Públicos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serviceController,
              decoration: const InputDecoration(
                labelText: 'Servicio (Luz, Agua, Gas, etc.)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [PuntosMilesInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: 'Ej: 10.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = parseMontoPuntosMiles(amountController.text);
              final service = serviceController.text.trim();

              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }

              if (service.isEmpty) {
                Get.snackbar('Error', 'Ingrese el tipo de servicio');
                return;
              }

              final user = AuthService.to.currentUser;
              if (user == null) {
                Get.snackbar('Error', 'Usuario no autenticado');
                return;
              }

              try {
                await AccountingService.recordOperationalExpense(
                  amount,
                  'Servicios públicos: $service',
                  'UTILITIES',
                  user.id!,
                  paymentMethod: _selectedPaymentMethod,
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                );

                Get.back();
                Get.snackbar('Éxito',
                    'Servicio público registrado: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar('Error', 'No se pudo registrar el servicio: $e');
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para mantenimiento
  void _showMaintenanceDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Mantenimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción del Mantenimiento',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [PuntosMilesInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: 'Ej: 10.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = parseMontoPuntosMiles(amountController.text);
              final description = descriptionController.text.trim();

              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }

              if (description.isEmpty) {
                Get.snackbar(
                    'Error', 'Ingrese la descripción del mantenimiento');
                return;
              }

              final user = AuthService.to.currentUser;
              if (user == null) {
                Get.snackbar('Error', 'Usuario no autenticado');
                return;
              }

              try {
                await AccountingService.recordOperationalExpense(
                  amount,
                  'Mantenimiento: $description',
                  'MAINTENANCE',
                  user.id!,
                  paymentMethod: _selectedPaymentMethod,
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                );

                Get.back();
                Get.snackbar('Éxito',
                    'Mantenimiento registrado: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar(
                    'Error', 'No se pudo registrar el mantenimiento: $e');
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para devolución a proveedor
  void _showSupplierReturnDialog() {
    final supplierController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final documentController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Devolución a Proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Proveedor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [PuntosMilesInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: 'Ej: 10.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: documentController,
              decoration: const InputDecoration(
                labelText: 'Número de Documento (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = parseMontoPuntosMiles(amountController.text);
              final supplier = supplierController.text.trim();

              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }

              if (supplier.isEmpty) {
                Get.snackbar('Error', 'Ingrese el nombre del proveedor');
                return;
              }

              final user = AuthService.to.currentUser;
              if (user == null) {
                Get.snackbar('Error', 'Usuario no autenticado');
                return;
              }

              try {
                await AccountingService.recordSupplierReturn(
                  amount,
                  supplier,
                  user.id!,
                  paymentMethod: _selectedPaymentMethod,
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                  documentNumber: documentController.text.trim().isEmpty
                      ? null
                      : documentController.text.trim(),
                );

                Get.back();
                Get.snackbar('Éxito',
                    'Devolución a proveedor registrada: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar('Error', 'No se pudo registrar la devolución: $e');
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Diálogo para egreso genérico
  void _showGenericExpenseDialog() {
    _clearForm();
    _selectedTransactionType = 'expense';
    _tabController.animateTo(1); // Cambiar a pestaña de egresos
    Get.back(); // Cerrar el modal actual
  }

  // ✅ NUEVO: Modal para pagos de facturas electrónicas
  void _showElectronicInvoicePaymentModal() {
    Get.dialog(
      const ElectronicInvoicePaymentModal(),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión Contable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // Información de sesión de caja
            if (_currentSession != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesión de Caja Abierta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Saldo inicial: \$${_currentSession!.initialAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _closeCashSessionDialog,
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Cerrar caja'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hay sesión de caja abierta',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _openCashSessionDialog,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Abrir caja'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.trending_up),
                  text: 'Ingresos',
                ),
                Tab(
                  icon: Icon(Icons.trending_down),
                  text: 'Egresos',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIncomeForm(),
                  _buildExpenseForm(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processTransaction,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_selectedTransactionType == 'income'
                            ? Icons.add
                            : Icons.remove),
                    label: Text(_isProcessing
                        ? 'Procesando...'
                        : 'Registrar ${_selectedTransactionType == 'income' ? 'Ingreso' : 'Egreso'}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTransactionType == 'income'
                          ? Colors.green
                          : Colors.red,
                      foregroundColor: Colors.white,
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

  Widget _buildIncomeForm() {
    return _buildTransactionForm('income', _incomeCategories);
  }

  Widget _buildExpenseForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ✅ NUEVO: Botones rápidos para tipos de egresos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipos de Egresos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickExpenseButton(
                      'Pago Proveedor',
                      Icons.business,
                      Colors.blue,
                      () => _showSupplierPaymentDialog(),
                    ),
                    _buildQuickExpenseButton(
                      'Gasto Operativo',
                      Icons.receipt,
                      Colors.orange,
                      () => _showOperationalExpenseDialog(),
                    ),
                    _buildQuickExpenseButton(
                      'Servicios Públicos',
                      Icons.electrical_services,
                      Colors.purple,
                      () => _showUtilitiesDialog(),
                    ),
                    _buildQuickExpenseButton(
                      'Mantenimiento',
                      Icons.build,
                      Colors.teal,
                      () => _showMaintenanceDialog(),
                    ),
                    _buildQuickExpenseButton(
                      'Devolución Proveedor',
                      Icons.keyboard_return,
                      Colors.red,
                      () => _showSupplierReturnDialog(),
                    ),
                    _buildQuickExpenseButton(
                      'Otro Egreso',
                      Icons.add_circle_outline,
                      Colors.grey,
                      () => _showGenericExpenseDialog(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Botón especial para pagos de facturas electrónicas
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showElectronicInvoicePaymentModal(),
                    icon: const Icon(Icons.receipt_long, color: Colors.white),
                    label: const Text(
                      'Pagos de Facturas Electrónicas',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Formulario general de egresos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro Manual de Egreso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTransactionForm('expense', _expenseCategories),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionForm(
      String type, List<TransactionCategory> categories) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Monto (punto de miles automático, estilo Colombia)
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Monto *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
              hintText: 'Ej: 10.000',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [PuntosMilesInputFormatter()],
          ),
          const SizedBox(height: 16),

          // Descripción
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Categoría
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory != null &&
                    categories.any((cat) => cat.code == _selectedCategory)
                ? _selectedCategory
                : null,
            decoration: const InputDecoration(
              labelText: 'Categoría *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: categories.map((category) {
              return DropdownMenuItem(
                value: category.code,
                child: Text(category.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _selectedSubcategory = null;
              });
            },
          ),
          const SizedBox(height: 16),

          // Método de pago
          DropdownButtonFormField<String>(
            initialValue: _paymentMethods
                    .any((method) => method.code == _selectedPaymentMethod)
                ? _selectedPaymentMethod
                : (_paymentMethods.isNotEmpty
                    ? _paymentMethods.first.code
                    : null),
            decoration: const InputDecoration(
              labelText: 'Método de Pago',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payment),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method.code,
                child: Text(method.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value ??
                    (_paymentMethods.isNotEmpty
                        ? _paymentMethods.first.code
                        : 'CASH');
              });
            },
          ),
          const SizedBox(height: 16),

          // Opciones de facturación
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Documento/Comprobante',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _showInvoiceOptions,
                        onChanged: (value) {
                          setState(() {
                            _showInvoiceOptions = value;
                          });
                        },
                        activeThumbColor: Colors.blue,
                      ),
                    ],
                  ),
                  if (_showInvoiceOptions) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _documentNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Documento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notas
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
