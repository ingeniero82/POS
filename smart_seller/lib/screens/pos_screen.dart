import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'pos_controller.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../services/authorization_service.dart';
import '../services/print_service.dart';
import '../widgets/authorization_modal.dart';
import '../services/auth_service.dart';
import '../modules/weight/controllers/weight_controller.dart';
import '../modules/weight/widgets/scale_widget.dart';
import '../utils/sample_weight_products.dart';
import 'package:intl/intl.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  
  List<Product> _products = [];
  bool _isLoading = true;
  String _currentMode = 'barcode'; // barcode, quantity, payment
  Product? _selectedProduct;
  bool _isShowingProductDialog = false;
  
  // Controlador del POS
  late PosController _posController;
  
  // Controlador de peso
  late WeightController _weightController;
  
  // Variables para autorización
  bool _isAuthorized = false;
  DateTime? _authorizationTime;
  String? _authorizedUser;
  
  // Códigos de autorización válidos
  static const List<String> _validBarcodes = [
    'BARCODE001', // Tarjeta Admin
    'BARCODE002', // Tarjeta Supervisor  
    'BARCODE003', // Tarjeta Gerente
  ];
  
  static const Map<String, String> _validPersonalCodes = {
    'ADMIN123': 'Administrador',
    'SUPER456': 'Supervisor',
    'MANAGER789': 'Gerente',
  };
  
  @override
  void initState() {
    super.initState();
    _posController = Get.put(PosController());
    _weightController = Get.put(WeightController());
    _loadProducts();
    
    // Auto-focus al barcode al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _products = await SQLiteDatabaseService.getAllProducts();
      
      // Debug: mostrar productos pesados
      final weightedProducts = _products.where((p) => p.isWeighted).toList();
      print('🔍 Productos cargados: ${_products.length}');
      print('⚖️ Productos pesados: ${weightedProducts.length}');
      for (final product in weightedProducts) {
        print('   - ${product.name} (${product.code}) - \$${product.pricePerKg}/kg');
      }
    } catch (e) {
      Get.snackbar('Error', 'Error cargando productos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String quitarTildes(String texto) {
    return texto
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'[ÁÀÄÂÃ]'), 'A')
      .replaceAll(RegExp(r'[ÉÈËÊ]'), 'E')
      .replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I')
      .replaceAll(RegExp(r'[ÓÒÖÔÕ]'), 'O')
      .replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // AppBar degradado
          Container(
            width: double.infinity,
            height: kToolbarHeight + 8,
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2979FF), Color(0xFF6C47FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Volver al Dashboard',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'SMART SELLER',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showHelp(),
                  icon: const Icon(Icons.help, color: Colors.white),
                  tooltip: 'Ayuda (F1)',
                ),
              ],
            ),
          ),
          // Indicador de autorización
          if (_isAuthorized && _authorizationTime != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autorizado: ${_authorizedUser ?? 'Usuario'} - ${_getTimeRemaining()}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAuthorization,
                    child: Text('Cerrar', style: TextStyle(color: Colors.green.shade700)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: _handleKeyboardInput,
              child: Row(
                children: [
                  // Panel izquierdo - Búsqueda y productos
                  Expanded(
                    flex: 2,
                    child: _buildLeftPanel(),
                  ),
                  // Panel derecho - Carrito y totales
                  Expanded(
                    flex: 1,
                    child: _buildRightPanel(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de búsqueda/escaneo
          _buildSearchBar(),
          const SizedBox(height: 16),
          
          // Producto seleccionado
          if (_selectedProduct != null) _buildSelectedProduct(),
          
          const SizedBox(height: 16),
          
          // Lista de productos recientes
          Expanded(
            child: _buildRecentProducts(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentMode == 'barcode' ? '📱 Escanear código de barras' : '⌨️ Ingresar cantidad',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentMode == 'barcode' ? _barcodeController : _quantityController,
              focusNode: _currentMode == 'barcode' ? _barcodeFocus : _quantityFocus,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _currentMode == 'barcode' 
                    ? 'Escanear código o escribir código PLU...' 
                    : 'Cantidad (Enter = 1)',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(
                  _currentMode == 'barcode' ? Icons.qr_code_scanner : Icons.keyboard,
                ),
              ),
              onSubmitted: (value) => _handleSubmit(value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeButton('barcode', '📱 Escanear', Icons.qr_code_scanner),
                const SizedBox(width: 8),
                _buildModeButton('quantity', '⌨️ Cantidad', Icons.keyboard),
                const SizedBox(width: 8),
                _buildModeButton('payment', '💳 Pago', Icons.payment),
                const SizedBox(width: 8),
                // Botón para crear productos pesados (DEBUG)
                IconButton(
                  onPressed: () async {
                    await SampleWeightProducts.insertSampleProducts();
                    await _loadProducts();
                    Get.snackbar(
                      'Productos Creados',
                      'Productos pesados de ejemplo creados',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.scale),
                  tooltip: 'Crear productos pesados',
                ),
                
                // Botón para debug de balanza
                IconButton(
                  onPressed: () async {
                    await _debugScale();
                  },
                  icon: const Icon(Icons.bug_report),
                  tooltip: 'Debug balanza',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _switchMode(mode),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
  
  Widget _buildSelectedProduct() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Producto Seleccionado:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedProduct!.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Código: ${_selectedProduct!.code}'),
            Row(
              children: [
                Expanded(
                  child: Text('Precio: \$${NumberFormat('#,###').format(_selectedProduct!.price)}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: 'Editar precio',
                  onPressed: () => _showPriceEditDialog(_selectedProduct!),
                ),
              ],
            ),
            Text('Stock: ${_selectedProduct!.stock}'),
            const SizedBox(height: 16),
            
            // Campo de cantidad (siempre visible)
            TextField(
              controller: _quantityController,
              focusNode: _quantityFocus,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                hintText: 'Ingrese cantidad (Enter = 1)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.keyboard),
              ),
              onSubmitted: (value) => _selectedProduct!.isWeighted 
                  ? _addWeightedProductToCart() 
                  : _addToCart(int.tryParse(value) ?? 1),
            ),
            
            const SizedBox(height: 16),
            
            // Sección de peso (SIEMPRE visible - como POS profesional)
            _buildWeightDisplay(),
            const SizedBox(height: 12),
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectedProduct!.isWeighted 
                        ? _addWeightedProductToCart() 
                        : _addToCart(int.tryParse(_quantityController.text) ?? 1),
                    icon: Icon(_selectedProduct!.isWeighted ? Icons.scale : Icons.add_shopping_cart),
                    label: Text(_selectedProduct!.isWeighted ? 'Agregar Pesado' : 'Agregar al Carrito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelCurrentOperation(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentProducts() {
    // Atajos: 1-9 (solo números, como POS profesionales)
    final atajos = [
      ...List.generate(9, (i) => (i + 1).toString()),
    ];
    final productos = _products.take(9).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos Frecuentes (Teclas 1-9)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final product = productos[index];
                  final atajo = index < atajos.length ? atajos[index] : '';
                  return GestureDetector(
                    onTap: () => _selectProduct(product),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue[100]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Imagen o ícono
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                              ? Image.network(product.imageUrl!, fit: BoxFit.contain)
                              : Icon(Icons.inventory_2, size: 32, color: Colors.blue[200]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, color: Colors.blue),
                              ),
                              GestureDetector(
                                onTap: () => _showPriceEditDialog(product),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stock: ${product.stock}',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.isLowStock ? Colors.red : Colors.grey[700],
                              fontWeight: product.isLowStock ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (atajo.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tecla: $atajo',
                                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Totales
          _buildTotals(),
          const SizedBox(height: 16),
          
          // Carrito
          Expanded(
            child: _buildCart(),
          ),
          
          // Botones de acción
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  Widget _buildTotals() {
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold),
                ),
                Obx(() => Text(
                  '\$${_posController.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                )),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Impuestos (19%):',
                  style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold),
                ),
                Obx(() => Text(
                  '\$${_posController.taxes.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                )),
              ],
            ),
            const Divider(height: 28, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: Colors.orange[300],
                    end: Colors.orangeAccent,
                  ),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, color, child) {
                    return Text(
                      'TOTAL:',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                  key: ValueKey(_posController.total),
                ),
                Obx(() {
                  final total = _posController.total;
                  return TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      begin: Colors.orange[300],
                      end: Colors.orangeAccent,
                    ),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, color, child) {
                      return Text(
                        '\$${total.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      );
                    },
                    key: ValueKey(total),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCart() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Carrito de Compras',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: _posController.cartItems.length,
              itemBuilder: (context, index) {
                final item = _posController.cartItems[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.quantity} x \$${NumberFormat('#,###').format(item.price)}'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showCartItemPriceEditDialog(item),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '\$${NumberFormat('#,###').format(item.price * item.quantity)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _clearCart(),
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar (F4)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openCashDrawer(),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Abrir Cajón (F5)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _finalizeSale(),
            icon: const Icon(Icons.payment),
            label: const Text('Finalizar Venta (F6)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
  
  // ================== MANEJO DE TECLADO ==================
  
  void _handleKeyboardInput(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Si el diálogo de selección está abierto, no procesar atajos
      if (_isShowingProductDialog) {
        return;
      }
      
      // Si el campo de búsqueda tiene texto, no procesar atajos de productos
      if (_barcodeController.text.isNotEmpty) {
        // Solo procesar atajos globales cuando hay texto en búsqueda
        switch (event.logicalKey.keyLabel) {
          case 'F1':
            _showHelp();
            break;
          case 'F4':
            _clearCart();
            break;
          case 'F5':
            _openCashDrawer();
            break;
          case 'F6':
            _finalizeSale();
            break;
          case 'Escape':
            _cancelCurrentOperation();
            break;
        }
        return;
      }
      
      final atajos = [
        ...List.generate(9, (i) => (i + 1).toString()),
      ];
      final productos = _products.take(9).toList();
      // Atajo de producto frecuente (solo números 1-9)
      final key = event.logicalKey.keyLabel.toUpperCase();
      final idx = atajos.indexOf(key);
      if (idx != -1 && idx < productos.length && _currentMode == 'barcode') {
        _selectProduct(productos[idx]);
        return;
      }
      // Atajos globales
      switch (event.logicalKey.keyLabel) {
        case 'F1':
          _showHelp();
          break;
        case 'F4':
          _clearCart();
          break;
        case 'F5':
          _openCashDrawer();
          break;
        case 'F6':
          _finalizeSale();
          break;
        case 'Escape':
          _cancelCurrentOperation();
          break;
      }
    }
  }
  
  void _handleSubmit(String value) {
    if (value.isEmpty) return;
    
    switch (_currentMode) {
      case 'barcode':
        _searchProduct(value);
        break;
      case 'quantity':
        _addToCart(int.tryParse(value) ?? 1);
        break;
      case 'payment':
        _handlePayment(value);
        break;
    }
  }
  
  void _switchMode(String mode) {
    setState(() {
      _currentMode = mode;
      _selectedProduct = null;
    });
    
    // Cambiar focus según el modo
    if (mode == 'barcode') {
      _barcodeFocus.requestFocus();
    } else if (mode == 'quantity') {
      _quantityFocus.requestFocus();
    }
  }
  
  void _searchProduct(String code) {
    // Verificar si es un código numérico (código de barras)
    final isNumericCode = int.tryParse(code) != null && code.length >= 3;
    
    // Primero buscar por código exacto
    final exactMatch = _products.where((p) => p.code == code || p.shortCode == code).toList();
    
    if (exactMatch.isNotEmpty) {
      // Si hay coincidencia exacta de código, usar el primero
      final product = exactMatch.first;
      _selectProductDirectly(product);
      return;
    }
    
    // Si no hay código exacto, buscar por nombre
    final nameMatches = _products.where((p) =>
      quitarTildes(p.name.toLowerCase()).contains(quitarTildes(code.toLowerCase()))
    ).toList();
    
    if (nameMatches.isEmpty) {
      Get.snackbar(
        'Producto no encontrado',
        'No se encontró el producto con código: $code',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      _barcodeController.clear();
      _barcodeFocus.requestFocus();
      return;
    }
    
    // Para búsquedas por nombre, SIEMPRE mostrar diálogo para que el usuario elija
    _showProductSelectionDialog(nameMatches, code);
  }
  
  void _selectProductDirectly(Product product) {
    setState(() {
      _selectedProduct = product;
      _currentMode = 'quantity';
    });
    
    // Debug: verificar si el producto es pesado
    print('📦 Producto seleccionado: ${product.name}');
    print('⚖️ Es pesado: ${product.isWeighted}');
    if (product.isWeighted) {
      print('💰 Precio por kg: \$${product.pricePerKg}');
    }
    
    // Configurar el campo de cantidad
    _quantityController.text = '1';
    _quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _quantityController.text.length,
    );
    
    // Enfocar el campo de cantidad después de un breve delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quantityFocus.requestFocus();
      // Forzar rebuild para asegurar que el campo esté visible
      setState(() {});
    });
    
    Get.snackbar(
      'Producto encontrado',
      '${product.name} - Ingrese cantidad',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
  
  void _showProductSelectionDialog(List<Product> products, String searchTerm) {
    int selectedIndex = 0;
    final FocusNode dialogFocusNode = FocusNode();
    final ScrollController scrollController = ScrollController(); // <-- Nuevo controlador

    setState(() {
      _isShowingProductDialog = true;
    });

    void scrollToSelected(int index) {
      // Calcula la posición del item seleccionado y hace scroll automático
      final itemHeight = 80.0; // Aproximado, ajusta si tu ListTile es más alto/bajo
      scrollController.animateTo(
        index * itemHeight,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return RawKeyboardListener(
            focusNode: dialogFocusNode,
            autofocus: true,
            onKey: (event) {
              if (event is RawKeyDownEvent) {
                switch (event.logicalKey.keyLabel) {
                  case 'Arrow Up':
                    if (selectedIndex > 0) {
                      setDialogState(() {
                        selectedIndex--;
                        scrollToSelected(selectedIndex);
                      });
                    }
                    break;
                  case 'Arrow Down':
                    if (selectedIndex < products.length - 1) {
                      setDialogState(() {
                        selectedIndex++;
                        scrollToSelected(selectedIndex);
                      });
                    }
                    break;
                  case 'Enter':
                    Navigator.of(context).pop();
                    _selectProductDirectly(products[selectedIndex]);
                    break;
                  case 'Escape':
                    Navigator.of(context).pop();
                    _barcodeController.clear();
                    _barcodeFocus.requestFocus();
                    break;
                }
              }
            },
            child: AlertDialog(
              title: Text('Seleccionar Producto (${products.length} encontrados)'),
              content: Container(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      'Búsqueda: "$searchTerm"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Usa ↑↓ para navegar, Enter para seleccionar, Esc para cancelar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController, // <-- Aquí se agrega el controlador
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final isSelected = index == selectedIndex;
                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue[100] : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.blue[600] : Colors.blue[100],
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.blue[700],
                                  ),
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.blue[800] : Colors.black,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Código: ${product.code}'),
                                  Text('Precio: \$${NumberFormat('#,###').format(product.price)}'),
                                  Text('Stock: ${product.stock}'),
                                ],
                              ),
                                            trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${NumberFormat('#,###').format(product.price)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.blue[800] : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue[600], size: 18),
                    tooltip: 'Editar precio',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showPriceEditDialog(product);
                    },
                  ),
                ],
              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                _selectProductDirectly(product);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _barcodeController.clear();
                    _barcodeFocus.requestFocus();
                  },
                  child: const Text('Cancelar (Esc)'),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      setState(() {
        _isShowingProductDialog = false;
      });
    });
  }
  
  void _addToCart(int quantity) {
    if (_selectedProduct != null) {
      _posController.addToCart(
        _selectedProduct!.name,
        _selectedProduct!.price,
        _selectedProduct!.unit,
        quantity: quantity,
        availableStock: _selectedProduct!.stock,
      );
      
      Get.snackbar(
        'Producto agregado',
        '${_selectedProduct!.name} x$quantity agregado al carrito',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      
      // Reset para siguiente producto
      setState(() {
        _selectedProduct = null;
        _currentMode = 'barcode';
      });
      _barcodeController.clear();
      _quantityController.clear();
      _quantityController.text = '1';
      _barcodeFocus.requestFocus();
    }
  }
  
  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _currentMode = 'quantity';
    });
    
    // Configurar el campo de cantidad
    _quantityController.text = '1';
    _quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _quantityController.text.length,
    );
    
    // Enfocar el campo de cantidad después de un breve delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quantityFocus.requestFocus();
      // Forzar rebuild para asegurar que el campo esté visible
      setState(() {});
    });
    
    Get.snackbar(
      'Producto seleccionado',
      '${product.name} - Ingrese cantidad',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
  
  void _clearCart() {
    // Verificar si ya está autorizado y la autorización es válida
    if (_isAuthorizationValid()) {
      _performClearCart();
      return;
    }
    
    // Si no está autorizado, mostrar diálogo de autorización
    _showAuthorizationDialog();
  }
  
  void _performClearCart() {
    _posController.clearCart();
    Get.snackbar(
      'Carrito limpiado',
      'Se han removido todos los productos${_authorizedUser != null ? ' (Autorizado por: $_authorizedUser)' : ''}',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }
  
  void _finalizeSale() {
    if (_posController.cartItems.isEmpty) {
      Get.snackbar(
        'Carrito vacío',
        'Agrega productos antes de finalizar la venta',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    _posController.processPayment();
  }
  
  void _openCashDrawer() async {
    // Verificar si el usuario actual tiene permisos
    final authService = AuthorizationService();
    final currentUser = AuthService.to.currentUser;
    
    if (currentUser == null) {
      Get.snackbar(
        'Error',
        'No hay usuario autenticado',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    // Verificar permisos del usuario actual
    final hasPermission = await authService.hasPermission(AuthorizationService.CASH_DRAWER_OPEN);
    
    if (!hasPermission) {
      // Mostrar modal de autorización
      _showAuthorizationModal();
      return;
    }
    
    // Si tiene permisos, abrir cajón directamente
    await _performCashDrawerOpen('Apertura directa por ${currentUser.fullName}');
  }
  
  void _showAuthorizationModal() {
    Get.dialog(
      AuthorizationModal(
        action: AuthorizationService.CASH_DRAWER_OPEN,
        onAuthorized: (code) async {
          final authService = AuthorizationService();
          
          // Obtener información del autorizador
          final authorizerInfo = await authService.getAuthorizerInfo(code);
          
          // Registrar autorización
          await authService.logAuthorization(
            AuthorizationService.CASH_DRAWER_OPEN,
            code,
            'Apertura manual del cajón monedero'
          );
          
          await _performCashDrawerOpen('Autorizado por: $authorizerInfo');
        },
        onCancelled: () {
          // No hacer nada, el modal se cierra automáticamente
        },
      ),
    );
  }
  
  Future<void> _performCashDrawerOpen(String reason) async {
    try {
      final printService = PrintService.instance;
      await printService.initialize();
      
      final opened = await printService.openCashDrawer();
      
      if (opened) {
        // Registrar en auditoría
        print('🔓 AUDITORÍA: Cajón abierto manualmente - $reason - ${DateTime.now()}');
        
        Get.snackbar(
          'Cajón abierto',
          'El cajón monedero se abrió correctamente\n$reason',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          'No se pudo abrir el cajón monedero',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al abrir el cajón: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
  
  void _cancelCurrentOperation() {
    setState(() {
      _selectedProduct = null;
      _currentMode = 'barcode';
    });
    _barcodeController.clear();
    _quantityController.clear();
    _quantityController.text = '1';
    _barcodeFocus.requestFocus();
  }
  
  void _handlePayment(String value) {
    // Implementar lógica de pago
  }
  
  void _showPaymentDialog() {
    // Ya no se necesita, se usa processPayment() directamente
  }
  
  void _processSale(String paymentMethod) {
    // Ya no se necesita, se usa processPayment() directamente
  }
  
  void _showHelp() {
    Get.dialog(
      AlertDialog(
        title: const Text('Atajos de Teclado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('📱 ESCANEAR: Escanear código de barras'),
            Text('⌨️ CANTIDAD: Ingresar cantidad (Enter = 1)'),
            Text('💳 PAGO: Seleccionar forma de pago'),
            SizedBox(height: 16),
            Text('F1: Mostrar ayuda'),
            Text('F4: Limpiar carrito'),
            Text('F5: Abrir cajón monedero'),
            Text('F6: Finalizar venta'),
            Text('ESC: Cancelar operación actual'),
            Text('ENTER: Confirmar acción'),
          ],
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
  
  // Funciones de autorización
  bool _isAuthorizationValid() {
    if (!_isAuthorized || _authorizationTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final timeDifference = now.difference(_authorizationTime!);
    
    // Autorización válida por 5 minutos
    if (timeDifference.inMinutes >= 5) {
      _clearAuthorization();
      return false;
    }
    
    return true;
  }
  
  void _clearAuthorization() {
    setState(() {
      _isAuthorized = false;
      _authorizationTime = null;
      _authorizedUser = null;
    });
  }
  
  String _getTimeRemaining() {
    if (_authorizationTime == null) return '';
    
    final now = DateTime.now();
    final timeDifference = now.difference(_authorizationTime!);
    final remainingMinutes = 5 - timeDifference.inMinutes;
    final remainingSeconds = 60 - (timeDifference.inSeconds % 60);
    
    if (remainingMinutes <= 0) {
      return 'Expirado';
    }
    
    return '${remainingMinutes}m ${remainingSeconds}s restantes';
  }
  
  void _setAuthorization(String user) {
    setState(() {
      _isAuthorized = true;
      _authorizationTime = DateTime.now();
      _authorizedUser = user;
    });
  }
  
  bool _validateBarcode(String barcode) {
    return _validBarcodes.contains(barcode.toUpperCase());
  }
  
  bool _validatePersonalCode(String code) {
    return _validPersonalCodes.containsKey(code.toUpperCase());
  }
  
  void _showAuthorizationDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('🔐 Autorización Requerida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Limpiar carrito requiere autorización'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _showBarcodeInput();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Código de Barras'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _showPersonalCodeInput();
              },
              icon: const Icon(Icons.keyboard),
              label: const Text('Código Personal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _showPriceAuthorizationDialog(Product product) {
    Get.dialog(
      AlertDialog(
        title: const Text('🔐 Autorización Requerida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Modificar precio requiere autorización'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _showPriceBarcodeInput(product);
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Código de Barras'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _showPricePersonalCodeInput(product);
              },
              icon: const Icon(Icons.keyboard),
              label: const Text('Código Personal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _showPriceEditDialog(Product product) {
    // Verificar si ya está autorizado y la autorización es válida
    if (_isAuthorizationValid()) {
      _showPriceEditForm(product);
      return;
    }
    
    // Si no está autorizado, mostrar diálogo de autorización
    _showPriceAuthorizationDialog(product);
  }
  
  void _showPriceEditForm(Product product) {
    final TextEditingController priceController = TextEditingController();
    priceController.text = product.price.toString();
    
    Get.dialog(
      AlertDialog(
        title: const Text('💰 Editar Precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Producto: ${product.name}'),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nuevo Precio',
                hintText: 'Ingrese el nuevo precio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              onSubmitted: (value) {
                final newPrice = double.tryParse(value);
                if (newPrice != null && newPrice > 0) {
                  _updateProductPrice(product, newPrice);
                  Get.back();
                } else {
                  Get.snackbar(
                    'Error',
                    'Precio inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                _updateProductPrice(product, newPrice);
                Get.back();
              } else {
                Get.snackbar(
                  'Error',
                  'Precio inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
  
  void _showPriceBarcodeInput(Product product) {
    final TextEditingController barcodeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🏷️ Escanear Código de Barras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escanee o ingrese el código de barras:'),
            const SizedBox(height: 10),
            TextField(
              controller: barcodeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Código de Barras',
                hintText: 'BARCODE001, BARCODE002, BARCODE003',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
              onSubmitted: (value) {
                if (_validateBarcode(value)) {
                  _setAuthorization('Autorizado por código de barras');
                  Get.back();
                  _showPriceEditForm(product);
                } else {
                  Get.snackbar(
                    'Error',
                    'Código de barras inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateBarcode(barcodeController.text)) {
                _setAuthorization('Autorizado por código de barras');
                Get.back();
                _showPriceEditForm(product);
              } else {
                Get.snackbar(
                  'Error',
                  'Código de barras inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  void _showPricePersonalCodeInput(Product product) {
    final TextEditingController codeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🔑 Código Personal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese su código personal:'),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Código Personal',
                hintText: 'ADMIN123, SUPER456, MANAGER789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (value) {
                if (_validatePersonalCode(value)) {
                  final user = _validPersonalCodes[value.toUpperCase()]!;
                  _setAuthorization(user);
                  Get.back();
                  _showPriceEditForm(product);
                } else {
                  Get.snackbar(
                    'Error',
                    'Código personal inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validatePersonalCode(codeController.text)) {
                final user = _validPersonalCodes[codeController.text.toUpperCase()]!;
                _setAuthorization(user);
                Get.back();
                _showPriceEditForm(product);
              } else {
                Get.snackbar(
                  'Error',
                  'Código personal inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _updateProductPrice(Product product, double newPrice) async {
    try {
      // Verificar que el producto tenga ID
      if (product.id == null) {
        Get.snackbar(
          'Error',
          'No se puede actualizar el precio: producto sin ID',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Actualizar en la base de datos
      await SQLiteDatabaseService.updateProductPrice(product.id!, newPrice);
      
      // Actualizar en la lista local
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        setState(() {
          _products[index] = Product(
            id: product.id,
            name: product.name,
            description: product.description,
            code: product.code,
            shortCode: product.shortCode,
            price: newPrice,
            cost: product.cost,
            stock: product.stock,
            minStock: product.minStock,
            category: product.category,
            unit: product.unit,
            isWeighted: product.isWeighted,
            pricePerKg: product.pricePerKg,
            weight: product.weight,
            minWeight: product.minWeight,
            maxWeight: product.maxWeight,
            isActive: product.isActive,
            imageUrl: product.imageUrl,
            createdAt: product.createdAt,
            updatedAt: DateTime.now(),
          );
          
          // Si es el producto seleccionado, actualizarlo también
          if (_selectedProduct?.id == product.id) {
            _selectedProduct = _products[index];
          }
        });
      }
      
      Get.snackbar(
        'Precio actualizado',
        'Nuevo precio: \$${NumberFormat('#,###').format(newPrice)} (Autorizado por: ${_authorizedUser ?? 'Usuario'})',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error actualizando precio: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  void _showBarcodeInput() {
    final TextEditingController barcodeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🏷️ Escanear Código de Barras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escanee o ingrese el código de barras:'),
            const SizedBox(height: 10),
            TextField(
              controller: barcodeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Código de Barras',
                hintText: 'BARCODE001, BARCODE002, BARCODE003',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
              onSubmitted: (value) {
                if (_validateBarcode(value)) {
                  _setAuthorization('Autorizado por código de barras');
                  Get.back();
                  _clearCart();
                } else {
                  Get.snackbar(
                    'Error',
                    'Código de barras inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateBarcode(barcodeController.text)) {
                _setAuthorization('Autorizado por código de barras');
                Get.back();
                _clearCart();
              } else {
                Get.snackbar(
                  'Error',
                  'Código de barras inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  void _showPersonalCodeInput() {
    final TextEditingController codeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🔑 Código Personal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese su código personal:'),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Código Personal',
                hintText: 'ADMIN123, SUPER456, MANAGER789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (value) {
                if (_validatePersonalCode(value)) {
                  final user = _validPersonalCodes[value.toUpperCase()]!;
                  _setAuthorization(user);
                  Get.back();
                  _clearCart();
                } else {
                  Get.snackbar(
                    'Error',
                    'Código personal inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validatePersonalCode(codeController.text)) {
                final user = _validPersonalCodes[codeController.text.toUpperCase()]!;
                _setAuthorization(user);
                Get.back();
                _clearCart();
              } else {
                Get.snackbar(
                  'Error',
                  'Código personal inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  // ================== EDICIÓN DE PRECIOS EN CARRITO ==================
  
  void _showCartItemPriceEditDialog(CartItem cartItem) {
    // Verificar si ya está autorizado y la autorización es válida
    if (_isAuthorizationValid()) {
      _showCartItemPriceEditForm(cartItem);
      return;
    }
    
    // Si no está autorizado, mostrar diálogo de autorización
    _showCartItemPriceAuthorizationDialog(cartItem);
  }
  
  void _showCartItemPriceEditForm(CartItem cartItem) {
    final TextEditingController priceController = TextEditingController();
    priceController.text = cartItem.price.toString();
    
    Get.dialog(
      AlertDialog(
        title: const Text('💰 Editar Precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Producto: ${cartItem.name}'),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nuevo Precio',
                hintText: 'Ingrese el nuevo precio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              onSubmitted: (value) {
                final newPrice = double.tryParse(value);
                if (newPrice != null && newPrice > 0) {
                  _updateCartItemPrice(cartItem, newPrice);
                  Get.back();
                } else {
                  Get.snackbar(
                    'Error',
                    'Precio inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                _updateCartItemPrice(cartItem, newPrice);
                Get.back();
              } else {
                Get.snackbar(
                  'Error',
                  'Precio inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
  
  void _showCartItemPriceAuthorizationDialog(CartItem cartItem) {
    Get.dialog(
      AlertDialog(
        title: const Text('🔐 Autorización Requerida'),
        content: const Text('Se requiere autorización para editar precios. ¿Cómo desea autorizar?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _showCartItemPriceBarcodeInput(cartItem);
            },
            child: const Text('Código de Barras'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _showCartItemPricePersonalCodeInput(cartItem);
            },
            child: const Text('Código Personal'),
          ),
        ],
      ),
    );
  }
  
  void _showCartItemPriceBarcodeInput(CartItem cartItem) {
    final TextEditingController barcodeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🏷️ Escanear Código de Barras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escanee o ingrese el código de barras:'),
            const SizedBox(height: 10),
            TextField(
              controller: barcodeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Código de Barras',
                hintText: 'BARCODE001, BARCODE002, BARCODE003',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
              onSubmitted: (value) {
                if (_validateBarcode(value)) {
                  _setAuthorization('Autorizado por código de barras');
                  Get.back();
                  _showCartItemPriceEditForm(cartItem);
                } else {
                  Get.snackbar(
                    'Error',
                    'Código de barras inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateBarcode(barcodeController.text)) {
                _setAuthorization('Autorizado por código de barras');
                Get.back();
                _showCartItemPriceEditForm(cartItem);
              } else {
                Get.snackbar(
                  'Error',
                  'Código de barras inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  void _showCartItemPricePersonalCodeInput(CartItem cartItem) {
    final TextEditingController codeController = TextEditingController();
    
    Get.dialog(
      AlertDialog(
        title: const Text('🔢 Código Personal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese su código personal:'),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Código Personal',
                hintText: 'ADMIN123, SUPER456, MANAGER789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              onSubmitted: (value) {
                if (_validatePersonalCode(value)) {
                  final user = _validPersonalCodes[value.toUpperCase()]!;
                  _setAuthorization(user);
                  Get.back();
                  _showCartItemPriceEditForm(cartItem);
                } else {
                  Get.snackbar(
                    'Error',
                    'Código personal inválido',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validatePersonalCode(codeController.text)) {
                final user = _validPersonalCodes[codeController.text.toUpperCase()]!;
                _setAuthorization(user);
                Get.back();
                _showCartItemPriceEditForm(cartItem);
              } else {
                Get.snackbar(
                  'Error',
                  'Código personal inválido',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }
  
  // Método para mostrar el peso SIEMPRE (como POS profesional)
  Widget _buildWeightDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Título con estado de balanza
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.scale, size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Peso',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              // Estado de conexión
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _weightController.isConnected.value ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _weightController.isConnected.value ? 'Conectada' : 'Desconectada',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          // Peso actual (SIEMPRE visible)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // Peso grande
                Obx(() => Text(
                  '${_weightController.currentWeight.value.toStringAsFixed(3)} kg',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _weightController.isConnected.value ? Colors.blue.shade700 : Colors.grey,
                  ),
                )),
                const SizedBox(height: 8),
                
                // Indicador de lectura
                Obx(() => Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _weightController.isReading.value ? Colors.blue : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: _weightController.isReading.value
                      ? const LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        )
                      : null,
                )),
                
                const SizedBox(height: 16),
                
                // Información del producto pesado (solo si aplica)
                if (_selectedProduct != null && _selectedProduct!.isWeighted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Precio/kg:',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              '\$${(_selectedProduct!.pricePerKg ?? 0).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_weightController.calculatedPrice.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Controles de balanza
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Conectar/Desconectar
                    Obx(() => ElevatedButton.icon(
                      onPressed: _weightController.isConnected.value 
                          ? _weightController.disconnectScale
                          : _weightController.connectScale,
                      icon: Icon(
                        _weightController.isConnected.value 
                            ? Icons.bluetooth_connected 
                            : Icons.bluetooth_disabled,
                        size: 16,
                      ),
                      label: Text(
                        _weightController.isConnected.value ? 'Desconectar' : 'Conectar',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _weightController.isConnected.value ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
                    
                    // Tare
                    Obx(() => ElevatedButton.icon(
                      onPressed: _weightController.isConnected.value ? _weightController.tare : null,
                      icon: const Icon(Icons.horizontal_rule, size: 16),
                      label: const Text('Tare', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
                    
                    // Iniciar/Detener
                    Obx(() => ElevatedButton.icon(
                      onPressed: _weightController.isConnected.value
                          ? (_weightController.isReading.value 
                              ? _weightController.stopReading 
                              : _weightController.startReading)
                          : null,
                      icon: Icon(
                        _weightController.isReading.value ? Icons.pause : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(
                        _weightController.isReading.value ? 'Detener' : 'Iniciar',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _weightController.isReading.value ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Método para agregar productos pesados al carrito
  void _addWeightedProductToCart() {
    if (_selectedProduct == null) {
      Get.snackbar('Error', 'No hay producto seleccionado');
      return;
    }
    
    if (!_weightController.isConnected.value) {
      Get.snackbar('Error', 'Balanza no conectada');
      return;
    }
    
    if (_weightController.currentWeight.value <= 0) {
      Get.snackbar('Error', 'Peso inválido. Coloque el producto en la balanza');
      return;
    }
    
    // Validar límites de peso
    if (!_weightController.validateWeight(_selectedProduct!, _weightController.currentWeight.value)) {
      return; // El mensaje de error ya se muestra en validateWeight
    }
    
    // Crear producto con peso actual
    final productWithWeight = _selectedProduct!.copyWith(
      weight: _weightController.currentWeight.value,
    );
    
    // Calcular precio total
    final totalPrice = productWithWeight.calculatedPrice;
    
    // Agregar al carrito
    _posController.addToCart(
      productWithWeight.name,
      totalPrice,
      productWithWeight.unit,
      quantity: 1,
      availableStock: productWithWeight.stock,
    );
    
    // Mostrar confirmación
    Get.snackbar(
      'Producto Agregado',
      '${productWithWeight.name}\n'
      'Peso: ${_weightController.currentWeight.value.toStringAsFixed(3)} kg\n'
      'Total: \$${totalPrice.toStringAsFixed(0)}',
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade800,
      duration: const Duration(seconds: 3),
    );
    
    // Limpiar selección
    _selectedProduct = null;
    _barcodeController.clear();
    _quantityController.text = '1';
    _weightController.selectedProduct.value = null;
    
    // Volver al modo de escaneo
    _currentMode = 'barcode';
    _barcodeFocus.requestFocus();
    
    setState(() {});
  }

  // Método para debug de balanza
  Future<void> _debugScale() async {
    try {
      print('🔍 INICIANDO DEBUG DE BALANZA');
      
      // Verificar si el controlador existe
      print('⚖️ Controlador de peso: ${_weightController.runtimeType}');
      print('🔗 Conectada: ${_weightController.isConnected.value}');
      print('📊 Peso actual: ${_weightController.currentWeight.value}');
      
      // Intentar conectar
      print('🔌 Intentando conectar...');
      await _weightController.connectScale();
      
      // Esperar un momento
      await Future.delayed(const Duration(seconds: 2));
      
      // Verificar estado después de conectar
      print('🔗 Estado después de conectar: ${_weightController.isConnected.value}');
      
      if (_weightController.isConnected.value) {
        print('✅ Balanza conectada exitosamente');
        
        // Iniciar lectura
        await _weightController.startReading();
        print('📖 Lectura iniciada');
        
        // Esperar para obtener peso
        await Future.delayed(const Duration(seconds: 3));
        print('📊 Peso leído: ${_weightController.currentWeight.value} kg');
        
        Get.snackbar(
          'Debug Balanza',
          'Balanza conectada\nPeso: ${_weightController.currentWeight.value.toStringAsFixed(3)} kg',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else {
        print('❌ Error: No se pudo conectar la balanza');
        Get.snackbar(
          'Debug Balanza',
          'Error: No se pudo conectar la balanza\nRevisa la conexión USB',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      print('❌ Error en debug: $e');
      Get.snackbar(
        'Debug Balanza',
        'Error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _updateCartItemPrice(CartItem cartItem, double newPrice) {
    // Encontrar el índice del elemento en el carrito
    final index = _posController.cartItems.indexWhere((item) => 
      item.name == cartItem.name && item.price == cartItem.price);
    
    if (index >= 0) {
      _posController.changeItemPrice(index, newPrice);
    } else {
      Get.snackbar(
        'Error',
        'No se pudo encontrar el elemento en el carrito',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
} 