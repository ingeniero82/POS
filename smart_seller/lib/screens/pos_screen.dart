import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'pos_controller.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../services/authorization_service.dart';
import '../services/print_service.dart';
import '../widgets/authorization_modal.dart';
import '../services/permissions_service.dart';
import '../models/permissions.dart';
import '../services/auth_service.dart';
import '../modules/weight/controllers/weight_controller.dart';
import '../modules/weight/widgets/scale_widget.dart';
import '../modules/electronic_invoicing/controllers/electronic_invoice_controller.dart';
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
    
    // ✅ Auto-focus al barcode al iniciar
    _ensureBarcodeFocus();
  }
  
  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }
  
  // ✅ FUNCIÓN HELPER PARA ASEGURAR FOCUS
  void _ensureBarcodeFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _currentMode == 'barcode') {
          _barcodeFocus.requestFocus();
        }
      });
    });
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _products = await SQLiteDatabaseService.getAllProducts();
    } catch (e) {
      Get.snackbar('Error', 'Error cargando productos: $e');
    } finally {
      setState(() => _isLoading = false);
      // ✅ Asegurar focus después de cargar productos
      _ensureBarcodeFocus();
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
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false, // ❌ Cambiado a false para no interferir
      onKeyEvent: _handleKeyPress,
      child: Scaffold(
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
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Volver al Dashboard',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'SMART SELLER POS',
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
                  onPressed: _showHelp,
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
        ],
      ),
    ),  // Cierre del KeyboardListener
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
              _currentMode == 'barcode' 
                ? (_selectedProduct?.isWeighted == true 
                    ? '⚖️ Producto por peso seleccionado' 
                    : '📱 Escanear código de barras')
                : '⌨️ Ingresar cantidad',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentMode == 'barcode' ? _barcodeController : _quantityController,
              focusNode: _currentMode == 'barcode' ? _barcodeFocus : _quantityFocus,
              autofocus: false, // ❌ Cambiado a false para evitar conflictos
              keyboardType: _currentMode == 'quantity' ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                hintText: _currentMode == 'barcode' 
                    ? (_selectedProduct?.isWeighted == true 
                        ? 'Use la balanza integrada para pesar...'
                        : 'Escanear código o escribir código PLU...')
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
      color: _selectedProduct!.isWeighted ? Colors.orange[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Producto Seleccionado:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _selectedProduct!.isWeighted ? Colors.orange[700] : Colors.blue[700],
                    ),
                  ),
                ),
                if (_selectedProduct!.isWeighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.scale,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Por Peso',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedProduct!.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Código: ${_selectedProduct!.code}'),
            if (_selectedProduct!.isWeighted) 
              Text('Precio/kg: \$${_selectedProduct!.pricePerKg?.toStringAsFixed(0) ?? '0'}')
            else
              Text('Precio: \$${NumberFormat('#,###').format(_selectedProduct!.price)}'),
            Text('Stock: ${_selectedProduct!.stock}'),
            const SizedBox(height: 16),
            
            // Campo de cantidad SOLO para productos NO pesados
            if (!_selectedProduct!.isWeighted) ...[
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
                onSubmitted: (value) => _addToCart(int.tryParse(value) ?? 1),
              ),
              const SizedBox(height: 16),
            ],
            
            // Para productos pesados, mostrar mensaje informativo
            if (_selectedProduct!.isWeighted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Producto por peso: Use la balanza integrada en el panel derecho',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelSelection(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_selectedProduct!.isWeighted)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _addToCart(int.tryParse(_quantityController.text) ?? 1),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Agregar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Productos Frecuentes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Táctil',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // 3 columnas
                        childAspectRatio: 1.2, // Proporción ancho:alto
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _products.take(9).length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        
                        return _ProductButton(
                          product: product,
                          teclaNumero: '', // ❌ SIN NÚMERO DE TECLA
                          onTap: () => _selectProduct(product),
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
          
          // Widget de Peso (integrado en POS) - Solo aparece si hay producto pesado o balanza conectada
          _buildWeightDisplay(),
          
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 16),
                ),
                Obx(() => Text(
                  '\$${_posController.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Obx(() => Text(
                  '\$${_posController.total.toStringAsFixed(0)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget de peso integrado en POS (solo aparece cuando es relevante)
  Widget _buildWeightDisplay() {
    // Solo mostrar si hay un producto pesado seleccionado O si la balanza está conectada
    if (_selectedProduct?.isWeighted != true && !_weightController.isConnected.value) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      color: _selectedProduct?.isWeighted == true ? Colors.orange.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título con estado de balanza
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.scale, 
                      size: 20, 
                      color: _selectedProduct?.isWeighted == true ? Colors.orange.shade700 : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedProduct?.isWeighted == true ? '⚖️ Producto por Peso' : 'Balanza',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedProduct?.isWeighted == true ? Colors.orange.shade700 : Colors.grey.shade700,
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
            
            // Peso actual y cálculos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedProduct?.isWeighted == true ? Colors.orange.shade300 : Colors.grey.shade300,
                  width: _selectedProduct?.isWeighted == true ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  // Peso actual
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Peso:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Obx(() => Text(
                        '${_weightController.currentWeight.value.toStringAsFixed(3)} kg',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _weightController.isConnected.value ? Colors.blue.shade700 : Colors.grey,
                        ),
                      )),
                    ],
                  ),
                  
                  // Si hay producto pesado seleccionado, mostrar cálculos
                  if (_selectedProduct?.isWeighted == true) ...[
                    const Divider(height: 20),
                    
                    // Precio por kg
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Precio/kg:',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        Text(
                          '\$${_selectedProduct!.pricePerKg?.toStringAsFixed(0) ?? '0'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Precio total calculado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Obx(() {
                          final totalPrice = (_selectedProduct!.pricePerKg ?? 0) * _weightController.currentWeight.value;
                          return Text(
                            '\$${totalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Botón para agregar al carrito
                    Obx(() {
                      final hasValidWeight = _weightController.currentWeight.value > 0;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: hasValidWeight ? _addWeightProductToCart : null,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: Text(
                            hasValidWeight 
                              ? 'Agregar al Carrito'
                              : 'Coloque producto en la balanza',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }),
                  ],
                  
                  const SizedBox(height: 12),
                  
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
                ],
              ),
            ),
            
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
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Carrito de Compras',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Obx(() => Text(
                  '${_posController.cartItems.length} items',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                )),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (_posController.cartItems.isEmpty) {
                  return const Center(
                    child: Text(
                      '🛒 Carrito vacío\nEscanea productos para agregar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: _posController.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _posController.cartItems[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text('${item.quantity}'),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${item.unit} x \$${item.price.toStringAsFixed(0)}'),
                      trailing: Text(
                        '\$${(item.quantity * item.price).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _showItemOptions(item, index),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Fila de botones principales
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearCart,
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
                onPressed: _openCashDrawer,
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Cajón (F5)'),
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
                onPressed: _finalizeSale,
                icon: const Icon(Icons.payment),
                label: const Text('Finalizar Venta (F6)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // ================== MÉTODOS DE LÓGICA ==================
  
  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Solo manejar teclas de función
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
          _cancelSelection();
          break;
        case 'Enter':
          // Solo si hay producto seleccionado
          if (_selectedProduct != null && !_selectedProduct!.isWeighted) {
            _addToCart(int.tryParse(_quantityController.text) ?? 1);
          }
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
    // Si hay un producto pesado seleccionado, no permitir cambiar a modo cantidad
    if (mode == 'quantity' && _selectedProduct?.isWeighted == true) {
      Get.snackbar(
        'Modo no disponible',
        'Para productos por peso use la balanza integrada',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    setState(() {
      _currentMode = mode;
      if (mode != 'quantity') {
        _selectedProduct = null;
      }
    });
    
    // ✅ MEJORAR FOCUS - Con delay para asegurar que el widget se haya reconstruido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          if (mode == 'barcode') {
            _barcodeFocus.requestFocus();
          } else if (mode == 'quantity') {
            _quantityFocus.requestFocus();
          }
        }
      });
    });
  }
  
  void _searchProduct(String code) {
    // Primero buscar por código exacto
    final exactMatch = _products.where((p) => p.code == code || p.shortCode == code).toList();
    
    if (exactMatch.isNotEmpty) {
      _selectProduct(exactMatch.first);
      return;
    }
    
    // Si no hay código exacto, buscar por nombre
    final nameMatches = _products.where((p) =>
      quitarTildes(p.name.toLowerCase()).contains(quitarTildes(code.toLowerCase()))
    ).toList();
    
    if (nameMatches.isEmpty) {
      // ❌ MENSAJE MOLESTO ELIMINADO - No mostrar nada cuando no encuentre productos
      // Solo limpiar el campo y mantener el focus
      _barcodeController.clear();
      _ensureBarcodeFocus();
      return;
    }
    
    if (nameMatches.length == 1) {
      _selectProduct(nameMatches.first);
    } else {
      _showProductSelectionDialog(nameMatches, code);
    }
  }
  
  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      // SOLO cambiar a modo cantidad si el producto NO es pesado
      if (!product.isWeighted) {
        _currentMode = 'quantity';
      }
      // Para productos pesados, mantener el modo 'barcode' 
    });
    
    // Para productos pesados, actualizar el controlador de peso
    if (product.isWeighted) {
      _weightController.selectProduct(product);
    }
    
    // Configurar el campo de cantidad solo para productos normales
    if (!product.isWeighted) {
      _quantityController.text = '1';
      _quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantityController.text.length,
      );
      
      // Enfocar el campo de cantidad después de un breve delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _quantityFocus.requestFocus();
      });
    }
    
    _barcodeController.clear();
    
    // ❌ MENSAJE ELIMINADO - Era innecesario y molesto
    // Solo mostrar mensaje cuando efectivamente se agregue al carrito
  }
  
  void _addToCart(int quantity) {
    if (_selectedProduct == null) {
      Get.snackbar('Error', 'No hay producto seleccionado');
      return;
    }
    
    if (_selectedProduct!.isWeighted) {
      Get.snackbar('Error', 'Use la balanza integrada para productos por peso');
      return;
    }
    
    _posController.addToCart(
      _selectedProduct!.name,
      _selectedProduct!.price,
      _selectedProduct!.unit,
      quantity: quantity,
      availableStock: _selectedProduct!.stock,
    );
    
    Get.snackbar(
      '✅ Agregado',
      '${_selectedProduct!.name} x$quantity',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 1), // ⚡ MÁS RÁPIDO
    );
    
    _cancelSelection();
  }
  
  // Método para agregar productos por peso al carrito
  void _addWeightProductToCart() {
    if (_selectedProduct == null || !_selectedProduct!.isWeighted) {
      Get.snackbar('Error', 'No hay producto pesado seleccionado');
      return;
    }
    
    final currentWeight = _weightController.currentWeight.value;
    if (currentWeight <= 0) {
      Get.snackbar('Error', 'Peso inválido');
      return;
    }
    
    // Validar límites de peso si existen
    if (_selectedProduct!.minWeight != null && currentWeight < _selectedProduct!.minWeight!) {
      Get.snackbar('Error', 'Peso mínimo: ${_selectedProduct!.minWeight!.toStringAsFixed(3)} kg');
      return;
    }
    
    if (_selectedProduct!.maxWeight != null && currentWeight > _selectedProduct!.maxWeight!) {
      Get.snackbar('Error', 'Peso máximo: ${_selectedProduct!.maxWeight!.toStringAsFixed(3)} kg');
      return;
    }
    
    // Calcular precio total
    final pricePerKg = _selectedProduct!.pricePerKg ?? 0;
    final totalPrice = pricePerKg * currentWeight;
    
    // Agregar al carrito con información de peso
    _posController.addToCart(
      '${_selectedProduct!.name} (${currentWeight.toStringAsFixed(3)} kg)',
      totalPrice,
      'kg',
      quantity: 1, // Siempre 1 para productos pesados
      availableStock: _selectedProduct!.stock,
    );
    
    // Mensaje de confirmación optimizado
    Get.snackbar(
      '⚖️ Pesado agregado',
      '${_selectedProduct!.name} - ${currentWeight.toStringAsFixed(3)} kg - \$${totalPrice.toStringAsFixed(0)}',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 1, milliseconds: 500), // ⚡ MÁS RÁPIDO
    );
    
    // Limpiar selección y volver al modo de escaneo
    _cancelSelection();
  }
  
  void _cancelSelection() {
    setState(() {
      _selectedProduct = null;
      _currentMode = 'barcode';
    });
    
    _barcodeController.clear();
    _quantityController.text = '1';
    _weightController.selectedProduct.value = null;
    
    // ✅ Asegurar focus en búsqueda
    _ensureBarcodeFocus();
  }
  
  void _showProductSelectionDialog(List<Product> products, String searchTerm) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Producto (${products.length} encontrados)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.isWeighted ? Colors.orange[100] : Colors.blue[100],
                  child: Icon(
                    product.isWeighted ? Icons.scale : Icons.inventory,
                    color: product.isWeighted ? Colors.orange[700] : Colors.blue[700],
                  ),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código: ${product.code}'),
                    Text(
                      product.isWeighted 
                        ? 'Precio: \$${product.pricePerKg?.toStringAsFixed(0) ?? '0'}/kg'
                        : 'Precio: \$${NumberFormat('#,###').format(product.price)}',
                    ),
                  ],
                ),
                trailing: product.isWeighted
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PESO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    )
                  : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _selectProduct(product);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _barcodeController.clear();
              // ✅ Asegurar focus después de cerrar dialog
              Future.delayed(const Duration(milliseconds: 200), () {
                _ensureBarcodeFocus();
              });
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _showItemOptions(item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Opciones: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Cambiar cantidad'),
              onTap: () {
                Navigator.of(context).pop();
                _checkPermissionAndExecute('changeCartQuantity', () {
                  _showQuantityDialog(item, index);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.orange),
              title: const Text('Modificar precio'),
              onTap: () {
                Navigator.of(context).pop();
                _checkPermissionAndExecute('modifyCartPrice', () {
                  _showPriceDialog(item, index);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.of(context).pop();
                _checkPermissionAndExecute('removeCartItem', () {
                  _posController.removeFromCart(index);
                  Get.snackbar(
                    'Producto eliminado',
                    '${item.name} eliminado del carrito',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showQuantityDialog(item, int index) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Cantidad'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nueva cantidad',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final newQuantity = int.tryParse(value) ?? 1;
            Navigator.of(context).pop();
            _posController.updateQuantity(index, newQuantity);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text) ?? 1;
              Navigator.of(context).pop();
              _posController.updateQuantity(index, newQuantity);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
  
  void _clearCart() {
    if (_isAuthorizationValid()) {
      _performClearCart();
      return;
    }
    
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
  
  void _openCashDrawer() {
    Get.snackbar(
      'Cajón abierto',
      'Comando enviado para abrir el cajón monedero',
      backgroundColor: Colors.blue,
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
    
    // Mostrar opciones de finalización
    _showPaymentOptionsDialog();
  }
  
  void _showPaymentOptionsDialog() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 12),
            Text('Finalizar Venta'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selecciona el tipo de facturación:',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              _posController.processPayment();
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Venta Normal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              _openElectronicInvoiceModal();
            },
            icon: const Icon(Icons.description),
            label: const Text('Facturación Electrónica'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  void _openElectronicInvoiceModal() {
    // Cargar productos del carrito actual
    final cartProducts = _posController.cartItems.map((item) {
      return {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'total': item.quantity * item.price,
      };
    }).toList();
    
    Get.dialog(
      Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: _ElectronicInvoiceModalContent(
            cartProducts: cartProducts,
            cartTotal: _posController.total,
            onComplete: (success) {
              if (success) {
                _posController.clearCart();
                Get.snackbar(
                  'Éxito',
                  'Factura electrónica procesada correctamente',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
  
  void _handlePayment(String value) {
    // Implementar lógica de pago
    Get.snackbar('Pago', 'Procesando pago: $value');
  }
  
  void _showHelp() {
    Get.dialog(
      AlertDialog(
        title: const Text('Atajos de Teclado'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 ESCANEAR: Escanear código de barras'),
            Text('⌨️ CANTIDAD: Ingresar cantidad (Enter = 1)'),
            Text('💳 PAGO: Seleccionar forma de pago'),
            SizedBox(height: 16),
            Text('F1: Mostrar ayuda'),
            Text('F4: Limpiar carrito'),
            Text('F5: Abrir cajón monedero'),
            Text('F6: Finalizar venta / Facturación electrónica'),
            Text('ESC: Cancelar operación actual'),
            Text('ENTER: Confirmar acción'),
            SizedBox(height: 16),
            Text('🖱️ PRODUCTOS FRECUENTES:'),
            Text('• Usa los botones táctiles'),
            Text('• Selección rápida y fácil'),
            SizedBox(height: 8),
            Text('⚖️ PRODUCTOS POR PESO:'),
            Text('• Selecciona producto pesado'),
            Text('• Usa balanza integrada en panel derecho'),
            Text('• Precio se calcula automáticamente'),
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
  
  void _showAuthorizationDialog() {
    showDialog(
      context: context,
      builder: (context) => AuthorizationModal(
        action: 'CLEAR_CART',
        onAuthorized: (code) {
          _setAuthorization('Usuario autorizado');
          _performClearCart();
        },
        onCancelled: () {
          // No hacer nada, el diálogo ya se cerró
        },
      ),
    );
  }
  
  void _setAuthorization(String user) {
    setState(() {
      _isAuthorized = true;
      _authorizationTime = DateTime.now();
      _authorizedUser = user;
    });
  }
  
  String _getTimeRemaining() {
    if (_authorizationTime == null) return '';
    
    final now = DateTime.now();
    final elapsed = now.difference(_authorizationTime!);
    final remaining = const Duration(minutes: 5) - elapsed;
    
    if (remaining.isNegative) {
      _clearAuthorization();
      return '';
    }
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes}m ${seconds}s restantes';
  }

  // Verificar permisos y ejecutar acción o solicitar autorización
  void _checkPermissionAndExecute(String action, VoidCallback executeAction) {
    final currentUser = AuthService.to.currentUser;
    if (currentUser == null) return;

    Permission? requiredPermission;
    String actionDescription = '';
    
    switch (action) {
      case 'changeCartQuantity':
        requiredPermission = Permission.changeCartQuantity;
        actionDescription = 'Cambiar cantidad en carrito';
        break;
      case 'removeCartItem':
        requiredPermission = Permission.removeCartItem;
        actionDescription = 'Eliminar producto del carrito';
        break;
      case 'modifyCartPrice':
        requiredPermission = Permission.modifyCartPrice;
        actionDescription = 'Modificar precio en carrito';
        break;
    }

    if (requiredPermission == null) {
      executeAction();
      return;
    }

    // Verificar si el usuario actual tiene el permiso
    final permissionsService = PermissionsService.to;
    if (permissionsService.hasPermission(currentUser.role, requiredPermission)) {
      executeAction();
      return;
    }

    // Si no tiene permiso, solicitar autorización
    _requestAuthorization(action, actionDescription, executeAction);
  }

  void _requestAuthorization(String action, String description, VoidCallback executeAction) {
    showDialog(
      context: context,
      builder: (context) => AuthorizationModal(
        action: action.toUpperCase(),
        onAuthorized: (authorizerInfo) {
          Get.snackbar(
            '✅ Autorizado',
            '$description autorizado por: $authorizerInfo',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
          executeAction();
        },
        onCancelled: () {
          // No hacer nada, el diálogo ya se cerró
        },
      ),
    );
  }

  void _showPriceDialog(item, int index) {
    final controller = TextEditingController(text: item.price.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Producto: ${item.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo precio',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final newPrice = double.tryParse(value) ?? item.price;
                Navigator.of(context).pop();
                _posController.updateItemPrice(index, newPrice);
                Get.snackbar(
                  '💰 Precio modificado',
                  '${item.name}: \$${item.price.toStringAsFixed(0)} → \$${newPrice.toStringAsFixed(0)}',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text) ?? item.price;
              Navigator.of(context).pop();
              _posController.updateItemPrice(index, newPrice);
              Get.snackbar(
                '💰 Precio modificado',
                '${item.name}: \$${item.price.toStringAsFixed(0)} → \$${newPrice.toStringAsFixed(0)}',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}

// Widget para botón táctil de producto
class _ProductButton extends StatelessWidget {
  final Product product;
  final String teclaNumero;
  final VoidCallback onTap;

  const _ProductButton({
    required this.product,
    required this.teclaNumero,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWeighted = product.isWeighted;
    final primaryColor = isWeighted ? Colors.orange : Colors.blue;
    final backgroundColor = isWeighted ? Colors.orange[50] : Colors.blue[50];
    final iconColor = isWeighted ? Colors.orange[700] : Colors.blue[700];
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: primaryColor.withOpacity(0.3),
        highlightColor: primaryColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fila superior: Solo icono de peso si es necesario
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isWeighted)
                    Icon(
                      Icons.scale,
                      size: 16,
                      color: iconColor,
                    ),
                ],
              ),
              
              // Centro: Icono principal
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isWeighted ? Icons.scale : Icons.inventory_2,
                  color: iconColor,
                  size: 24,
                ),
              ),
              
              // Parte inferior: Nombre y precio
              Column(
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isWeighted 
                        ? '\$${product.pricePerKg?.toStringAsFixed(0) ?? '0'}/kg'
                        : '\$${NumberFormat('#,###').format(product.price)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modal completo para facturación electrónica
class _ElectronicInvoiceModalContent extends StatefulWidget {
  final List<Map<String, dynamic>> cartProducts;
  final double cartTotal;
  final Function(bool success) onComplete;

  const _ElectronicInvoiceModalContent({
    required this.cartProducts,
    required this.cartTotal,
    required this.onComplete,
  });

  @override
  State<_ElectronicInvoiceModalContent> createState() => _ElectronicInvoiceModalContentState();
}

class _ElectronicInvoiceModalContentState extends State<_ElectronicInvoiceModalContent>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  
  // Controladores de formulario
  final _invoiceNumberController = TextEditingController();
  final _clientNitController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _observationsController = TextEditingController();
  
  String _selectedPaymentMethod = 'Efectivo';
  String _selectedClientType = 'CUANTIAS MENORES';
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Generar número de factura automático
    final now = DateTime.now();
    _invoiceNumberController.text = 'FE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceNumberController.dispose();
    _clientNitController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Facturación Electrónica DIAN'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Get.back();
              widget.onComplete(false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1976D2),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total a facturar: \$${NumberFormat('#,###').format(widget.cartTotal)} - ${widget.cartProducts.length} productos',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Pestañas
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF1976D2),
              tabs: const [
                Tab(icon: Icon(Icons.description), text: 'Datos Factura'),
                Tab(icon: Icon(Icons.person), text: 'Cliente'),
                Tab(icon: Icon(Icons.shopping_cart), text: 'Productos'),
              ],
            ),
          ),
          
          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoiceDataTab(),
                _buildClientTab(),
                _buildProductsTab(),
              ],
            ),
          ),
          
          // Botones de acción
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      widget.onComplete(false);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveDraft,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Borrador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendToDIAN,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Enviando...' : 'Enviar a DIAN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Información de la Factura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de Factura *',
                  hintText: 'Ej: FE-001',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                items: ['Efectivo', 'Tarjeta Débito', 'Tarjeta Crédito', 'Transferencia', 'Cheque']
                    .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                decoration: const InputDecoration(
                  labelText: 'Método de Pago *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _observationsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Información adicional (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Datos del Cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateClientDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Cliente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedClientType,
                items: ['CUANTIAS MENORES', 'CLIENTE REGISTRADO']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedClientType = value!),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cliente *',
                  border: OutlineInputBorder(),
                ),
              ),
              
              if (_selectedClientType == 'CLIENTE REGISTRADO') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientNitController,
                  decoration: const InputDecoration(
                    labelText: 'NIT/RUT *',
                    hintText: 'Ej: 123456789-0',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Razón Social *',
                    hintText: 'Nombre completo o razón social',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'correo@ejemplo.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: 'Ej: 3001234567',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Dirección completa',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    final subtotal = widget.cartTotal;
    final iva = subtotal * 0.19;
    final total = subtotal + iva;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productos de la Factura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Lista de productos
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.cartProducts.length,
                itemBuilder: (context, index) {
                  final product = widget.cartProducts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.inventory_2, color: Colors.white),
                      ),
                      title: Text(product['name']),
                      subtitle: Text('Cantidad: ${product['quantity']} x \$${NumberFormat('#,###').format(product['price'])}'),
                      trailing: Text(
                        '\$${NumberFormat('#,###').format(product['total'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              
              // Totales
              Container(
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
                        Text('\$${NumberFormat('#,###').format(subtotal)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('IVA (19%):'),
                        Text('\$${NumberFormat('#,###').format(iva)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '\$${NumberFormat('#,###').format(total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateClientDialog() {
    final nitController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Crear Nuevo Cliente'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nitController,
                decoration: const InputDecoration(
                  labelText: 'NIT/RUT *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Razón Social *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nitController.text.isNotEmpty && nameController.text.isNotEmpty) {
                // Llenar los campos del cliente
                setState(() {
                  _selectedClientType = 'CLIENTE REGISTRADO';
                  _clientNitController.text = nitController.text;
                  _clientNameController.text = nameController.text;
                  _clientEmailController.text = emailController.text;
                  _clientPhoneController.text = phoneController.text;
                  _clientAddressController.text = addressController.text;
                });
                
                Get.back();
                Get.snackbar(
                  'Cliente Creado',
                  'Cliente agregado a la factura',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Error',
                  'NIT y Razón Social son obligatorios',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _saveDraft() async {
    setState(() => _isLoading = true);
    
    try {
      // Simular guardado de borrador
      await Future.delayed(const Duration(seconds: 1));
      
      Get.snackbar(
        'Borrador Guardado',
        'La factura se guardó como borrador',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al guardar borrador: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendToDIAN() async {
    // Validaciones
    if (_invoiceNumberController.text.isEmpty) {
      Get.snackbar('Error', 'El número de factura es obligatorio');
      return;
    }

    if (_selectedClientType == 'CLIENTE REGISTRADO' && 
        (_clientNitController.text.isEmpty || _clientNameController.text.isEmpty)) {
      Get.snackbar('Error', 'Los datos del cliente son obligatorios');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Simular envío a DIAN
      await Future.delayed(const Duration(seconds: 2));
      
      Get.back();
      widget.onComplete(true);
      
      Get.snackbar(
        'Éxito',
        'Factura electrónica enviada a DIAN correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al enviar a DIAN: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 