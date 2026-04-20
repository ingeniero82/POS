// Pantalla para gestión de cuentas por cobrar y pagar

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/accounts_receivable.dart';
import '../models/receivable_payment.dart';
import '../models/payable_payment.dart';
import '../services/accounting_service.dart';
import '../services/accounts_receivable_payable_service.dart';
import '../../../services/print_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/puntos_miles_input_formatter.dart';

class AccountsReceivablePayableScreen extends StatefulWidget {
  const AccountsReceivablePayableScreen({super.key});

  @override
  State<AccountsReceivablePayableScreen> createState() =>
      _AccountsReceivablePayableScreenState();
}

class _AccountsReceivablePayableScreenState
    extends State<AccountsReceivablePayableScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _receivablePaymentMethods = [
    'Efectivo',
    'Nequi',
    'Daviplata',
  ];

  late TabController _tabController;

  List<ReceivableCustomerSummary> _receivableByCustomer = [];
  List<PayableSupplierSummary> _payableBySupplier = [];
  Map<String, dynamic> _receivableSummary = {};
  Map<String, dynamic> _payableSummary = {};
  bool _isLoading = true;

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 0,
  );

  static final DateFormat _df = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final receivableData = await Future.wait([
        AccountsReceivablePayableService.getReceivablesGroupedByCustomer(),
        AccountsReceivablePayableService.getReceivableSummary(),
      ]);

      final payableData = await Future.wait([
        AccountsReceivablePayableService.getPayablesGroupedBySupplier(),
        AccountsReceivablePayableService.getPayableSummary(),
      ]);

      setState(() {
        _receivableByCustomer =
            receivableData[0] as List<ReceivableCustomerSummary>;
        _receivableSummary = receivableData[1] as Map<String, dynamic>;
        _payableBySupplier = payableData[0] as List<PayableSupplierSummary>;
        _payableSummary = payableData[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudieron cargar los datos: $e');
    }
  }

  /// Vincula factura POS-123 con la venta guardada con id 123.
  static int? _parsePosSaleIdFromInvoice(String invoiceNumber) {
    final m = RegExp(r'^POS-(\d+)$').firstMatch(invoiceNumber.trim());
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  Future<Map<String, dynamic>> _loadReceivableDetailPayload(
      ReceivableCustomerSummary s) async {
    final ids = s.accounts.map((a) => a.id).whereType<int>().toList();
    final paymentsByReceivableId =
        await AccountsReceivablePayableService.getPaymentsForReceivables(ids);
    return {
      'payments': paymentsByReceivableId,
    };
  }

  Future<Map<String, dynamic>> _loadPayableDetailPayload(
      PayableSupplierSummary s) async {
    final ids = s.accounts.map((a) => a.id).whereType<int>().toList();
    final paymentsByPayableId =
        await AccountsReceivablePayableService.getPaymentsForPayables(ids);
    return {'payments': paymentsByPayableId};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar y Pagar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.account_balance_wallet),
              text: 'Por Cobrar',
            ),
            Tab(
              icon: Icon(Icons.payment),
              text: 'Por Pagar',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceivableTab(),
                _buildPayableTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReceivableTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Text(
                'Resumen de Cuentas por Cobrar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCard(
                    'Total Pendiente',
                    '\$${(_receivableSummary['totalPending'] ?? 0).toStringAsFixed(2)}',
                    Colors.red,
                  ),
                  _buildSummaryCard(
                    'Total Cobrado',
                    '\$${(_receivableSummary['totalPaid'] ?? 0).toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    'Vencidas',
                    '${_receivableSummary['overdueCount'] ?? 0}',
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _receivableByCustomer.isEmpty
              ? const Center(
                  child: Text(
                    'No hay cuentas por cobrar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _receivableByCustomer.length,
                  itemBuilder: (context, index) {
                    final row = _receivableByCustomer[index];
                    return _buildReceivableCustomerCard(row);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayableTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              Text(
                'Resumen de Cuentas por Pagar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCard(
                    'Total Pendiente',
                    '\$${(_payableSummary['totalPending'] ?? 0).toStringAsFixed(2)}',
                    Colors.red,
                  ),
                  _buildSummaryCard(
                    'Total Pagado',
                    '\$${(_payableSummary['totalPaid'] ?? 0).toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    'Vencidas',
                    '${_payableSummary['overdueCount'] ?? 0}',
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _payableBySupplier.isEmpty
              ? const Center(
                  child: Text(
                    'No hay cuentas por pagar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _payableBySupplier.length,
                  itemBuilder: (context, index) {
                    final row = _payableBySupplier[index];
                    return _buildPayableSupplierCard(row);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Column(
      children: [
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildReceivableCustomerCard(ReceivableCustomerSummary s) {
    final hasOverdue = s.accounts.any((a) => a.isOverdue);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasOverdue ? Colors.red : Colors.blue,
          child: Icon(
            hasOverdue ? Icons.warning : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          s.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${s.customerDocument} · ${s.documentCount} documento(s)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money.format(s.totalPending),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Pendiente',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        onTap: () => _showReceivableCustomerDetail(s),
      ),
    );
  }

  Widget _buildPayableSupplierCard(PayableSupplierSummary s) {
    final hasOverdue = s.accounts.any((a) => a.isOverdue);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasOverdue ? Colors.red : Colors.orange,
          child: Icon(
            hasOverdue ? Icons.warning : Icons.store,
            color: Colors.white,
          ),
        ),
        title: Text(
          s.supplierName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${s.supplierDocument} · ${s.documentCount} documento(s)',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money.format(s.totalPending),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Pendiente',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        onTap: () => _showPayableSupplierDetail(s),
      ),
    );
  }

  void _showReceivableCustomerDetail(ReceivableCustomerSummary summary) {
    final detailFuture = _loadReceivableDetailPayload(summary);
    final detailScrollController = ScrollController();
    showDialog<void>(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                width: 320,
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando detalle…'),
                  ],
                ),
              ),
            );
          }
          if (snap.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('${snap.error}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar')),
              ],
            );
          }
          final data = snap.data!;
          final paymentsByReceivableId =
              data['payments'] as Map<int, List<ReceivablePayment>>;
          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 760,
              height: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.customerName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                summary.customerDocument,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _chipInfo('Total facturado',
                            _money.format(summary.totalInvoiced)),
                        _chipInfo(
                            'Total cobrado', _money.format(summary.totalPaid)),
                        _chipInfo('Saldo pendiente',
                            _money.format(summary.totalPending)),
                        Chip(
                          label: Text('${summary.documentCount} documento(s)'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: Scrollbar(
                      controller: detailScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: detailScrollController,
                        itemCount: summary.accounts.length,
                        itemBuilder: (context, index) {
                          final acc = summary.accounts[index];
                          final id = acc.id;
                          final payments = id != null
                              ? (paymentsByReceivableId[id] ?? [])
                              : <ReceivablePayment>[];
                          final saleId =
                              _parsePosSaleIdFromInvoice(acc.invoiceNumber);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              leading: Icon(
                                acc.isOverdue
                                    ? Icons.error_outline
                                    : Icons.receipt_long,
                                color: acc.isOverdue ? Colors.red : Colors.blue,
                              ),
                              title: Text(
                                acc.invoiceNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${_df.format(acc.invoiceDate)} · ${_statusLabel(acc.status)}',
                              ),
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _rowKV('Total factura',
                                          _money.format(acc.totalAmount)),
                                      _rowKV('Pagado',
                                          _money.format(acc.paidAmount)),
                                      _rowKV('Pendiente',
                                          _money.format(acc.pendingAmount)),
                                      _rowKV('Vence',
                                          _formatDateOnly(acc.dueDate)),
                                      if (acc.notes != null &&
                                          acc.notes!.trim().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Notas: ${acc.notes}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade800),
                                          ),
                                        ),
                                      if ((acc.id != null) &&
                                          (acc.pendingAmount > 0))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 10, bottom: 4),
                                          child: Wrap(
                                            spacing: 10,
                                            runSpacing: 8,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showRegisterReceivablePaymentDialog(
                                                  ctx,
                                                  summary,
                                                  acc,
                                                ),
                                                icon: const Icon(
                                                    Icons.payments_outlined),
                                                label: const Text(
                                                    'Registrar abono'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade600,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showRegisterReceivableFullPaymentDialog(
                                                  ctx,
                                                  summary,
                                                  acc,
                                                ),
                                                icon: const Icon(
                                                    Icons.check_circle_outline),
                                                label: const Text('Pago total'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade800,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Abonos / pagos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      if (payments.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Sin abonos registrados (saldo inicial = factura completa a crédito).',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...payments.map((p) => ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title:
                                                  Text(_money.format(p.amount)),
                                              subtitle: Text(
                                                '${_df.format(p.paymentDate)} · ${p.paymentMethod}'
                                                '${p.reference != null && p.reference!.isNotEmpty ? ' · Ref: ${p.reference}' : ''}',
                                              ),
                                            )),
                                      if (saleId != null) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'Mercancía / ítems (venta POS)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Carga de ítems desactivada temporalmente para evitar bloqueos al desplazarse.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      detailScrollController.dispose();
    });
  }

  Future<void> _showRegisterReceivablePaymentDialog(
    BuildContext detailDialogContext,
    ReceivableCustomerSummary summary,
    AccountsReceivable account,
  ) async {
    if (account.id == null) {
      Get.snackbar('Aviso', 'La cuenta no tiene identificador válido.');
      return;
    }

    final amountCtrl =
        TextEditingController(text: account.pendingAmount.toStringAsFixed(2));
    final referenceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = _receivablePaymentMethods.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Registrar abono'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Factura: ${account.invoiceNumber}\nPendiente: ${_money.format(account.pendingAmount)}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        PuntosMilesInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto a abonar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                        border: OutlineInputBorder(),
                      ),
                      items: _receivablePaymentMethods
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setLocalState(() => paymentMethod = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: referenceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Referencia (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final amount = parseMontoPuntosMiles(amountCtrl.text);
    if (amount == null || amount <= 0) {
      Get.snackbar('Validación', 'Ingresa un monto válido mayor a 0.');
      return;
    }
    if (amount > account.pendingAmount) {
      Get.snackbar(
          'Validación', 'El abono no puede superar el saldo pendiente.');
      return;
    }

    final now = DateTime.now();
    final payment = ReceivablePayment(
      accountsReceivableId: account.id!,
      amount: amount,
      paymentDate: now,
      paymentMethod: paymentMethod,
      reference:
          referenceCtrl.text.trim().isEmpty ? null : referenceCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      userId: 1,
      createdAt: now,
    );

    try {
      await AccountsReceivablePayableService.recordReceivablePayment(payment);
      try {
        final uid = AuthService.to.currentUser?.id ?? 1;
        await AccountingService.recordReceivableCollection(
          amount,
          summary.customerName,
          account.invoiceNumber,
          uid,
          isFullPayment: false,
          paymentMethod: paymentMethod,
          reference: payment.reference,
          notes: payment.notes,
        );
      } catch (_) {}
      if (!mounted) return;
      if (Navigator.of(detailDialogContext).canPop()) {
        Navigator.of(detailDialogContext).pop();
      }
      await _loadData();

      final shouldPrint = await _askPrintAfterPayment(
        customerName: summary.customerName,
        invoiceNumber: account.invoiceNumber,
        isFullPayment: false,
      );
      if (shouldPrint && mounted) {
        await _printReceivablePaymentReceipt(
          summary: summary,
          account: account,
          payment: payment,
          isFullPayment: false,
        );
      }

      Get.snackbar(
        'Pago registrado',
        'Se registró un abono de ${_money.format(amount)} para ${summary.customerName}.',
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'No se pudo registrar el abono: $e');
    }
  }

  Future<void> _showRegisterReceivableFullPaymentDialog(
    BuildContext detailDialogContext,
    ReceivableCustomerSummary summary,
    AccountsReceivable account,
  ) async {
    if (account.id == null) {
      Get.snackbar('Aviso', 'La cuenta no tiene identificador válido.');
      return;
    }
    if (account.pendingAmount <= 0) {
      Get.snackbar('Aviso', 'La factura ya no tiene saldo pendiente.');
      return;
    }

    String paymentMethod = _receivablePaymentMethods.first;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Confirmar pago total'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Registrar pago total de ${_money.format(account.pendingAmount)} '
                  'para la factura ${account.invoiceNumber}?',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: _receivablePaymentMethods
                      .map(
                        (m) => DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setLocalState(() => paymentMethod = v);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí, pagar todo'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true) return;

    final now = DateTime.now();
    final payment = ReceivablePayment(
      accountsReceivableId: account.id!,
      amount: account.pendingAmount,
      paymentDate: now,
      paymentMethod: paymentMethod,
      reference: null,
      notes: 'Pago total',
      userId: 1,
      createdAt: now,
    );

    try {
      await AccountsReceivablePayableService.recordReceivablePayment(payment);
      try {
        final uid = AuthService.to.currentUser?.id ?? 1;
        await AccountingService.recordReceivableCollection(
          payment.amount,
          summary.customerName,
          account.invoiceNumber,
          uid,
          isFullPayment: true,
          paymentMethod: paymentMethod,
          reference: 'full_payment_receivable',
          notes: 'Pago total',
        );
      } catch (_) {}
      if (!mounted) return;
      if (Navigator.of(detailDialogContext).canPop()) {
        Navigator.of(detailDialogContext).pop();
      }
      await _loadData();

      final shouldPrint = await _askPrintAfterPayment(
        customerName: summary.customerName,
        invoiceNumber: account.invoiceNumber,
        isFullPayment: true,
      );
      if (shouldPrint && mounted) {
        await _printReceivablePaymentReceipt(
          summary: summary,
          account: account,
          payment: payment,
          isFullPayment: true,
        );
      }

      Get.snackbar(
        'Pago registrado',
        'Factura ${account.invoiceNumber} pagada por completo para ${summary.customerName}.',
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', 'No se pudo registrar el pago total: $e');
    }
  }

  Future<bool> _askPrintAfterPayment({
    required String customerName,
    required String invoiceNumber,
    required bool isFullPayment,
  }) async {
    final typeText = isFullPayment ? 'Pago total' : 'Abono';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Imprimir comprobante'),
        content: Text(
          '$typeText registrado para $customerName\n'
          'Factura: $invoiceNumber\n\n'
          '¿Deseas imprimir el comprobante detallado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, imprimir'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _printReceivablePaymentReceipt({
    required ReceivableCustomerSummary summary,
    required AccountsReceivable account,
    required ReceivablePayment payment,
    required bool isFullPayment,
  }) async {
    try {
      final text = _buildReceivablePaymentReceiptText(
        summary: summary,
        account: account,
        payment: payment,
        isFullPayment: isFullPayment,
      );
      final ok =
          await PrintService.instance.printRawToPrinter(utf8.encode(text));
      if (!mounted) return;
      if (ok) {
        Get.snackbar(
          'Impresión',
          'Comprobante enviado a la impresora.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Impresión',
          'No se pudo imprimir el comprobante.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Error al imprimir comprobante: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _buildReceivablePaymentReceiptText({
    required ReceivableCustomerSummary summary,
    required AccountsReceivable account,
    required ReceivablePayment payment,
    required bool isFullPayment,
  }) {
    const width = 48;
    final sep = '=' * width;
    final dash = '-' * width;
    final nf = NumberFormat('#,##0', 'es_CO');
    final sb = StringBuffer();

    String fit(String value) {
      if (value.length <= width) return value;
      return value.substring(0, width);
    }

    String money(double value) => '\$${nf.format(value)}';
    final previousPending =
        (account.pendingAmount + payment.amount).clamp(0, 999999999).toDouble();
    final previousPaid =
        (account.paidAmount - payment.amount).clamp(0, 999999999).toDouble();
    final operationLabel = isFullPayment ? 'PAGO TOTAL' : 'ABONO';

    sb.writeln(sep);
    sb.writeln(fit('COMPROBANTE $operationLabel CxC').padLeft(34));
    sb.writeln(dash);
    sb.writeln(fit('Cliente: ${summary.customerName}'));
    sb.writeln(fit('Doc: ${summary.customerDocument}'));
    sb.writeln(fit('Factura: ${account.invoiceNumber}'));
    sb.writeln(fit('Fecha factura: ${_df.format(account.invoiceDate)}'));
    sb.writeln(fit('Fecha pago: ${_df.format(payment.paymentDate)}'));
    sb.writeln(fit('Tipo operacion: $operationLabel'));
    sb.writeln(dash);
    sb.writeln(fit('Total factura: ${money(account.totalAmount)}'));
    sb.writeln(fit('Pagado previo: ${money(previousPaid)}'));
    sb.writeln(fit('Saldo antes pago: ${money(previousPending)}'));
    sb.writeln(fit('Pago aplicado: ${money(payment.amount)}'));
    sb.writeln(fit('Pagado acumulado: ${money(account.paidAmount)}'));
    sb.writeln(fit('Saldo pendiente: ${money(account.pendingAmount)}'));
    sb.writeln(fit('Metodo: ${payment.paymentMethod}'));
    if (payment.reference != null && payment.reference!.trim().isNotEmpty) {
      sb.writeln(fit('Referencia: ${payment.reference!.trim()}'));
    }
    if (payment.notes != null && payment.notes!.trim().isNotEmpty) {
      sb.writeln(fit('Nota: ${payment.notes!.trim()}'));
    }
    sb.writeln(dash);
    sb.writeln('Documento generado por Smart Seller'.padLeft(36));
    sb.writeln(sep);
    sb.writeln('');
    sb.writeln('');
    sb.writeln('');
    return sb.toString();
  }

  Widget _chipInfo(String label, String value) {
    return Chip(
      avatar: const Icon(Icons.info_outline, size: 18),
      label: Text('$label: $value'),
    );
  }

  Widget _rowKV(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey.shade700)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'partial':
        return 'Parcial';
      case 'paid':
        return 'Pagada';
      case 'overdue':
        return 'Vencida';
      default:
        return status;
    }
  }

  void _showPayableSupplierDetail(PayableSupplierSummary summary) {
    final detailFuture = _loadPayableDetailPayload(summary);
    final detailScrollController = ScrollController();
    showDialog<void>(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                width: 320,
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando detalle…'),
                  ],
                ),
              ),
            );
          }
          if (snap.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('${snap.error}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar')),
              ],
            );
          }
          final paymentsByPayableId =
              (snap.data!['payments'] as Map<int, List<PayablePayment>>);

          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 720,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.supplierName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                summary.supplierDocument,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        _chipInfo('Total facturado',
                            _money.format(summary.totalInvoiced)),
                        _chipInfo(
                            'Total pagado', _money.format(summary.totalPaid)),
                        _chipInfo(
                            'Pendiente', _money.format(summary.totalPending)),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: Scrollbar(
                      controller: detailScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: detailScrollController,
                        itemCount: summary.accounts.length,
                        itemBuilder: (context, index) {
                          final acc = summary.accounts[index];
                          final id = acc.id;
                          final payments = id != null
                              ? (paymentsByPayableId[id] ?? [])
                              : <PayablePayment>[];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              title: Text(acc.invoiceNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(_df.format(acc.invoiceDate)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _rowKV('Total',
                                          _money.format(acc.totalAmount)),
                                      _rowKV('Pagado',
                                          _money.format(acc.paidAmount)),
                                      _rowKV('Pendiente',
                                          _money.format(acc.pendingAmount)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Pagos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      if (payments.isEmpty)
                                        const Text(
                                          'Sin pagos registrados.',
                                          style: TextStyle(
                                              fontStyle: FontStyle.italic),
                                        )
                                      else
                                        ...payments.map((p) => ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title:
                                                  Text(_money.format(p.amount)),
                                              subtitle: Text(
                                                '${_df.format(p.paymentDate)} · ${p.paymentMethod}',
                                              ),
                                            )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      detailScrollController.dispose();
    });
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddAccountDialog() {
    Get.snackbar('Info', 'Funcionalidad en desarrollo');
  }
}
