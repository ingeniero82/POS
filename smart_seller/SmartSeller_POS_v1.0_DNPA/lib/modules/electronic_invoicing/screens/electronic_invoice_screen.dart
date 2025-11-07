import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/electronic_invoice_controller.dart';
import 'package:intl/intl.dart';
import '../../../models/product.dart';

class ElectronicInvoiceScreen extends StatefulWidget {
  const ElectronicInvoiceScreen({super.key});

  @override
  State<ElectronicInvoiceScreen> createState() => _ElectronicInvoiceScreenState();
}

class _ElectronicInvoiceScreenState extends State<ElectronicInvoiceScreen> with SingleTickerProviderStateMixin {
  final ElectronicInvoiceController _controller = Get.put(ElectronicInvoiceController());
  
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  // Controladores para los campos del formulario
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _issueDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();
  
  String _selectedPaymentMethod = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Inicializar fechas por defecto
    final now = DateTime.now();
    _issueDateController.text = DateFormat('MM/dd/yyyy').format(now);
    _dueDateController.text = DateFormat('MM/dd/yyyy').format(now);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _invoiceNumberController.dispose();
    _issueDateController.dispose();
    _dueDateController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Facturación Electrónica'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header azul con icono y título
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Facturación Electrónica DIAN',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Sistema POS - Colombia',
                      style: TextStyle(
                        fontSize: 14, 
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Pestañas de navegación
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              labelColor: const Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF1976D2),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: Icon(
                    Icons.description,
                    color: _currentTabIndex == 0 ? const Color(0xFF1976D2) : Colors.grey[600],
                  ),
                  child: const Text(
                    'Datos Factura',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Tab(
                  icon: Icon(
                    Icons.person,
                    color: _currentTabIndex == 1 ? const Color(0xFF1976D2) : Colors.grey[600],
                  ),
                  child: const Text(
                    'Cliente',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Tab(
                  icon: Icon(
                    Icons.shopping_cart,
                    color: _currentTabIndex == 2 ? const Color(0xFF1976D2) : Colors.grey[600],
                  ),
                  child: const Text(
                    'Productos',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido principal
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInvoiceDataTab(),
                  _buildClientTab(),
                  _buildProductsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInvoiceDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de la Factura',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 24),
            
            // Número de Factura
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Número de Factura *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: _invoiceNumberController,
                  onChanged: (value) => _controller.updateInvoiceNumber(value),
                  decoration: const InputDecoration(
                    hintText: 'Ej: FE-001',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Fecha de Emisión
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha de Emisión *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: _issueDateController,
                  onChanged: (value) => _controller.updateIssueDate(value),
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _issueDateController.text = DateFormat('MM/dd/yyyy').format(picked);
                      });
                      _controller.updateIssueDate(_issueDateController.text);
                    }
                  },
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Fecha de Vencimiento
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha de Vencimiento *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: _dueDateController,
                  onChanged: (value) => _controller.updateDueDate(value),
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _dueDateController.text = DateFormat('MM/dd/yyyy').format(picked);
                      });
                      _controller.updateDueDate(_dueDateController.text);
                    }
                  },
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Medio de Pago
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medio de Pago *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => DropdownButtonFormField<String>(
                  value: _controller.paymentMethod.value,
                  items: [
                    'Efectivo',
                    'Tarjeta Débito',
                    'Tarjeta Crédito',
                    'Transferencia',
                    'Cheque',
                    'Otro'
                  ].map((method) => 
                    DropdownMenuItem(
                      value: method, 
                      child: Text(method),
                    )
                  ).toList(),
                  onChanged: (value) => _controller.updatePaymentMethod(value!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Observaciones
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observaciones',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: _observationsController,
                  onChanged: (value) => _controller.updateObservations(value),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Observaciones adicionales...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 32),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                    onPressed: _controller.isLoading.value ? null : () {
                      _controller.saveDraft();
                    },
                    icon: _controller.isLoading.value 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _controller.isLoading.value ? 'Guardando...' : 'Guardar Borrador',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                    onPressed: _controller.isLoading.value ? null : () {
                      _controller.sendToDIAN();
                    },
                    icon: _controller.isLoading.value 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 20),
                    label: Text(
                      _controller.isLoading.value ? 'Enviando...' : 'Enviar a DIAN',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del Cliente',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 24),
            
            // Tipo de Cliente
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tipo de Cliente *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => DropdownButtonFormField<String>(
                  value: _controller.clientType.value,
                  items: [
                    'CUANTIAS MENORES',
                    'CLIENTE REGISTRADO'
                  ].map((type) => 
                    DropdownMenuItem(
                      value: type, 
                      child: Text(type),
                    )
                  ).toList(),
                  onChanged: (value) => _controller.updateClientType(value!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // NIT/RUT
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NIT/RUT *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  onChanged: (value) => _controller.updateClientNit(value),
                  decoration: const InputDecoration(
                    hintText: 'Ej: 900123456-7',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Nombre/Razón Social
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nombre/Razón Social *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  onChanged: (value) => _controller.updateClientName(value),
                  decoration: const InputDecoration(
                    hintText: 'Nombre del cliente',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Dirección
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dirección',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  onChanged: (value) => _controller.updateClientAddress(value),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Dirección del cliente',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Teléfono
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teléfono',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  onChanged: (value) => _controller.updateClientPhone(value),
                  decoration: const InputDecoration(
                    hintText: 'Ej: 3001234567',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 20),
            
            // Email
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  onChanged: (value) => _controller.updateClientEmail(value),
                  decoration: const InputDecoration(
                    hintText: 'cliente@ejemplo.com',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 24),
            
            // Botón para buscar cliente
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implementar búsqueda de clientes
                  Get.snackbar(
                    'Búsqueda de Clientes',
                    'Funcionalidad en desarrollo',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                  );
                },
                icon: const Icon(Icons.search, size: 20),
                label: const Text('Buscar Cliente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Productos de la Factura',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implementar agregar producto
                    Get.snackbar(
                      'Agregar Producto',
                      'Funcionalidad en desarrollo',
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Agregar Producto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Lista de productos
            Obx(() {
              if (_controller.invoiceProducts.isEmpty) {
                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay productos agregados',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Haz clic en "Agregar Producto" para comenzar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Column(
                children: [
                  // Encabezados de la tabla
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Producto',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Cantidad',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Precio',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 40), // Espacio para botón eliminar
                      ],
                    ),
                  ),
                  
                  // Lista de productos
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _controller.invoiceProducts.length,
                      itemBuilder: (context, index) {
                        final product = _controller.invoiceProducts[index];
                        final productModel = product['product'] as Product;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productModel.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Código: ${productModel.code}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    product['quantity'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '\$${product['unitPrice'].toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '\$${product['total'].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _controller.removeProduct(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
            
            const SizedBox(height: 24),
            
            // Resumen de totales
            Obx(() => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text('\$${_controller.subtotal.value.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('IVA (19%):'),
                      Text('\$${_controller.iva.value.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_controller.total.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
} 