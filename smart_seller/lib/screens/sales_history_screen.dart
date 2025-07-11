import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sqlite_database_service.dart';
import '../models/sale.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> sales = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  String userFilter = '';
  final TextEditingController _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSales();
  }

  Future<void> fetchSales() async {
    setState(() => isLoading = true);
    try {
      sales = await SQLiteDatabaseService.getSales(date: selectedDate, user: userFilter.isEmpty ? null : userFilter);
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudieron cargar las ventas: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'), // Español Colombia
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchSales();
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
          'Historial de Ventas',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Color(0xFF22315B)),
            onPressed: pickDate,
            tooltip: 'Seleccionar fecha',
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF22315B)),
            onPressed: () => Get.offAllNamed('/dashboard'),
            tooltip: 'Ir al Dashboard',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por usuario',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        userFilter = value.trim();
                      });
                      fetchSales();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      userFilter = _userController.text.trim();
                    });
                    fetchSales();
                  },
                  child: const Text('Buscar'),
                ),
                if (userFilter.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        userFilter = '';
                        _userController.clear();
                      });
                      fetchSales();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : sales.isEmpty
                    ? const Center(child: Text('No hay ventas registradas para esta fecha/usuario.'))
                    : ListView.builder(
                        itemCount: sales.length,
                        itemBuilder: (context, index) {
                          final sale = sales[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text('Venta #${sale.id} - ${sale.user}'),
                              subtitle: Text(
                                'Fecha: ${sale.date.toString().substring(0, 16)}\nTotal: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(sale.total)}',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('Detalle de Venta #${sale.id}'),
                                    content: SizedBox(
                                      width: 350,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Usuario: ${sale.user}'),
                                          Text('Fecha: ${sale.date.toString().substring(0, 16)}'),
                                          Text('Método de pago: ${sale.paymentMethod ?? '-'}'),
                                          const SizedBox(height: 12),
                                          const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ...sale.items.map((item) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Text(
                                                    '- ${item.name} x${item.quantity} (${item.unit})  |  ${NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(item.price)}'),
                                              )),
                                          const Divider(),
                                          Text('Total: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(sale.total)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Get.back(),
                                        child: const Text('Cerrar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 