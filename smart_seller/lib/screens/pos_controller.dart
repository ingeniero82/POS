import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/client.dart';
import '../services/sqlite_database_service.dart';
import '../services/auth_service.dart';
import '../modules/accounting/services/accounting_service.dart';

import '../services/print_service.dart';
import '../services/tax_calculation_service.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';

class CartItem {
  final String name;
  double price; // Cambiado de final para permitir modificaciones temporales
  final String unit;
  int quantity;
  
  // ✅ NUEVO: Campos para cálculo de impuestos
  Product? product; // Producto asociado
  SaleItem? saleItem; // Item de venta con impuestos calculados

  CartItem({
    required this.name,
    required this.price,
    required this.unit,
    this.quantity = 1,
    this.product,
    this.saleItem,
  });

  double get total {
    // Si hay saleItem calculado, usar su total
    if (saleItem != null) {
      return saleItem!.total;
    }
    return price * quantity;
  }
  
  String get displayInfo => '$quantity ${unit}';
}

class PosController extends GetxController {
  var cartItems = <CartItem>[].obs;
  
  // ✅ NUEVO: Variables para gestión de clientes
  var selectedCustomer = Rxn<Customer>();
  var isSearchingCustomer = false.obs;
  var customerSearchResults = <Customer>[].obs;
  var customerSearchQuery = ''.obs;
  
  // ✅ NUEVO: Variables para gestión de clientes de facturación electrónica
  var selectedClient = Rxn<Client>();
  var isSearchingClient = false.obs;
  var clientSearchResults = <Client>[].obs;
  var clientSearchQuery = ''.obs;
  
  // ✅ NUEVO: Callback para limpiar campo de búsqueda
  Function()? onClearSearchField;

  @override
  void onInit() {
    super.onInit();
  }
  
  // ✅ NUEVO: Método para buscar clientes
  Future<void> searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      customerSearchResults.clear();
      return;
    }
    
    try {
      isSearchingCustomer.value = true;
      final allCustomers = await SQLiteDatabaseService.getAllCustomers();
      
      // Filtrar por nombre, email, cédula o teléfono
      final filtered = allCustomers.where((customer) {
        final searchLower = query.toLowerCase();
        return customer.name.toLowerCase().contains(searchLower) ||
               customer.email.toLowerCase().contains(searchLower) ||
               (customer.documentNumber?.toLowerCase().contains(searchLower) ?? false) ||
               customer.phone.contains(query);
      }).toList();
      
      customerSearchResults.value = filtered;
    } catch (e) {
      print('Error buscando clientes: $e');
      customerSearchResults.clear();
    } finally {
      isSearchingCustomer.value = false;
    }
  }
  
  // ✅ NUEVO: Método para seleccionar cliente
  void selectCustomer(Customer customer) {
    selectedCustomer.value = customer;
    Get.back(); // Cerrar modal de búsqueda
    Get.snackbar(
      'Cliente seleccionado',
      '${customer.name} - Tasa: ${customer.pointsRate} pts/\$1000 - Acumulados: ${customer.accumulatedPoints}',
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
  
  // ✅ NUEVO: Método para limpiar cliente seleccionado
  void clearSelectedCustomer() {
    selectedCustomer.value = null;
    Get.snackbar(
      'Cliente removido',
      'No hay cliente seleccionado',
      duration: const Duration(seconds: 1),
    );
  }
  
  // ✅ NUEVO: Método para buscar clientes de facturación electrónica
  Future<void> searchClients(String query) async {
    if (query.trim().isEmpty) {
      clientSearchResults.clear();
      return;
    }
    
    try {
      isSearchingClient.value = true;
      // Por ahora simulamos la búsqueda, en el futuro se conectará con la base de datos
      final allClients = await _getAllClients();
      
      // Filtrar por nombre, email, documento o teléfono
      final filtered = allClients.where((client) {
        final searchLower = query.toLowerCase();
        return client.businessName.toLowerCase().contains(searchLower) ||
               (client.email?.toLowerCase().contains(searchLower) ?? false) ||
               client.documentNumber.toLowerCase().contains(searchLower) ||
               (client.phone?.contains(query) ?? false);
      }).toList();
      
      clientSearchResults.value = filtered;
    } catch (e) {
      print('Error buscando clientes: $e');
      clientSearchResults.clear();
    } finally {
      isSearchingClient.value = false;
    }
  }
  
  // ✅ NUEVO: Método para seleccionar cliente de facturación electrónica
  void selectClient(Client client) {
    selectedClient.value = client;
    Get.back(); // Cerrar modal de búsqueda
    Get.snackbar(
      'Cliente seleccionado',
      '${client.businessName} (${client.documentType} ${client.documentNumber})',
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
  
  // ✅ NUEVO: Método para limpiar cliente seleccionado
  void clearSelectedClient() {
    selectedClient.value = null;
    Get.snackbar(
      'Cliente removido',
      'No hay cliente seleccionado para facturación electrónica',
      duration: const Duration(seconds: 1),
    );
  }
  
  // ✅ NUEVO: Método temporal para obtener clientes (simulado)
  Future<List<Client>> _getAllClients() async {
    // Simular delay de base de datos
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Retornar clientes de ejemplo
    return [
      Client(
        documentType: 'CC',
        documentNumber: '123456789',
        businessName: 'Juan Pérez',
        email: 'juan.perez@email.com',
        phone: '3001234567',
        address: 'Calle 123 #45-67',
        city: 'Bogotá',
        department: 'Cundinamarca',
        fiscalResponsibility: 'Responsable de IVA',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Client(
        documentType: 'NIT',
        documentNumber: '900123456-7',
        businessName: 'Empresa ABC Ltda',
        email: 'contacto@empresaabc.com',
        phone: '6012345678',
        address: 'Carrera 78 #90-12',
        city: 'Bogotá',
        department: 'Cundinamarca',
        fiscalResponsibility: 'Responsable de IVA',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
  
  // ✅ NUEVO: Método para mostrar modal de selección de cliente
  void showCustomerSelectionModal() {
    Get.dialog(
      Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Seleccionar Cliente',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Campo de búsqueda
              TextField(
                onChanged: (value) {
                  customerSearchQuery.value = value;
                  searchCustomers(value);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, email, cédula o teléfono...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Lista de resultados
              Expanded(
                child: Obx(() {
                  if (isSearchingCustomer.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (customerSearchResults.isEmpty && customerSearchQuery.value.isNotEmpty) {
                    return const Center(
                      child: Text('No se encontraron clientes'),
                    );
                  }
                  
                  if (customerSearchResults.isEmpty) {
                    return const Center(
                      child: Text('Busca un cliente para comenzar'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: customerSearchResults.length,
                    itemBuilder: (context, index) {
                      final customer = customerSearchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            customer.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.email),
                            Text('${customer.pointsRate} pts/\$1000 - Acumulados: ${customer.accumulatedPoints}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => selectCustomer(customer),
                          child: const Text('Seleccionar'),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ✅ NUEVO: Método para actualizar puntos del cliente después de la venta
  Future<void> updateCustomerAfterSale() async {
    if (selectedCustomer.value == null) return;
    
    try {
      final customer = selectedCustomer.value!;
      // 🎯 AQUÍ ESTÁ LA LÓGICA: Usar la tasa del cliente
      final pointsEarned = customer.calculatePointsEarned(total);
      final newAccumulatedPoints = customer.accumulatedPoints + pointsEarned;
      final newTotalPurchases = customer.totalPurchases + total;
      
      // Actualizar puntos acumulados y total de compras
      await SQLiteDatabaseService.updateCustomer(
        customer.copyWith(
          accumulatedPoints: newAccumulatedPoints,
          totalPurchases: newTotalPurchases,
          lastPurchase: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Actualizar el cliente en memoria
      selectedCustomer.value = customer.copyWith(
        accumulatedPoints: newAccumulatedPoints,
        totalPurchases: newTotalPurchases,
        lastPurchase: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      print('✅ Cliente actualizado: ${customer.name} - Puntos ganados: $pointsEarned - Acumulados: $newAccumulatedPoints - Total: \$${newTotalPurchases}');
      
      // Limpiar cliente seleccionado
      selectedCustomer.value = null;
    } catch (e) {
      print('❌ Error actualizando cliente: $e');
    }
  }

  // ✅ ACTUALIZADO: Agregar producto al carrito con cálculo de impuestos
  Future<void> addToCart(String name, double price, String unit, {
    int quantity = 1,
    int? availableStock,
    Product? product,
  }) async {
    // Buscar si el producto ya existe en el carrito
    final existingIndex = cartItems.indexWhere((item) => item.name == name);
    
    if (existingIndex >= 0) {
      // Si existe, verificar stock antes de aumentar
      final currentQuantity = cartItems[existingIndex].quantity;
      if (availableStock != null && currentQuantity + quantity > availableStock) {
        Get.snackbar(
          'Stock insuficiente',
          'No hay más unidades disponibles de $name',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
      cartItems[existingIndex].quantity += quantity;
      
      // ✅ NUEVO: Recalcular impuestos del item
      if (cartItems[existingIndex].product != null) {
        final saleItem = await TaxCalculationService.calculateItemTaxes(
          product: cartItems[existingIndex].product!,
          quantity: cartItems[existingIndex].quantity,
        );
        cartItems[existingIndex].saleItem = saleItem;
      }
      
      cartItems.refresh(); // Notificar cambios
    } else {
      // Si no existe, verificar stock antes de agregar
      if (availableStock != null && quantity > availableStock) {
        Get.snackbar(
          'Sin stock',
          'El producto $name no tiene unidades disponibles',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // ✅ NUEVO: Obtener producto completo si no se proporciona
      Product? productToUse = product;
      if (productToUse == null) {
        final products = await SQLiteDatabaseService.getAllProducts();
        try {
          productToUse = products.firstWhere((p) => p.name == name && p.isActive);
        } catch (e) {
          productToUse = null; // Producto no encontrado
        }
      }
      
      // ✅ NUEVO: Calcular impuestos del item
      SaleItem? saleItem;
      if (productToUse != null) {
        saleItem = await TaxCalculationService.calculateItemTaxes(
          product: productToUse,
          quantity: quantity,
        );
      }
      
      cartItems.add(CartItem(
        name: name,
        price: price,
        unit: unit,
        quantity: quantity,
        product: productToUse,
        saleItem: saleItem,
      ));
    }
  }
  
  // Cambiar precio temporal de un item del carrito
  void changeItemPrice(int index, double newPrice) {
    if (index >= 0 && index < cartItems.length) {
      final item = cartItems[index];
      // Crear nuevo item con precio actualizado
      final updatedItem = CartItem(
        name: item.name,
        price: newPrice,
        unit: item.unit,
        quantity: item.quantity,

      );
      cartItems[index] = updatedItem;
      cartItems.refresh();
      
      Get.snackbar(
        'Precio actualizado',
        'Precio cambiado a ${CurrencyFormatter.formatCurrency(newPrice)}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }



  
  
  // Remover producto del carrito
  void removeFromCart(int index) {
    if (index >= 0 && index < cartItems.length) {
      cartItems.removeAt(index);
    }
  }
  
  // Cambiar cantidad de un producto
  void updateQuantity(int index, int newQuantity) {
    if (index >= 0 && index < cartItems.length && newQuantity > 0) {
      cartItems[index].quantity = newQuantity;
      cartItems.refresh();
    }
  }
  
  // Cambiar precio de un producto del carrito
  void updateItemPrice(int index, double newPrice) {
    if (index >= 0 && index < cartItems.length && newPrice > 0) {
      cartItems[index].price = newPrice;
      cartItems.refresh();
    }
  }
  

  
  // Limpiar carrito
  void clearCart() {
    cartItems.clear();
    Get.snackbar(
      'Carrito limpiado',
      'Todos los productos han sido removidos',
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  

  
  
  

  

  
  // ✅ ACTUALIZADO: Calcular subtotal (sin impuestos)
  double get subtotal {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null) {
        return sum + item.saleItem!.itemSubtotal;
      }
      return sum + (item.price * item.quantity);
    });
  }
  
  // ✅ ACTUALIZADO: Calcular impuestos (IVA + IpoConsumo + Bolsas)
  double get taxes {
    double totalTaxes = 0.0;
    for (final item in cartItems) {
      if (item.saleItem != null) {
        totalTaxes += item.saleItem!.itemVat;
        totalTaxes += item.saleItem!.itemIpoConsumo;
        if (item.saleItem!.isPlasticBag && 
            item.saleItem!.plasticBagTax != null && 
            item.saleItem!.bagQuantity != null) {
          totalTaxes += (item.saleItem!.plasticBagTax! * item.saleItem!.bagQuantity!);
        }
      }
    }
    return totalTaxes;
  }
  
  // ✅ ACTUALIZADO: Calcular IVA por tasas
  double get vatAt0 {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null && item.saleItem!.vatRate == 0.0) {
        return sum + item.saleItem!.itemVat;
      }
      return sum;
    });
  }
  
  double get vatAt5 {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null && item.saleItem!.vatRate == 0.05) {
        return sum + item.saleItem!.itemVat;
      }
      return sum;
    });
  }
  
  double get vatAt19 {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null && item.saleItem!.vatRate == 0.19) {
        return sum + item.saleItem!.itemVat;
      }
      return sum;
    });
  }
  
  // ✅ NUEVO: Calcular IpoConsumo
  double get ipoConsumoAmount {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null) {
        return sum + item.saleItem!.itemIpoConsumo;
      }
      return sum;
    });
  }
  
  // ✅ NUEVO: Calcular impuesto bolsas
  double get plasticBagTaxAmount {
    return cartItems.fold(0.0, (sum, item) {
      if (item.saleItem != null && 
          item.saleItem!.isPlasticBag && 
          item.saleItem!.plasticBagTax != null && 
          item.saleItem!.bagQuantity != null) {
        return sum + (item.saleItem!.plasticBagTax! * item.saleItem!.bagQuantity!);
      }
      return sum;
    });
  }
  
  int get plasticBagCount {
    return cartItems.fold(0, (sum, item) {
      if (item.saleItem != null && item.saleItem!.bagQuantity != null) {
        return sum + item.saleItem!.bagQuantity!;
      }
      return sum;
    });
  }
  
  // ✅ ACTUALIZADO: Calcular total
  double get total {
    return subtotal + taxes;
  }
  
  // ✅ NUEVO: Getter para obtener el cliente actual
  Client? get currentClient => selectedClient.value;
  
  // ✅ NUEVA FUNCIÓN: Forzar limpieza de focus después de completar venta
  void _forceFocusCleanup() {
    // Forzar que se pierda el focus de cualquier widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
  
  // Procesar pago
  void processPayment() async {
    if (cartItems.isEmpty) {
      Get.snackbar(
        'Carrito vacío',
        'Agrega productos antes de procesar el pago',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    // Mostrar opciones de pago
    Get.dialog(
      Dialog(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Método de Pago',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Total a pagar: ${CurrencyFormatter.formatCurrency(total)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(height: 24),
              
              // Opciones de pago
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.money,
                      title: 'Efectivo',
                      subtitle: 'Pago en efectivo',
                      onTap: () => _processPaymentWithMethod('Efectivo'),
                    ),
              ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.credit_card,
                      title: 'Tarjeta',
                      subtitle: 'Débito/Crédito',
                      onTap: () => _processPaymentWithMethod('Tarjeta'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.phone_android,
                      title: 'Transferencia',
                      subtitle: 'PSE/Bancolombia',
                      onTap: () => _processPaymentWithMethod('Transferencia'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.qr_code,
                      title: 'QR',
                      subtitle: 'Nequi/Daviplata',
                      onTap: () => _processPaymentWithMethod('QR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Get.back(),
                child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _processPaymentWithMethod(String method) async {
    Get.back(); // Cierra el diálogo de métodos de pago
    
    try {
      // ✅ ACTUALIZADO: Convertir cartItems a SaleItems con impuestos calculados
      List<SaleItem> saleItems = [];
      for (final cartItem in cartItems) {
        if (cartItem.saleItem != null) {
          saleItems.add(cartItem.saleItem!);
        } else {
          // Si no hay saleItem calculado, crear uno básico
          saleItems.add(SaleItem(
            name: cartItem.name,
            price: cartItem.price,
            quantity: cartItem.quantity,
            unit: cartItem.unit,
          ));
        }
      }
      
      // ✅ ACTUALIZADO: Calcular desglose completo de la venta
      final sale = await TaxCalculationService.calculateSaleBreakdown(
        items: saleItems,
        date: DateTime.now(),
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: method,
      );
      
      // Guardar la venta
      await SQLiteDatabaseService.saveSale(sale);
      
      // ✅ NUEVO: Registrar ingreso contable automático
      try {
        final currentUser = AuthService.to.currentUser;
        if (currentUser != null && currentUser.id != null) {
          await AccountingService.recordSaleIncome(
            total,
            'Venta POS - ${method}',
            currentUser.id!,
            paymentMethod: method,
            reference: 'sale_${sale.id ?? 'temp'}',
          );
          print('✅ Ingreso contable registrado automáticamente: \$${total}');
        }
      } catch (e) {
        print('❌ Error registrando ingreso contable: $e');
        // No interrumpir la venta por error contable
      }
      
      // ✅ NUEVO: Actualizar puntos del cliente si hay uno seleccionado
      await updateCustomerAfterSale();
      
      // El stock se actualiza automáticamente en saveSale
      
      // Mostrar confirmación con opción de imprimir
      _showPrintConfirmationDialog(sale, method);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al procesar la venta: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  // Mostrar diálogo de confirmación con opción de imprimir
  void _showPrintConfirmationDialog(Sale sale, String method) {
    // Nodos de foco para los botones
    final FocusNode yesButtonFocus = FocusNode();
    final FocusNode noButtonFocus = FocusNode();
    
    // Variable para prevenir ejecución duplicada
    bool isProcessing = false;
    
    // Enfocar el botón "SÍ" automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      yesButtonFocus.requestFocus();
    });
    
    // Función para imprimir (solo se ejecuta una vez)
    void handlePrint() {
      if (isProcessing) return;
      isProcessing = true;
      
      print('🖨️ Ejecutando handlePrint()...');
      
      // ✅ MEJORADO: Cerrar modal inmediatamente
      Get.back();
      
      // ✅ MEJORADO: Feedback visual después de cerrar
      Get.snackbar(
        '🖨️ Imprimiendo...',
        'Procesando impresión del recibo',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      
      // ✅ MEJORADO: Ejecutar impresión después de cerrar modal
      Future.delayed(const Duration(milliseconds: 100), () {
        _printReceipt(sale, method);
        // ✅ NUEVO: Notificar que se debe restaurar el foco
        Get.snackbar(
          '✅ Listo para siguiente cliente',
          'Presiona F2 para reimpresión o escanea nuevo producto',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // ✅ NUEVO: Forzar limpieza de focus después de completar venta
        _forceFocusCleanup();
      });
    }
    
    // Función para no imprimir (solo se ejecuta una vez)
    void handleNoPrint() {
      if (isProcessing) return;
      isProcessing = true;
      
      print('❌ Ejecutando handleNoPrint()...');
      
      // ✅ MEJORADO: Cerrar modal inmediatamente
      Get.back();
      
      // ✅ MEJORADO: Feedback visual después de cerrar
      Get.snackbar(
        '✅ Venta completada',
        'Recibo no impreso - Venta guardada',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      
      // ✅ MEJORADO: Limpiar carrito después de cerrar modal
      Future.delayed(const Duration(milliseconds: 100), () {
        clearCart();
        
        // ✅ NUEVO: Limpiar campo de búsqueda para evitar que la "N" quede ahí
        print('🔧 DEBUG: Llamando callback para limpiar campo de búsqueda...');
        onClearSearchField?.call();
        print('🔧 DEBUG: Callback ejecutado correctamente');
        
        // ✅ NUEVO: Notificar que se debe restaurar el foco
        Get.snackbar(
          '✅ Listo para siguiente cliente',
          'Presiona F2 para reimpresión o escanea nuevo producto',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // ✅ NUEVO: Forzar limpieza de focus después de completar venta
        _forceFocusCleanup();
      });
    }
    
    Get.dialog(
      Dialog(
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              // ✅ TECLAS DE ACCESO RÁPIDO PARA IMPRESIÓN:
              // - Enter: Imprimir recibo
              // - S: Imprimir recibo (acceso rápido)
              // - Escape: No imprimir
              // - N: No imprimir (acceso rápido)
              
              // Debug: Imprimir la tecla presionada
              print('🔍 Tecla presionada: ${event.logicalKey.keyLabel}');
              
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                print('✅ Enter detectado - Imprimiendo...');
                handlePrint();
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                print('❌ Escape detectado - No imprimir...');
                handleNoPrint();
              } else if (event.logicalKey == LogicalKeyboardKey.keyS || 
                         event.logicalKey.keyLabel == 'S' ||
                         event.logicalKey.keyLabel == 's' ||
                         event.character == 'S' ||
                         event.character == 's') {
                print('✅ S detectado - Imprimiendo...');
                handlePrint();
              } else if (event.logicalKey == LogicalKeyboardKey.keyN || 
                         event.logicalKey.keyLabel == 'N' ||
                         event.logicalKey.keyLabel == 'n' ||
                         event.character == 'N' ||
                         event.character == 'n') {
                print('❌ N detectado - No imprimir...');
                handleNoPrint();
              }
            }
          },
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Venta Exitosa!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: ${CurrencyFormatter.formatCurrency(total)}',
                  style: const TextStyle(fontSize: 18, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Método: $method',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                
                // Pregunta sobre imprimir
                const Text(
                  '¿Desea imprimir el recibo?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                
                // Botones de respuesta
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        focusNode: yesButtonFocus,
                        onPressed: handlePrint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SÍ (S)',
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        focusNode: noButtonFocus,
                        onPressed: handleNoPrint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'NO (N)',
                          style: TextStyle(
                            color: Colors.black87, 
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Texto de ayuda actualizado
                const Text(
                  'Presiona Enter/S para imprimir o Escape/N para continuar',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      // ✅ MEJORADO: Asegurar que el modal se cierre correctamente
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
  
  // Imprimir recibo
  void _printReceipt(Sale sale, String method) async {
    try {
      print('🖨️ Iniciando proceso de impresión...');
      
      // Mostrar diálogo de imprimiendo
      Get.dialog(
        Dialog(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Imprimiendo recibo...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
      
      // Inicializar servicio de impresión
      final printService = PrintService.instance;
      await printService.initialize();
      
      print('🔍 Estado de la impresora: ${printService.isConnected ? 'Conectada' : 'No conectada'}');
      print('🔌 Puerto: ${printService.printerPort}');
      
      // Verificar si la impresora está conectada
      if (!printService.isConnected) {
        Get.back(); // Cerrar diálogo de imprimiendo
        Get.snackbar(
          'Error de impresión',
          'Impresora Citizen TZ30-M01 no detectada. Verifique la conexión.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        clearCart();
        return;
      }
      
      // Imprimir recibo
      final success = await printService.printReceipt(
        sale, 
        cartItems, 
        subtotal, 
        taxes, 
        total,
        paymentMethod: sale.paymentMethod
      );
      
      Get.back(); // Cerrar diálogo de imprimiendo
      
      if (success) {
        print('✅ Recibo impreso exitosamente');
        
        // Esperar un momento antes de abrir el cajón (para que la impresora termine)
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Abrir cajón monedero automáticamente
        print('💰 Intentando abrir cajón monedero...');
        final drawerOpened = await printService.openCashDrawer();
        if (drawerOpened) {
          print('✅ Cajón monedero abierto correctamente');
        } else {
          print('❌ Error: El cajón monedero NO se pudo abrir');
        }
        
        Get.snackbar(
          'Venta completada',
          'El recibo se imprimió correctamente${drawerOpened ? ' y el cajón se abrió' : ''}\n¡Listo para la siguiente venta!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        print('❌ Error al imprimir el recibo');
        Get.snackbar(
          'Error de impresión',
          'Hubo un problema al imprimir el recibo',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
      
      // Limpiar el carrito y regresar al POS listo para la siguiente venta
      clearCart();
      
      // Asegurar que estamos en la pantalla de POS
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed('/pos'); // Regresar al POS limpio y listo
    } catch (e) {
      Get.back(); // Cerrar diálogo de imprimiendo
      Get.snackbar(
        'Error',
        'Error al imprimir: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      clearCart();
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF7C4DFF)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
} 