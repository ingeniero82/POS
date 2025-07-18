import 'package:get/get.dart';
import '../../../models/product.dart';
import '../../../services/scale_service.dart';
import '../../../services/sqlite_database_service.dart';
import 'dart:async';

class WeightController extends GetxController {
  final ScaleService _scaleService = ScaleService();
  
  // Estados reactivos
  var isConnected = false.obs;
  var isReading = false.obs;
  var currentWeight = 0.0.obs;
  var currentUnit = 'kg'.obs;
  var products = <Product>[].obs;
  var filteredProducts = <Product>[].obs;
  var selectedProduct = Rxn<Product>();
  var isLoading = false.obs;
  
  // Streams
  StreamSubscription? _weightSubscription;
  StreamSubscription? _connectionSubscription;
  
  @override
  void onInit() {
    super.onInit();
    _initializeScaleService();
    _loadWeightProducts();
    _setupStreams();
  }
  
  @override
  void onClose() {
    _weightSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scaleService.dispose();
    super.onClose();
  }
  
  // Inicializar servicio de balanza
  Future<void> _initializeScaleService() async {
    try {
      await _scaleService.initialize();
    } catch (e) {
      Get.snackbar('Error', 'Error inicializando balanza: $e');
    }
  }
  
  // Configurar streams de la balanza
  void _setupStreams() {
    _weightSubscription = _scaleService.weightStream.listen((weight) {
      currentWeight.value = weight;
      // Si hay un producto seleccionado, actualizar su peso
      if (selectedProduct.value != null) {
        selectedProduct.value = selectedProduct.value!.copyWith(weight: weight);
      }
    });
    
    _connectionSubscription = _scaleService.connectionStream.listen((connected) {
      isConnected.value = connected;
    });
  }
  
  // Cargar productos pesados
  Future<void> _loadWeightProducts() async {
    isLoading.value = true;
    try {
      final allProducts = await SQLiteDatabaseService.getAllProducts();
      products.value = allProducts.where((p) => p.isWeighted).toList();
      filteredProducts.value = products;
    } catch (e) {
      Get.snackbar('Error', 'Error cargando productos: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  // Filtrar productos por texto
  void filterProducts(String query) {
    if (query.isEmpty) {
      filteredProducts.value = products;
    } else {
      filteredProducts.value = products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
               product.code.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
  }
  
  // Conectar balanza
  Future<void> connectScale() async {
    try {
      await _scaleService.connect();
      Get.snackbar('Éxito', 'Balanza conectada exitosamente');
    } catch (e) {
      Get.snackbar('Error', 'Error conectando balanza: $e');
    }
  }
  
  // Desconectar balanza
  Future<void> disconnectScale() async {
    try {
      await _scaleService.disconnect();
      Get.snackbar('Info', 'Balanza desconectada');
    } catch (e) {
      Get.snackbar('Error', 'Error desconectando balanza: $e');
    }
  }
  
  // Iniciar lectura de peso
  Future<void> startReading() async {
    try {
      await _scaleService.startReading();
      isReading.value = true;
    } catch (e) {
      Get.snackbar('Error', 'Error iniciando lectura: $e');
    }
  }
  
  // Detener lectura de peso
  Future<void> stopReading() async {
    try {
      await _scaleService.stopReading();
      isReading.value = false;
    } catch (e) {
      Get.snackbar('Error', 'Error deteniendo lectura: $e');
    }
  }
  
  // Tarar balanza
  Future<void> tare() async {
    try {
      await _scaleService.tare();
      Get.snackbar('Info', 'Balanza tarada');
    } catch (e) {
      Get.snackbar('Error', 'Error tarando balanza: $e');
    }
  }
  
  // Seleccionar producto
  void selectProduct(Product product) {
    if (!product.isWeighted) {
      Get.snackbar('Error', 'Este producto no se vende por peso');
      return;
    }
    
    selectedProduct.value = product.copyWith(weight: currentWeight.value);
  }
  
  // Calcular precio actual
  double get calculatedPrice {
    if (selectedProduct.value == null) return 0.0;
    return selectedProduct.value!.calculatedPrice;
  }
  
  // Validar peso
  bool validateWeight(Product product, double weight) {
    if (product.minWeight != null && weight < product.minWeight!) {
      Get.snackbar('Error', 
        'Peso mínimo: ${product.minWeight!.toStringAsFixed(3)} kg');
      return false;
    }
    
    if (product.maxWeight != null && weight > product.maxWeight!) {
      Get.snackbar('Error', 
        'Peso máximo: ${product.maxWeight!.toStringAsFixed(3)} kg');
      return false;
    }
    
    return true;
  }
  
  // Agregar producto al carrito (para integración con POS)
  void addToCart() {
    if (selectedProduct.value == null) {
      Get.snackbar('Error', 'Selecciona un producto');
      return;
    }
    
    if (currentWeight.value <= 0) {
      Get.snackbar('Error', 'Peso inválido');
      return;
    }
    
    if (!validateWeight(selectedProduct.value!, currentWeight.value)) {
      return;
    }
    
    // Crear producto con peso actual
    final productWithWeight = selectedProduct.value!.copyWith(
      weight: currentWeight.value,
    );
    
    // Notificar que se agregó al carrito
    Get.snackbar('Éxito', 
      'Producto agregado: ${productWithWeight.name}\n'
      'Peso: ${currentWeight.value.toStringAsFixed(3)} kg\n'
      'Precio: \$${calculatedPrice.toStringAsFixed(0)}');
    
    // Limpiar selección
    selectedProduct.value = null;
  }
  
  // Crear nuevo producto pesado
  Future<void> createWeightProduct({
    required String name,
    required String code,
    required double pricePerKg,
    required ProductCategory category,
    double? minWeight,
    double? maxWeight,
    String? description,
  }) async {
    try {
      final product = Product(
        code: code,
        shortCode: code,
        name: name,
        description: description ?? '',
        price: 0.0, // Para productos pesados, el precio se calcula dinámicamente
        cost: 0.0,
        stock: 999999, // Stock infinito para productos pesados
        minStock: 0,
        category: category,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isWeighted: true,
        pricePerKg: pricePerKg,
        minWeight: minWeight,
        maxWeight: maxWeight,
      );
      
      await SQLiteDatabaseService.createProduct(product);
      await _loadWeightProducts();
      Get.snackbar('Éxito', 'Producto creado exitosamente');
    } catch (e) {
      Get.snackbar('Error', 'Error creando producto: $e');
    }
  }
  
  // Actualizar producto pesado
  Future<void> updateWeightProduct(Product product) async {
    try {
      await SQLiteDatabaseService.updateProduct(product);
      await _loadWeightProducts();
      Get.snackbar('Éxito', 'Producto actualizado exitosamente');
    } catch (e) {
      Get.snackbar('Error', 'Error actualizando producto: $e');
    }
  }
  
  // Eliminar producto pesado
  Future<void> deleteWeightProduct(int productId) async {
    try {
      await SQLiteDatabaseService.deleteProduct(productId);
      await _loadWeightProducts();
      Get.snackbar('Éxito', 'Producto eliminado exitosamente');
    } catch (e) {
      Get.snackbar('Error', 'Error eliminando producto: $e');
    }
  }
  
  // Formatear peso para mostrar
  String formatWeight(double weight) {
    return _scaleService.formatWeight(weight);
  }
  
  // Formatear precio para mostrar
  String formatPrice(double price) {
    return _scaleService.formatPrice(price);
  }
  
  // Refrescar datos
  Future<void> refresh() async {
    await _loadWeightProducts();
  }
} 