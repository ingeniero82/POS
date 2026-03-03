// Pantalla para gestión de cuentas por cobrar y pagar

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/accounts_receivable.dart';
import '../models/accounts_payable.dart';
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

  List<AccountsReceivable> _receivableAccounts = [];
  List<AccountsPayable> _payableAccounts = [];
  Map<String, dynamic> _receivableSummary = {};
  Map<String, dynamic> _payableSummary = {};
  bool _isLoading = true;

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
        AccountsReceivablePayableService.getAllAccountsReceivable(),
        AccountsReceivablePayableService.getReceivableSummary(),
      ]);

      final payableData = await Future.wait([
        AccountsReceivablePayableService.getAllAccountsPayable(),
        AccountsReceivablePayableService.getPayableSummary(),
      ]);

      setState(() {
        _receivableAccounts = receivableData[0] as List<AccountsReceivable>;
        _receivableSummary = receivableData[1] as Map<String, dynamic>;
        _payableAccounts = payableData[0] as List<AccountsPayable>;
        _payableSummary = payableData[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'No se pudieron cargar los datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar y Pagar'),
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
        // Resumen de cuentas por cobrar
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

        // Lista de cuentas por cobrar
        Expanded(
          child: _receivableAccounts.isEmpty
              ? const Center(
                  child: Text(
                    'No hay cuentas por cobrar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _receivableAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _receivableAccounts[index];
                    return _buildReceivableCard(account);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayableTab() {
    return Column(
      children: [
        // Resumen de cuentas por pagar
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

        // Lista de cuentas por pagar
        Expanded(
          child: _payableAccounts.isEmpty
              ? const Center(
                  child: Text(
                    'No hay cuentas por pagar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _payableAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _payableAccounts[index];
                    return _buildPayableCard(account);
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

  Widget _buildReceivableCard(AccountsReceivable account) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: account.isOverdue ? Colors.red : Colors.blue,
          child: Icon(
            account.isOverdue ? Icons.warning : Icons.account_balance_wallet,
            color: Colors.white,
          ),
        ),
        title: Text(account.customerName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Factura: ${account.invoiceNumber}'),
            Text('Vence: ${_formatDate(account.dueDate)}'),
            if (account.isOverdue)
              Text(
                'Vencida hace ${account.daysOverdue} días',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${account.pendingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${account.paymentPercentage.toStringAsFixed(0)}% pagado',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: () => _showReceivableDetails(account),
      ),
    );
  }

  Widget _buildPayableCard(AccountsPayable account) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: account.isOverdue ? Colors.red : Colors.orange,
          child: Icon(
            account.isOverdue ? Icons.warning : Icons.payment,
            color: Colors.white,
          ),
        ),
        title: Text(account.supplierName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Factura: ${account.invoiceNumber}'),
            Text('Vence: ${_formatDate(account.dueDate)}'),
            if (account.isOverdue)
              Text(
                'Vencida hace ${account.daysOverdue} días',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${account.pendingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${account.paymentPercentage.toStringAsFixed(0)}% pagado',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: () => _showPayableDetails(account),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddAccountDialog() {
    // Implementar diálogo para agregar nueva cuenta
    Get.snackbar('Info', 'Funcionalidad en desarrollo');
  }

  void _showReceivableDetails(AccountsReceivable account) {
    // Implementar detalles de cuenta por cobrar
    Get.snackbar('Info', 'Detalles de ${account.customerName}');
  }

  void _showPayableDetails(AccountsPayable account) {
    // Implementar detalles de cuenta por pagar
    Get.snackbar('Info', 'Detalles de ${account.supplierName}');
  }
}
