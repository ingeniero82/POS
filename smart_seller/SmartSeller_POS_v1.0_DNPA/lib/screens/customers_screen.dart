import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/customer.dart';
import '../services/sqlite_database_service.dart';
import '../services/company_config_service.dart';
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
    final q = searchQuery.toLowerCase();
    return customers
        .where((customer) =>
            customer.name.toLowerCase().contains(q) ||
            customer.email.toLowerCase().contains(q) ||
            customer.phone.contains(searchQuery) ||
            (customer.city?.toLowerCase().contains(q) ?? false))
        .toList();
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
            tooltip: 'Recargar clientes',
          ),
          IconButton(
            onPressed: _debugRecreateTable,
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug: Estado de tabla',
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ NUEVO: Indicador de estado de la tabla
          FutureBuilder<Map<String, dynamic>>(
            future: SQLiteDatabaseService.getCustomersTableStatus(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final status = snapshot.data!;
                final hasError = !status['exists'] ||
                    !status['hasPointsRate'] ||
                    !status['hasAccumulatedPoints'];

                if (hasError) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Problema detectado con la tabla customers. Usa el botón de debug para solucionarlo.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                        TextButton(
                          onPressed: _debugRecreateTable,
                          child: const Text('SOLUCIONAR'),
                        ),
                      ],
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),

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
            searchQuery.isEmpty
                ? 'No hay clientes registrados'
                : 'No se encontraron clientes',
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
          backgroundColor: Colors.blue,
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
                Expanded(
                    child: Text(customer.email.isEmpty ? '—' : customer.email)),
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
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${customer.pointsRate == 1 ? '1 punto' : '${customer.pointsRate} puntos'} por \$1000',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.attach_money,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  'Total: \$${NumberFormat('#,###').format(customer.totalPurchases)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
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

  Future<void> _showCustomerDialog({Customer? customer}) async {
    final config = await CompanyConfigService.getCompanyConfig();
    final pointsEnabled = config.pointsEnabled;

    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController =
        TextEditingController(text: customer?.address ?? '');
    final cityController = TextEditingController(text: customer?.city ?? '');
    final documentController =
        TextEditingController(text: customer?.documentNumber ?? '');
    // Por defecto 0 para clientes nuevos (no acumula puntos); al editar se muestra su tasa actual
    final pointsController =
        TextEditingController(text: customer?.pointsRate.toString() ?? '0');

    if (!context.mounted) return;
    String selectedDocumentType = customer?.documentType ?? 'CC';
    Get.dialog(
      AlertDialog(
        title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
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
                      labelText: 'Email (opcional)',
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
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad (opcional)',
                      prefixIcon: Icon(Icons.location_city),
                      hintText: 'Ej: Santa Rosa de Cabal, Risaralda',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue:
                        ['CC', 'NIT', 'TI', 'CE'].contains(selectedDocumentType)
                            ? selectedDocumentType
                            : 'CC',
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento (opcional)',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'CC',
                          child: Text('CC - Cédula de ciudadanía')),
                      DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                      DropdownMenuItem(
                          value: 'TI',
                          child: Text('TI - Tarjeta de identidad')),
                      DropdownMenuItem(
                          value: 'CE',
                          child: Text('CE - Cédula de extranjería')),
                    ],
                    onChanged: (value) {
                      setDialogState(
                          () => selectedDocumentType = value ?? 'CC');
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: documentController,
                    decoration: const InputDecoration(
                      labelText: 'Número de documento (opcional)',
                      prefixIcon: Icon(Icons.badge),
                      hintText: 'Ej: 123456789, 900123456-2',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tasa de puntos solo si el programa está habilitado en Configuración de empresa
                  if (pointsEnabled)
                    TextField(
                      controller: pointsController,
                      decoration: const InputDecoration(
                        labelText: 'Tasa de Puntos',
                        prefixIcon: Icon(Icons.star, color: Colors.amber),
                        hintText: '0 = sin puntos. Ej: 1, 2, 0.5 por \$1000',
                        helperText:
                            '0 = no acumula puntos. 1 = 1 punto por \$1000, 2 = 2 puntos por \$1000.',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^[0-9]*\.?[0-9]*$')),
                      ],
                    ),
                  if (!pointsEnabled)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Programa de puntos desactivado. Actívalo en Configuración de empresa si quieres fidelización.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty) {
                Get.snackbar(
                    'Error', 'Los campos nombre y teléfono son obligatorios');
                return;
              }

              try {
                // Tasa de puntos: si el programa está desactivado usamos 0 (no acumula puntos)
                double pointsRate = 0.0;
                if (pointsEnabled) {
                  final pointsText = pointsController.text.trim();
                  if (pointsText.isEmpty) {
                    Get.snackbar('Error', 'La tasa de puntos es obligatoria');
                    return;
                  }
                  final parsed = double.tryParse(pointsText);
                  if (parsed == null) {
                    Get.snackbar('Error',
                        'La tasa de puntos debe ser un número válido (ej: 0, 1, 0.5, 2)');
                    return;
                  }
                  if (parsed < 0) {
                    Get.snackbar(
                        'Error', 'La tasa de puntos no puede ser negativa');
                    return;
                  }
                  pointsRate =
                      parsed; // 0 = no acumula puntos, 1 = 1 punto por \$1000, etc.
                }

                if (isEditing) {
                  await SQLiteDatabaseService.updateCustomer(
                    customer.copyWith(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      address: addressController.text.isEmpty
                          ? null
                          : addressController.text,
                      city: cityController.text.isEmpty
                          ? null
                          : cityController.text,
                      documentType: selectedDocumentType,
                      documentNumber: documentController.text.isEmpty
                          ? null
                          : documentController.text,
                      pointsRate: pointsRate,
                      updatedAt: DateTime.now(),
                    ),
                  );
                } else {
                  await SQLiteDatabaseService.createCustomer(
                    Customer(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      address: addressController.text.isEmpty
                          ? null
                          : addressController.text,
                      city: cityController.text.isEmpty
                          ? null
                          : cityController.text,
                      documentType: selectedDocumentType,
                      documentNumber: documentController.text.isEmpty
                          ? null
                          : documentController.text,
                      pointsRate: pointsRate,
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
              _buildDetailRow(
                  'Email', customer.email.isEmpty ? '—' : customer.email),
              _buildDetailRow('Teléfono', customer.phone),
              if (customer.address != null)
                _buildDetailRow('Dirección', customer.address!),
              if (customer.city != null && customer.city!.isNotEmpty)
                _buildDetailRow('Ciudad', customer.city!),
              if ((customer.documentType ?? '').trim().isNotEmpty ||
                  (customer.documentNumber ?? '').trim().isNotEmpty)
                _buildDetailRow(
                    'Documento',
                    '${customer.documentType ?? ''} ${customer.documentNumber ?? ''}'
                        .trim()),
              _buildDetailRow('Tasa de Puntos',
                  '${customer.pointsRate == 1 ? '1 punto' : '${customer.pointsRate} puntos'} por cada \$1000'),
              _buildDetailRow(
                  'Puntos Acumulados', '${customer.accumulatedPoints}'),
              _buildDetailRow('Total compras',
                  '\$${NumberFormat('#,###').format(customer.totalPurchases)}'),
              if (customer.lastPurchase != null)
                _buildDetailRow(
                    'Última compra',
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(customer.lastPurchase!)),
              _buildDetailRow('Fecha registro',
                  DateFormat('dd/MM/yyyy HH:mm').format(customer.createdAt)),
              _buildDetailRow('Última actualización',
                  DateFormat('dd/MM/yyyy HH:mm').format(customer.updatedAt)),
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
        content:
            Text('¿Estás seguro de que quieres eliminar a ${customer.name}?'),
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

  // ✅ NUEVO: Función de debug para recrear tabla customers
  Future<void> _debugRecreateTable() async {
    try {
      // Primero verificar el estado actual de la tabla
      final status = await SQLiteDatabaseService.getCustomersTableStatus();

      String message = 'Estado actual de la tabla customers:\n\n';
      message += '• Existe: ${status['exists'] ? 'SÍ' : 'NO'}\n';
      message += '• Columnas: ${status['columns']}\n';
      message +=
          '• Tiene pointsRate: ${status['hasPointsRate'] ? 'SÍ' : 'NO'}\n';
      message +=
          '• Tiene accumulatedPoints: ${status['hasAccumulatedPoints'] ? 'SÍ' : 'NO'}\n';

      if (status['error'] != null) {
        message += '• Error: ${status['error']}\n';
      }

      message += '\n¿Qué acción deseas realizar?';

      Get.dialog(
        AlertDialog(
          title: const Text('Debug: Estado de Tabla Customers'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancelar'),
            ),
            if (!status['exists'] ||
                !status['hasPointsRate'] ||
                !status['hasAccumulatedPoints'])
              ElevatedButton(
                onPressed: () async {
                  Get.back();
                  try {
                    await SQLiteDatabaseService.forceRecreateCustomersTable();
                    Get.snackbar(
                        'Éxito', 'Tabla customers recreada correctamente');
                    _loadCustomers();
                  } catch (e) {
                    Get.snackbar('Error', 'Error recreando tabla: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Recrear Tabla'),
              ),
            if (status['exists'])
              ElevatedButton(
                onPressed: () async {
                  Get.back();
                  try {
                    await SQLiteDatabaseService.ensureCustomersTableExists();
                    Get.snackbar('Éxito', 'Tabla customers verificada');
                    _loadCustomers();
                  } catch (e) {
                    Get.snackbar('Error', 'Error verificando tabla: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Verificar Tabla'),
              ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Error en debug: $e');
    }
  }
}
