import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'pos_controller.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../services/authorization_service.dart';
import '../widgets/authorization_modal.dart';
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
  
  @override
  void initState() {
    super.initState();
    _posController = Get.put(PosController());
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
            Text('Precio: \$${NumberFormat('#,###').format(_selectedProduct!.price)}'),
            Text('Stock: ${_selectedProduct!.stock}'),
            if (_selectedProduct!.isWeighted) Text('Producto por peso'),
            const SizedBox(height: 16),
            // Campo de cantidad
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
            const SizedBox(height: 12),
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addToCart(int.tryParse(_quantityController.text) ?? 1),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar al Carrito'),
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
                          Text(
                            '\$${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, color: Colors.blue),
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
                  subtitle: Text('${item.quantity} x \$${NumberFormat('#,###').format(item.price)}'),
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
                              trailing: Text(
                                '\$${NumberFormat('#,###').format(product.price)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected ? Colors.blue[800] : Colors.black,
                                ),
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
    _posController.clearCart();
    Get.snackbar(
      'Carrito limpiado',
      'Se han removido todos los productos',
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
} 