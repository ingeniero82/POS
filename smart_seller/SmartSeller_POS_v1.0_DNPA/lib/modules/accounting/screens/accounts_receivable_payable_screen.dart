// Pantalla para gestión de cuentas por cobrar y pagar

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../models/sale.dart';
import '../../../services/sqlite_database_service.dart';
import '../models/receivable_payment.dart';
import '../models/payable_payment.dart';
import '../services/accounts_receivable_payable_service.dart';

class AccountsReceivablePayableScreen extends StatefulWidget {
  const AccountsReceivablePayableScreen({super.key});

  @override
  State<AccountsReceivablePayableScreen> createState() =>
      _AccountsReceivablePayableScreenState();
}

class _AccountsReceivablePayableScreenState
    extends State<AccountsReceivablePayableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, Future<Sale?>> _saleFutureById = {};

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
        _receivableByCustomer = receivableData[0] as List<ReceivableCustomerSummary>;
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

  Future<Sale?> _getSaleFutureById(int saleId) {
    return _saleFutureById.putIfAbsent(
      saleId,
      () => SQLiteDatabaseService.getSaleById(saleId),
    );
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
    showDialog<void>(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              content: SizedBox(
                width: 320,
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
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
                        _chipInfo('Total facturado', _money.format(summary.totalInvoiced)),
                        _chipInfo('Total cobrado', _money.format(summary.totalPaid)),
                        _chipInfo('Saldo pendiente', _money.format(summary.totalPending)),
                        Chip(
                          label: Text('${summary.documentCount} documento(s)'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: Scrollbar(
                      child: ListView.builder(
                        itemCount: summary.accounts.length,
                        itemBuilder: (context, index) {
                          final acc = summary.accounts[index];
                          final id = acc.id;
                          final payments = id != null
                              ? (paymentsByReceivableId[id] ?? [])
                              : <ReceivablePayment>[];
                          final saleId = _parsePosSaleIdFromInvoice(acc.invoiceNumber);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              leading: Icon(
                                acc.isOverdue ? Icons.error_outline : Icons.receipt_long,
                                color: acc.isOverdue ? Colors.red : Colors.blue,
                              ),
                              title: Text(
                                acc.invoiceNumber,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${_df.format(acc.invoiceDate)} · ${_statusLabel(acc.status)}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _rowKV('Total factura', _money.format(acc.totalAmount)),
                                      _rowKV('Pagado', _money.format(acc.paidAmount)),
                                      _rowKV('Pendiente', _money.format(acc.pendingAmount)),
                                      _rowKV('Vence', _formatDateOnly(acc.dueDate)),
                                      if (acc.notes != null && acc.notes!.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Notas: ${acc.notes}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade800),
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
                                                fontSize: 13, fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...payments.map((p) => ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(_money.format(p.amount)),
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
                                        const SizedBox(height: 4),
                                        FutureBuilder<Sale?>(
                                          future: _getSaleFutureById(saleId),
                                          builder: (context, saleSnap) {
                                            if (saleSnap.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 8),
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                            final sale = saleSnap.data;
                                            if (sale == null) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Text(
                                                  'No se encontró la venta en el historial para enlazar ítems.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              );
                                            }
                                            return SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                headingRowHeight: 36,
                                                dataRowMinHeight: 32,
                                                dataRowMaxHeight: 48,
                                                columns: const [
                                                  DataColumn(label: Text('Producto')),
                                                  DataColumn(label: Text('Cant.')),
                                                  DataColumn(label: Text('P. unit')),
                                                  DataColumn(label: Text('Total')),
                                                ],
                                                rows: sale.items.map((it) {
                                                  final line = it.price * it.quantity;
                                                  return DataRow(cells: [
                                                    DataCell(Text(it.name)),
                                                    DataCell(Text('${it.quantity} ${it.unit}')),
                                                    DataCell(Text(_money.format(it.price))),
                                                    DataCell(Text(_money.format(line))),
                                                  ]);
                                                }).toList(),
                                              ),
                                            );
                                          },
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
    );
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
    showDialog<void>(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              content: SizedBox(
                width: 320,
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
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
                        _chipInfo('Total facturado', _money.format(summary.totalInvoiced)),
                        _chipInfo('Total pagado', _money.format(summary.totalPaid)),
                        _chipInfo('Pendiente', _money.format(summary.totalPending)),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: Scrollbar(
                      child: ListView.builder(
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
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(_df.format(acc.invoiceDate)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _rowKV('Total', _money.format(acc.totalAmount)),
                                      _rowKV('Pagado', _money.format(acc.paidAmount)),
                                      _rowKV('Pendiente', _money.format(acc.pendingAmount)),
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
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        )
                                      else
                                        ...payments.map((p) => ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(_money.format(p.amount)),
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
    );
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddAccountDialog() {
    Get.snackbar('Info', 'Funcionalidad en desarrollo');
  }
}
