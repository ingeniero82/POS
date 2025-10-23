import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../services/supplier_service.dart';
import 'package:intl/intl.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> with SingleTickerProviderStateMixin {
  List<Supplier> _suppliers = [];
  List<SupplierPayment> _payments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  late TabController _tabController;

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
      final suppliers = await SupplierService.getAllSuppliers();
      final payments = await SupplierService.getAllSupplierPayments();
      setState(() {
        _suppliers = suppliers;
        _payments = payments;
      });
    } catch (e) {
      Get.snackbar('Error', 'No se pudieron cargar los datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Supplier> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((supplier) =>
      supplier.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (supplier.document?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  Future<void> _showCreateSupplierDialog() async {
    final nameController = TextEditingController();
    final documentController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Nuevo Proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: documentController,
                decoration: const InputDecoration(
                  labelText: 'Documento',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
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
              if (nameController.text.trim().isEmpty) {
                Get.snackbar('Error', 'El nombre es obligatorio');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final newSupplier = Supplier(
          name: nameController.text.trim(),
          document: documentController.text.trim().isEmpty ? null : documentController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await SupplierService.createSupplier(newSupplier);
        await _loadData();
        Get.snackbar('Éxito', 'Proveedor creado correctamente');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo crear el proveedor: $e');
      }
    }

    nameController.dispose();
    documentController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }

  Future<void> _showEditSupplierDialog(Supplier supplier) async {
    final nameController = TextEditingController(text: supplier.name);
    final documentController = TextEditingController(text: supplier.document ?? '');
    final phoneController = TextEditingController(text: supplier.phone ?? '');
    final emailController = TextEditingController(text: supplier.email ?? '');
    final addressController = TextEditingController(text: supplier.address ?? '');

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Editar Proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: documentController,
                decoration: const InputDecoration(
                  labelText: 'Documento',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
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
              if (nameController.text.trim().isEmpty) {
                Get.snackbar('Error', 'El nombre es obligatorio');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final updatedSupplier = supplier.copyWith(
          name: nameController.text.trim(),
          document: documentController.text.trim().isEmpty ? null : documentController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          updatedAt: DateTime.now(),
        );

        await SupplierService.updateSupplier(updatedSupplier);
        await _loadData();
        Get.snackbar('Éxito', 'Proveedor actualizado correctamente');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo actualizar el proveedor: $e');
      }
    }

    nameController.dispose();
    documentController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Eliminar Proveedor'),
        content: Text('¿Estás seguro de que quieres eliminar a ${supplier.name}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await SupplierService.deleteSupplier(supplier.id!);
        await _loadData();
        Get.snackbar('Éxito', 'Proveedor eliminado correctamente');
      } catch (e) {
        Get.snackbar('Error', 'No se pudo eliminar el proveedor: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Proveedores'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Proveedores'),
            Tab(icon: Icon(Icons.payment), text: 'Pagos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña de Proveedores
          Column(
            children: [
              // Barra de búsqueda y botón nuevo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Buscar proveedores',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showCreateSupplierDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
              ),
              
              // Lista de proveedores
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSuppliers.isEmpty
                        ? const Center(
                            child: Text('No hay proveedores disponibles'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredSuppliers.length,
                            itemBuilder: (context, index) {
                              final supplier = _filteredSuppliers[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(supplier.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (supplier.document != null)
                                        Text('Doc: ${supplier.document}'),
                                      if (supplier.phone != null)
                                        Text('Tel: ${supplier.phone}'),
                                      if (supplier.email != null)
                                        Text('Email: ${supplier.email}'),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _showEditSupplierDialog(supplier);
                                          break;
                                        case 'delete':
                                          _deleteSupplier(supplier);
                                          break;
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          
          // Pestaña de Pagos
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
                  ? const Center(
                      child: Text('No hay pagos registrados'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        final supplier = _suppliers.firstWhere(
                          (s) => s.id == payment.supplierId,
                          orElse: () => Supplier(
                            name: 'Proveedor eliminado',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(
                                Icons.payment,
                                color: Colors.green.shade800,
                              ),
                            ),
                            title: Text(supplier.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Monto: \$${payment.amount.toStringAsFixed(2)}'),
                                Text('Método: ${payment.paymentMethod}'),
                                Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.paymentDate)}'),
                                if (payment.description != null)
                                  Text('Descripción: ${payment.description}'),
                                // ✅ NUEVO: Mostrar información de facturación si existe
                                if (payment.description?.contains('Factura:') == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.receipt_long, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Con Factura',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              DateFormat('dd/MM').format(payment.paymentDate),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
