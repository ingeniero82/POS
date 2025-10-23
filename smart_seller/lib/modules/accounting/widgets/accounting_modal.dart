// Modal contable integral para gestión de ingresos y egresos
// Reemplaza el modal de proveedores con funcionalidad contable completa

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/accounting_entry.dart';
import '../models/cash_session.dart';
import '../models/payment_method.dart';
import '../models/transaction_category.dart';
import '../services/accounting_service.dart';
import '../../../services/auth_service.dart';
import 'electronic_invoice_payment_modal.dart';

class AccountingModal extends StatefulWidget {
  final Function(AccountingEntry)? onTransactionProcessed;
  
  const AccountingModal({super.key, this.onTransactionProcessed});

  @override
  State<AccountingModal> createState() => _AccountingModalState();
}

class _AccountingModalState extends State<AccountingModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controladores para el formulario
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _documentNumberController = TextEditingController();
  
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
      _expenseCategories = await AccountingService.getCategoriesByType('expense');
      
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
      Get.snackbar('Caja cerrada', 'Debes abrir la caja antes de registrar ingresos o egresos');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Ingresa el monto de la transacción');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
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
        documentNumber: _showInvoiceOptions ? _documentNumberController.text.trim() : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await AccountingService.createAccountingEntry(entry);

      // Llamar callback si existe
      if (widget.onTransactionProcessed != null) {
        widget.onTransactionProcessed!(entry);
      }

      String successMessage = '${_selectedTransactionType == 'income' ? 'Ingreso' : 'Egreso'} registrado correctamente';
      if (_showInvoiceOptions) {
        successMessage += '\nDocumento: ${_documentNumberController.text.trim()}';
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

  Future<void> _openCashSessionDialog() async {
    final TextEditingController initialAmountController = TextEditingController(text: '0');
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Abrir caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa el monto inicial de la caja'),
            const SizedBox(height: 12),
            TextField(
              controller: initialAmountController,
              decoration: const InputDecoration(
                labelText: 'Monto inicial',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Abrir'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      final amount = double.tryParse(initialAmountController.text.trim()) ?? 0.0;
      final user = AuthService.to.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'Usuario no autenticado');
        return;
      }
      try {
        await AccountingService.openCashSession(amount, user.id!);
        _currentSession = await AccountingService.getOpenCashSession();
        setState(() {});
        Get.snackbar('Éxito', 'Caja abierta con \$${amount.toStringAsFixed(2)}');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo abrir la caja: $e');
      }
    }
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
  Widget _buildQuickExpenseButton(String label, IconData icon, Color color, VoidCallback onTap) {
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
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
              final amount = double.tryParse(amountController.text.trim());
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
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                  documentNumber: documentController.text.trim().isEmpty ? null : documentController.text.trim(),
                );
                
                Get.back();
                Get.snackbar('Éxito', 'Pago a proveedor registrado: \$${amount.toStringAsFixed(2)}');
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
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
              final amount = double.tryParse(amountController.text.trim());
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
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                );
                
                Get.back();
                Get.snackbar('Éxito', 'Gasto operativo registrado: \$${amount.toStringAsFixed(2)}');
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
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
              final amount = double.tryParse(amountController.text.trim());
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
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                );
                
                Get.back();
                Get.snackbar('Éxito', 'Servicio público registrado: \$${amount.toStringAsFixed(2)}');
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
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
              final amount = double.tryParse(amountController.text.trim());
              final description = descriptionController.text.trim();
              
              if (amount == null || amount <= 0) {
                Get.snackbar('Error', 'Ingrese un monto válido');
                return;
              }
              
              if (description.isEmpty) {
                Get.snackbar('Error', 'Ingrese la descripción del mantenimiento');
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
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                );
                
                Get.back();
                Get.snackbar('Éxito', 'Mantenimiento registrado: \$${amount.toStringAsFixed(2)}');
              } catch (e) {
                Get.snackbar('Error', 'No se pudo registrar el mantenimiento: $e');
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
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
              final amount = double.tryParse(amountController.text.trim());
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
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                  documentNumber: documentController.text.trim().isEmpty ? null : documentController.text.trim(),
                );
                
                Get.back();
                Get.snackbar('Éxito', 'Devolución a proveedor registrada: \$${amount.toStringAsFixed(2)}');
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
                    Icon(Icons.account_balance_wallet, color: Colors.green.shade700),
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
                        : Icon(_selectedTransactionType == 'income' ? Icons.add : Icons.remove),
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

  Widget _buildTransactionForm(String type, List<TransactionCategory> categories) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Monto
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Monto *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
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
            value: _selectedCategory != null && categories.any((cat) => cat.code == _selectedCategory) 
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
            value: _selectedPaymentMethod != null && _paymentMethods.any((method) => method.code == _selectedPaymentMethod) 
                ? _selectedPaymentMethod 
                : (_paymentMethods.isNotEmpty ? _paymentMethods.first.code : null),
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
                _selectedPaymentMethod = value ?? (_paymentMethods.isNotEmpty ? _paymentMethods.first.code : 'CASH');
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
                        activeColor: Colors.blue,
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
