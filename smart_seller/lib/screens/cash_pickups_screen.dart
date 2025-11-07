// Pantalla para gestionar recogidas de efectivo (retiros parciales)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/cash_pickup.dart';
import '../models/user.dart';
import '../services/sqlite_database_service.dart';
import '../services/auth_service.dart';
import '../modules/accounting/services/accounting_service.dart';

class CashPickupsScreen extends StatefulWidget {
  const CashPickupsScreen({super.key});

  @override
  State<CashPickupsScreen> createState() => _CashPickupsScreenState();
}

class _CashPickupsScreenState extends State<CashPickupsScreen> {
  List<CashPickup> _pickups = [];
  List<User> _users = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pickups = await SQLiteDatabaseService.getCashPickups(
        startDate: _startDate,
        endDate: _endDate,
      );
      final users = await SQLiteDatabaseService.getAllUsers();

      setState(() {
        _pickups = pickups;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'No se pudieron cargar las recogidas: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _getUserName(int? userId) {
    if (userId == null) return 'N/A';
    final user = _users.firstWhereOrNull((u) => u.id == userId);
    return user?.fullName ?? 'Usuario desconocido';
  }

  Future<void> _showAddPickupDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedReason = 'Retiro parcial';

    await Get.dialog(
      Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nueva Recogida de Efectivo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto a Retirar *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                    hintText: 'Ej: 50000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Razón del Retiro *',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedReason,
                  items: const [
                    DropdownMenuItem(value: 'Retiro parcial', child: Text('Retiro Parcial')),
                    DropdownMenuItem(value: 'Pago a proveedor', child: Text('Pago a Proveedor')),
                    DropdownMenuItem(value: 'Gasto operativo', child: Text('Gasto Operativo')),
                    DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedReason = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (Opcional)',
                    border: OutlineInputBorder(),
                    hintText: 'Observaciones adicionales',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isEmpty) {
                          Get.snackbar(
                            'Error',
                            'El monto es obligatorio',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          Get.snackbar(
                            'Error',
                            'El monto debe ser un número válido mayor a 0',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        try {
                          final currentUser = AuthService.to.currentUser;
                          if (currentUser == null || currentUser.id == null) {
                            Get.snackbar(
                              'Error',
                              'Usuario no autenticado',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                            return;
                          }

                          // Obtener sesión de caja abierta
                          final cashSession = await AccountingService.getOpenCashSession();
                          if (cashSession == null) {
                            Get.snackbar(
                              'Error',
                              'No hay sesión de caja abierta. Debe abrir una sesión primero.',
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 4),
                            );
                            return;
                          }

                          final pickup = CashPickup(
                            date: DateTime.now(),
                            amount: amount,
                            reason: selectedReason,
                            userId: currentUser.id!,
                            cashSessionId: cashSession.id,
                            notes: notesController.text.trim().isEmpty 
                                ? null 
                                : notesController.text.trim(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          await SQLiteDatabaseService.saveCashPickup(pickup);

                          // Registrar como egreso contable
                          await AccountingService.recordExpense(
                            amount,
                            'Recogida de efectivo: ${selectedReason}',
                            currentUser.id!,
                            category: 'Recogidas de Efectivo',
                            paymentMethod: 'Efectivo',
                            reference: 'pickup_${pickup.id ?? 'temp'}',
                          );

                          Get.back();
                          Get.snackbar(
                            '✅ Recogida Registrada',
                            'La recogida de \$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(amount)} ha sido registrada',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );

                          _loadData();
                        } catch (e) {
                          Get.snackbar(
                            'Error',
                            'No se pudo registrar la recogida: $e',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: const Text('Registrar Recogida'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(CashPickup pickup) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Está seguro de eliminar la recogida de \$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(pickup.amount)}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await SQLiteDatabaseService.deleteCashPickup(pickup.id!);
        if (success) {
          Get.snackbar(
            '✅ Eliminado',
            'La recogida ha sido eliminada',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          _loadData();
        } else {
          Get.snackbar(
            'Error',
            'No se pudo eliminar la recogida',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Error al eliminar: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  double _getTotalPickups() {
    return _pickups.fold(0.0, (sum, pickup) => sum + pickup.amount);
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat copFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recogidas de Efectivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              final dates = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                initialDateRange: _startDate != null && _endDate != null
                    ? DateTimeRange(start: _startDate!, end: _endDate!)
                    : null,
              );

              if (dates != null) {
                setState(() {
                  _startDate = dates.start;
                  _endDate = dates.end;
                });
                _loadData();
              }
            },
            tooltip: 'Filtrar por fecha',
          ),
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _loadData();
              },
              tooltip: 'Limpiar filtros',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Resumen
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryCard(
                        title: 'Total Recogidas',
                        value: copFormat.format(_getTotalPickups()),
                        icon: Icons.money_off,
                        color: Colors.orange,
                      ),
                      _SummaryCard(
                        title: 'Cantidad',
                        value: '${_pickups.length}',
                        icon: Icons.list,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
                // Lista
                Expanded(
                  child: _pickups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay recogidas registradas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_startDate != null || _endDate != null)
                                const SizedBox(height: 8),
                              if (_startDate != null || _endDate != null)
                                Text(
                                  'Intenta ajustar el rango de fechas',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pickups.length,
                          itemBuilder: (context, index) {
                            final pickup = _pickups[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Icon(
                                    Icons.money_off,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                title: Text(
                                  copFormat.format(pickup.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Razón: ${pickup.reason}'),
                                    Text(
                                      'Por: ${_getUserName(pickup.userId)}',
                                    ),
                                    Text(
                                      'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(pickup.date)}',
                                    ),
                                    if (pickup.notes != null && pickup.notes!.isNotEmpty)
                                      Text(
                                        'Notas: ${pickup.notes}',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(pickup),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPickupDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Recogida'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

