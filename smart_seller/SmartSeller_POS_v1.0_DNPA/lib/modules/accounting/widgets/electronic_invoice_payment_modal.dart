// Widget para gestionar pagos de facturas electrónicas pendientes

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/sqlite_database_service.dart';
import '../services/electronic_invoicing_integration_service.dart';
import '../services/accounting_service.dart';

class ElectronicInvoicePaymentModal extends StatefulWidget {
  const ElectronicInvoicePaymentModal({super.key});

  @override
  State<ElectronicInvoicePaymentModal> createState() => _ElectronicInvoicePaymentModalState();
}

class _ElectronicInvoicePaymentModalState extends State<ElectronicInvoicePaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedPaymentMethod = 'CASH';
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _pendingInvoices = [];
  Map<String, dynamic>? _selectedInvoice;

  @override
  void initState() {
    super.initState();
    _loadPendingInvoices();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingInvoices() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return;

      final results = await db.rawQuery('''
        SELECT 
          id,
          customer_name,
          invoice_number,
          total_amount,
          paid_amount,
          pending_amount,
          invoice_date,
          due_date,
          status
        FROM accounts_receivable 
        WHERE status IN ('pending', 'partial')
        ORDER BY invoice_date DESC
      ''');

      setState(() {
        _pendingInvoices = results;
      });
    } catch (e) {
      print('❌ Error cargando facturas pendientes: $e');
    }
  }

  void _selectInvoice(Map<String, dynamic> invoice) {
    setState(() {
      _selectedInvoice = invoice;
      _invoiceNumberController.text = invoice['invoice_number'] as String;
      _amountController.text = (invoice['pending_amount'] as double).toStringAsFixed(2);
    });
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final invoiceNumber = _invoiceNumberController.text.trim();
      
      // Obtener usuario actual (simulado)
      final currentUser = {'id': 1}; // En un caso real, obtener del AuthService
      
      // Obtener sesión de caja activa
      final openSession = await AccountingService.getOpenCashSession();
      
      final success = await ElectronicInvoicingIntegrationService.recordPaymentAgainstInvoice(
        invoiceNumber: invoiceNumber,
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
        userId: currentUser['id'] as int,
        cashSessionId: openSession?.id,
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (success) {
        Get.snackbar(
          'Pago Registrado',
          'El pago se registró exitosamente en el sistema contable',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
        
        // Limpiar formulario y recargar datos
        _clearForm();
        await _loadPendingInvoices();
      } else {
        Get.snackbar(
          'Error',
          'No se pudo registrar el pago. Verifique los datos e intente nuevamente.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          icon: const Icon(Icons.error, color: Colors.white),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error procesando el pago: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _invoiceNumberController.clear();
    _amountController.clear();
    _referenceController.clear();
    _notesController.clear();
    _selectedPaymentMethod = 'CASH';
    _selectedInvoice = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.payment, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Pagos de Facturas Electrónicas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: Row(
                children: [
                  // Lista de facturas pendientes
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Facturas Pendientes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _pendingInvoices.isEmpty
                                ? const Center(
                                    child: Text('No hay facturas pendientes'),
                                  )
                                : ListView.builder(
                                    itemCount: _pendingInvoices.length,
                                    itemBuilder: (context, index) {
                                      final invoice = _pendingInvoices[index];
                                      final isSelected = _selectedInvoice?['id'] == invoice['id'];
                                      
                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.blue.shade50 : Colors.white,
                                          border: Border.all(
                                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            invoice['invoice_number'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.blue : Colors.black,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Cliente: ${invoice['customer_name']}'),
                                              Text('Pendiente: \$${(invoice['pending_amount'] as double).toStringAsFixed(2)}'),
                                            ],
                                          ),
                                          trailing: Text(
                                            '${invoice['status']}',
                                            style: TextStyle(
                                              color: invoice['status'] == 'pending' ? Colors.red : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onTap: () => _selectInvoice(invoice),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Formulario de pago
                  Expanded(
                    flex: 1,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Pago',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Número de factura
                          TextFormField(
                            controller: _invoiceNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Número de Factura',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingrese el número de factura';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Monto
                          TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Monto del Pago',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingrese el monto del pago';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Ingrese un monto válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Método de pago
                          DropdownButtonFormField<String>(
                            value: _selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Método de Pago',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payment),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'CASH', child: Text('Efectivo')),
                              DropdownMenuItem(value: 'CARD', child: Text('Tarjeta')),
                              DropdownMenuItem(value: 'TRANSFER', child: Text('Transferencia')),
                              DropdownMenuItem(value: 'CHECK', child: Text('Cheque')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPaymentMethod = value ?? 'CASH';
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Referencia
                          TextFormField(
                            controller: _referenceController,
                            decoration: const InputDecoration(
                              labelText: 'Referencia (Opcional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Notas
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notas (Opcional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),
                          
                          // Botones
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _clearForm,
                                  child: const Text('Limpiar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _processPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text('Registrar Pago'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
