import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../services/authorization_service.dart';
import '../widgets/authorization_modal.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Added for RawKeyboard
import 'package:flutter_typeahead/flutter_typeahead.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  ProductCategory? _selectedCategory;

  // --- NUEVO: Controladores para el diálogo flotante de cantidad ---
  Product? _dialogSelectedProduct;
  final TextEditingController _dialogProductController = TextEditingController();
  final TextEditingController _dialogQuantityController = TextEditingController(text: '1');
  final FocusNode _dialogProductFocus = FocusNode();
  final FocusNode _dialogQuantityFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Auto-focus al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
    // --- NUEVO: Listener global de teclado para F3 o * ---
    // Eliminado: RawKeyboard.instance.addListener(_handleGlobalKey);
  }

  @override
  void dispose() {
    // Eliminado: RawKeyboard.instance.removeListener(_handleGlobalKey);
    _dialogProductController.dispose();
    _dialogQuantityController.dispose();
    _dialogProductFocus.dispose();
    _dialogQuantityFocus.dispose();
    super.dispose();
  }

  void _handleGlobalKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey.keyLabel == '*' || event.logicalKey.keyLabel.toUpperCase() == 'F3') {
        _showQuickAddDialog();
      }
    }
  }

  void _showQuickAddDialog() {
    _dialogProductController.clear();
    _dialogQuantityController.text = '1';
    _dialogSelectedProduct = null;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        // Forzar el foco al campo de búsqueda al abrir el diálogo
        Future.delayed(Duration.zero, () {
          _dialogProductFocus.requestFocus();
        });
        return StatefulBuilder(
          builder: (context, setState) {
            void focusCantidad() {
              Future.delayed(Duration.zero, () {
                _dialogQuantityFocus.requestFocus();
                _dialogQuantityController.selection = TextSelection(baseOffset: 0, extentOffset: _dialogQuantityController.text.length);
              });
            }
            return AlertDialog(
                title: const Text('Agregar producto rápido'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeAheadField<Product>(
                      textFieldConfiguration: TextFieldConfiguration(
                        controller: _dialogProductController,
                        focusNode: _dialogProductFocus,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Buscar producto',
                        ),
                      ),
                      suggestionsCallback: (pattern) async {
                        if (pattern.isEmpty) return [];
                        return _products.where((p) =>
                          p.name.toLowerCase().contains(pattern.toLowerCase()) ||
                          p.code.toLowerCase().contains(pattern.toLowerCase()) ||
                          (p.shortCode != null && p.shortCode!.toLowerCase().contains(pattern.toLowerCase()))
                        ).toList();
                      },
                      itemBuilder: (context, Product suggestion) {
                        return ListTile(
                          title: Text(suggestion.name),
                          subtitle: Text('Código: ${suggestion.code}  Precio: ${suggestion.price.toStringAsFixed(0)}'),
                        );
                      },
                      onSuggestionSelected: (Product suggestion) {
                        setState(() {
                          _dialogSelectedProduct = suggestion;
                        });
                        Future.delayed(Duration.zero, () {
                          _dialogQuantityFocus.requestFocus();
                          _dialogQuantityController.selection = TextSelection(baseOffset: 0, extentOffset: _dialogQuantityController.text.length);
                        });
                      },
                      noItemsFoundBuilder: (context) => const ListTile(title: Text('No se encontró producto')),
                    ),
                    const SizedBox(height: 12),
                    if (_dialogSelectedProduct != null) ...[
                      Text('Código:  ${_dialogSelectedProduct!.code}'),
                      Text('Precio:  ${_dialogSelectedProduct!.price.toStringAsFixed(0)}'),
                      Text('Stock:  ${_dialogSelectedProduct!.stock}'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dialogQuantityController,
                        focusNode: _dialogQuantityFocus,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          hintText: 'Ingrese cantidad',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onSubmitted: (_) {
                          final posController = Get.find<PosController>();
                          if (int.tryParse(_dialogQuantityController.text) != null && int.parse(_dialogQuantityController.text) > 0) {
                            posController.addToCart(
                              _dialogSelectedProduct!.name,
                              _dialogSelectedProduct!.price,
                              _dialogSelectedProduct!.unit,
                              quantity: int.parse(_dialogQuantityController.text),
                              availableStock: _dialogSelectedProduct!.stock,
                            );
                            Navigator.of(context).pop();
                            Get.snackbar(
                              'Producto agregado',
                              '${_dialogSelectedProduct!.name} x${_dialogQuantityController.text} agregado al carrito',
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 1),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar (Esc)'),
                  ),
                  ElevatedButton(
                    onPressed: _dialogSelectedProduct != null && int.tryParse(_dialogQuantityController.text) != null && int.parse(_dialogQuantityController.text) > 0
                      ? () {
                          final posController = Get.find<PosController>();
                          posController.addToCart(
                            _dialogSelectedProduct!.name,
                            _dialogSelectedProduct!.price,
                            _dialogSelectedProduct!.unit,
                            quantity: int.parse(_dialogQuantityController.text),
                            availableStock: _dialogSelectedProduct!.stock,
                          );
                          Navigator.of(context).pop();
                          Get.snackbar(
                            'Producto agregado',
                            '${_dialogSelectedProduct!.name} x${_dialogQuantityController.text} agregado al carrito',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 1),
                          );
                        }
                      : null,
                    child: const Text('Agregar (Enter)'),
                  ),
                ],
              );
          },
        );
      },
    );
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await SQLiteDatabaseService.getAllProducts();
    setState(() {
      _products = products;
      _filteredProducts = products;
      _isLoading = false;
    });
  }

  void _filterProducts() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredProducts = _products.where((product) {
        // Filtro por texto
        final matchesText = product.name.toLowerCase().contains(query) ||
               product.code.toLowerCase().contains(query) ||
               product.shortCode.toLowerCase().contains(query);
        
        // Filtro por categoría
        final matchesCategory = _selectedCategory == null || product.category == _selectedCategory;
        
        return matchesText && matchesCategory;
      }).toList();
    });
  }
  
  void _selectCategory(ProductCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterProducts();
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // quita espacios y signos
  }

  void _addProductBySearch(String query) {
    final inputNorm = normalize(query.trim());
    if (inputNorm.isEmpty) {
      _searchFocusNode.requestFocus();
      return;
    }
    // Coincidencia exacta por código, nombre o código corto
    final exactMatches = _products.where((product) =>
      product.code.toLowerCase() == inputNorm ||
      normalize(product.name) == inputNorm ||
      (product.shortCode != null && normalize(product.shortCode!) == inputNorm)
    ).toList();

    if (exactMatches.length == 1) {
      final product = exactMatches.first;
      final posController = Get.find<PosController>();
      if (product.isWeighted) {
        Get.snackbar(
          'Producto pesado',
          'Debes usar la balanza o ingresar el peso manualmente',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        posController.addToCart(
          product.name,
          product.price,
          product.unit,
          availableStock: product.stock,
        );
        Get.snackbar(
          'Producto agregado',
          '${product.name} agregado al carrito',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
      }
    } else if (exactMatches.isEmpty) {
      // Coincidencia parcial por nombre o código
      final partialMatches = _products.where((product) =>
        normalize(product.name).contains(inputNorm) ||
        product.code.toLowerCase().contains(inputNorm) ||
        (product.shortCode != null && normalize(product.shortCode!).contains(inputNorm))
      ).toList();
      if (partialMatches.length == 1) {
        final product = partialMatches.first;
        final posController = Get.find<PosController>();
        if (product.isWeighted) {
          Get.snackbar(
            'Producto pesado',
            'Debes usar la balanza o ingresar el peso manualmente',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        } else {
          posController.addToCart(
            product.name,
            product.price,
            product.unit,
            availableStock: product.stock,
          );
          Get.snackbar(
            'Producto agregado',
            '${product.name} agregado al carrito',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 1),
          );
        }
      } else if (partialMatches.isEmpty) {
        Get.snackbar(
          'No encontrado',
          'No existe un producto con ese código o nombre',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Múltiples coincidencias',
          'Especifica mejor el producto (hay más de uno con ese nombre/código)',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } else {
      Get.snackbar(
        'Múltiples coincidencias',
        'Especifica mejor el producto (hay más de uno con ese nombre/código)',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final posController = Get.put(PosController());
    final NumberFormat copFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');
    
    return Focus(
      autofocus: true,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey.keyLabel == '*' || event.logicalKey.keyLabel.toUpperCase() == 'F3') {
            _showQuickAddDialog();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Campo de búsqueda grande y centrado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: 500,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        onSubmitted: _addProductBySearch,
                        decoration: InputDecoration(
                          hintText: 'Buscar producto por nombre, código o escanear...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          filled: true,
                          fillColor: const Color(0xFFF6F8FA),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          hintStyle: const TextStyle(fontSize: 18),
                        ),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ShortcutChip(label: 'Enter', description: 'Agregar producto'),
                        const SizedBox(width: 8),
                        _ShortcutChip(label: 'Esc', description: 'Limpiar'),
                      ],
                    ),
                  ],
                ),
              ),
              // Botón de retorno al menú principal
              InkWell(
                onTap: () {
                  Get.back();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.blue[700]),
                        onPressed: () {
                          Get.back();
                        },
                      ),
                      Text(
                        'Volver al Menú Principal',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Columna de categorías y búsqueda
                    Container(
                      width: 260,
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          // Categorías
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Categorías',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22315B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                _CategoryButton(
                                  icon: Icons.grid_view,
                                  label: 'Todos los productos',
                                  selected: _selectedCategory == null,
                                  color: Color(0xFF7C4DFF),
                                  onTap: () => _selectCategory(null),
                                ),
                                _CategoryButton(
                                  icon: Icons.apple,
                                  label: 'Frutas y Verduras',
                                  selected: _selectedCategory == ProductCategory.frutasVerduras,
                                  color: Color(0xFFE53935),
                                  onTap: () => _selectCategory(ProductCategory.frutasVerduras),
                                ),
                                _CategoryButton(
                                  icon: Icons.local_drink,
                                  label: 'Lácteos',
                                  selected: _selectedCategory == ProductCategory.lacteos,
                                  color: Color(0xFF29B6F6),
                                  onTap: () => _selectCategory(ProductCategory.lacteos),
                                ),
                                _CategoryButton(
                                  icon: Icons.bakery_dining,
                                  label: 'Panadería',
                                  selected: _selectedCategory == ProductCategory.panaderia,
                                  color: Color(0xFFFFB300),
                                  onTap: () => _selectCategory(ProductCategory.panaderia),
                                ),
                                _CategoryButton(
                                  icon: Icons.set_meal,
                                  label: 'Carnes',
                                  selected: _selectedCategory == ProductCategory.carnes,
                                  color: Color(0xFF8D6E63),
                                  onTap: () => _selectCategory(ProductCategory.carnes),
                                ),
                                _CategoryButton(
                                  icon: Icons.local_bar,
                                  label: 'Bebidas',
                                  selected: _selectedCategory == ProductCategory.bebidas,
                                  color: Color(0xFF43A047),
                                  onTap: () => _selectCategory(ProductCategory.bebidas),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Columna central de productos
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Header azul
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1EC6FF), Color(0xFF3B82F6)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: const Column(
                              children: [
                                SizedBox(height: 8),
                                Text(
                                  'Sistema POS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Haz clic en los productos para agregarlos al carrito',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Cuadrícula de productos
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _filteredProducts.isEmpty
                                    ? const Center(child: Text('No hay productos para mostrar.'))
                                    : Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.transparent,
                                        child: GridView.builder(
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                            childAspectRatio: 0.8,
                                          ),
                                          itemCount: _filteredProducts.length,
                                          itemBuilder: (context, index) {
                                            final product = _filteredProducts[index];
                                            return _ProductCard(
                                              name: product.name,
                                              price: product.isWeighted 
                                                  ? copFormat.format(product.pricePerKg ?? 0) + '/kg'
                                                  : copFormat.format(product.price),
                                              unit: product.unit,
                                              shortCode: product.shortCode,
                                              color: product.isWeighted ? Colors.orange : Colors.blue,
                                              icon: product.isWeighted ? Icons.scale : Icons.shopping_bag,
                                              stock: product.stock,
                                              isWeighted: product.isWeighted,
                                              onTap: () {
                                                final posController = Get.find<PosController>();
                                                if (product.isWeighted) {
                                                  posController.addWeightedProduct(product);
                                                } else {
                                                posController.addToCart(
                                                  product.name,
                                                  product.price,
                                                  product.unit,
                                                    availableStock: product.stock,
                                                );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                    // Columna del carrito
                    Container(
                      width: 320,
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header del carrito
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Carrito de Compras',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Lista de productos en el carrito (dinámica)
                          Expanded(
                            child: Obx(() => ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: posController.cartItems.length,
                              itemBuilder: (context, index) {
                                final item = posController.cartItems[index];
                                return _CartItem(
                                  name: item.name,
                                  price: copFormat.format(item.total),
                                  quantity: item.quantity,
                                  isWeighted: item.isWeighted,
                                  weight: item.weight,
                                  onRemove: () {
                                    posController.removeFromCart(index);
                                  },
                                  onQuantityChanged: (newQuantity) {
                                    posController.updateQuantity(index, newQuantity);
                                  },
                                  onPriceChange: (newPrice) {
                                    posController.changeItemPrice(index, newPrice);
                                  },
                                  onWeightChange: (newWeight) {
                                    posController.changeItemWeight(index, newWeight);
                                  },
                                );
                              },
                            )),
                          ),
                          
                          // Resumen de totales (dinámico)
                          Obx(() => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FA),
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!, width: 1),
                              ),
                            ),
                            child: Column(
                              children: [
                                _TotalRow('Subtotal:', copFormat.format(posController.subtotal)),
                                _TotalRow('Impuestos (19%):', copFormat.format(posController.taxes)),
                                const Divider(thickness: 1),
                                _TotalRow('Total:', copFormat.format(posController.total), isTotal: true),
                              ],
                            ),
                          )),
                          
                          // Botones de acción
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Botón Procesar Pago
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      posController.processPayment();
                                    },
                                    icon: Icon(Icons.payment, color: Colors.white),
                                    label: Text('Procesar Pago'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Botones secundarios
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          // Funcionalidad de suspender venta
                                          Get.snackbar(
                                            'Venta suspendida',
                                            'La venta ha sido guardada temporalmente',
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                        },
                                        icon: Icon(Icons.pause, size: 18),
                                        label: Text('Suspender'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFF9800),
                                          side: BorderSide(color: const Color(0xFFFF9800)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          posController.clearCart();
                                        },
                                        icon: Icon(Icons.clear, size: 18),
                                        label: Text('Limpiar'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFF44336),
                                          side: BorderSide(color: const Color(0xFFF44336)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

// Widget para las tarjetas de productos
class _ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final String unit;
  final String shortCode;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final int stock;
  final bool isWeighted;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.unit,
    required this.shortCode,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.stock,
    this.isWeighted = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                shortCode,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
              ),
              Text('por $unit', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stock > 0 ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stock > 0 ? 'Stock: $stock' : 'Sin stock',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para las categorías
class _CategoryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.color,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? color.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : const Color(0xFF22315B),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para items del carrito
class _CartItem extends StatefulWidget {
  final String name;
  final String price;
  final int quantity;
  final bool isWeighted;
  final double? weight;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;
  final Function(double)? onPriceChange;
  final Function(double)? onWeightChange;

  const _CartItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.isWeighted = false,
    this.weight,
    required this.onRemove,
    required this.onQuantityChanged,
    this.onPriceChange,
    this.onWeightChange,
    Key? key,
  }) : super(key: key);

  @override
  State<_CartItem> createState() => _CartItemState();
}

class _CartItemState extends State<_CartItem> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  void _showPriceChangeDialog() async {
    final authService = AuthorizationService();
    final hasPermission = await authService.hasPermission(AuthorizationService.PRICE_CHANGE);
    
    if (hasPermission) {
      _showPriceInputDialog();
    } else {
      // Mostrar modal de autorización
      showDialog(
        context: context,
        builder: (context) => AuthorizationModal(
          action: AuthorizationService.PRICE_CHANGE,
          onAuthorized: (authorizationCode) {
            // Una vez autorizado, mostrar el diálogo de cambio de precio
            _showPriceInputDialog();
          },
          onCancelled: () {
            Get.snackbar(
              'Acción cancelada',
              'No se realizó ningún cambio',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          },
        ),
      );
    }
  }

  void _showPriceInputDialog() {
    _priceController.text = widget.price.replaceAll('\$', '').replaceAll(',', '').trim();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Producto: ${widget.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Nuevo Precio',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
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
              final newPrice = double.tryParse(_priceController.text);
              if (newPrice != null && newPrice > 0) {
                widget.onPriceChange?.call(newPrice);
                Navigator.of(context, rootNavigator: true).pop();
                Get.snackbar(
                  'Precio actualizado',
                  'El precio ha sido actualizado correctamente',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              } else {
                Get.snackbar(
                  'Precio inválido',
                  'Ingresa un precio válido',
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

  void _showWeightChangeDialog() async {
    final authService = AuthorizationService();
    final hasPermission = await authService.hasPermission(AuthorizationService.WEIGHT_MANUAL);
    
    if (hasPermission) {
      _showWeightInputDialog();
    } else {
      // Mostrar modal de autorización
      showDialog(
        context: context,
        builder: (context) => AuthorizationModal(
          action: AuthorizationService.WEIGHT_MANUAL,
          onAuthorized: (authorizationCode) {
            // Cerrar el modal de autorización y luego abrir el diálogo de peso manual
            Get.back();
            Future.delayed(Duration.zero, () {
              _showWeightInputDialog();
            });
          },
          onCancelled: () {
            Get.snackbar(
              'Acción cancelada',
              'No se realizó ningún cambio',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          },
        ),
      );
    }
  }

  void _showWeightInputDialog() {
    _weightController.text = widget.weight?.toString() ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Peso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Producto:  [200~${widget.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Nuevo Peso (kg)',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                helperText: 'Ejemplo: 0.250 para 250 gramos',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newWeight = double.tryParse(_weightController.text.replaceAll(',', '.'));
              if (newWeight != null && newWeight > 0) {
                widget.onWeightChange?.call(newWeight);
                Navigator.of(context, rootNavigator: true).pop();
                Get.snackbar(
                  'Peso actualizado',
                  'El peso ha sido actualizado correctamente',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              } else {
                Get.snackbar(
                  'Peso inválido',
                  'Ingresa un peso válido (ej: 0.250)',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22315B),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red[400], size: 18),
                onPressed: widget.onRemove,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Precio clickeable
                  GestureDetector(
                    onTap: widget.onPriceChange != null ? () => _showPriceChangeDialog() : null,
                    child: Tooltip(
                      message: widget.onPriceChange != null ? 'Doble clic para cambiar precio' : '',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.onPriceChange != null ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: widget.onPriceChange != null ? Border.all(color: Colors.blue.withOpacity(0.3)) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.price,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C4DFF),
                              ),
                            ),
                            if (widget.onPriceChange != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.isWeighted && widget.weight != null)
                    GestureDetector(
                      onTap: widget.onWeightChange != null ? () => _showWeightChangeDialog() : null,
                      child: Tooltip(
                        message: widget.onWeightChange != null ? 'Doble clic para cambiar peso' : '',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.onWeightChange != null ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: widget.onWeightChange != null ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.weight!.toStringAsFixed(3)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (widget.onWeightChange != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Colors.orange[600],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, size: 18),
                    onPressed: widget.quantity > 1 ? () => widget.onQuantityChanged(widget.quantity - 1) : null,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.quantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, size: 18),
                    onPressed: () => widget.onQuantityChanged(widget.quantity + 1),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget para filas de totales
class _TotalRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isTotal;

  const _TotalRow(this.label, this.amount, {this.isTotal = false, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF22315B) : const Color(0xFF7B809A),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? const Color(0xFF4CAF50) : const Color(0xFF22315B),
            ),
          ),
        ],
      ),
    );
  }
} 

// Widget para mostrar información de la balanza
class _ScaleWidget extends StatelessWidget {
  final double weight;
  final bool isConnected;
  final bool isReading;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onStartReading;
  final VoidCallback onStopReading;
  final VoidCallback onTare;

  const _ScaleWidget({
    required this.weight,
    required this.isConnected,
    required this.isReading,
    required this.onConnect,
    required this.onDisconnect,
    required this.onStartReading,
    required this.onStopReading,
    required this.onTare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.scale,
                color: isConnected ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Balanza',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConnected ? 'Conectada' : 'Desconectada',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Peso actual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '${weight.toStringAsFixed(3)} kg',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  isReading ? 'Leyendo...' : 'Peso actual',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Botones de control
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isConnected ? onDisconnect : onConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.red : Colors.green,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      isConnected ? 'Desconectar' : 'Conectar',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isConnected ? (isReading ? onStopReading : onStartReading) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReading ? Colors.orange : Colors.blue,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      isReading ? 'Detener' : 'Iniciar',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isConnected ? onTare : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Tare',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 

// Widget para mostrar atajos de teclado
class _ShortcutChip extends StatelessWidget {
  final String label;
  final String description;
  const _ShortcutChip({required this.label, required this.description, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
} 