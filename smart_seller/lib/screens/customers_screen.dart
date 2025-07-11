import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/customer.dart';
import '../services/sqlite_database_service.dart';
import 'package:intl/intl.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> customers = [];
  bool isLoading = true;
  String searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }
  
  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);
    try {
      final loadedCustomers = await SQLiteDatabaseService.getAllCustomers();
      setState(() {
        customers = loadedCustomers;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      Get.snackbar('Error', 'Error cargando clientes: $e');
    }
  }
  
  List<Customer> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    return customers.where((customer) =>
      customer.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      customer.email.toLowerCase().contains(searchQuery.toLowerCase()) ||
      customer.phone.contains(searchQuery)
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar clientes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(() => searchQuery = ''),
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          
          // Lista de clientes
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return _buildCustomerCard(customer);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Cliente'),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? 'No hay clientes registrados' : 'No se encontraron clientes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isEmpty 
                ? 'Agrega tu primer cliente usando el botón +'
                : 'Intenta con otros términos de búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getMembershipColor(customer.membershipLevel ?? 'bronze'),
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(child: Text(customer.email)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(customer.phone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${customer.points} puntos'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMembershipColor(customer.membershipLevel ?? 'bronze'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    customer.membershipLevel ?? 'bronze',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
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
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('Ver detalles'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showCustomerDialog(customer: customer);
                break;
              case 'view':
                _showCustomerDetails(customer);
                break;
              case 'delete':
                _showDeleteConfirmation(customer);
                break;
            }
          },
        ),
      ),
    );
  }
  
  Color _getMembershipColor(String level) {
    switch (level.toLowerCase()) {
      case 'platinum':
        return Colors.purple;
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
  
  void _showCustomerDialog({Customer? customer}) {
    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(text: customer?.address ?? '');
    final documentController = TextEditingController(text: customer?.documentNumber ?? '');
    
    Get.dialog(
      AlertDialog(
        title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección (opcional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: documentController,
                decoration: const InputDecoration(
                  labelText: 'Documento (opcional)',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  phoneController.text.isEmpty) {
                Get.snackbar('Error', 'Los campos nombre, email y teléfono son obligatorios');
                return;
              }
              
              try {
                if (isEditing) {
                  await SQLiteDatabaseService.updateCustomer(
                    customer!.copyWith(
                      name: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                      address: addressController.text.isEmpty ? null : addressController.text,
                      documentNumber: documentController.text.isEmpty ? null : documentController.text,
                      updatedAt: DateTime.now(),
                    ),
                  );
                } else {
                  await SQLiteDatabaseService.createCustomer(
                    Customer(
                      name: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                      address: addressController.text.isEmpty ? null : addressController.text,
                      documentNumber: documentController.text.isEmpty ? null : documentController.text,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                }
                
                Get.back();
                _loadCustomers();
                Get.snackbar(
                  'Éxito',
                  isEditing ? 'Cliente actualizado' : 'Cliente creado',
                );
              } catch (e) {
                Get.snackbar('Error', 'Error guardando cliente: $e');
              }
            },
            child: Text(isEditing ? 'Actualizar' : 'Crear'),
          ),
        ],
      ),
    );
  }
  
  void _showCustomerDetails(Customer customer) {
    Get.dialog(
      AlertDialog(
        title: Text('Detalles de ${customer.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nombre', customer.name),
              _buildDetailRow('Email', customer.email),
              _buildDetailRow('Teléfono', customer.phone),
              if (customer.address != null)
                _buildDetailRow('Dirección', customer.address!),
              if (customer.documentNumber != null)
                _buildDetailRow('Documento', customer.documentNumber!),
              _buildDetailRow('Puntos', '${customer.points}'),
              _buildDetailRow('Nivel', customer.membershipLevel ?? 'bronze'),
              _buildDetailRow('Total compras', '\$${NumberFormat('#,###').format(customer.totalPurchases)}'),
              if (customer.lastPurchase != null)
                _buildDetailRow('Última compra', DateFormat('dd/MM/yyyy').format(customer.lastPurchase!)),
              _buildDetailRow('Fecha registro', DateFormat('dd/MM/yyyy').format(customer.createdAt)),
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
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation(Customer customer) {
    Get.dialog(
      AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de que quieres eliminar a ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SQLiteDatabaseService.deleteCustomer(customer.id!);
                Get.back();
                _loadCustomers();
                Get.snackbar('Éxito', 'Cliente eliminado');
              } catch (e) {
                Get.snackbar('Error', 'Error eliminando cliente: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
} 