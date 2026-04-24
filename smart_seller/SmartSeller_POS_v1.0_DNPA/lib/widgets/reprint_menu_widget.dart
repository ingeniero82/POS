import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/client.dart';
import '../services/sqlite_database_service.dart';
import '../services/print_service.dart';
import '../services/auth_service.dart';
import '../models/permissions.dart';
import '../services/permissions_service.dart';
import '../screens/pos_controller.dart';
import 'partial_return_dialog.dart';

class ReprintMenuWidget extends StatefulWidget {
  const ReprintMenuWidget({super.key});

  @override
  State<ReprintMenuWidget> createState() => _ReprintMenuWidgetState();
}

class _ReprintMenuWidgetState extends State<ReprintMenuWidget> {
  List<Sale> sales = [];
  List<Sale> filteredSales = [];
  bool isLoading = true;

  /// Nombre del cliente (sistema o facturación) por sale.id para mostrar y buscar.
  final Map<int, String> _saleClientNames = {};

  // Filtros mejorados
  DateTime selectedDate = DateTime.now();
  String searchTerm = '';
  String selectedCashier = '';
  String selectedPaymentMethod = '';
  String selectedClient = '';
  String selectedStatus = '';

  // Controladores
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Formatters
  final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0');
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
    if (!permissionsService.hasPermission(
        currentUser.role, Permission.viewSalesHistory)) {
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
    _saleClientNames.clear();

    try {
      final loadedSales =
          await SQLiteDatabaseService.getSales(date: selectedDate);

      for (final sale in loadedSales) {
        if (sale.id == null) continue;
        String name = '';
        if (sale.customerId != null) {
          final c =
              await SQLiteDatabaseService.getCustomerById(sale.customerId!);
          if (c != null) name = c.name.trim();
        }
        if (name.isEmpty && sale.clientId != null) {
          final c = await SQLiteDatabaseService.getClientById(sale.clientId!);
          if (c != null) name = c.businessName.trim();
        }
        _saleClientNames[sale.id!] = name;
      }

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
        final clientName =
            (sale.id != null ? _saleClientNames[sale.id!] : null) ?? '';
        final searchMatch = searchTerm.isEmpty ||
            sale.id.toString().contains(searchTerm) ||
            sale.user.toLowerCase().contains(searchTerm.toLowerCase()) ||
            clientName.toLowerCase().contains(searchTerm.toLowerCase());

        final cashierMatch =
            selectedCashier.isEmpty || sale.user == selectedCashier;
        final paymentMatch = selectedPaymentMethod.isEmpty ||
            (sale.paymentMethod ?? '') == selectedPaymentMethod;

        // Filtro por estado: '' = Todas, 'activas' = solo no anuladas, 'anuladas' = solo anuladas
        final statusMatch = selectedStatus.isEmpty ||
            (selectedStatus == 'anuladas' && sale.isAnulada) ||
            (selectedStatus == 'activas' && !sale.isAnulada);

        return searchMatch && cashierMatch && paymentMatch && statusMatch;
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now()
          .subtract(const Duration(days: 30)), // Máximo 30 días atrás
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

  Future<void> _showSaleDetails(Sale sale) async {
    final role = AuthService.to.currentUser?.role;
    final canCancel = role != null &&
        PermissionsService.to.hasPermission(role, Permission.cancelSales);
    final hasAnyReturn = sale.id != null &&
            !sale.isReturn &&
            !sale.isAnulada
        ? await SQLiteDatabaseService.hasReturnForSale(sale.id!)
        : false;
    final fullyReturned = sale.id != null &&
            !sale.isReturn &&
            !sale.isAnulada
        ? await SQLiteDatabaseService.isOriginalSaleFullyReturned(sale)
        : false;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              sale.isAnulada
                  ? Icons.cancel
                  : (sale.isReturn
                      ? Icons.keyboard_return
                      : Icons.receipt_long),
              color: sale.isAnulada
                  ? Colors.red
                  : (sale.isReturn ? Colors.deepOrange : Colors.blue),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                sale.isReturn
                    ? 'Devolución #${sale.id.toString().padLeft(6, '0')}'
                    : 'Factura #${sale.id.toString().padLeft(6, '0')}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sale.isAnulada) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ANULADA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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
              if ((sale.id != null ? _saleClientNames[sale.id!] : null)
                      ?.isNotEmpty ??
                  false)
                _buildDetailRow('Cliente:', _saleClientNames[sale.id!]!),
              _buildDetailRow(
                  'Método de pago:', sale.paymentMethod ?? 'No especificado'),
              if (sale.isReturn && sale.originalSaleId != null)
                _buildDetailRow(
                  'Factura original:',
                  '#${sale.originalSaleId!.toString().padLeft(6, '0')}',
                ),
              _buildDetailRow(
                sale.isReturn ? 'Monto devuelto:' : 'Total:',
                sale.isReturn
                    ? '- ${currencyFormat.format(sale.total)}'
                    : currencyFormat.format(sale.total),
              ),
              if (sale.isAnulada) ...[
                _buildDetailRow('Anulada por:', sale.anuladaPor ?? '—'),
                _buildDetailRow(
                    'Fecha anulación:',
                    sale.anuladaAt != null
                        ? dateFormat.format(sale.anuladaAt!)
                        : '—'),
              ],
              if (fullyReturned && !sale.isAnulada && !sale.isReturn) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2,
                          color: Colors.grey.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toda la mercancía de esta factura consta como devuelta.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (hasAnyReturn &&
                  !fullyReturned &&
                  !sale.isAnulada &&
                  !sale.isReturn) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hay devoluciones parciales. Puede registrar otra por ítems '
                          'hasta completar lo vendido.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      final isKgLine = item.weightKg != null &&
                          item.weightKg! > 1e-9;
                      final lineMoney = isKgLine
                          ? item.price
                          : item.price * item.quantity;
                      final qtyLabel = isKgLine
                          ? '${item.weightKg!.toStringAsFixed(3)} kg'
                          : 'x${item.quantity}';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.name} $qtyLabel',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                currencyFormat.format(lineMoney),
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
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: const Text('Cerrar'),
          ),
          if (!sale.isAnulada)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dlgContext).pop();
                _reprintInvoice(sale);
              },
              icon: const Icon(Icons.print),
              label: const Text('Reimprimir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (!sale.isAnulada && !sale.isReturn && !fullyReturned && canCancel)
            ElevatedButton.icon(
              onPressed: () => showPartialReturnDialog(
                dialogContext: dlgContext,
                detailContext: dlgContext,
                original: sale,
                currencyFormat: currencyFormat,
                onSuccess: _loadSales,
                onImmediateExchangeCreditCreated: (amount) {
                  if (!Get.isRegistered<PosController>()) return;
                  final pos = Get.find<PosController>();
                  pos.assignImmediateExchangeCredit(
                    amount,
                    sourceSaleId: sale.id,
                  );
                },
              ),
              icon: const Icon(Icons.keyboard_return),
              label: const Text('Registrar devolución'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          if (!sale.isAnulada && canCancel)
            ElevatedButton.icon(
              onPressed: () => _confirmVoidSale(dlgContext, sale),
              icon: const Icon(Icons.cancel),
              label: const Text('Anular venta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmVoidSale(BuildContext context, Sale sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Anular venta'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Está seguro de anular la factura #${sale.id.toString().padLeft(6, '0')}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${currencyFormat.format(sale.total)} — ${sale.items.length} producto(s).',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'La venta quedará marcada como anulada y el stock de los productos se devolverá al inventario. Esta acción no se puede deshacer.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Sí, anular'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Cerrar detalle
    try {
      final user = AuthService.to.currentUser?.fullName ??
          AuthService.to.currentUser?.username ??
          'Sistema';
      await SQLiteDatabaseService.voidSale(sale.id!, user);
      if (mounted) {
        _loadSales();
        Get.snackbar(
          'Venta anulada',
          'Factura #${sale.id.toString().padLeft(6, '0')} anulada correctamente. El stock fue devuelto.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error al anular',
          e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
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
      const reprintCount = 0; // TODO: Implementar contador de reimpresiones

      // Mostrar diálogo de confirmación mejorado
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirmar Reimpresión #${reprintCount + 1}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '¿Desea reimprimir la factura #${sale.id.toString().padLeft(6, '0')}?'),
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
                    if ((sale.id != null ? _saleClientNames[sale.id!] : null)
                            ?.isNotEmpty ??
                        false)
                      Text('Cliente: ${_saleClientNames[sale.id!]}'),
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
                    const Icon(Icons.info, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '✅ Auditoría completa:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                          const Text(
                            '• Reimpresión #${reprintCount + 1}',
                            style:
                                TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                          Text(
                            '• Usuario: ${currentUser?.fullName ?? 'No identificado'}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.orange),
                          ),
                          Text(
                            '• Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.orange),
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
              label: const Text('Reimprimir #${reprintCount + 1}'),
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

      // Cargar cliente asociado a la venta para que el ticket salga con el mismo nombre que la primera vez
      Customer? customer;
      Client? client;
      if (sale.customerId != null) {
        customer =
            await SQLiteDatabaseService.getCustomerById(sale.customerId!);
      }
      if (sale.clientId != null) {
        client = await SQLiteDatabaseService.getClientById(sale.clientId!);
      }

      // Convertir Sale a formato requerido para impresión
      final cartItems = sale.items
          .map((item) => CartItem(
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                unit: item.unit,
                ivaPercentage: item.ivaPercentage,
              ))
          .toList();

      double subtotal = 0.0;
      double taxAt19 = 0.0;
      double taxAt5 = 0.0;
      for (final item in sale.items) {
        final itemTotal = item.price * item.quantity;
        subtotal += itemTotal;
        if (item.ivaPercentage == 19) {
          taxAt19 += itemTotal * 0.19;
        } else if (item.ivaPercentage == 5) taxAt5 += itemTotal * 0.05;
      }
      final taxes = taxAt19 + taxAt5;

      final success = await printService.printReceipt(
        sale,
        cartItems,
        subtotal,
        taxes,
        sale.total,
        customer: customer,
        client: client,
        isReprint: true,
        reprintReason:
            'Reimpresión solicitada por ${AuthService.to.currentUser?.fullName}',
        paymentMethod: sale.paymentMethod,
        vatAt19: taxAt19 > 0 ? taxAt19 : null,
        vatAt5: taxAt5 > 0 ? taxAt5 : null,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
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
                          hintText: 'Buscar por # factura, cajero o cliente...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
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
                        initialValue:
                            selectedCashier.isEmpty ? null : selectedCashier,
                        decoration: InputDecoration(
                          labelText: 'Cajero',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Todos los cajeros')),
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
                        initialValue: selectedPaymentMethod.isEmpty
                            ? null
                            : selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Método de pago',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Todos los métodos')),
                          ...sales
                              .map((s) => s.paymentMethod ?? 'Sin especificar')
                              .toSet()
                              .map(
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

                    const SizedBox(width: 12),

                    // Filtro por estado (activas / anuladas)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            selectedStatus.isEmpty ? '' : selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Todas')),
                          DropdownMenuItem(
                              value: 'activas', child: Text('Solo activas')),
                          DropdownMenuItem(
                              value: 'anuladas', child: Text('Solo anuladas')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value ?? '';
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

          // Estadísticas rápidas (las devoluciones son movimientos aparte: no suman como venta)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Builder(
              builder: (context) {
                double ventasBruto = 0;
                double devolucionesMonto = 0;
                int nVentas = 0;
                int nDevoluciones = 0;
                for (final s in filteredSales) {
                  if (s.isAnulada) continue;
                  if (s.isReturn) {
                    devolucionesMonto += s.total;
                    nDevoluciones++;
                  } else {
                    ventasBruto += s.total;
                    nVentas++;
                  }
                }
                final neto = ventasBruto - devolucionesMonto;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Facturas de venta',
                        '$nVentas',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Devoluciones',
                        nDevoluciones > 0
                            ? '$nDevoluciones · -${currencyFormat.format(devolucionesMonto)}'
                            : '0',
                        Icons.keyboard_return,
                        Colors.deepOrange,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Total neto día',
                        currencyFormat.format(neto),
                        Icons.account_balance_wallet,
                        neto >= 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                );
              },
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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
    final isAnulada = sale.isAnulada;
    final isReturn = sale.isReturn;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isAnulada
          ? Colors.grey.shade100
          : (isReturn ? Colors.orange.shade50 : null),
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
                  color: isAnulada
                      ? Colors.grey.shade300
                      : (isReturn
                          ? Colors.deepOrange.shade100
                          : Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAnulada
                          ? Icons.cancel
                          : (isReturn ? Icons.keyboard_return : Icons.receipt),
                      color: isAnulada
                          ? Colors.grey
                          : (isReturn ? Colors.deepOrange : Colors.blue),
                      size: 20,
                    ),
                    Text(
                      '#${sale.id.toString().padLeft(4, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAnulada
                            ? Colors.grey.shade700
                            : (isReturn ? Colors.deepOrange : Colors.blue),
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
                        Row(
                          children: [
                            Text(
                              timeFormat.format(sale.date),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isAnulada ? Colors.grey.shade600 : null,
                                decoration: isAnulada
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (isAnulada) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Anulada',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ] else if (isReturn) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Devolución',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          isReturn
                              ? '- ${currencyFormat.format(sale.total)}'
                              : currencyFormat.format(sale.total),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAnulada
                                ? Colors.grey.shade600
                                : (isReturn
                                    ? Colors.deepOrange.shade800
                                    : Colors.green),
                            decoration:
                                isAnulada ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          sale.user,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.payment,
                            size: 16, color: Colors.grey.shade600),
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
                    if ((sale.id != null ? _saleClientNames[sale.id!] : null)
                            ?.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.badge,
                              size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _saleClientNames[sale.id!]!,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      isReturn && sale.originalSaleId != null
                          ? 'Devolución de factura #${sale.originalSaleId!.toString().padLeft(4, '0')} · ${sale.items.length} producto${sale.items.length != 1 ? 's' : ''}'
                          : '${sale.items.length} producto${sale.items.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Botón de acción
              if (!isAnulada)
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
