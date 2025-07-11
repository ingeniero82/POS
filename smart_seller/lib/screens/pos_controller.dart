import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../services/auth_service.dart';
import '../services/scale_service.dart';
import 'package:intl/intl.dart';

class CartItem {
  final String name;
  final double price;
  final String unit;
  int quantity;
  bool isWeighted;
  double? weight;
  double? pricePerKg;

  CartItem({
    required this.name,
    required this.price,
    required this.unit,
    this.quantity = 1,
    this.isWeighted = false,
    this.weight,
    this.pricePerKg,
  });

  double get total {
    if (isWeighted && weight != null && pricePerKg != null) {
      return pricePerKg! * weight! * quantity;
    }
    return price * quantity;
  }
  
  String get displayInfo {
    if (isWeighted && weight != null) {
      return '${weight!.toStringAsFixed(3)} kg';
    }
    return '$quantity ${unit}';
  }
}

class PosController extends GetxController {
  var cartItems = <CartItem>[].obs;
  var scaleWeight = 0.0.obs;
  var isScaleConnected = false.obs;
  var isScaleReading = false.obs;
  
  late ScaleService _scaleService;
  
  @override
  void onInit() {
    super.onInit();
    _initializeScale(); // Desactivado temporalmente para pruebas sin balanza
  }
  
  Future<void> _initializeScale() async {
    _scaleService = ScaleService();
    await _scaleService.initialize();
    
    // Escuchar cambios de peso
    _scaleService.weightStream.listen((weight) {
      scaleWeight.value = weight;
    });
    
    // Escuchar cambios de conexión
    _scaleService.connectionStream.listen((connected) {
      isScaleConnected.value = connected;
    });
  }
  
  // Agregar producto al carrito
  void addToCart(String name, double price, String unit, {
    int quantity = 1,
    int? availableStock,
    bool isWeighted = false,
    double? weight,
    double? pricePerKg,
  }) {
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
        isWeighted: isWeighted,
        weight: weight,
        pricePerKg: pricePerKg,
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
        isWeighted: item.isWeighted,
        weight: item.weight,
        pricePerKg: item.pricePerKg,
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

  // Cambiar peso temporal de un item del carrito
  void changeItemWeight(int index, double newWeight) {
    if (index >= 0 && index < cartItems.length) {
      final item = cartItems[index];
      if (item.isWeighted && item.pricePerKg != null) {
        // Crear nuevo item con peso actualizado
        final updatedItem = CartItem(
          name: item.name,
          price: item.price,
          unit: item.unit,
          quantity: item.quantity,
          isWeighted: item.isWeighted,
          weight: newWeight,
          pricePerKg: item.pricePerKg,
        );
        cartItems[index] = updatedItem;
        cartItems.refresh();
        
        final newTotal = item.pricePerKg! * newWeight;
        Get.snackbar(
          'Peso actualizado',
          'Peso cambiado a ${newWeight.toStringAsFixed(3)} kg - Total: \$${newTotal.toStringAsFixed(0)}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  // Agregar producto pesado usando balanza
  void addWeightedProduct(Product product) {
    if (!isScaleConnected.value) {
      Get.snackbar(
        'Balanza no conectada',
        'Conecta la balanza para agregar productos pesados',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    if (product.pricePerKg == null) {
      Get.snackbar(
        'Producto sin precio por kg',
        'Configura el precio por kg para este producto',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    final currentWeight = scaleWeight.value;
    if (currentWeight <= 0) {
      Get.snackbar(
        'Peso inválido',
        'Coloca el producto en la balanza',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    // Verificar peso mínimo y máximo
    if (product.minWeight != null && currentWeight < product.minWeight!) {
      Get.snackbar(
        'Peso mínimo no alcanzado',
        'El peso mínimo es ${product.minWeight!.toStringAsFixed(3)} kg',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    if (product.maxWeight != null && currentWeight > product.maxWeight!) {
      Get.snackbar(
        'Peso máximo excedido',
        'El peso máximo es ${product.maxWeight!.toStringAsFixed(3)} kg',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    // Agregar al carrito
    addToCart(
      product.name,
      product.price,
      product.unit,
      availableStock: product.stock,
      isWeighted: true,
      weight: currentWeight,
      pricePerKg: product.pricePerKg,
    );
    
    // Mostrar confirmación
    final calculatedPrice = product.pricePerKg! * currentWeight;
    Get.snackbar(
      'Producto agregado',
      '${product.name}: ${currentWeight.toStringAsFixed(3)} kg - \$${calculatedPrice.toStringAsFixed(0)}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
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
  
  // Actualizar peso de un producto pesado
  void updateWeightedProductWeight(int index, double newWeight) {
    if (index >= 0 && index < cartItems.length && cartItems[index].isWeighted) {
      cartItems[index].weight = newWeight;
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
  
  // Conectar balanza
  Future<void> connectScale() async {
    await _scaleService.connect();
  }
  
  // Desconectar balanza
  Future<void> disconnectScale() async {
    await _scaleService.disconnect();
  }
  
  // Iniciar lectura de balanza
  Future<void> startScaleReading() async {
    await _scaleService.startReading();
    isScaleReading.value = true;
  }
  
  // Detener lectura de balanza
  Future<void> stopScaleReading() async {
    await _scaleService.stopReading();
    isScaleReading.value = false;
  }
  
  // Tarar balanza
  Future<void> tareScale() async {
    await _scaleService.tare();
  }
  
  // Obtener peso actual de la balanza
  double get currentScaleWeight => scaleWeight.value;
  
  // Formatear peso para mostrar
  String formatWeight(double weight) {
    return _scaleService.formatWeight(weight);
  }
  
  // Calcular subtotal
  double get subtotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.total);
  }
  
  // Calcular impuestos (19%)
  double get taxes {
    return subtotal * 0.19;
  }
  
  // Calcular total
  double get total {
    return subtotal + taxes;
  }
  
  // Procesar pago
  void processPayment() async {
    final NumberFormat copFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');
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
    final NumberFormat copFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');
    Get.back(); // Cierra el diálogo de métodos de pago
    
    try {
      // Crear la venta
                      final sale = Sale()
                        ..date = DateTime.now()
                        ..total = total
                        ..user = AuthService.to.currentUser?.username ?? 'usuario'
        ..paymentMethod = method
                        ..items = cartItems.map((item) => SaleItem()
                          ..name = item.name
                          ..price = item.price
                          ..quantity = item.quantity
                          ..unit = item.unit
                        ).toList();
      
      // Guardar la venta
      await SQLiteDatabaseService.saveSale(sale);
      
      // El stock se actualiza automáticamente en saveSale
      
      // Mostrar confirmación
      Get.dialog(
        Dialog(
          child: Container(
            width: 400,
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
                  style: const TextStyle(fontSize: 18, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Método: $method',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      clearCart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Continuar', style: TextStyle(color: Colors.white)),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
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
  
  @override
  void onClose() {
    _scaleService.dispose();
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