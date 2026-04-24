import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../modules/accounting/models/receivable_payment.dart';

import '../services/print_service.dart';
import '../services/company_config_service.dart';
import '../models/permissions.dart';
import '../services/permissions_service.dart';
import '../services/authorization_service.dart';
import '../widgets/authorization_modal.dart';
import '../utils/puntos_miles_input_formatter.dart';
import 'package:intl/intl.dart';

/// Métodos de pago disponibles en POS (mixto, abono a crédito, etc.).
const List<String> kPosPaymentMethodOptions = [
  'Efectivo',
  'Tarjeta',
  'Transferencia',
  'QR',
  'Nequi',
  'Daviplata',
];

class CartItem {
  final String name;
  double price;
  final String unit;
  int quantity;

  /// IVA por ítem: 19 = gravado, 0 = exento. Por defecto 19.
  final int ivaPercentage;

  /// Coincide con `products.id` cuando el ítem viene del catálogo POS.
  final int? productId;

  /// Kg vendidos (inventario por kg). Si es null, el stock se controla por [quantity] en unidades.
  final double? weightKg;

  /// Trazabilidad de cambio de precio en carrito.
  final bool wasPriceEdited;
  final double? originalPrice;
  final DateTime? priceEditedAt;
  final String? priceEditedBy;
  final bool priceEditedFromIva;

  CartItem({
    required this.name,
    required this.price,
    required this.unit,
    this.quantity = 1,
    this.ivaPercentage = 19,
    this.productId,
    this.weightKg,
    this.wasPriceEdited = false,
    this.originalPrice,
    this.priceEditedAt,
    this.priceEditedBy,
    this.priceEditedFromIva = false,
  });

  double get total => price * quantity;

  String get displayInfo => '$quantity $unit';

  CartItem copy() => CartItem(
      name: name,
      price: price,
      unit: unit,
      quantity: quantity,
      ivaPercentage: ivaPercentage,
      productId: productId,
      weightKg: weightKg,
      wasPriceEdited: wasPriceEdited,
      originalPrice: originalPrice,
      priceEditedAt: priceEditedAt,
      priceEditedBy: priceEditedBy,
      priceEditedFromIva: priceEditedFromIva);
}

/// Carrito guardado en espera para atender otro cliente y recuperar después.
class HeldSale {
  final String label;
  final List<CartItem> items;
  final DateTime savedAt;
  final int? customerId;
  final int? clientId;

  /// Descuento % al cobrar asociado a este carrito (sobre subtotal + IVA).
  final double discountPercent;

  HeldSale({
    required this.label,
    required this.items,
    DateTime? savedAt,
    this.customerId,
    this.clientId,
    this.discountPercent = 0.0,
  }) : savedAt = savedAt ?? DateTime.now();

  double get total => items.fold(0.0, (sum, i) => sum + i.total);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}

class PosController extends GetxController {
  var cartItems = <CartItem>[].obs;

  /// Descuento global al cobrar: porcentaje sobre subtotal + IVA (requiere cliente y permiso).
  final cartDiscountPercent = 0.0.obs;

  /// Hasta 3 carritos en espera. Se persisten al salir del módulo POS para poder ir a Inventario y volver.
  static const int maxHeldSales = 3;
  static const String _keyHeldSales = 'pos_held_sales';
  var heldSales = <HeldSale>[].obs;

  /// Carrito actual: se persiste al salir del POS (config, inventario, etc.) para que al volver siga ahí.
  static const String _keyCurrentCart = 'pos_current_cart';

  /// Para recibo: monto recibido y vuelto en pago efectivo (se pasan al imprimir).
  double? _lastCashReceived;
  double? _lastChange;
  double? _creditReceiptAbono;
  double? _creditReceiptPending;
  String? _creditReceiptMethod;

  /// Crédito temporal de canje inmediato (devolución aplicada en esta misma visita).
  final immediateExchangeCredit = 0.0.obs;
  final immediateExchangeSourceSaleId = RxnInt();

  // Normalización centralizada para valores monetarios de caja (pesos enteros).
  double _normalizeCashAmount(num value) => value.toDouble().roundToDouble();

  bool _canCoverCashTotal(num received, num expectedTotal) =>
      _normalizeCashAmount(received) >= _normalizeCashAmount(expectedTotal);

  bool _isExactCashTotal(num paid, num expectedTotal) =>
      _normalizeCashAmount(paid) == _normalizeCashAmount(expectedTotal);

  double _calculateCashChange(num received, num expectedTotal) {
    final change =
        _normalizeCashAmount(received) - _normalizeCashAmount(expectedTotal);
    return change > 0 ? change : 0.0;
  }

  void setLastCashPayment(double received, double change) {
    _lastCashReceived = received;
    _lastChange = change;
  }

  void assignImmediateExchangeCredit(double amount, {int? sourceSaleId}) {
    final normalized = _normalizeCashAmount(amount);
    if (normalized <= 0) return;
    immediateExchangeCredit.value =
        _normalizeCashAmount(immediateExchangeCredit.value + normalized);
    immediateExchangeSourceSaleId.value = sourceSaleId;
  }

  void clearImmediateExchangeCredit({bool showSnack = false}) {
    if (immediateExchangeCredit.value <= 1e-9) return;
    immediateExchangeCredit.value = 0.0;
    immediateExchangeSourceSaleId.value = null;
    if (showSnack) {
      Get.snackbar(
        'Cambio inmediato',
        'Se limpió el saldo temporal de canje.',
        backgroundColor: Colors.blueGrey,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _decreaseImmediateExchangeCreditBy(double amount) {
    final n = _normalizeCashAmount(amount);
    if (n <= 0) return;
    final next = _normalizeCashAmount(immediateExchangeCredit.value - n)
        .clamp(0.0, double.infinity);
    immediateExchangeCredit.value = next;
    if (next <= 1e-9) {
      immediateExchangeSourceSaleId.value = null;
    }
  }

  void _consumeImmediateExchangeCredit(double usedAmount) {
    _decreaseImmediateExchangeCreditBy(usedAmount);
  }

  /// Crédito de canje que no cubre el total del carrito actual (sobrante a favor del cliente).
  double get immediateExchangeUnusedRemainder => _normalizeCashAmount(
        (immediateExchangeCredit.value - immediateExchangeApplied)
            .clamp(0.0, double.infinity),
      );

  /// Registra egreso por remanente de canje.
  /// Retorna `true` si se registró correctamente.
  Future<bool> refundImmediateExchangeUnusedRemainder(String paymentMethod) async {
    final amount = immediateExchangeUnusedRemainder;
    if (amount <= 1e-9) {
      Get.snackbar(
        'Canje inmediato',
        'No hay remanente por devolver respecto al carrito actual.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return false;
    }
    final uid = AuthService.to.currentUser?.id;
    if (uid == null) {
      Get.snackbar(
        'Sesión',
        'No hay usuario válido para registrar la devolución.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    try {
      final orig = immediateExchangeSourceSaleId.value;
      await AccountingService.recordExpense(
            amount,
            orig != null
                ? 'Devolución remanente cambio inmediato · Fact. orig. #${orig.toString().padLeft(6, '0')}'
                : 'Devolución remanente cambio inmediato',
            uid,
            category: 'Devolución POS (cambio inmediato)',
            paymentMethod: paymentMethod,
            reference:
                'instant_exchange_remainder_${DateTime.now().millisecondsSinceEpoch}',
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      final msg = e is TimeoutException
          ? 'Se demoró demasiado al registrar el egreso. Revise conexión/BD e intente de nuevo.'
          : e.toString().replaceFirst('Exception: ', '');
      Get.snackbar(
        'Contabilidad',
        'No se pudo registrar el egreso: $msg',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return false;
    }
    _decreaseImmediateExchangeCreditBy(amount);
    // Si la devolución se hace en efectivo, intentar abrir cajón automáticamente.
    if (paymentMethod.trim().toLowerCase() == 'efectivo') {
      try {
        final opened = await PrintService.instance.openCashDrawer();
        if (!opened) {
          Get.snackbar(
            'Cajón',
            'Remanente registrado, pero no se pudo abrir el cajón automáticamente.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } catch (_) {
        Get.snackbar(
          'Cajón',
          'Remanente registrado, pero hubo error al abrir el cajón.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
    Get.snackbar(
      'Canje inmediato',
      'Devolución registrada: \$${amount.toStringAsFixed(0)} ($paymentMethod).',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    return true;
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

  /// Tras guardar una venta en el POS: actualizar "Productos frecuentes" en pantalla.
  Function()? onSaleCompleted;

  void _notifySaleCompleted() {
    try {
      onSaleCompleted?.call();
    } catch (e) {
      print('onSaleCompleted: $e');
    }
  }

  String _normalizeForSearch(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

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
                  if (i.productId != null) 'productId': i.productId,
                  if (i.weightKg != null) 'weightKg': i.weightKg,
                  if (i.wasPriceEdited) 'wasPriceEdited': true,
                  if (i.originalPrice != null) 'originalPrice': i.originalPrice,
                  if (i.priceEditedAt != null)
                    'priceEditedAt': i.priceEditedAt!.toIso8601String(),
                  if (i.priceEditedBy != null) 'priceEditedBy': i.priceEditedBy,
                  if (i.priceEditedFromIva) 'priceEditedFromIva': true,
                })
            .toList(),
        'customerId': selectedCustomer.value?.id,
        'clientId': selectedClient.value?.id,
        'discountPercent': cartDiscountPercent.value,
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
          productId: (item['productId'] as num?)?.toInt(),
          weightKg: (item['weightKg'] as num?)?.toDouble(),
          wasPriceEdited: item['wasPriceEdited'] == true,
          originalPrice: (item['originalPrice'] as num?)?.toDouble(),
          priceEditedAt: item['priceEditedAt'] != null
              ? DateTime.tryParse(item['priceEditedAt'] as String)
              : null,
          priceEditedBy: item['priceEditedBy'] as String?,
          priceEditedFromIva: item['priceEditedFromIva'] == true,
        );
      }).toList();
      cartItems.assignAll(items);
      final dp = (map['discountPercent'] as num?)?.toDouble();
      if (dp != null && dp >= 0 && dp <= 100) {
        cartDiscountPercent.value = dp;
      } else {
        cartDiscountPercent.value = 0.0;
      }
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
      _syncCartDiscountWithCustomers();
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
                'discountPercent': h.discountPercent,
                'items': h.items
                    .map((i) => {
                          'name': i.name,
                          'price': i.price,
                          'unit': i.unit,
                          'quantity': i.quantity,
                          'ivaPercentage': i.ivaPercentage,
                          if (i.productId != null) 'productId': i.productId,
                          if (i.weightKg != null) 'weightKg': i.weightKg,
                          if (i.wasPriceEdited) 'wasPriceEdited': true,
                          if (i.originalPrice != null)
                            'originalPrice': i.originalPrice,
                          if (i.priceEditedAt != null)
                            'priceEditedAt': i.priceEditedAt!.toIso8601String(),
                          if (i.priceEditedBy != null)
                            'priceEditedBy': i.priceEditedBy,
                          if (i.priceEditedFromIva) 'priceEditedFromIva': true,
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
            productId: (item['productId'] as num?)?.toInt(),
            weightKg: (item['weightKg'] as num?)?.toDouble(),
            wasPriceEdited: item['wasPriceEdited'] == true,
            originalPrice: (item['originalPrice'] as num?)?.toDouble(),
            priceEditedAt: item['priceEditedAt'] != null
                ? DateTime.tryParse(item['priceEditedAt'] as String)
                : null,
            priceEditedBy: item['priceEditedBy'] as String?,
            priceEditedFromIva: item['priceEditedFromIva'] == true,
          );
        }).toList();
        if (items.isEmpty) continue;
        final savedAtStr = map['savedAt'] as String?;
        final heldDp = (map['discountPercent'] as num?)?.toDouble() ?? 0.0;
        loaded.add(HeldSale(
          label: map['label'] as String? ?? 'Carrito en espera',
          items: items,
          savedAt: savedAtStr != null ? DateTime.tryParse(savedAtStr) : null,
          customerId: (map['customerId'] as num?)?.toInt(),
          clientId: (map['clientId'] as num?)?.toInt(),
          discountPercent: heldDp.clamp(0.0, 100.0),
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
    Future.microtask(() => _reloadSelectedCustomerFromDb());
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
    _syncCartDiscountWithCustomers();
    notifyCustomerDisplayChanged();
    Get.snackbar(
      'Cliente removido',
      'No hay cliente seleccionado',
      duration: const Duration(seconds: 1),
    );
  }

  // ✅ Método para buscar clientes de facturación electrónica (BD real)
  Future<void> searchClients(String query) async {
    try {
      isSearchingClient.value = true;
      final allClients = await _getAllClients();

      // Si no hay texto, mostrar todos los clientes activos ordenados.
      if (query.trim().isEmpty) {
        clientSearchResults.value = allClients;
        return;
      }

      // Filtrar por nombre, email, documento o teléfono (tolerante a tildes y formato)
      final searchLower = query.toLowerCase().trim();
      final searchNormalized = _normalizeForSearch(query);
      final filtered = allClients.where((client) {
        final byName = client.businessName
                .toLowerCase()
                .contains(searchLower) ||
            _normalizeForSearch(client.businessName).contains(searchNormalized);
        final byEmail = (client.email?.toLowerCase().contains(searchLower) ??
                false) ||
            _normalizeForSearch(client.email ?? '').contains(searchNormalized);
        final byDoc =
            client.documentNumber.toLowerCase().contains(searchLower) ||
                _normalizeForSearch(client.documentNumber)
                    .contains(searchNormalized);
        final byPhone = (client.phone?.contains(query.trim()) ?? false) ||
            _normalizeForSearch(client.phone ?? '').contains(searchNormalized);
        return byName || byEmail || byDoc || byPhone;
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
    _syncCartDiscountWithCustomers();
    notifyCustomerDisplayChanged();
    Get.snackbar(
      'Cliente removido',
      'No hay cliente seleccionado para facturación electrónica',
      duration: const Duration(seconds: 1),
    );
  }

  // Obtener clientes desde SQLite (facturación electrónica)
  Future<List<Client>> _getAllClients() async {
    return SQLiteDatabaseService.getAllClients();
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
        pointsEarned =
            ((total / config.pointsPesosBase).floor() * config.pointsPerBase)
                .toInt();
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
    double? availableStockKg,
    double? weightKg,
    int ivaPercentage = 19,
    int? productId,
    bool mergeExisting = true,
  }) {
    // Buscar si el producto ya existe en el carrito (por id de catálogo o nombre+unidad)
    final existingIndex = mergeExisting
        ? cartItems.indexWhere((item) {
            if (productId != null &&
                item.productId != null &&
                item.productId == productId) {
              return true;
            }
            return item.name == name && item.unit == unit;
          })
        : -1;

    double kgInCartForProduct() {
      if (productId == null) return 0;
      return cartItems
          .where((i) => i.productId == productId && i.weightKg != null)
          .fold<double>(0.0, (s, i) => s + i.weightKg! * i.quantity);
    }

    if (existingIndex >= 0) {
      // Si existe, verificar stock antes de aumentar (solo unidades; ítems por kg no se fusionan)
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
      if (availableStockKg != null && weightKg != null && weightKg > 0) {
        if (kgInCartForProduct() + weightKg * quantity >
            availableStockKg + 1e-9) {
          Get.snackbar(
            'Sin stock',
            'No hay kilogramos suficientes de $name',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      } else if (availableStock != null && quantity > availableStock) {
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
        productId: productId,
        weightKg: weightKg,
      ));
    }
  }

  // Cambiar precio temporal de un item del carrito
  void changeItemPrice(int index, double newPrice) {
    updateItemPrice(index, newPrice);
    if (index >= 0 && index < cartItems.length) {
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
  void updateItemPrice(
    int index,
    double newPrice, {
    bool editedFromIva = false,
  }) {
    if (index >= 0 && index < cartItems.length && newPrice > 0) {
      final item = cartItems[index];
      final oldPrice = item.price;
      final now = DateTime.now();
      final editor = AuthService.to.currentUser?.username;
      cartItems[index] = CartItem(
        name: item.name,
        price: newPrice,
        unit: item.unit,
        quantity: item.quantity,
        ivaPercentage: item.ivaPercentage,
        productId: item.productId,
        weightKg: item.weightKg,
        wasPriceEdited: true,
        originalPrice: item.wasPriceEdited ? item.originalPrice : oldPrice,
        priceEditedAt: now,
        priceEditedBy: editor,
        priceEditedFromIva: editedFromIva,
      );
      cartItems.refresh();
    }
  }

  void _syncCartDiscountWithCustomers() {
    if (selectedCustomer.value == null && selectedClient.value == null) {
      cartDiscountPercent.value = 0.0;
    }
  }

  // Limpiar carrito
  void clearCart() {
    cartDiscountPercent.value = 0.0;
    cartItems.clear();
    // No llamar clearImmediateExchangeCredit aquí: tras una venta con canje puede
    // quedar saldo pendiente (remanente) hasta «Devolver remanente» o «Quitar».
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
      discountPercent: cartDiscountPercent.value.clamp(0.0, 100.0),
    ));
    cartItems.clear();
    cartDiscountPercent.value = 0.0;
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
    cartDiscountPercent.value = held.discountPercent.clamp(0.0, 100.0);
    for (final item in held.items) {
      cartItems.add(CartItem(
        name: item.name,
        price: item.price,
        unit: item.unit,
        quantity: item.quantity,
        ivaPercentage: item.ivaPercentage,
        productId: item.productId,
        weightKg: item.weightKg,
        wasPriceEdited: item.wasPriceEdited,
        originalPrice: item.originalPrice,
        priceEditedAt: item.priceEditedAt,
        priceEditedBy: item.priceEditedBy,
        priceEditedFromIva: item.priceEditedFromIva,
      ));
    }
    heldSales.removeAt(index);
    _saveHeldSalesToStorage();

    // Forzar que la UI se actualice ya (pestaña y sección cliente)
    _syncCartDiscountWithCustomers();
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
    cartDiscountPercent.value = 0.0;
    cartItems.clear();
    heldSales.clear();
    clearImmediateExchangeCredit();
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
    final currentDiscount = cartDiscountPercent.value.clamp(0.0, 100.0);
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
    cartDiscountPercent.value = held.discountPercent.clamp(0.0, 100.0);

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
      discountPercent: currentDiscount,
    );
    heldSales.value = newList;
    _saveHeldSalesToStorage();

    _syncCartDiscountWithCustomers();

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
      (sum, item) =>
          item.ivaPercentage == 19 ? sum + (item.total * 0.19) : sum);

  /// IVA a 5% (para mostrar en pantalla e impresión)
  double get taxAt5 => cartItems.fold(0.0,
      (sum, item) => item.ivaPercentage == 5 ? sum + (item.total * 0.05) : sum);

  /// IVA exento (0%) - monto base sin IVA
  double get taxAt0 => 0.0;

  /// Subtotal + IVA antes del descuento global al cobrar.
  double get grossTotal => subtotal + taxes;

  /// Monto descontado (pesos, redondeado) según [cartDiscountPercent] sobre [grossTotal].
  double get cartDiscountAmount {
    final p = cartDiscountPercent.value;
    if (p <= 0) return 0.0;
    final g = grossTotal;
    if (g <= 0) return 0.0;
    return (g * p / 100).roundToDouble();
  }

  /// Total a cobrar (neto tras descuento global).
  double get total =>
      (grossTotal - cartDiscountAmount).clamp(0.0, double.infinity);

  /// Monto del canje inmediato que realmente se puede aplicar en esta venta.
  double get immediateExchangeApplied =>
      math.min(immediateExchangeCredit.value, total);

  /// Valor que sí debe pagar el cliente después de aplicar canje inmediato.
  double get totalToCollect =>
      _normalizeCashAmount((total - immediateExchangeApplied).clamp(0.0, double.infinity));

  /// Campos de descuento para persistir en [Sale] (0 si no aplica).
  ({double amount, double percent}) get _cartSaleDiscount {
    final amt = cartDiscountAmount;
    final pct = cartDiscountPercent.value;
    if (amt <= 0 || pct <= 0) return (amount: 0.0, percent: 0.0);
    return (amount: amt, percent: pct);
  }

  /// Mismo flujo que el botón en «Método de pago»; se puede llamar desde el menú de opciones del ítem.
  void showCartGlobalDiscountDialog(NumberFormat copFormat) {
    _requestDiscountAuthorizationThenOpenDialog(copFormat);
  }

  /// Si el cajero no tiene [Permission.modifyCartPrice], pide autorización (mismo flujo que descuentos).
  void _requestDiscountAuthorizationThenOpenDialog(NumberFormat copFormat) {
    final role = AuthService.to.currentUser?.role;
    if (role != null &&
        PermissionsService.to.hasPermission(role, Permission.modifyCartPrice)) {
      openCartDiscountDialog(copFormat);
      return;
    }
    Get.dialog(
      AuthorizationModal(
        action: AuthorizationService.DISCOUNT_APPLY,
        onAuthorized: (_) =>
            openCartDiscountDialog(copFormat, skipPermissionCheck: true),
        onCancelled: () {},
      ),
      barrierDismissible: true,
    );
  }

  void openCartDiscountDialog(NumberFormat copFormat,
      {bool skipPermissionCheck = false}) {
    if (!skipPermissionCheck) {
      final role = AuthService.to.currentUser?.role;
      if (role == null ||
          !PermissionsService.to
              .hasPermission(role, Permission.modifyCartPrice)) {
        Get.snackbar(
          'Sin permiso',
          'No tiene permiso para aplicar descuento en el carrito.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
    }
    if (selectedCustomer.value == null && selectedClient.value == null) {
      Get.snackbar(
        'Cliente requerido',
        'Seleccione cliente de puntos o cliente de facturación para aplicar descuento %.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    final g = grossTotal;
    if (g <= 0) return;

    final initial = cartDiscountPercent.value;
    final ctrl = TextEditingController(
      text: initial > 0
          ? (initial == initial.roundToDouble()
              ? initial.round().toString()
              : initial.toStringAsFixed(1))
          : '',
    );

    void close() {
      ctrl.dispose();
      Get.back();
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Descuento % sobre el total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Se aplica sobre subtotal + IVA (${copFormat.format(g)}).',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Porcentaje',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: close, child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              cartDiscountPercent.value = 0.0;
              close();
            },
            child: const Text('Quitar descuento'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = ctrl.text.trim().replaceAll(',', '.');
              final v = double.tryParse(raw);
              if (v == null || v < 0 || v > 100) {
                Get.snackbar(
                  'Valor inválido',
                  'Ingrese un porcentaje entre 0 y 100.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              final disc = (g * v / 100).roundToDouble();
              if (g - disc < 1 && v > 0) {
                Get.snackbar(
                  'Total muy bajo',
                  'El descuento dejaría el total en menos de \$1.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                return;
              }
              cartDiscountPercent.value = v;
              close();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
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

  Future<void> _reloadSelectedCustomerFromDb() async {
    final id = selectedCustomer.value?.id;
    if (id == null) return;
    try {
      final c = await SQLiteDatabaseService.getCustomerById(id);
      if (c != null) selectedCustomer.value = c;
    } catch (_) {}
  }

  /// Saldo a favor insuficiente para la parte en «Saldo a favor» del pago mixto.
  Future<bool> _validateStoreCreditForPayment(double creditAmount) async {
    if (creditAmount <= 1e-9) return true;
    final cid = selectedCustomer.value?.id;
    if (cid == null) return false;
    final c = await SQLiteDatabaseService.getCustomerById(cid);
    return c != null && c.storeCredit + 1e-6 >= creditAmount;
  }

  void _showStoreCreditPlusComplementDialog(NumberFormat copFormat) {
    Get.back(); // Cierra el diálogo de métodos de pago
    final maxCred = selectedCustomer.value?.storeCredit ?? 0.0;
    final payTotal = totalToCollect;
    if (maxCred <= 0 || payTotal <= 0) return;
    final useCred = math.min(maxCred, payTotal);
    final rest = _normalizeCashAmount(payTotal - useCred);
    var complement = 'Tarjeta';

    void applyBreakdown(String secondMethod) {
      _processPaymentWithBreakdown(
        [
          PaymentPart(method: kSalePaymentMethodStoreCredit, amount: useCred),
          PaymentPart(method: secondMethod, amount: rest),
        ],
        copFormat,
      );
    }

    void openCashComplement() {
      Get.back();
      final controller = TextEditingController();
      final vuelto = 0.0.obs;
      final canConfirm = false.obs;
      void upd() {
        final value = parseMontoPuntosMiles(controller.text) ?? 0;
        canConfirm.value = _canCoverCashTotal(value, rest);
        vuelto.value = _calculateCashChange(value, rest);
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
                  'Complemento en efectivo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ya aplicado ${copFormat.format(useCred)} con saldo a favor.\n'
                  'Cobrar en efectivo: ${copFormat.format(rest)}',
                ),
                const SizedBox(height: 12),
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
                    labelText: 'Monto recibido',
                  ),
                  onChanged: (_) => upd(),
                ),
                const SizedBox(height: 12),
                Obx(() => Text('Vuelto: ${copFormat.format(vuelto.value)}')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () => Get.back(), child: const Text('Cancelar')),
                    const Spacer(),
                    Obx(() => ElevatedButton(
                          onPressed: canConfirm.value
                              ? () {
                                  final value =
                                      parseMontoPuntosMiles(controller.text) ??
                                          0.0;
                                  if (!_canCoverCashTotal(value, rest)) return;
                                  setLastCashPayment(
                                    _normalizeCashAmount(value),
                                    _calculateCashChange(value, rest),
                                  );
                                  Get.back();
                                  applyBreakdown('Efectivo');
                                }
                              : null,
                          child: const Text('Confirmar'),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Saldo a favor + complemento'),
        content: StatefulBuilder(
          builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo disponible: ${copFormat.format(maxCred)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                    'Se usará ${copFormat.format(useCred)} del saldo; complemento: ${copFormat.format(rest)}.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(complement),
                  initialValue: complement,
                  decoration: const InputDecoration(
                    labelText: 'Medio del complemento',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(
                        value: 'Transferencia', child: Text('Transferencia')),
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSt(() => complement = v);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              if (complement == 'Efectivo') {
                openCashComplement();
              } else {
                applyBreakdown(complement);
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
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

    await _reloadSelectedCustomerFromDb();

    // Mostrar opciones de pago (Builder: cerrar este modal con Navigator para no dejarlo debajo del flujo crédito)
    Get.dialog(
      Dialog(
        child: Builder(
          builder: (paymentDialogContext) => Container(
            width: 450,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(paymentDialogContext).height * 0.88,
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Método de Pago',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Obx(() => Text(
                        'Total a pagar: ${copFormat.format(totalToCollect)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50)),
                      )),
                  Obx(() {
                    final applied = immediateExchangeApplied;
                    if (applied <= 1e-9) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Canje inmediato aplicado: -${copFormat.format(applied)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange.shade700,
                            ),
                          ),
                          if (immediateExchangeSourceSaleId.value != null)
                            Text(
                              'Origen: Factura #${immediateExchangeSourceSaleId.value!.toString().padLeft(6, '0')}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700),
                            ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: () =>
                                  clearImmediateExchangeCredit(showSnack: true),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Quitar canje inmediato'),
                            ),
                          ),
                          if (immediateExchangeUnusedRemainder > 1e-9) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.amber.shade700, width: 1),
                              ),
                              child: Text(
                                'Sobrante del canje (a favor del cliente): '
                                '${copFormat.format(immediateExchangeUnusedRemainder)}.\n'
                                'Tras confirmar esta venta, use el aviso «Canje activo» '
                                'y «Devolver remanente» para registrar la devolución.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Colors.brown.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  Obx(() {
                    if (cartDiscountAmount <= 0) return const SizedBox.shrink();
                    final p = cartDiscountPercent.value;
                    final pctStr = p == p.roundToDouble()
                        ? p.round().toString()
                        : p.toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Incluye descuento $pctStr% (${copFormat.format(cartDiscountAmount)})',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Obx(() {
                    final hasClient = selectedCustomer.value != null ||
                        selectedClient.value != null;
                    if (grossTotal <= 0 || !hasClient) {
                      return const SizedBox.shrink();
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _requestDiscountAuthorizationThenOpenDialog(
                                copFormat),
                        icon: const Icon(Icons.percent),
                        label: Text(cartDiscountPercent.value > 0
                            ? 'Descuento ${cartDiscountPercent.value == cartDiscountPercent.value.roundToDouble() ? cartDiscountPercent.value.round().toString() : cartDiscountPercent.value.toStringAsFixed(1)}% (cambiar)'
                            : 'Descuento % al total'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: Colors.teal.shade800,
                          side: BorderSide(color: Colors.teal.shade700),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  Obx(() {
                    if (totalToCollect > 1e-9 || immediateExchangeApplied <= 1e-9) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _processPaymentWithMethod(kSalePaymentMethodInstantExchange),
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Confirmar cambio inmediato (sin cobro)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),

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
                          onTap: () =>
                              _processPaymentWithMethod('Transferencia'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentOption(
                          icon: Icons.qr_code,
                          title: 'QR',
                          subtitle: 'Nequi/Daviplata',
                          onTap: () => _showQRPaymentChoice(copFormat),
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
                  Obx(() {
                    final cust = selectedCustomer.value;
                    final sc = cust?.storeCredit ?? 0.0;
                    if (cust == null || sc <= 1e-9) {
                      return const SizedBox.shrink();
                    }
                    final pay = totalToCollect;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Saldo a favor del cliente: ${copFormat.format(sc)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (sc + 1e-6 >= pay)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _processPaymentWithMethod(
                                  kSalePaymentMethodStoreCredit),
                              icon: const Icon(Icons.savings_outlined),
                              label: const Text('Pagar todo con saldo a favor'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: Colors.teal.shade900,
                                side: BorderSide(color: Colors.teal.shade700),
                              ),
                            ),
                          ),
                        if (sc + 1e-6 < pay)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showStoreCreditPlusComplementDialog(
                                      copFormat),
                              icon: const Icon(Icons.balance),
                              label: const Text('Saldo a favor + otro medio'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: Colors.teal.shade900,
                                side: BorderSide(color: Colors.teal.shade700),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                  // Venta a crédito: queda en cuentas por cobrar (requiere cliente seleccionado)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (immediateExchangeApplied > 1e-9) {
                          Get.snackbar(
                            'Cambio inmediato',
                            'Para usar el canje inmediato finalice esta venta en contado (incluyendo pago mixto).',
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        Navigator.of(paymentDialogContext, rootNavigator: true)
                            .pop();
                        Future.microtask(
                            () => _openCreditReceivableDialogOnly(copFormat));
                      },
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
                    child:
                        const Text('Cancelar', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
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
    final requiredCash = totalToCollect;
    final controller =
        TextEditingController(); // Vacío para que el cajero ingrese con cuánto le pagan
    final vuelto = 0.0.obs;
    final canConfirm = false.obs;

    void updateVuelto() {
      final value = parseMontoPuntosMiles(controller.text) ?? 0;
      canConfirm.value = _canCoverCashTotal(value, requiredCash);
      vuelto.value = _calculateCashChange(value, requiredCash);
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
                'Total a pagar: ${copFormat.format(requiredCash)}',
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
                  if (_canCoverCashTotal(value, requiredCash)) {
                    setLastCashPayment(_normalizeCashAmount(value),
                        _calculateCashChange(value, requiredCash));
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
                                  if (_canCoverCashTotal(value, requiredCash)) {
                                    setLastCashPayment(
                                        _normalizeCashAmount(value),
                                        _calculateCashChange(
                                            value, requiredCash));
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

  void _showMixedPaymentDialog(NumberFormat copFormat) {
    Get.back(); // Cierra el diálogo de métodos de pago
    final requiredTotal = totalToCollect;
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
          final normalizedSum = _normalizeCashAmount(suma);
          final restante = requiredTotal - normalizedSum;
          final canConfirm = parts.isNotEmpty &&
              _isExactCashTotal(normalizedSum, requiredTotal);

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
                      'Total: ${copFormat.format(requiredTotal)}',
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
                                items: kPosPaymentMethodOptions
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
                        color: restante == 0
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                restante == 0 ? Colors.green : Colors.orange),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Suma: ${copFormat.format(normalizedSum)}'),
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
                                        method: parts[i].method,
                                        amount: _normalizeCashAmount(a),
                                      );
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

  Future<void> _processPaymentWithBreakdown(
      List<PaymentPart> parts, NumberFormat copFormat) async {
    Get.back();
    final requiredTotal = totalToCollect;
    final sum = _normalizeCashAmount(parts.fold(0.0, (s, p) => s + p.amount));
    if (!_isExactCashTotal(sum, requiredTotal)) {
      Get.snackbar('Error', 'La suma de los pagos debe ser igual al total',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    final creditPart = parts
        .where((p) => p.method == kSalePaymentMethodStoreCredit)
        .fold<double>(0.0, (s, p) => s + p.amount);
    if (creditPart > 0 && !await _validateStoreCreditForPayment(creditPart)) {
      Get.snackbar(
        'Saldo insuficiente',
        'El cliente no tiene saldo a favor suficiente para esta combinación de pago.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    try {
      final exchangeApplied = immediateExchangeApplied;
      final effectiveParts = <PaymentPart>[
        if (exchangeApplied > 1e-9)
          PaymentPart(
              method: kSalePaymentMethodInstantExchange, amount: exchangeApplied),
        ...parts,
      ];
      final saleMethod = effectiveParts.length > 1
          ? 'Mixto'
          : effectiveParts.first.method;
      final disc = _cartSaleDiscount;
      final sale = Sale(
        date: DateTime.now(),
        total: total,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: saleMethod,
        paymentBreakdown: effectiveParts.length > 1 ? effectiveParts : null,
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        discount: disc.amount > 0 ? disc.amount : null,
        discountPercentage: disc.percent > 0 ? disc.percent : null,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                  productId: item.productId,
                  weightKg: item.weightKg,
                  priceEditedInCart: item.wasPriceEdited,
                  originalUnitPrice: item.originalPrice,
                  priceEditedAt: item.priceEditedAt,
                  priceEditedBy: item.priceEditedBy,
                  priceEditedFromIva: item.priceEditedFromIva,
                ))
            .toList(),
      );
      await SQLiteDatabaseService.saveSale(sale);
      _notifySaleCompleted();

      final creditUsed = parts
          .where((p) => p.method == kSalePaymentMethodStoreCredit)
          .fold<double>(0.0, (s, p) => s + p.amount);
      if (creditUsed > 0 && selectedCustomer.value?.id != null) {
        try {
          await SQLiteDatabaseService.adjustCustomerStoreCredit(
            selectedCustomer.value!.id!,
            -creditUsed,
          );
          await _reloadSelectedCustomerFromDb();
        } catch (e) {
          Get.snackbar(
            'Saldo a favor',
            'Venta guardada pero error al descontar saldo: $e',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }

      try {
        final currentUser = AuthService.to.currentUser;
        if (currentUser != null && currentUser.id != null) {
          for (final part in effectiveParts) {
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
      _consumeImmediateExchangeCredit(exchangeApplied);
      _showPrintConfirmationDialog(sale, saleMethod, copFormat,
          customer: customerForReceipt, client: clientForReceipt);
    } catch (e) {
      Get.snackbar('Error', 'Error al procesar la venta: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// Abre solo el modal de crédito (el de «Método de pago» ya se cerró con Navigator desde su context).
  void _openCreditReceivableDialogOnly(NumberFormat copFormat) {
    Get.dialog(
      Dialog(
        child: _PosCreditReceivableDialog(
          pos: this,
          copFormat: copFormat,
        ),
      ),
      barrierDismissible: true,
    );
  }

  /// Venta a crédito con abono opcional. Crea cuenta por cobrar y, si hay abono, `receivable_payments` + ingreso en caja.
  Future<void> finalizeCreditSaleWithAbono(
    NumberFormat copFormat,
    double abonoInicial, {
    String abonoPaymentMethod = 'Efectivo',
  }) async {
    final customer = selectedCustomer.value;
    if (customer == null || customer.id == null) {
      Get.snackbar(
        'Cliente requerido',
        'Seleccione un cliente del sistema para venta a crédito.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    final normalizedTotal = _normalizeCashAmount(total);
    final abono =
        _normalizeCashAmount(abonoInicial).clamp(0.0, normalizedTotal);
    try {
      final disc = _cartSaleDiscount;
      final sale = Sale(
        date: DateTime.now(),
        total: normalizedTotal,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: 'Crédito',
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        discount: disc.amount > 0 ? disc.amount : null,
        discountPercentage: disc.percent > 0 ? disc.percent : null,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                  productId: item.productId,
                  weightKg: item.weightKg,
                  priceEditedInCart: item.wasPriceEdited,
                  originalUnitPrice: item.originalPrice,
                  priceEditedAt: item.priceEditedAt,
                  priceEditedBy: item.priceEditedBy,
                  priceEditedFromIva: item.priceEditedFromIva,
                ))
            .toList(),
      );
      await SQLiteDatabaseService.saveSale(sale);
      _notifySaleCompleted();
      final invoiceNumber = 'POS-${sale.id ?? 0}';
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 30));
      final receivable = AccountsReceivable(
        customerId: customer.id!,
        customerName: customer.name,
        customerDocument: customer.documentNumber?.trim() ??
            customer.documentType ??
            'Sin documento',
        totalAmount: normalizedTotal,
        paidAmount: 0,
        pendingAmount: normalizedTotal,
        invoiceNumber: invoiceNumber,
        invoiceDate: now,
        dueDate: dueDate,
        status: 'pending',
        notes: abono > 0
            ? 'Venta POS a crédito - $invoiceNumber (abono ${abono.toStringAsFixed(0)} $abonoPaymentMethod)'
            : 'Venta POS a crédito - $invoiceNumber',
        createdAt: now,
        updatedAt: now,
      );
      final receivableId =
          await AccountsReceivablePayableService.createAccountsReceivable(
              receivable);

      if (abono > 0) {
        final uid = AuthService.to.currentUser?.id ?? 0;
        if (uid == 0) {
          throw Exception('Usuario no válido para registrar abono');
        }
        await AccountsReceivablePayableService.recordReceivablePayment(
          ReceivablePayment(
            accountsReceivableId: receivableId,
            amount: abono,
            paymentDate: now,
            paymentMethod: abonoPaymentMethod,
            reference: invoiceNumber,
            notes: 'Abono inicial en POS',
            userId: uid,
            createdAt: now,
          ),
        );
        try {
          await AccountingService.recordReceivableCollection(
            abono,
            customer.name,
            invoiceNumber,
            uid,
            isFullPayment: false,
            paymentMethod: abonoPaymentMethod,
            reference: 'credit_down_payment',
            notes: 'Abono inicial en POS',
          );
        } catch (e) {
          Get.snackbar(
            'Aviso',
            'Abono registrado en cuenta por cobrar. No se pudo reflejar en caja contable: $e',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        }
      }

      // Contexto de impresión para recibo de venta a crédito (F6).
      _lastCashReceived = null;
      _lastChange = null;
      _creditReceiptAbono = abono;
      _creditReceiptPending =
          (normalizedTotal - abono).clamp(0.0, normalizedTotal);
      _creditReceiptMethod = abono > 0 ? abonoPaymentMethod : null;

      final customerForReceipt = selectedCustomer.value;
      final clientForReceipt = selectedClient.value;
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

  /// Al tocar QR, muestra opción: ¿Nequi o Daviplata?
  void _showQRPaymentChoice(NumberFormat copFormat) {
    // No cerrar aquí el diálogo de métodos; _processPaymentWithMethod lo cerrará al elegir
    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Cómo pagó con QR?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.qr_code,
                      title: 'Nequi',
                      subtitle: 'Billetera digital',
                      onTap: () {
                        Get.back();
                        _processPaymentWithMethod('Nequi');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.qr_code,
                      title: 'Daviplata',
                      subtitle: 'Billetera digital',
                      onTap: () {
                        Get.back();
                        _processPaymentWithMethod('Daviplata');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPaymentWithMethod(String method) async {
    final NumberFormat copFormat = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '\$ ',
        decimalDigits: 0,
        customPattern: '\u00A4#,##0');
    Get.back(); // Cierra el diálogo de métodos de pago

    try {
      final exchangeApplied = immediateExchangeApplied;
      final dueAmount = totalToCollect;

      if (dueAmount <= 1e-9 && method != kSalePaymentMethodInstantExchange) {
        method = kSalePaymentMethodInstantExchange;
      }

      if (method == kSalePaymentMethodStoreCredit) {
        final cid = selectedCustomer.value?.id;
        if (cid == null) {
          Get.snackbar('Cliente', 'Seleccione un cliente del sistema para usar saldo a favor.',
              backgroundColor: Colors.orange, colorText: Colors.white);
          return;
        }
        final fresh = await SQLiteDatabaseService.getCustomerById(cid);
        if (fresh == null || fresh.storeCredit + 1e-6 < dueAmount) {
          Get.snackbar(
            'Saldo insuficiente',
            'El cliente no tiene saldo a favor suficiente para esta venta.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
      }

      final paymentParts = <PaymentPart>[
        if (exchangeApplied > 1e-9)
          PaymentPart(
              method: kSalePaymentMethodInstantExchange, amount: exchangeApplied),
        if (dueAmount > 1e-9) PaymentPart(method: method, amount: dueAmount),
      ];
      final saleMethod = paymentParts.length > 1
          ? 'Mixto'
          : paymentParts.isNotEmpty
              ? paymentParts.first.method
              : kSalePaymentMethodInstantExchange;

      // Crear la venta (guardar cliente para reimpresión con nombre en ticket)
      final disc = _cartSaleDiscount;
      final sale = Sale(
        date: DateTime.now(),
        total: total,
        user: AuthService.to.currentUser?.username ?? 'usuario',
        paymentMethod: saleMethod,
        paymentBreakdown: paymentParts.length > 1 ? paymentParts : null,
        customerId: selectedCustomer.value?.id,
        clientId: selectedClient.value?.id,
        discount: disc.amount > 0 ? disc.amount : null,
        discountPercentage: disc.percent > 0 ? disc.percent : null,
        items: cartItems
            .map((item) => SaleItem(
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                  unit: item.unit,
                  ivaPercentage: item.ivaPercentage,
                  productId: item.productId,
                  weightKg: item.weightKg,
                  priceEditedInCart: item.wasPriceEdited,
                  originalUnitPrice: item.originalPrice,
                  priceEditedAt: item.priceEditedAt,
                  priceEditedBy: item.priceEditedBy,
                  priceEditedFromIva: item.priceEditedFromIva,
                ))
            .toList(),
      );

      // Guardar la venta
      await SQLiteDatabaseService.saveSale(sale);
      _notifySaleCompleted();

      if (method == kSalePaymentMethodStoreCredit &&
          selectedCustomer.value?.id != null) {
        try {
          await SQLiteDatabaseService.adjustCustomerStoreCredit(
            selectedCustomer.value!.id!,
            -dueAmount,
          );
          await _reloadSelectedCustomerFromDb();
        } catch (e) {
          Get.snackbar(
            'Saldo a favor',
            'Venta guardada pero error al descontar saldo: $e',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }

      // ✅ NUEVO: Registrar ingreso contable automático
      try {
        final currentUser = AuthService.to.currentUser;
        if (currentUser != null && currentUser.id != null) {
          if (paymentParts.length > 1) {
            for (final part in paymentParts) {
              await AccountingService.recordSaleIncome(
                part.amount,
                'Venta POS - ${part.method}',
                currentUser.id!,
                paymentMethod: part.method,
                reference: 'sale_${sale.id ?? 'temp'}',
              );
            }
          } else {
            await AccountingService.recordSaleIncome(
              total,
              'Venta POS - $saleMethod',
              currentUser.id!,
              paymentMethod: saleMethod,
              reference: 'sale_${sale.id ?? 'temp'}',
            );
          }
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
      _consumeImmediateExchangeCredit(exchangeApplied);

      // El stock se actualiza automáticamente en saveSale

      // Mostrar confirmación con opción de imprimir (pasamos cliente sistema y/o facturación para el ticket)
      _showPrintConfirmationDialog(sale, saleMethod, copFormat,
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
                  'Total: ${copFormat.format(sale.total)}',
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
                Obx(() {
                  final pending = immediateExchangeCredit.value;
                  if (pending <= 1e-9) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Text(
                        'Aún hay canje pendiente: ${copFormat.format(pending)}.\n'
                        'Si ya entregó dinero al cliente, pulse en el POS «Canje activo» '
                        'y luego «Devolver remanente» para que caja y contabilidad cuadren.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
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
          creditDownPayment: _creditReceiptAbono,
          creditPendingAmount: _creditReceiptPending,
          creditPaymentMethod: _creditReceiptMethod,
          customer: customer ?? selectedCustomer.value,
          client: client ?? selectedClient.value,
          vatAt19: taxAt19 > 0 ? taxAt19 : null,
          vatAt5: taxAt5 > 0 ? taxAt5 : null);

      _lastCashReceived = null;
      _lastChange = null;
      _creditReceiptAbono = null;
      _creditReceiptPending = null;
      _creditReceiptMethod = null;
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

/// Segundo paso al elegir venta a crédito (F6): cliente, saldo anterior, abono y saldo de esta venta.
class _PosCreditReceivableDialog extends StatefulWidget {
  final PosController pos;
  final NumberFormat copFormat;

  const _PosCreditReceivableDialog({
    required this.pos,
    required this.copFormat,
  });

  @override
  State<_PosCreditReceivableDialog> createState() =>
      _PosCreditReceivableDialogState();
}

class _PosCreditReceivableDialogState
    extends State<_PosCreditReceivableDialog> {
  final TextEditingController _abonoController = TextEditingController();
  String _abonoPaymentMethod = 'Efectivo';

  @override
  void dispose() {
    _abonoController.dispose();
    super.dispose();
  }

  double _parseAbono(double totalVenta) {
    final normalizedTotal = totalVenta.roundToDouble();
    final raw =
        (parseMontoPuntosMiles(_abonoController.text) ?? 0.0).roundToDouble();
    if (raw < 0) return 0.0;
    if (raw > normalizedTotal) return normalizedTotal;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totalVenta = widget.pos.total.roundToDouble();
      final customer = widget.pos.selectedCustomer.value;
      final abono = _parseAbono(totalVenta);
      final saldoEstaVenta = totalVenta - abono;

      return Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Venta a crédito (cuenta por cobrar)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Total del carrito: ${widget.copFormat.format(totalVenta)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Cliente (sistema / puntos)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (customer == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await widget.pos.showCustomerSelectionModal();
                    setState(() {});
                  },
                  icon: const Icon(Icons.person_search),
                  label: const Text('Elegir cliente'),
                )
              else
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(customer.name),
                    subtitle: Text(
                      customer.documentNumber?.trim().isNotEmpty == true
                          ? customer.documentNumber!
                          : (customer.email),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        await widget.pos.showCustomerSelectionModal();
                        setState(() {});
                      },
                      child: const Text('Cambiar'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FutureBuilder<double>(
                key: ValueKey(customer?.id ?? -1),
                future: customer?.id != null
                    ? AccountsReceivablePayableService
                        .getPendingTotalForCustomer(customer!.id!)
                    : Future.value(0.0),
                builder: (context, snap) {
                  final prev = snap.data ?? 0.0;
                  final loading =
                      snap.connectionState == ConnectionState.waiting &&
                          customer?.id != null;
                  final totalClienteEst = prev + saldoEstaVenta;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                              child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                        ),
                      Text(
                        'Saldo pendiente anterior (cuentas por cobrar):',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        widget.copFormat.format(prev),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Abono ahora (opcional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _abonoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          PuntosMilesInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                          hintText: '0 — dejar vacío si no hay abono',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (abono > 0) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Método de pago del abono',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _abonoPaymentMethod,
                              isExpanded: true,
                              items: kPosPaymentMethodOptions
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _abonoPaymentMethod = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo por cobrar (esta venta): ${widget.copFormat.format(saldoEstaVenta)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Saldo total estimado del cliente: ${widget.copFormat.format(totalClienteEst)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
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
                    child: FilledButton(
                      onPressed: customer == null || customer.id == null
                          ? null
                          : () async {
                              Get.back();
                              await widget.pos.finalizeCreditSaleWithAbono(
                                widget.copFormat,
                                abono,
                                abonoPaymentMethod: abono > 0
                                    ? _abonoPaymentMethod
                                    : 'Efectivo',
                              );
                            },
                      child: const Text('Confirmar crédito'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
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
