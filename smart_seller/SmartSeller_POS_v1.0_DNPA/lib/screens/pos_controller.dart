import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/client.dart';
import '../services/sqlite_database_service.dart';
import '../services/auth_service.dart';
import '../modules/accounting/services/accounting_service.dart';
import '../modules/accounting/services/accounts_receivable_payable_service.dart';
import '../modules/accounting/models/accounts_receivable.dart';

import '../services/print_service.dart';
import '../services/company_config_service.dart';
import '../utils/puntos_miles_input_formatter.dart';
import 'package:intl/intl.dart';

class CartItem {
  final String name;
  double price;
  final String unit;
  int quantity;

  /// IVA por ítem: 19 = gravado, 0 = exento. Por defecto 19.
  final int ivaPercentage;

  CartItem({
    required this.name,
    required this.price,
    required this.unit,
    this.quantity = 1,
    this.ivaPercentage = 19,
  });

  double get total => price * quantity;

  String get displayInfo => '$quantity $unit';

  CartItem copy() => CartItem(
      name: name,
      price: price,
      unit: unit,
      quantity: quantity,
      ivaPercentage: ivaPercentage);
}

/// Carrito guardado en espera para atender otro cliente y recuperar después.
class HeldSale {
  final String label;
  final List<CartItem> items;
  final DateTime savedAt;
  final int? customerId;
  final int? clientId;

  HeldSale({
    required this.label,
    required this.items,
    DateTime? savedAt,
    this.customerId,
    this.clientId,
  }) : savedAt = savedAt ?? DateTime.now();

  double get total => items.fold(0.0, (sum, i) => sum + i.total);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}

class PosController extends GetxController {
  var cartItems = <CartItem>[].obs;

  /// Hasta 3 carritos en espera. Se persisten al salir del módulo POS para poder ir a Inventario y volver.
  static const int maxHeldSales = 3;
  static const String _keyHeldSales = 'pos_held_sales';
  var heldSales = <HeldSale>[].obs;

  /// Carrito actual: se persiste al salir del POS (config, inventario, etc.) para que al volver siga ahí.
  static const String _keyCurrentCart = 'pos_current_cart';

  /// Para recibo: monto recibido y vuelto en pago efectivo (se pasan al imprimir).
  double? _lastCashReceived;
  double? _lastChange;
  void setLastCashPayment(double received, double change) {
    _lastCashReceived = received;
    _lastChange = change;
  }

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

  /// Id para GetBuilder: pestañas y sección cliente se actualizan con update(['customer_tabs']).
  static const String customerTabsId = 'customer_tabs';

  /// Disparador para forzar que la UI (pestaña y sección cliente) se actualice al cambiar cliente.
  var customerDisplayVersion = 0.obs;
  void notifyCustomerDisplayChanged() {
    customerDisplayVersion.value = customerDisplayVersion.value + 1;
    update([customerTabsId]);
  }

  // ✅ NUEVO: Callback para limpiar campo de búsqueda
  Function()? onClearSearchField;

  @override
  void onReady() {
    super.onReady();
    _loadHeldSalesFromStorage();
    _loadCurrentCartFromStorage();
  }

  @override
  void onClose() {
    _saveCurrentCartToStorage();
    super.onClose();
  }

  /// Persiste el carrito actual al salir del POS para que al volver (config, inventario, etc.) siga ahí.
  Future<void> _saveCurrentCartToStorage() async {
    try {
      if (cartItems.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'items': cartItems
            .map((i) => {
                  'name': i.name,
                  'price': i.price,
                  'unit': i.unit,
                  'quantity': i.quantity,
                  'ivaPercentage': i.ivaPercentage,
                })
            .toList(),
        'customerId': selectedCustomer.value?.id,
        'clientId': selectedClient.value?.id,
      };
      await prefs.setString(_keyCurrentCart, jsonEncode(data));
    } catch (e) {
      print('⚠️ No se pudo guardar carrito actual: $e');
    }
  }

  /// Carga el carrito actual guardado al volver al POS.
  Future<void> _loadCurrentCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCurrentCart);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      if (map == null) return;
      final itemsList = map['items'] as List<dynamic>? ?? [];
      if (itemsList.isEmpty) {
        await prefs.remove(_keyCurrentCart);
        return;
      }
      final items = itemsList.map((i) {
        final item = i as Map<String, dynamic>;
        return CartItem(
          name: item['name'] as String? ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0,
          unit: item['unit'] as String? ?? 'unidad',
          quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          ivaPercentage: (item['ivaPercentage'] as num?)?.toInt() ?? 19,
        );
      }).toList();
      cartItems.assignAll(items);
      final customerId = (map['customerId'] as num?)?.toInt();
      final clientId = (map['clientId'] as num?)?.toInt();
      if (customerId != null) {
        final c = await SQLiteDatabaseService.getCustomerById(customerId);
        selectedCustomer.value = c;
      } else {
        selectedCustomer.value = null;
      }
      if (clientId != null) {
        final c = await SQLiteDatabaseService.getClientById(clientId);
        selectedClient.value = c;
      } else {
        selectedClient.value = null;
      }
      notifyCustomerDisplayChanged();
      await prefs.remove(_keyCurrentCart);
    } catch (e) {
      print('⚠️ No se pudo cargar carrito actual: $e');
    }
  }

  /// Borra el carrito actual guardado (se llama al finalizar una venta para no restaurar después).
  Future<void> _clearCurrentCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCurrentCart);
    } catch (_) {}
  }

  /// Persiste los carritos en espera para que sigan disponibles al salir del POS (ej. a Inventario) y volver.
  Future<void> _saveHeldSalesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = heldSales
          .map((h) => {
                'label': h.label,
                'savedAt': h.savedAt.toIso8601String(),
                'customerId': h.customerId,
                'clientId': h.clientId,
                'items': h.items
                    .map((i) => {
                          'name': i.name,
                          'price': i.price,
                          'unit': i.unit,
                          'quantity': i.quantity,
                          'ivaPercentage': i.ivaPercentage,
                        })
                    .toList(),
              })
          .toList();
      await prefs.setString(_keyHeldSales, jsonEncode(list));
    } catch (e) {
      print('⚠️ No se pudieron guardar carritos en espera: $e');
    }
  }

  /// Carga los carritos en espera guardados (al volver al módulo POS).
  Future<void> _loadHeldSalesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyHeldSales);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null || list.isEmpty) return;
      final loaded = <HeldSale>[];
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final itemsList = map['items'] as List<dynamic>? ?? [];
        final items = itemsList.map((i) {
          final item = i as Map<String, dynamic>;
          return CartItem(
            name: item['name'] as String? ?? '',
            price: (item['price'] as num?)?.toDouble() ?? 0,
            unit: item['unit'] as String? ?? 'unidad',
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            ivaPercentage: (item['ivaPercentage'] as num?)?.toInt() ?? 19,
          );
        }).toList();
        if (items.isEmpty) continue;
        final savedAtStr = map['savedAt'] as String?;
        loaded.add(HeldSale(
          label: map['label'] as String? ?? 'Carrito en espera',
          items: items,
          savedAt: savedAtStr != null ? DateTime.tryParse(savedAtStr) : null,
          customerId: (map['customerId'] as num?)?.toInt(),
          clientId: (map['clientId'] as num?)?.toInt(),
        ));
      }
      if (loaded.isNotEmpty) heldSales.value = loaded;
    } catch (e) {
      print('⚠️ No se pudieron cargar carritos en espera: $e');
    }
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
            (customer.documentNumber?.toLowerCase().contains(searchLower) ??
                false) ||
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => notifyCustomerDisplayChanged());
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
    notifyCustomerDisplayChanged();
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => notifyCustomerDisplayChanged());
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
    notifyCustomerDisplayChanged();
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

  // ✅ NUEVO: Método para mostrar modal de selección de cliente (retorna Future para que la pantalla restaure foco al cerrar y F6 funcione)
  Future<void> showCustomerSelectionModal() async {
    await Get.dialog(
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
                autofocus: true,
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

                  if (customerSearchResults.isEmpty &&
                      customerSearchQuery.value.isNotEmpty) {
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
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.email),
                            Text(
                                '${customer.pointsRate} pts/\$1000 - Acumulados: ${customer.accumulatedPoints}'),
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

  // Actualizar puntos del cliente después de la venta (solo acumulación: por cada X pesos = Y puntos)
  Future<void> updateCustomerAfterSale() async {
    if (selectedCustomer.value == null) return;

    try {
      final customer = selectedCustomer.value!;
      final config = await CompanyConfigService.getCompanyConfig();
      int pointsEarned = 0;
      if (config.pointsEnabled && config.pointsPesosBase > 0) {
        pointsEarned = ((total / config.pointsPesosBase).floor() * config.pointsPerBase).toInt();
      }
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

      print(
          '✅ Cliente actualizado: ${customer.name} - Puntos ganados: $pointsEarned - Acumulados: $newAccumulatedPoints - Total: \$$newTotalPurchases');

      // Limpiar cliente seleccionado
      selectedCustomer.value = null;
    } catch (e) {
      print('❌ Error actualizando cliente: $e');
    }
  }

  // Agregar producto al carrito
  void addToCart(
    String name,
    double price,
    String unit, {
    int quantity = 1,
    int? availableStock,
    int ivaPercentage = 19,
  }) {
    // Buscar si el producto ya existe en el carrito
    final existingIndex = cartItems.indexWhere((item) => item.name == name);

    if (existingIndex >= 0) {
      // Si existe, verificar stock antes de aumentar
      final currentQuantity = cartItems[existingIndex].quantity;
      if (availableStock != null &&
          currentQuantity + quantity > availableStock) {
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
      cartItems.add(CartItem(
        name: name,
        price: price,
        unit: unit,
        quantity: quantity,
        ivaPercentage: ivaPercentage,
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
        ivaPercentage: item.ivaPercentage,
      );
      cartItems[index] = updatedItem;
      cartItems.refresh();

      Get.snackbar(
        'Precio actualizado',
        'Precio cambiado a \$${newPrice.toStringAsFixed(0)}',
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

  /// Guarda el carrito actual en espera y deja el carrito vacío para atender otro cliente.
  void holdCurrentSale() {
    if (cartItems.isEmpty) {
      Get.snackbar(
        'Carrito vacío',
        'No hay productos para dejar en espera',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (heldSales.length >= maxHeldSales) {
      Get.snackbar(
        'Límite de carritos en espera',
        'Solo puedes tener hasta $maxHeldSales carritos en espera. Recupera o cancela uno.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    // Si hay cliente seleccionado, usar su nombre como etiqueta del carrito en espera.
    String label;
    final cust = selectedCustomer.value;
    final cli = selectedClient.value;
    if (cust != null && cust.name.trim().isNotEmpty) {
      label = cust.name.trim();
    } else if (cli != null && cli.businessName.trim().isNotEmpty) {
      label = cli.businessName.trim();
    } else {
      label = 'Carrito en espera ${heldSales.length + 1}';
    }
    final copy = cartItems.map((e) => e.copy()).toList();
    heldSales.add(HeldSale(
      label: label,
      items: copy,
      customerId: cust?.id,
      clientId: cli?.id,
    ));
    cartItems.clear();
    // Nueva venta limpia: sin cliente del sistema ni cliente de facturación
    selectedCustomer.value = null;
    selectedClient.value = null;
    notifyCustomerDisplayChanged();
    _saveHeldSalesToStorage();
    Get.snackbar(
      'En espera',
      '$label guardada. Puedes salir a Inventario y al volver recuperarla aquí.',
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Recupera una venta en espera al carrito (la quita de la lista de espera).
  Future<void> recallHeldSale(int index) async {
    if (index < 0 || index >= heldSales.length) return;
    final held = heldSales[index];
    final label = held.label.trim();

    // 1) Cargar cliente por ID si está guardado
    Customer? newCustomer;
    Client? newClient;
    if (held.customerId != null) {
      newCustomer =
          await SQLiteDatabaseService.getCustomerById(held.customerId!);
    }
    if (held.clientId != null) {
      newClient = await SQLiteDatabaseService.getClientById(held.clientId!);
    }

    // 2) Si no hay ID guardado pero la etiqueta tiene nombre, buscar por nombre (cliente sistema y/o facturación)
    if (label.isNotEmpty && !label.startsWith('Carrito en espera')) {
      if (newCustomer == null) {
        final customers = await SQLiteDatabaseService.getAllCustomers();
        for (final c in customers) {
          if (c.name.trim().toLowerCase() == label.toLowerCase()) {
            newCustomer = c;
            break;
          }
        }
      }
      if (newClient == null) {
        final clients =
            await SQLiteDatabaseService.searchClientsByBusinessName(label);
        if (clients.isNotEmpty) {
          newClient = clients.firstWhere(
            (c) => c.businessName.trim().toLowerCase() == label.toLowerCase(),
            orElse: () => clients.first,
          );
        }
      }
    }

    selectedCustomer.value = newCustomer;
    selectedClient.value = newClient;
    cartItems.clear();
    for (final item in held.items) {
      cartItems.add(CartItem(
        name: item.name,
        price: item.price,
        unit: item.unit,
        quantity: item.quantity,
        ivaPercentage: item.ivaPercentage,
      ));
    }
    heldSales.removeAt(index);
    _saveHeldSalesToStorage();

    // Forzar que la UI se actualice ya (pestaña y sección cliente)
    notifyCustomerDisplayChanged();

    Get.back();
    // Vuelve a forzar actualización cuando ya se cerró el modal, por si la primera no pintó
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyCustomerDisplayChanged();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => notifyCustomerDisplayChanged());
    });
    Get.snackbar(
      'Recuperado',
      '${held.label} cargado en el carrito',
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Elimina una venta en espera sin recuperarla. También quita cualquier otro carrito vacío para no dejar dos pestañas "Venta actual".
  void cancelHeldSale(int index) {
    if (index < 0 || index >= heldSales.length) return;
    final label = heldSales[index].label;
    heldSales.removeAt(index);
    _removeEmptyHeldSales(); // quitar carritos vacíos (ej. "Venta actual" 0 ítems) que hayan quedado de un intercambio
    _saveHeldSalesToStorage();
    Get.back();
    Get.snackbar(
      'Cancelada',
      '$label eliminado',
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Quita de la lista en espera los carritos que ya no tienen ítems (evita dos pestañas "Venta actual" tras liquidar).
  void _removeEmptyHeldSales() {
    final toKeep = heldSales.where((h) => h.items.isNotEmpty).toList();
    if (toKeep.length != heldSales.length) {
      heldSales.value = toKeep;
      _saveHeldSalesToStorage();
    }
  }

  /// Limpia todos los carritos (actual y en espera). Se usa al hacer cierre de caja manual.
  Future<void> clearAllCartsOnCashClose() async {
    cartItems.clear();
    heldSales.clear();
    selectedCustomer.value = null;
    selectedClient.value = null;
    notifyCustomerDisplayChanged();
    await _saveHeldSalesToStorage();
  }

  /// Cambia a un carrito en espera: intercambia el carrito actual con el de ese slot (para alternar entre clientes sin abrir el diálogo).
  Future<void> switchToHeldSale(int index) async {
    if (index < 0 || index >= heldSales.length) return;
    final held = heldSales[index];

    // Guardar copia del carrito actual y su cliente asociado
    final currentCopy = cartItems.map((e) => e.copy()).toList();
    final currentCustomerId = selectedCustomer.value?.id;
    final currentClientId = selectedClient.value?.id;
    final currentCustomerName = selectedCustomer.value?.name.trim();
    final currentClientName = selectedClient.value?.businessName.trim();

    // Cargar cliente asociado al carrito seleccionado (si existe)
    Customer? newCustomer;
    Client? newClient;
    if (held.customerId != null) {
      newCustomer =
          await SQLiteDatabaseService.getCustomerById(held.customerId!);
    }
    if (held.clientId != null) {
      newClient = await SQLiteDatabaseService.getClientById(held.clientId!);
    }

    selectedCustomer.value = newCustomer;
    selectedClient.value = newClient;
    notifyCustomerDisplayChanged();

    // Cambiar los ítems del carrito al seleccionado
    cartItems.assignAll(held.items.map((e) => e.copy()));

    // Dejar en espera el carrito que estaba activo; la etiqueta debe describir ESE carrito, no el de Oscar
    final newList = List<HeldSale>.from(heldSales);
    final labelForSlot =
        (currentCustomerName != null && currentCustomerName.isNotEmpty)
            ? currentCustomerName
            : (currentClientName != null && currentClientName.isNotEmpty)
                ? currentClientName
                : 'Venta actual';
    newList[index] = HeldSale(
      label: labelForSlot,
      items: currentCopy,
      customerId: currentCustomerId,
      clientId: currentClientId,
    );
    heldSales.value = newList;
    _saveHeldSalesToStorage();

    Get.snackbar(
      'Cambiado',
      newCustomer != null || newClient != null
          ? 'Ahora estás en ${held.label}'
          : 'Ahora estás en un carrito sin cliente asignado',
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  // Calcular subtotal
  double get subtotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.total);
  }

  // Calcular impuestos según % por ítem (0%, 5%, 19%)
  double get taxes {
    return cartItems.fold(
        0.0, (sum, item) => sum + (item.total * (item.ivaPercentage / 100)));
  }

  /// IVA a 19% (para mostrar en pantalla e impresión)
  double get taxAt19 => cartItems.fold(
      0.0,
      (sum, item) => item.ivaPercentage == 19
          ? sum + (item.total * 0.19)
          : sum);

  /// IVA a 5% (para mostrar en pantalla e impresión)
  double get taxAt5 => cartItems.fold(
      0.0,
      (sum, item) =>
          item.ivaPercentage == 5 ? sum + (item.total * 0.05) : sum);

  /// IVA exento (0%) - monto base sin IVA
  double get taxAt0 => 0.0;

  // Calcular total
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
    final NumberFormat copFormat = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '\$ ',
        decimalDigits: 0,
        customPattern: '\u00A4#,##0');
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
                'Total a pagar: ${copFormat.format(total)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50)),
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
                      onTap: () => _showCashReceivedDialog(copFormat),
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
              const SizedBox(height: 12),
              // Pago mixto: parte efectivo, parte Nequi, etc.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showMixedPaymentDialog(copFormat),
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text(
                      'Pago mixto (ej. parte efectivo, parte Nequi)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Venta a crédito: queda en cuentas por cobrar (requiere cliente seleccionado)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _processCreditSale(copFormat),
                  icon: const Icon(Icons.schedule),
                  label: const Text('A crédito (cuenta por cobrar)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade800),
                  ),
                ),
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

  /// Tras confirmar pago en efectivo: abre cajón para entregar vuelto, luego procesa venta y pregunta si imprime.
  Future<void> _onConfirmCashPayment() async {
    try {
      final printService = PrintService.instance;
      await printService.initialize();
      Get.snackbar(
        'Entregue el vuelto',
        'Abriendo cajón monedero...',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      await printService.openCashDrawer();
    } catch (_) {}
    _processPaymentWithMethod('Efectivo');
  }

  /// Diálogo para pago en efectivo: ingresa monto recibido y muestra vuelto.
  /// Usa punto de miles automático (Colombia) para no confundir cifras.
  void _showCashReceivedDialog(NumberFormat copFormat) {
    Get.back(); // Cierra el diálogo de métodos de pago
    final totalToPay = total;
    final controller =
        TextEditingController(); // Vacío para que el cajero ingrese con cuánto le pagan
    final vuelto = 0.0.obs;
    final canConfirm = false.obs;

    void updateVuelto() {
      final value = parseMontoPuntosMiles(controller.text) ?? 0;
      canConfirm.value = value >= totalToPay;
      vuelto.value = value >= totalToPay ? value - totalToPay : 0;
    }

    Get.dialog(
      Dialog(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pago en efectivo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Total a pagar: ${copFormat.format(totalToPay)}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50)),
              ),
              const SizedBox(height: 20),
              const Text('Monto con que paga:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  PuntosMilesInputFormatter(),
                ],
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 10.000',
                ),
                onChanged: (_) => updateVuelto(),
                onSubmitted: (_) {
                  final value = parseMontoPuntosMiles(controller.text) ?? 0;
                  if (value >= totalToPay) {
                    setLastCashPayment(value, value - totalToPay);
                    Get.back();
                    _onConfirmCashPayment();
                  }
                },
              ),
              const SizedBox(height: 16),
              Obx(() => Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vuelto:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '\$ ${formatMontoPuntosMiles(vuelto.value)}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                          onPressed: canConfirm.value
                              ? () {
                                  final value =
                                      parseMontoPuntosMiles(controller.text) ??
                                          0.0;
                                  if (value >= totalToPay) {
                                    setLastCashPayment(
                                        value, value - totalToPay);
                                    Get.back();
                                    _onConfirmCashPayment();
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => updateVuelto());
    controller.addListener(updateVuelto);
  }

  static const List<String> _paymentMethodOptions = [
    'Efectivo',
    'Tarjeta',
    'Transferencia',
    'QR',
    'Nequi',
    'Daviplata',
  ];

  void _showMixedPaymentDialog(NumberFormat copFormat) {
    Get.back(); // Cierra el diálogo de métodos de pago
    final totalToPay = total;
    final parts = <PaymentPart>[];
    final amountControllers = <TextEditingController>[];

    void addRow() {
      parts.add(PaymentPart(method: 'Efectivo', amount: 0));
      amountControllers.add(TextEditingController(text: '0'));
    }

    addRow(); // Una fila inicial

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          double suma = 0;
          for (var i = 0; i < amountControllers.length; i++) {
            suma += parseMontoPuntosMiles(amountControllers[i].text) ?? 0.0;
          }
          final restante = totalToPay - suma;
          final canConfirm = parts.isNotEmpty &&
              suma >= totalToPay - 0.01 &&
              suma <= totalToPay + 0.01;

          return Dialog(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pago mixto',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${copFormat.format(totalToPay)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(parts.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 130,
                              child: DropdownButton<String>(
                                value: parts[i].method,
                                isExpanded: true,
                                items: _paymentMethodOptions
                                    .map((m) => DropdownMenuItem(
                                        value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    parts[i] = PaymentPart(
                                        method: v, amount: parts[i].amount);
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: amountControllers[i],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  PuntosMilesInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: '0',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (parts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  amountControllers[i].dispose();
                                  amountControllers.removeAt(i);
                                  parts.removeAt(i);
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        addRow();
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar otro pago'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: restante.abs() < 0.01
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: restante.abs() < 0.01
                                ? Colors.green
                                : Colors.orange),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Suma: ${copFormat.format(suma)}'),
                          Text(
                            'Restante: ${copFormat.format(restante)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                            onPressed: () {
                              for (final c in amountControllers) {
                                c.dispose();
                              }
                              Get.back();
                            },
                            child: const Text('Cancelar')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canConfirm
                                ? () {
                                    for (var i = 0; i < parts.length; i++) {
                                      final a = parseMontoPuntosMiles(
                                              amountControllers[i].text) ??
                                          0.0;
                                      parts[i] = PaymentPart(
                                          method: parts[i].method, amount: a);
                                    }
                                    for (final c in amountControllers) {
                                      c.dispose();
                                    }
                                    Get.back();
                                    _processPaymentWithBreakdown(
                                        List.from(parts), copFormat);
                                  }
                                : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Confirmar'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  void _processPaymentWithBreakdown(
      List<PaymentPart> parts, NumberFormat copFormat) async {
    Get.back();
    final totalToPay = total;
    final sum = parts.fold(0.0, (s, p) => s + p.amount);
    if (sum < totalToPay - 0.01 || sum > totalToPay + 0.01) {
      Get.snackbar('Error', 'La suma de los pagos debe ser igual al total',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    try {
      final sale = Sale(
        date: DateTime.now(),
        total: totalToPay,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: 'Mixto',
        paymentBreakdown: parts,
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                ))
            .toList(),
      );
      await SQLiteDatabaseService.saveSale(sale);
      try {
        final currentUser = AuthService.to.currentUser;
        if (currentUser != null && currentUser.id != null) {
          for (final part in parts) {
            await AccountingService.recordSaleIncome(
              part.amount,
              'Venta POS - ${part.method}',
              currentUser.id!,
              paymentMethod: part.method,
              reference: 'sale_mixto',
            );
          }
        }
      } catch (e) {
        print('❌ Error registrando ingreso contable: $e');
      }
      final customerForReceipt = selectedCustomer.value;
      final clientForReceipt = selectedClient.value;
      await updateCustomerAfterSale();
      _showPrintConfirmationDialog(sale, 'Mixto', copFormat,
          customer: customerForReceipt, client: clientForReceipt);
    } catch (e) {
      Get.snackbar('Error', 'Error al procesar la venta: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// Venta a crédito: requiere cliente seleccionado. Guarda venta y crea cuenta por cobrar.
  Future<void> _processCreditSale(NumberFormat copFormat) async {
    Get.back(); // Cierra diálogo de métodos de pago
    final customer = selectedCustomer.value;
    if (customer == null || customer.id == null) {
      Get.snackbar(
        'Cliente requerido',
        'Para venta a crédito debe seleccionar un cliente (Cliente del Sistema).',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    try {
      final sale = Sale(
        date: DateTime.now(),
        total: total,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: 'Crédito',
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                ))
            .toList(),
      );
      await SQLiteDatabaseService.saveSale(sale);
      // No registrar ingreso en caja (es por cobrar). Crear cuenta por cobrar.
      final invoiceNumber = 'POS-${sale.id ?? 0}';
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 30));
      final receivable = AccountsReceivable(
        customerId: customer.id!,
        customerName: customer.name,
        customerDocument: customer.documentNumber?.trim() ??
            customer.documentType ??
            'Sin documento',
        totalAmount: total,
        paidAmount: 0,
        pendingAmount: total,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
        dueDate: dueDate,
        status: 'pending',
        notes: 'Venta POS a crédito - Recibo $invoiceNumber',
        createdAt: now,
        updatedAt: now,
      );
      await AccountsReceivablePayableService.createAccountsReceivable(
          receivable);
      final customerForReceipt = selectedCustomer.value;
      final clientForReceipt = selectedClient.value;
      // No sumar puntos en venta a crédito (se dan cuando el cliente pague)
      _showPrintConfirmationDialog(sale, 'Crédito', copFormat,
          customer: customerForReceipt, client: clientForReceipt);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al registrar venta a crédito: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _processPaymentWithMethod(String method) async {
    final NumberFormat copFormat = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '\$ ',
        decimalDigits: 0,
        customPattern: '\u00A4#,##0');
    Get.back(); // Cierra el diálogo de métodos de pago

    try {
      // Crear la venta (guardar cliente para reimpresión con nombre en ticket)
      final sale = Sale(
        date: DateTime.now(),
        total: total,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: method,
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                ))
            .toList(),
      );

      // Guardar la venta
      await SQLiteDatabaseService.saveSale(sale);

      // ✅ NUEVO: Registrar ingreso contable automático
      try {
        final currentUser = AuthService.to.currentUser;
        if (currentUser != null && currentUser.id != null) {
          await AccountingService.recordSaleIncome(
            total,
            'Venta POS - $method',
            currentUser.id!,
            paymentMethod: method,
            reference: 'sale_${sale.id ?? 'temp'}',
          );
          print('✅ Ingreso contable registrado automáticamente: \$$total');
        }
      } catch (e) {
        print('❌ Error registrando ingreso contable: $e');
        // No interrumpir la venta por error contable
      }

      // Guardar referencias para el ticket (antes de limpiar en updateCustomerAfterSale)
      final customerForReceipt = selectedCustomer.value;
      final clientForReceipt = selectedClient.value;

      // ✅ NUEVO: Actualizar puntos del cliente si hay uno seleccionado
      await updateCustomerAfterSale();

      // El stock se actualiza automáticamente en saveSale

      // Mostrar confirmación con opción de imprimir (pasamos cliente sistema y/o facturación para el ticket)
      _showPrintConfirmationDialog(sale, method, copFormat,
          customer: customerForReceipt, client: clientForReceipt);
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
  void _showPrintConfirmationDialog(
      Sale sale, String method, NumberFormat copFormat,
      {Customer? customer, Client? client}) {
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

      // ✅ MEJORADO: Ejecutar impresión después de cerrar modal (con cliente guardado para el ticket)
      Future.delayed(const Duration(milliseconds: 100), () {
        _printReceipt(sale, method, copFormat,
            customer: customer, client: client);
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

      // ✅ MEJORADO: Limpiar carrito y quitar carritos vacíos en espera (evitar varias pestañas "Venta actual")
      Future.delayed(const Duration(milliseconds: 100), () {
        clearCart();
        _clearCurrentCartFromStorage();
        selectedCustomer.value = null;
        selectedClient.value = null;
        _removeEmptyHeldSales();
        notifyCustomerDisplayChanged();

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
                  'Total: ${copFormat.format(total)}',
                  style:
                      const TextStyle(fontSize: 18, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 8),
                Text(
                  method == 'Mixto' && sale.paymentBreakdown != null
                      ? 'Método: Mixto (${sale.paymentBreakdown!.map((p) => '${p.method}: ${copFormat.format(p.amount)}').join(', ')})'
                      : 'Método: $method',
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

  // Imprimir recibo (customer/client: datos para ticket; si no se pasan, usa selectedCustomer/selectedClient)
  void _printReceipt(Sale sale, String method, NumberFormat copFormat,
      {Customer? customer, Client? client}) async {
    try {
      print('🖨️ Iniciando proceso de impresión...');

      // Mostrar diálogo de imprimiendo
      Get.dialog(
        Dialog(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
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

      print(
          '🔍 Estado de la impresora: ${printService.isConnected ? 'Conectada' : 'No conectada'}');
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
        _clearCurrentCartFromStorage();
        return;
      }

      // Imprimir recibo con desglose IVA (5% y 19%) según productos
      final success = await printService.printReceipt(
          sale, cartItems, subtotal, taxes, total,
          paymentMethod: sale.paymentMethod,
          receivedAmount: _lastCashReceived,
          changeAmount: _lastChange,
          customer: customer ?? selectedCustomer.value,
          client: client ?? selectedClient.value,
          vatAt19: taxAt19 > 0 ? taxAt19 : null,
          vatAt5: taxAt5 > 0 ? taxAt5 : null);

      _lastCashReceived = null;
      _lastChange = null;
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

      // Limpiar el carrito y quitar de "en espera" el slot vacío para no mostrar dos pestañas "Venta actual"
      clearCart();
      _clearCurrentCartFromStorage();
      selectedCustomer.value = null;
      selectedClient.value = null;
      _removeEmptyHeldSales();
      notifyCustomerDisplayChanged();

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
      _clearCurrentCartFromStorage();
      selectedCustomer.value = null;
      selectedClient.value = null;
      _removeEmptyHeldSales();
      notifyCustomerDisplayChanged();
    }
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
