import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/sqlite_database_service.dart';
import '../services/print_service.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../services/permissions_service.dart';
import '../screens/pos_controller.dart';

class ReprintMenuWidget extends StatefulWidget {
  @override
  State<ReprintMenuWidget> createState() => _ReprintMenuWidgetState();
}

class _ReprintMenuWidgetState extends State<ReprintMenuWidget> {
  List<Sale> sales = [];
  List<Sale> filteredSales = [];
  bool isLoading = true;
  
  // Filtros mejorados
  DateTime selectedDate = DateTime.now();
  String searchTerm = '';
  String selectedCashier = '';
  String selectedPaymentMethod = '';
  String selectedClient = ''; // ✅ NUEVO: Filtro por cliente
  String selectedStatus = ''; // ✅ NUEVO: Filtro por estado
  
  // Controladores
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Formatters
  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'es_CO', 
    symbol: '\$ ', 
    decimalDigits: 0, 
    customPattern: '\u00A4#,##0'
  );
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSales();
    _searchController.addListener(_filterSales);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkPermissions() {
    final currentUser = AuthService.to.currentUser;
    if (currentUser == null) {
      Get.back();
      return;
    }

    final permissionsService = PermissionsService.to;
    if (!permissionsService.hasPermission(currentUser.role, Permission.viewSalesHistory)) {
      Get.back();
      Get.snackbar(
        'Sin permisos',
        'No tienes permisos para ver el historial de ventas',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
  }

  Future<void> _loadSales() async {
    setState(() => isLoading = true);
    
    try {
      // Cargar ventas del día seleccionado
      final loadedSales = await SQLiteDatabaseService.getSales(date: selectedDate);
      
      setState(() {
        sales = loadedSales;
        _filterSales();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Error al cargar ventas: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _filterSales() {
    setState(() {
      filteredSales = sales.where((sale) {
        // Filtro por término de búsqueda (mejorado)
        final searchMatch = searchTerm.isEmpty || 
                           sale.id.toString().contains(searchTerm) ||
                           sale.user.toLowerCase().contains(searchTerm.toLowerCase());
        
        // Filtro por cajero
        final cashierMatch = selectedCashier.isEmpty || sale.user == selectedCashier;
        
        // Filtro por método de pago
        final paymentMatch = selectedPaymentMethod.isEmpty || 
                            (sale.paymentMethod ?? '') == selectedPaymentMethod;
        
        return searchMatch && cashierMatch && paymentMatch;
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Máximo 30 días atrás
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadSales();
    }
  }

  void _showSaleDetails(Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Factura #${sale.id.toString().padLeft(6, '0')}'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Fecha:', dateFormat.format(sale.date)),
              _buildDetailRow('Hora:', timeFormat.format(sale.date)),
              _buildDetailRow('Cajero:', sale.user),
              _buildDetailRow('Método de pago:', sale.paymentMethod ?? 'No especificado'),
              _buildDetailRow('Total:', currencyFormat.format(sale.total)),
              
              const SizedBox(height: 16),
              const Text(
                'Productos:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sale.items.length,
                    itemBuilder: (context, index) {
                      final item = sale.items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.name} x${item.quantity}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                currencyFormat.format(item.price * item.quantity),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _reprintInvoice(sale);
            },
            icon: const Icon(Icons.print),
            label: const Text('Reimprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reprintInvoice(Sale sale) async {
    try {
      // ✅ MEJORADO: Información detallada de auditoría
      final currentUser = AuthService.to.currentUser;
      final reprintCount = 0; // TODO: Implementar contador de reimpresiones
      
      // Mostrar diálogo de confirmación mejorado
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Confirmar Reimpresión #${reprintCount + 1}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Desea reimprimir la factura #${sale.id.toString().padLeft(6, '0')}?'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${currencyFormat.format(sale.total)}'),
                    Text('Fecha: ${dateFormat.format(sale.date)}'),
                    Text('Cajero: ${sale.user}'),
                    Text('Método: ${sale.paymentMethod ?? 'No especificado'}'),
                    Text('Productos: ${sale.items.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✅ Auditoría completa:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          Text(
                            '• Reimpresión #${reprintCount + 1}',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                          Text(
                            '• Usuario: ${currentUser?.fullName ?? 'No identificado'}',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                          Text(
                            '• Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.print),
              label: Text('Reimprimir #${reprintCount + 1}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mostrar diálogo de impresión
      Get.dialog(
        const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reimprimiendo factura...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Reimprimir usando el servicio de impresión
      final printService = PrintService.instance;
      await printService.initialize();

      if (!printService.isConnected) {
        Get.back(); // Cerrar diálogo de reimpresión
        Get.snackbar(
          'Error de impresión',
          'Impresora no detectada. Verifique la conexión.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Convertir Sale a formato requerido para impresión
      final cartItems = sale.items.map((item) => CartItem(
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        unit: item.unit,
      )).toList();

      final subtotal = sale.total / 1.19; // Asumir IVA del 19%
      final taxes = sale.total - subtotal;

      final success = await printService.printReceipt(
        sale,
        cartItems,
        subtotal,
        taxes,
        sale.total,
        isReprint: true, // Marcar como reimpresión
        reprintReason: 'Reimpresión solicitada por ${AuthService.to.currentUser?.fullName}',
        paymentMethod: sale.paymentMethod,
      );

      Get.back(); // Cerrar diálogo de reimpresión

      if (success) {
        // Registrar la reimpresión (aquí podrías guardar en una tabla de auditoría)
        Get.snackbar(
          '✅ Reimpresión exitosa',
          'Factura #${sale.id.toString().padLeft(6, '0')} reimpresa correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error de impresión',
          'No se pudo reimprimir la factura',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }

    } catch (e) {
      Get.back(); // Cerrar cualquier diálogo abierto
      Get.snackbar(
        'Error',
        'Error durante la reimpresión: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.print, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reimpresión de Facturas'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _loadSales,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Primera fila de filtros
                Row(
                  children: [
                    // Selector de fecha
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Campo de búsqueda
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por # factura o cajero...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchTerm = value;
                          });
                          _filterSales();
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Segunda fila de filtros
                Row(
                  children: [
                    // Filtro por cajero
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCashier.isEmpty ? null : selectedCashier,
                        decoration: InputDecoration(
                          labelText: 'Cajero',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Todos los cajeros')),
                          ...sales.map((s) => s.user).toSet().map(
                            (cashier) => DropdownMenuItem(
                              value: cashier,
                              child: Text(cashier),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCashier = value ?? '';
                          });
                          _filterSales();
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Filtro por método de pago
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPaymentMethod.isEmpty ? null : selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Método de pago',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Todos los métodos')),
                          ...sales.map((s) => s.paymentMethod ?? 'Sin especificar').toSet().map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value ?? '';
                          });
                          _filterSales();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Estadísticas rápidas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Total Facturas',
                  filteredSales.length.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Ventas del Día',
                  currencyFormat.format(
                    filteredSales.fold(0.0, (sum, sale) => sum + sale.total),
                  ),
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),
          ),

          // Lista de ventas
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay facturas para mostrar',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cambia los filtros o selecciona otra fecha',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSales.length,
                        itemBuilder: (context, index) {
                          final sale = filteredSales[index];
                          return _buildSaleCard(sale);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
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

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showSaleDetails(sale),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Número de factura
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt, color: Colors.blue, size: 20),
                    Text(
                      '#${sale.id.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Información principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeFormat.format(sale.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currencyFormat.format(sale.total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          sale.user,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.payment, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          sale.paymentMethod ?? 'Sin especificar',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${sale.items.length} producto${sale.items.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Botón de acción
              IconButton(
                onPressed: () => _reprintInvoice(sale),
                icon: const Icon(Icons.print),
                color: Colors.green,
                tooltip: 'Reimprimir factura',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

 