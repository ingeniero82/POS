import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../services/supplier_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class SupplierModal extends StatefulWidget {
  final Function(Supplier, double, String)? onPaymentProcessed;

  const SupplierModal({
    super.key,
    this.onPaymentProcessed,
  });

  @override
  State<SupplierModal> createState() => _SupplierModalState();
}

class _SupplierModalState extends State<SupplierModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  Supplier? _selectedSupplier;
  bool _isLoading = false;
  bool _isProcessingPayment = false;
  bool _showInvoiceOptions = false;
  String _selectedPaymentMethod = 'efectivo';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await SupplierService.getAllSuppliers();
      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
      });
    } catch (e) {
      Get.snackbar('Error', 'No se pudieron cargar los proveedores: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSuppliers = _suppliers
          .where((supplier) =>
              supplier.name.toLowerCase().contains(query) ||
              (supplier.document?.toLowerCase().contains(query) ?? false))
          .toList();
    });
  }

  Future<void> _createNewSupplier() async {
    final nameController = TextEditingController();
    final documentController = TextEditingController();
    final documentTypeController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final departmentController = TextEditingController();
    final postalCodeController = TextEditingController();
    final countryController = TextEditingController(text: 'Colombia');
    final taxRegimeController = TextEditingController();
    final economicActivityController = TextEditingController();
    final contactPersonController = TextEditingController();
    final contactPhoneController = TextEditingController();
    final contactEmailController = TextEditingController();

    final result = await Get.dialog<bool>(
      Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nuevo Proveedor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Get.back(result: false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Información Básica
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información Básica',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre/Razón Social *',
                                        border: OutlineInputBorder(),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: 'NIT',
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo Doc *',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'NIT', child: Text('NIT')),
                                        DropdownMenuItem(
                                            value: 'CC', child: Text('CC')),
                                        DropdownMenuItem(
                                            value: 'CE', child: Text('CE')),
                                        DropdownMenuItem(
                                            value: 'TI', child: Text('TI')),
                                        DropdownMenuItem(
                                            value: 'PP', child: Text('PP')),
                                      ],
                                      onChanged: (value) {
                                        documentTypeController.text =
                                            value ?? 'NIT';
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: documentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Número Documento',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: phoneController,
                                      decoration: const InputDecoration(
                                        labelText: 'Teléfono',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Información de Ubicación
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información de Ubicación',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Dirección',
                                  border: OutlineInputBorder(),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: cityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Ciudad',
                                        border: OutlineInputBorder(),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: departmentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Departamento',
                                        border: OutlineInputBorder(),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: postalCodeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Código Postal',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: countryController,
                                      decoration: const InputDecoration(
                                        labelText: 'País',
                                        border: OutlineInputBorder(),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Información Tributaria
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información Tributaria',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Régimen Tributario',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'Responsable de IVA',
                                            child: Text('Responsable de IVA')),
                                        DropdownMenuItem(
                                            value: 'No Responsable de IVA',
                                            child:
                                                Text('No Responsable de IVA')),
                                        DropdownMenuItem(
                                            value: 'Simplificado',
                                            child: Text('Simplificado')),
                                        DropdownMenuItem(
                                            value: 'Común',
                                            child: Text('Común')),
                                      ],
                                      onChanged: (value) {
                                        taxRegimeController.text = value ?? '';
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: economicActivityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Actividad Económica',
                                        border: OutlineInputBorder(),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.words,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Información de Contacto
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.contact_phone,
                                      color: Colors.purple.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información de Contacto',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: contactPersonController,
                                decoration: const InputDecoration(
                                  labelText: 'Persona de Contacto',
                                  border: OutlineInputBorder(),
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: contactPhoneController,
                                      decoration: const InputDecoration(
                                        labelText: 'Teléfono de Contacto',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: contactEmailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email de Contacto',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
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
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          Get.snackbar('Error', 'El nombre es obligatorio');
                          return;
                        }
                        Get.back(result: true);
                      },
                      child: const Text('Crear Proveedor'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      try {
        final newSupplier = Supplier(
          name: nameController.text.trim(),
          document: documentController.text.trim().isEmpty
              ? null
              : documentController.text.trim(),
          documentType: documentTypeController.text.trim().isEmpty
              ? null
              : documentTypeController.text.trim(),
          phone: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          address: addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
          city: cityController.text.trim().isEmpty
              ? null
              : cityController.text.trim(),
          department: departmentController.text.trim().isEmpty
              ? null
              : departmentController.text.trim(),
          postalCode: postalCodeController.text.trim().isEmpty
              ? null
              : postalCodeController.text.trim(),
          country: countryController.text.trim().isEmpty
              ? 'Colombia'
              : countryController.text.trim(),
          taxRegime: taxRegimeController.text.trim().isEmpty
              ? null
              : taxRegimeController.text.trim(),
          economicActivity: economicActivityController.text.trim().isEmpty
              ? null
              : economicActivityController.text.trim(),
          contactPerson: contactPersonController.text.trim().isEmpty
              ? null
              : contactPersonController.text.trim(),
          contactPhone: contactPhoneController.text.trim().isEmpty
              ? null
              : contactPhoneController.text.trim(),
          contactEmail: contactEmailController.text.trim().isEmpty
              ? null
              : contactEmailController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final supplierId = await SupplierService.createSupplier(newSupplier);
        final createdSupplier = newSupplier.copyWith(id: supplierId);

        setState(() {
          _suppliers.add(createdSupplier);
          _filteredSuppliers = _suppliers;
          _selectedSupplier = createdSupplier;
        });

        Get.snackbar('Éxito', 'Proveedor creado correctamente');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo crear el proveedor: $e');
      }
    }

    // Limpiar controladores
    nameController.dispose();
    documentController.dispose();
    documentTypeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    cityController.dispose();
    departmentController.dispose();
    postalCodeController.dispose();
    countryController.dispose();
    taxRegimeController.dispose();
    economicActivityController.dispose();
    contactPersonController.dispose();
    contactPhoneController.dispose();
    contactEmailController.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedSupplier == null) {
      Get.snackbar('Error', 'Selecciona un proveedor');
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      Get.snackbar('Error', 'Ingresa el monto del pago');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      Get.snackbar('Error', 'Monto inválido');
      return;
    }

    // Validar campos de facturación si está habilitada
    if (_showInvoiceOptions) {
      if (_invoiceNumberController.text.trim().isEmpty) {
        Get.snackbar('Error', 'Ingresa el número de factura');
        return;
      }
      if (_invoiceDateController.text.trim().isEmpty) {
        Get.snackbar('Error', 'Ingresa la fecha de la factura');
        return;
      }
    }

    setState(() => _isProcessingPayment = true);

    try {
      final currentUser = AuthService.to.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'Usuario no autenticado');
        return;
      }

      // Crear descripción que incluya información de factura si aplica
      String description = _descriptionController.text.trim().isEmpty
          ? 'Pago a proveedor'
          : _descriptionController.text.trim();

      if (_showInvoiceOptions) {
        description += ' | Factura: ${_invoiceNumberController.text.trim()}';
        description += ' | Fecha: ${_invoiceDateController.text.trim()}';
      }

      final payment = SupplierPayment(
        supplierId: _selectedSupplier!.id!,
        amount: amount,
        paymentDate: DateTime.now(),
        paymentMethod: _selectedPaymentMethod,
        description: description,
        userId: currentUser.id!,
        createdAt: DateTime.now(),
      );

      await SupplierService.createSupplierPayment(payment);

      // Llamar callback si existe
      if (widget.onPaymentProcessed != null) {
        widget.onPaymentProcessed!(
            _selectedSupplier!, amount, _selectedPaymentMethod);
      }

      String successMessage = 'Pago procesado correctamente';
      if (_showInvoiceOptions) {
        successMessage +=
            '\nFactura registrada: ${_invoiceNumberController.text.trim()}';
      }

      Get.snackbar('Éxito', successMessage);

      // Limpiar formulario
      _amountController.clear();
      _descriptionController.clear();
      _invoiceNumberController.clear();
      _invoiceDateController.clear();
      _selectedSupplier = null;
      _showInvoiceOptions = false;
    } catch (e) {
      Get.snackbar('Error', 'No se pudo procesar el pago: $e');
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión de Proveedores',
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

            // Búsqueda y botón nuevo
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar proveedor',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _createNewSupplier,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista de proveedores
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSuppliers.isEmpty
                      ? const Center(
                          child: Text('No hay proveedores disponibles'),
                        )
                      : ListView.builder(
                          itemCount: _filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = _filteredSuppliers[index];
                            final isSelected =
                                _selectedSupplier?.id == supplier.id;

                            return Card(
                              color: isSelected ? Colors.blue.shade50 : null,
                              child: ListTile(
                                title: Text(supplier.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (supplier.document != null)
                                      Text('Doc: ${supplier.document}'),
                                    if (supplier.phone != null)
                                      Text('Tel: ${supplier.phone}'),
                                    const SizedBox(height: 4),
                                    // ✅ NUEVO: Indicador de completitud para facturación electrónica
                                    Builder(
                                      builder: (context) {
                                        final validation = SupplierService
                                            .validateSupplierForElectronicInvoicing(
                                                supplier);
                                        final isComplete =
                                            validation['isComplete'] as bool;
                                        final completionPercentage =
                                            validation['completionPercentage']
                                                as int;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isComplete
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isComplete
                                                    ? Icons.check_circle
                                                    : Icons.warning,
                                                size: 12,
                                                color: isComplete
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isComplete
                                                    ? 'FE Completo'
                                                    : '$completionPercentage%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isComplete
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.blue)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedSupplier = supplier;
                                  });
                                },
                              ),
                            );
                          },
                        ),
            ),

            // Formulario de pago
            if (_selectedSupplier != null) ...[
              const Divider(),
              const Text(
                'Registrar Pago',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Método de Pago',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(
                            value: 'transferencia',
                            child: Text('Transferencia')),
                        DropdownMenuItem(
                            value: 'cheque', child: Text('Cheque')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // ✅ NUEVO: Opciones de facturación electrónica
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
                            'Facturación Electrónica',
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
                                if (value) {
                                  // Establecer fecha actual por defecto
                                  _invoiceDateController.text =
                                      DateFormat('dd/MM/yyyy')
                                          .format(DateTime.now());
                                }
                              });
                            },
                            activeThumbColor: Colors.blue,
                          ),
                        ],
                      ),
                      if (_showInvoiceOptions) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _invoiceNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Número de Factura *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.receipt),
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _invoiceDateController,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha Factura *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    _invoiceDateController.text =
                                        DateFormat('dd/MM/yyyy').format(date);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info,
                                  color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se registrará el pago con información de facturación',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingPayment ? null : _processPayment,
                      icon: _isProcessingPayment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment),
                      label: Text(_isProcessingPayment
                          ? 'Procesando...'
                          : 'Procesar Pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
