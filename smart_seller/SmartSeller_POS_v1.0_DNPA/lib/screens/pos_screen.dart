import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'pos_controller.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
import '../widgets/authorization_modal.dart';
import '../services/permissions_service.dart';
import '../models/permissions.dart';
import '../widgets/reprint_menu_widget.dart';
import '../modules/accounting/widgets/accounting_modal.dart';
import '../modules/accounting/services/accounting_service.dart';
import '../services/auth_service.dart';

import '../services/client_validation_service.dart';
import '../models/client.dart';
import '../modules/electronic_invoicing/services/system_configuration_service.dart';
import '../modules/electronic_invoicing/models/system_configuration.dart';

import 'package:intl/intl.dart';

/// Intent para que Enter en el campo cantidad agregue al carrito (un solo Enter).
class _AddToCartIntent extends Intent {
  const _AddToCartIntent();
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();

  /// Focus del KeyboardListener (F1–F6, etc.). Persistente para que F6 siga funcionando al volver de modo Touch.
  final FocusNode _keyboardListenerFocus = FocusNode();

  List<Product> _products = [];
  bool _isLoading = true;
  String _currentMode = 'barcode'; // barcode, quantity, payment
  Product? _selectedProduct;
  bool _isTactileMode = false; // Modo táctil activado/desactivado

  // Controlador del POS
  late PosController _posController;

  // Variables para autorización
  bool _isAuthorized = false;
  DateTime? _authorizationTime;
  String? _authorizedUser;

  @override
  void initState() {
    super.initState();
    _posController = Get.put(PosController());

    // ✅ NUEVO: Configurar callback para limpiar campo de búsqueda
    _posController.onClearSearchField = () {
      print('🔧 DEBUG: Callback ejecutado - Limpiando campo de búsqueda...');
      _barcodeController.clear();
      print('🔧 DEBUG: Campo limpiado, restaurando foco...');
      _ensureBarcodeFocus();
      print('🔧 DEBUG: Foco restaurado correctamente');
    };

    _loadProducts();

    // ✅ Auto-focus al barcode al iniciar
    _ensureBarcodeFocus();

    // ✅ Verificar sesión de caja: si no hay, pedir abrir; si ya hay, continuar (nunca se cierra automáticamente)
    Future.microtask(() async {
      try {
        final session = await AccountingService.getOpenCashSession();
        if (session == null) {
          Get.snackbar('Caja cerrada', 'Debes abrir la caja antes de vender');
          Get.dialog(
            const AccountingModal(),
            barrierDismissible: false,
          );
        } else {
          Get.snackbar('Caja abierta', 'Continuando con la sesión actual',
              duration: const Duration(seconds: 2));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocus.dispose();
    _quantityFocus.dispose();
    _keyboardListenerFocus.dispose();
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

  /// Restaura el foco al listener del teclado para que F6 (liquidar) funcione tras cerrar diálogos (ej. selección de cliente).
  void _restoreFocusForF6() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _keyboardListenerFocus.canRequestFocus) {
          _keyboardListenerFocus.requestFocus();
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
      focusNode: _keyboardListenerFocus,
      autofocus: false,
      onKeyEvent: (KeyEvent event) {
        // ✅ MEJORADO: Solo manejar teclas específicas, permitir que otras pasen
        if (event is KeyDownEvent) {
          final keyLabel = event.logicalKey.keyLabel;
          if (keyLabel == 'F1' ||
              keyLabel == 'F2' ||
              keyLabel == 'F3' ||
              keyLabel == 'F4' ||
              keyLabel == 'F5' ||
              keyLabel == 'F6' ||
              keyLabel == 'Escape' ||
              keyLabel == 'Enter') {
            _handleKeyPress(event);
          }
          // Si no es una tecla de función, no hacer nada (permitir que pase)
        }
      },
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
                    onPressed: () {
                      // ✅ SOLUCIÓN DIRECTA: Forzar navegación sin importar el estado
                      Get.offAllNamed('/dashboard');
                    },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user,
                        color: Colors.green.shade700, size: 20),
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
                      child: Text('Cerrar',
                          style: TextStyle(color: Colors.green.shade700)),
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
      ), // Cierre del KeyboardListener
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
                  ? '📱 Escanear código de barras'
                  : '⌨️ Ingresar cantidad',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _currentMode == 'quantity' && _selectedProduct != null
                ? Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter):
                          _AddToCartIntent(),
                    },
                    child: Actions(
                      actions: {
                        _AddToCartIntent: CallbackAction<_AddToCartIntent>(
                          onInvoke: (_) {
                            if (_selectedProduct != null) {
                              _addToCart(int.tryParse(
                                      _quantityController.text.trim()) ??
                                  1);
                            }
                            return null;
                          },
                        ),
                      },
                      child: TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocus,
                        autofocus: false,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Cantidad (Enter = 1)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.keyboard),
                        ),
                        onSubmitted: (value) => _handleSubmit(value),
                      ),
                    ),
                  )
                : TextField(
                    controller: _currentMode == 'barcode'
                        ? _barcodeController
                        : _quantityController,
                    focusNode: _currentMode == 'barcode'
                        ? _barcodeFocus
                        : _quantityFocus,
                    autofocus: false,
                    keyboardType: _currentMode == 'quantity'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      hintText: _currentMode == 'barcode'
                          ? 'Escanear código o escribir código PLU...'
                          : 'Cantidad (Enter = 1)',
                      border: const OutlineInputBorder(),
                      suffixIcon: Icon(
                        _currentMode == 'barcode'
                            ? Icons.qr_code_scanner
                            : Icons.keyboard,
                      ),
                    ),
                    onSubmitted: (value) => _handleSubmit(value),
                  ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeButton(
                    'barcode', '📱 Escanear', Icons.qr_code_scanner),
                const SizedBox(width: 8),
                // Botón de cantidad solo en modo táctil
                if (_isTactileMode) ...[
                  _buildModeButton('quantity', '⌨️ Cantidad', Icons.keyboard),
                  const SizedBox(width: 8),
                ],
                _buildModeButton('payment', '💳 Pago', Icons.payment),
              ],
            ),
            // En modo táctil: teclado en pantalla y ver todos los productos (cuando no está en la imagen)
            if (_isTactileMode) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showSearchKeyboard,
                      icon: const Icon(Icons.keyboard, size: 20),
                      label: const Text('Teclado para buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAllProductsDialog,
                      icon: const Icon(Icons.list, size: 20),
                      label: const Text('Ver todos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSearchKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Escribir código o parte del nombre',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _barcodeController.text.isEmpty
                              ? '...'
                              : _barcodeController.text,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _barcodeController.clear();
                          setStateSheet(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSearchKeypad(setStateSheet),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final value = _barcodeController.text.trim();
                          Navigator.of(context).pop();
                          if (value.isNotEmpty) _handleSubmit(value);
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
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
        ),
      ),
    );
  }

  Widget _buildSearchKeypad(StateSetter setStateSheet) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['0', '⌫', 'A-Z'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              if (key == '⌫') {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_barcodeController.text.isNotEmpty) {
                          _barcodeController.text = _barcodeController.text
                              .substring(0, _barcodeController.text.length - 1);
                          setStateSheet(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Icon(Icons.backspace),
                    ),
                  ),
                );
              }
              if (key == 'A-Z') {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => _showLetterKeypad(setStateSheet),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('A-Z', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                );
              }
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      _barcodeController.text += key;
                      setStateSheet(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(key,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _showLetterKeypad(StateSetter setStateSheet) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: letters.split('').map((char) {
            return SizedBox(
              width: 36,
              child: ElevatedButton(
                onPressed: () {
                  _barcodeController.text += char.toLowerCase();
                  setStateSheet(() {});
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: Size.zero,
                ),
                child: Text(char),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAllProductsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.list, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Todos los productos (${_products.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.inventory_2, color: Colors.blue[700]),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${product.code} · \$${NumberFormat('#,0').format(product.price)}',
                ),
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Producto Seleccionado:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
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
            Text(
                'Precio: \$${NumberFormat('#,###').format(_selectedProduct!.price)}'),
            Text('Stock: ${_selectedProduct!.stock}'),
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
            const SizedBox(height: 16),

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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _addToCart(int.tryParse(_quantityController.text) ?? 1),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // 4 columnas para más productos
                        childAspectRatio:
                            0.9, // Más alto que ancho para mejor visualización
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _products.take(12).length,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Altura mínima para el carrito: en pantallas pequeñas (ej. segunda pantalla del cliente)
        // así siempre se ven al menos 2-3 productos además del subtotal e IVA.
        const double minCartHeight = 220.0;
        final availableHeight = constraints.maxHeight;
        const fixedHeights = 16.0 * 4 +
            80 +
            80 +
            120 +
            80; // aprox. clientes + totales + botones
        final cartHeight = (availableHeight - fixedHeights)
            .clamp(minCartHeight, double.infinity);

        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  // ✅ Selección de cliente del sistema
                  _buildCustomerSelection(),
                  const SizedBox(height: 16),

                  // ✅ Cliente para facturación electrónica
                  _buildElectronicInvoiceClient(),
                  const SizedBox(height: 16),

                  // Totales
                  _buildTotals(),
                  const SizedBox(height: 16),

                  // Carrito: altura mínima para que siempre se vean productos (resoluciones pequeñas)
                  SizedBox(
                    height: cartHeight,
                    child: _buildCart(),
                  ),

                  // Botones de acción
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: Widget para selección de cliente
  Widget _buildCustomerSelection() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cliente del Sistema',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                GetBuilder<PosController>(
                  id: PosController.customerTabsId,
                  builder: (c) {
                    if (c.selectedCustomer.value != null) {
                      return Row(
                        children: [
                          Text(
                            '${c.selectedCustomer.value!.pointsRate} pts/\$1000',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: c.clearSelectedCustomer,
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Remover cliente',
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            GetBuilder<PosController>(
              id: PosController.customerTabsId,
              builder: (c) {
                if (c.selectedCustomer.value != null) {
                  final customer = c.selectedCustomer.value!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        customer.email,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      if (customer.documentNumber != null)
                        Text(
                          'Doc: ${customer.documentNumber}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sin cliente seleccionado',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _posController.showCustomerSelectionModal();
                          _restoreFocusForF6();
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Seleccionar Cliente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Widget para cliente de facturación electrónica
  Widget _buildElectronicInvoiceClient() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cliente Facturación Electrónica',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                GetBuilder<PosController>(
                  id: PosController.customerTabsId,
                  builder: (c) {
                    if (c.currentClient != null) {
                      final validationSummary =
                          ClientValidationService.getClientValidationSummary(
                              c.currentClient!);
                      final canReceiveInvoice =
                          validationSummary['canReceiveElectronicInvoice']
                              as bool;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: canReceiveInvoice
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          canReceiveInvoice ? '✅ Válido' : '❌ Incompleto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: canReceiveInvoice
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            GetBuilder<PosController>(
              id: PosController.customerTabsId,
              builder: (c) {
                if (c.currentClient != null) {
                  final client = c.currentClient!;
                  final validationSummary =
                      ClientValidationService.getClientValidationSummary(
                          client);
                  final canReceiveInvoice =
                      validationSummary['canReceiveElectronicInvoice'] as bool;
                  final missingFields =
                      validationSummary['missingFields'] as List<String>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.businessName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: canReceiveInvoice
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                      Text(
                        '${client.documentType} ${client.documentNumber}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        client.email ?? 'Sin email',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      if (client.city != null && client.department != null)
                        Text(
                          '${client.city}, ${client.department}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      if (!canReceiveInvoice && missingFields.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Faltan: ${missingFields.join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sin cliente para facturación electrónica',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showClientSelectionDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Seleccionar Cliente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 16),
                ),
                Obx(() => Text(
                      '\$${_posController.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            // IVA según lo configurado en inventario (0%, 5%, 19%)
            Obx(() {
              final t19 = _posController.taxAt19;
              final t5 = _posController.taxAt5;
              final has19 = t19 > 0;
              final has5 = t5 > 0;
              if (!has19 && !has5) {
                if (_posController.taxes > 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('IVA:', style: TextStyle(fontSize: 16)),
                        Text(
                          '\$${_posController.taxes.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (has19)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IVA (19%):',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '\$${t19.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (has5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IVA (5%):',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '\$${t5.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              );
            }),
            const Divider(),
            // Total
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
            // Pestañas: venta actual + cada carrito en espera (clic = cambiar a ese carrito sin abrir modal)
            Obx(() {
              final held = _posController.heldSales;
              final currentName =
                  _posController.selectedCustomer.value?.name.trim();
              final currentClientName =
                  _posController.selectedClient.value?.businessName.trim();
              final currentLabel = (currentName != null &&
                      currentName.isNotEmpty)
                  ? currentName
                  : (currentClientName != null && currentClientName.isNotEmpty)
                      ? currentClientName
                      : 'Venta actual';
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Chip(
                        label: Text(currentLabel),
                        backgroundColor: Colors.blue[200],
                        side:
                            BorderSide(color: Colors.blue.shade800, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      ...List.generate(held.length, (i) {
                        final label = held[i].label;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            label: Text(label),
                            onPressed: () => _posController.switchToHeldSale(i),
                            backgroundColor: Colors.grey[200],
                            side: BorderSide(color: Colors.grey.shade700),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
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
                    final ivaLabel = item.ivaPercentage == 0
                        ? 'Exento'
                        : 'IVA ${item.ivaPercentage}%';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text('${item.quantity}'),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                          '${item.unit} x \$${item.price.toStringAsFixed(0)} · $ivaLabel'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila de botones principales: Wrap en pantallas estrechas para que no queden como columnas
            isNarrow
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionBtn(
                        onPressed: _showAccountingModal,
                        icon: Icons.account_balance,
                        label: 'Conta (F4)',
                        color: Colors.red,
                      ),
                      _actionBtn(
                        onPressed: _openCashDrawer,
                        icon: Icons.account_balance_wallet,
                        label: 'Cajón (F5)',
                        color: Colors.orange,
                      ),
                      _actionBtn(
                        onPressed: _toggleTactileMode,
                        icon: _isTactileMode ? Icons.keyboard : Icons.touch_app,
                        label: _isTactileMode ? 'KB' : 'Touch',
                        color:
                            _isTactileMode ? Colors.grey[600]! : Colors.purple,
                        isTactile: _isTactileMode,
                      ),
                      _actionBtn(
                        onPressed: _showHeldSalesDialog,
                        icon: Icons.pause_circle_outline,
                        label: 'En espera',
                        color: Colors.indigo,
                      ),
                      _actionBtn(
                        onPressed: _finalizeSale,
                        icon: Icons.payment,
                        label: 'Finalizar Venta (F6)',
                        color: Colors.green,
                        wide: true,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                          onPressed: _showAccountingModal,
                          icon: Icons.account_balance,
                          label: 'Conta (F4)',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          onPressed: _openCashDrawer,
                          icon: Icons.account_balance_wallet,
                          label: 'Cajón (F5)',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          onPressed: _toggleTactileMode,
                          icon:
                              _isTactileMode ? Icons.keyboard : Icons.touch_app,
                          label: _isTactileMode ? 'KB' : 'Touch',
                          color: _isTactileMode
                              ? Colors.grey[600]!
                              : Colors.purple,
                          isTactile: _isTactileMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          onPressed: _showHeldSalesDialog,
                          icon: Icons.pause_circle_outline,
                          label: 'En espera',
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _actionBtn(
                          onPressed: _finalizeSale,
                          icon: Icons.payment,
                          label: 'Finalizar Venta (F6)',
                          color: Colors.green,
                          wide: true,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 8),
            // Fila de botones secundarios (cliente)
            Row(
              children: [
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                        onPressed: _showClientSelectionDialog,
                        icon: Icon(
                          _posController.currentClient != null
                              ? Icons.person
                              : Icons.person_add,
                          color: _posController.currentClient != null
                              ? Colors.white
                              : Colors.blue[700],
                        ),
                        label: Text(
                          _posController.currentClient != null
                              ? 'Cliente: ${_posController.currentClient!.businessName}'
                              : 'Seleccionar Cliente',
                          style: TextStyle(
                            fontSize: isNarrow ? 11 : 12,
                            color: _posController.currentClient != null
                                ? Colors.white
                                : Colors.blue[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _posController.currentClient != null
                              ? Colors.blue
                              : Colors.blue[50],
                          foregroundColor: _posController.currentClient != null
                              ? Colors.white
                              : Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      )),
                ),
                if (_posController.currentClient != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: isNarrow ? 120 : null,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _posController.clearSelectedClient();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text('Limpiar Cliente',
                          style: TextStyle(fontSize: isNarrow ? 11 : 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _actionBtn({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool wide = false,
    bool isTactile = false,
  }) {
    return SizedBox(
      width: wide ? null : 120,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: isTactile ? 2 : 8,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
      ),
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
        case 'F2':
          _showReprintMenu(); // ✅ NUEVO: Abrir menú de reimpresión
          break;
        case 'F3':
          _finalizeSaleElectronic(); // Facturación electrónica directa
          break;
        case 'F4':
          _showAccountingModal();
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
          if (_selectedProduct != null) {
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

    setState(() {
      _currentMode = mode;
      if (mode != 'quantity') {
        _selectedProduct = null;
      }
    });

    // Si está en modo táctil y se selecciona cantidad, mostrar diálogo táctil
    if (_isTactileMode && mode == 'quantity') {
      _showTactileQuantityDialog();
      return;
    }

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

  void _toggleTactileMode() {
    setState(() {
      _isTactileMode = !_isTactileMode;
    });
    // Al volver a modo teclado (KB), devolver el foco al listener para que F6 y demás atajos funcionen.
    if (!_isTactileMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _keyboardListenerFocus.canRequestFocus) {
          _keyboardListenerFocus.requestFocus();
        }
      });
    }
  }

  void _showTactileQuantityDialog() {
    final controller =
        TextEditingController(text: ''); // Campo vacío por defecto
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('🎯 TECLADO TÁCTIL - Ingresar Cantidad'),
          content: SizedBox(
            width: 400, // Ancho fijo para asegurar que se vea
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo de cantidad más grande
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.numbers, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.text.isEmpty
                              ? 'Ingrese cantidad...'
                              : controller.text,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: controller.text.isEmpty
                                ? Colors.grey
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Teclado virtual más grande
                _buildVirtualKeyboard(controller, setState),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('❌ Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(controller.text) ?? 1;
                if (quantity > 0) {
                  _addToCart(quantity);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('✅ Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard(
      TextEditingController controller, StateSetter setState) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: 1, 2, 3
          Row(
            children: [
              Expanded(child: _buildNumberButton('1', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('2', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('3', controller, setState)),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: 4, 5, 6
          Row(
            children: [
              Expanded(child: _buildNumberButton('4', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('5', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('6', controller, setState)),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 3: 7, 8, 9
          Row(
            children: [
              Expanded(child: _buildNumberButton('7', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('8', controller, setState)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumberButton('9', controller, setState)),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 4: 0, Borrar, Enter
          Row(
            children: [
              Expanded(child: _buildNumberButton('0', controller, setState)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildActionButton('⌫', () {
                if (controller.text.isNotEmpty) {
                  controller.text =
                      controller.text.substring(0, controller.text.length - 1);
                  setState(() {}); // Actualizar la interfaz
                }
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildActionButton('✓', () {
                final quantity = int.tryParse(controller.text) ?? 1;
                if (quantity > 0) {
                  _addToCart(quantity);
                  Navigator.of(context).pop();
                }
              })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(
      String number, TextEditingController controller, StateSetter setState) {
    return ElevatedButton(
      onPressed: () {
        controller.text += number;
        setState(() {}); // Actualizar la interfaz
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Text(
        number,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _searchProduct(String code) {
    // Primero buscar por código exacto
    final exactMatch =
        _products.where((p) => p.code == code || p.shortCode == code).toList();

    if (exactMatch.isNotEmpty) {
      _selectProduct(exactMatch.first);
      return;
    }

    // Si no hay código exacto, buscar por nombre
    final nameMatches = _products
        .where((p) => quitarTildes(p.name.toLowerCase())
            .contains(quitarTildes(code.toLowerCase())))
        .toList();

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
      _currentMode = 'quantity';
    });

    // Configurar el campo de cantidad
    _quantityController.text = '1';
    _quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _quantityController.text.length,
    );

    // Enfocar el campo de cantidad (como antes): un Enter agrega al carrito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quantityFocus.requestFocus();
    });

    _barcodeController.clear();

    // ❌ MENSAJE ELIMINADO - Era innecesario y molesto
    // Solo mostrar mensaje cuando efectivamente se agregue al carrito
  }

  void _addToCart(int quantity) {
    if (_selectedProduct == null) {
      Get.snackbar('Error', 'No hay producto seleccionado');
      return;
    }

    _posController.addToCart(
      _selectedProduct!.name,
      _selectedProduct!.price,
      _selectedProduct!.unit,
      quantity: quantity,
      availableStock: _selectedProduct!.stock,
      ivaPercentage: _selectedProduct!.ivaPercentage,
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

  void _cancelSelection() {
    // Quitar foco del campo cantidad para que no quede "pegado" ahí
    _quantityFocus.unfocus();
    setState(() {
      _selectedProduct = null;
      _currentMode = 'barcode';
    });

    _barcodeController.clear();
    _quantityController.text = '1';

    // ✅ Asegurar focus en búsqueda para elegir el siguiente producto
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
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    Icons.inventory,
                    color: Colors.blue[700],
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
                      'Precio: \$${NumberFormat('#,0').format(product.price)}',
                    ),
                  ],
                ),
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
    // Bloquear si no hay sesión de caja abierta
    AccountingService.getOpenCashSession().then((session) {
      if (session == null) {
        Get.snackbar(
          'Caja cerrada',
          'Debes abrir la caja antes de finalizar una venta',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.dialog(
          const AccountingModal(),
          barrierDismissible: false,
        );
        return;
      }
      _finalizeSaleProceed();
    }).catchError((_) {
      Get.snackbar(
        'Caja cerrada',
        'Debes abrir la caja antes de finalizar una venta',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.dialog(
        const AccountingModal(),
        barrierDismissible: false,
      );
    });
  }

  /// F3: ir directo a facturación electrónica (sin modal venta normal / electrónica).
  void _finalizeSaleElectronic() {
    AccountingService.getOpenCashSession().then((session) {
      if (session == null) {
        Get.snackbar(
          'Caja cerrada',
          'Debes abrir la caja antes de finalizar una venta',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.dialog(
          const AccountingModal(),
          barrierDismissible: false,
        );
        return;
      }
      if (_posController.cartItems.isEmpty) {
        Get.snackbar(
          'Carrito vacío',
          'Agrega productos antes de facturación electrónica',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      _openElectronicInvoiceModal();
    }).catchError((_) {
      Get.snackbar(
        'Caja cerrada',
        'Debes abrir la caja antes de finalizar una venta',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.dialog(
        const AccountingModal(),
        barrierDismissible: false,
      );
    });
  }

  void _finalizeSaleProceed() {
    if (_posController.cartItems.isEmpty) {
      Get.snackbar(
        'Carrito vacío',
        'Agrega productos antes de finalizar la venta',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // F6: ir directo a métodos de pago (venta normal)
    _posController.processPayment();
  }

  void _showPaymentOptionsDialog() {
    // Obtener información del cliente actual si existe
    final currentClient = _posController.currentClient;
    final clientValidationSummary = currentClient != null
        ? ClientValidationService.getClientValidationSummary(currentClient)
        : null;

    // Verificar si el cliente puede recibir facturación electrónica
    final canReceiveElectronicInvoice =
        clientValidationSummary?['canReceiveElectronicInvoice'] as bool? ??
            false;
    final missingFields =
        clientValidationSummary?['missingFields'] as List<String>? ?? [];

    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 12),
            Text('Finalizar Venta'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona el tipo de facturación:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Información del cliente actual
            if (currentClient != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Cliente Seleccionado:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '${currentClient.businessName} (${currentClient.documentType} ${currentClient.documentNumber})'),
                    Text('${currentClient.email}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Estado de validación del cliente para facturación electrónica
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canReceiveElectronicInvoice
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      canReceiveElectronicInvoice ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        canReceiveElectronicInvoice
                            ? Icons.check_circle
                            : Icons.error,
                        color: canReceiveElectronicInvoice
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        canReceiveElectronicInvoice
                            ? '✅ Cliente válido para facturación electrónica'
                            : '❌ Cliente incompleto para facturación electrónica',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canReceiveElectronicInvoice
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (!canReceiveElectronicInvoice &&
                      missingFields.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Campos faltantes: ${missingFields.join(', ')}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Get.back();
                            _showClientSelectionDialog();
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Seleccionar Cliente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (currentClient != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _posController.clearSelectedClient();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpiar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ NUEVO: Información de configuración del sistema
            FutureBuilder<SystemConfiguration>(
              future: SystemConfigurationService.getConfiguration(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '❌ Configuración del sistema no disponible',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final config = snapshot.data!;
                final hasValidConfig = config.dianResolutionNumber.isNotEmpty &&
                    config.softwareId.isNotEmpty &&
                    config.softwarePin.isNotEmpty;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasValidConfig
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasValidConfig ? Colors.blue : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasValidConfig ? Icons.settings : Icons.warning,
                            color: hasValidConfig ? Colors.blue : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasValidConfig
                                ? '✅ Configuración del sistema válida'
                                : '⚠️ Configuración del sistema incompleta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hasValidConfig
                                  ? Colors.blue.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasValidConfig) ...[
                        Text('Resolución DIAN: ${config.dianResolutionNumber}'),
                        Text('Software ID: ${config.softwareId}'),
                        Text('Ambiente: ${config.environment}'),
                        Text('Prefijo: ${config.invoicePrefix}'),
                        Text('Consecutivo: ${config.currentConsecutive}'),
                      ] else ...[
                        Text(
                          'Para facturación electrónica necesitas configurar:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('• Número de resolución DIAN'),
                        const Text('• ID del software'),
                        const Text('• PIN del software'),
                        const Text('• Ambiente (Pruebas/Producción)'),
                      ],
                    ],
                  ),
                );
              },
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
            onPressed: canReceiveElectronicInvoice
                ? () {
                    Get.back();
                    _openElectronicInvoiceModal();
                  }
                : null,
            icon: const Icon(Icons.description),
            label: Text(canReceiveElectronicInvoice
                ? 'Facturación Electrónica'
                : 'Facturación Electrónica (Cliente Incompleto)'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canReceiveElectronicInvoice ? Colors.blue : Colors.grey,
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
        child: SizedBox(
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
                  'Factura electrónica generada (pendiente de envío)',
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
            Text('F2: Reimpresión de facturas'),
            Text('F3: Facturación electrónica (directo)'),
            Text('F4: Contabilidad / Caja'),
            Text('F5: Abrir cajón monedero'),
            Text('F6: Finalizar venta (métodos de pago)'),
            Text('ESC: Cancelar operación actual'),
            Text('ENTER: Confirmar acción'),
            SizedBox(height: 16),
            Text('🖱️ PRODUCTOS FRECUENTES:'),
            Text('• Usa los botones táctiles'),
            Text('• Selección rápida y fácil'),
            SizedBox(height: 8),
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

  // ✅ NUEVO: Método para mostrar diálogo de selección de cliente
  void _showClientSelectionDialog() {
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
                    'Seleccionar Cliente para Facturación Electrónica',
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
                  _posController.clientSearchQuery.value = value;
                  _posController.searchClients(value);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, email, documento o teléfono...',
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
                  if (_posController.isSearchingClient.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_posController.clientSearchResults.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron clientes',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: _posController.clientSearchResults.length,
                    itemBuilder: (context, index) {
                      final client = _posController.clientSearchResults[index];
                      final validationSummary =
                          ClientValidationService.getClientValidationSummary(
                              client);
                      final canReceiveInvoice =
                          validationSummary['canReceiveElectronicInvoice']
                              as bool;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                canReceiveInvoice ? Colors.green : Colors.red,
                            child: Icon(
                              canReceiveInvoice
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            client.businessName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${client.documentType} ${client.documentNumber}'),
                              Text(client.email ?? 'Sin email'),
                              if (client.city != null &&
                                  client.department != null)
                                Text('${client.city}, ${client.department}'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: canReceiveInvoice
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  canReceiveInvoice
                                      ? '✅ Válido'
                                      : '❌ Incompleto',
                                  style: TextStyle(
                                    color: canReceiveInvoice
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            _posController.selectClient(client);
                            setState(() {});
                            Get.back();
                          },
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
    ).then((_) => _restoreFocusForF6());
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

  void _showReprintMenu() {
    Get.dialog(
      Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.9,
          child: ReprintMenuWidget(),
        ),
      ),
      barrierDismissible: true,
    );
  }

  /// Diálogo de carritos en espera: dejar carrito actual en espera o recuperar/cancelar uno.
  void _showHeldSalesDialog() {
    final copFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    );
    Get.dialog(
      Obx(() {
        final held = _posController.heldSales;
        final cartEmpty = _posController.cartItems.isEmpty;
        final canHold = !cartEmpty && held.length < PosController.maxHeldSales;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.indigo),
              SizedBox(width: 12),
              Text('Carritos en espera'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canHold) ...[
                  const Text(
                    'Deja el carrito en espera para ir a Inventario u otra pantalla (crear producto, etc.). Al volver al POS, recupera el carrito aquí.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _posController.holdCurrentSale();
                      Get.back();
                    },
                    icon: const Icon(Icons.pause_circle_filled),
                    label: Text(
                      'Dejar en espera (${_posController.cartItems.length} ítems · ${copFormat.format(_posController.total)})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (held.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No hay carritos en espera.\nAgrega productos, usa "Dejar en espera" y podrás salir a Inventario u otras pantallas; al volver al POS recupera el carrito aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else ...[
                  const Text(
                    'Carritos guardados (máx. ${PosController.maxHeldSales}):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...held.asMap().entries.map((e) {
                    final i = e.key;
                    final h = e.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${h.itemCount} ítems · ${copFormat.format(h.total)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _posController.recallHeldSale(i),
                              icon: const Icon(Icons.play_arrow, size: 20),
                              label: const Text('Recuperar'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _posController.cancelHeldSale(i),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              label: const Text('Quitar'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      }),
      barrierDismissible: true,
    );
  }

  // ✅ NUEVO: Mostrar modal de proveedores
  void _showAccountingModal() {
    Get.dialog(
      AccountingModal(
        onTransactionProcessed: (entry) {
          // Callback cuando se procesa una transacción
          Get.snackbar(
            'Transacción Registrada',
            '${entry.type == 'income' ? 'Ingreso' : 'Egreso'} de \$${entry.amount.toStringAsFixed(2)} registrado',
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          );
        },
      ),
      barrierDismissible: true,
    );
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
    if (permissionsService.hasPermission(
        currentUser.role, requiredPermission)) {
      executeAction();
      return;
    }

    // Si no tiene permiso, solicitar autorización
    _requestAuthorization(action, actionDescription, executeAction);
  }

  void _requestAuthorization(
      String action, String description, VoidCallback executeAction) {
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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

  Widget _buildProductImage() {
    // Si el producto tiene una imagen URL
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      // Si es una URL de red
      if (product.imageUrl!.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: product.imageUrl!,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultIcon(),
        );
      }
      // Si es una ruta local de assets
      else if (product.imageUrl!.startsWith('assets/')) {
        return Image.asset(
          product.imageUrl!,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        );
      }
      // Si es una ruta de archivo local
      else {
        return Image.file(
          File(product.imageUrl!),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        );
      }
    }

    // Si no hay imagen, mostrar icono por defecto
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2,
          color: Colors.blue[700],
          size: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    final backgroundColor = Colors.blue[50];
    final iconColor = Colors.blue[700];

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: primaryColor.withOpacity(0.3),
        highlightColor: primaryColor.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Imagen que ocupa todo el ancho y altura hasta el texto
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: _buildProductImage(),
                ),
              ),

              // Texto y precio en la parte inferior - altura fija
              Container(
                width: double.infinity, // Ocupa todo el ancho
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${NumberFormat('#,###').format(product.price)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
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
  State<_ElectronicInvoiceModalContent> createState() =>
      _ElectronicInvoiceModalContentState();
}

class _ElectronicInvoiceModalContentState
    extends State<_ElectronicInvoiceModalContent>
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

  // ✅ NUEVOS CONTROLADORES PARA VALIDACIÓN
  final _clientCityController = TextEditingController();
  final _clientDepartmentController = TextEditingController();

  String _selectedPaymentMethod = 'Efectivo';
  String _selectedClientType = 'CUANTIAS MENORES';
  String _selectedDocumentType = 'CC'; // ✅ NUEVO: Tipo de documento por defecto

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Generar número de factura automático
    final now = DateTime.now();
    _invoiceNumberController.text =
        'FE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    // ✅ NUEVO: Agregar listeners para validación en tiempo real
    _addClientFieldListeners();
  }

  // ✅ NUEVO: Agregar listeners a los campos del cliente para validación en tiempo real
  void _addClientFieldListeners() {
    _clientNitController.addListener(_onClientFieldChanged);
    _clientNameController.addListener(_onClientFieldChanged);
    _clientEmailController.addListener(_onClientFieldChanged);
    _clientPhoneController.addListener(_onClientFieldChanged);
    _clientAddressController.addListener(_onClientFieldChanged);
    _clientCityController.addListener(_onClientFieldChanged);
    _clientDepartmentController.addListener(_onClientFieldChanged);
  }

  // ✅ NUEVO: Callback cuando cambian los campos del cliente
  void _onClientFieldChanged() {
    if (mounted) {
      setState(() {
        // Esto forzará la reconstrucción del widget de validación
      });
    }
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

    // ✅ DISPOSE DE NUEVOS CONTROLADORES
    _clientCityController.dispose();
    _clientDepartmentController.dispose();

    super.dispose();
  }

  // ✅ NUEVO: Widget para mostrar estado de validación del cliente
  Widget _buildClientValidationStatus() {
    // Crear un cliente temporal para validación
    final tempClient = Client(
      documentType: _selectedDocumentType,
      documentNumber: _clientNitController.text,
      businessName: _clientNameController.text,
      email: _clientEmailController.text,
      phone: _clientPhoneController.text,
      address: _clientAddressController.text,
      city: _clientCityController.text,
      department: _clientDepartmentController.text,
      fiscalResponsibility: 'Responsable de IVA', // Valor por defecto
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final validationSummary =
        ClientValidationService.getClientValidationSummary(tempClient);
    final canReceiveInvoice =
        validationSummary['canReceiveElectronicInvoice'] as bool;
    final missingFields = validationSummary['missingFields'] as List<String>;
    final validationMessage = validationSummary['validationMessage'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canReceiveInvoice ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: canReceiveInvoice ? Colors.green : Colors.red,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canReceiveInvoice ? Icons.check_circle : Icons.error,
                color: canReceiveInvoice ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  canReceiveInvoice
                      ? '✅ Cliente válido para facturación electrónica'
                      : '❌ Cliente incompleto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: canReceiveInvoice
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            validationMessage,
            style: TextStyle(
              color: canReceiveInvoice
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
          if (!canReceiveInvoice && missingFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Campos faltantes:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            ...missingFields.map((field) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '• $field',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f2) {
            // _showReprintMenu(); // ❌ Eliminado - método no existe en esta clase
          }
        }
      },
      child: Scaffold(
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
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
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                          _isLoading ? 'Guardando...' : 'Guardar Borrador'),
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
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
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
                initialValue: _selectedPaymentMethod,
                items: [
                  'Efectivo',
                  'Tarjeta Débito',
                  'Tarjeta Crédito',
                  'Transferencia',
                  'Cheque'
                ]
                    .map((method) =>
                        DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedPaymentMethod = value!),
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
                initialValue: _selectedClientType,
                items: ['CUANTIAS MENORES', 'CLIENTE REGISTRADO']
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedClientType = value!),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cliente *',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_selectedClientType == 'CLIENTE REGISTRADO') ...[
                const SizedBox(height: 16),

                // ✅ NUEVO: Tipo de documento
                DropdownButtonFormField<String>(
                  initialValue: _selectedDocumentType,
                  items: ['CC', 'NIT', 'TI', 'CE', 'PASAPORTE', 'RC', 'OTRO']
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedDocumentType = value!),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Documento *',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientNitController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Documento *',
                    hintText: 'Ej: 123456789-0',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o Razón Social *',
                    hintText: 'Nombre completo o razón social',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'correo@ejemplo.com',
                    border: OutlineInputBorder(),
                    helperText: 'OBLIGATORIO para envío de factura electrónica',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono *',
                    hintText: 'Ej: 3001234567',
                    border: OutlineInputBorder(),
                    helperText: 'Recomendado para facturación electrónica',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección *',
                    hintText: 'Dirección completa',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),

                const SizedBox(height: 16),
                // ✅ NUEVO: Ciudad
                TextFormField(
                  controller: _clientCityController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad *',
                    hintText: 'Ej: Bogotá',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),

                const SizedBox(height: 16),
                // ✅ NUEVO: Departamento
                TextFormField(
                  controller: _clientDepartmentController,
                  decoration: const InputDecoration(
                    labelText: 'Departamento *',
                    hintText: 'Ej: Cundinamarca',
                    border: OutlineInputBorder(),
                    helperText: 'Obligatorio para facturación electrónica',
                  ),
                ),

                const SizedBox(height: 16),
                // ✅ NUEVO: Validación en tiempo real
                _buildClientValidationStatus(),
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
                      subtitle: Text(
                          'Cantidad: ${product['quantity']} x \$${NumberFormat('#,###').format(product['price'])}'),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '\$${NumberFormat('#,###').format(total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
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
              if (nitController.text.isNotEmpty &&
                  nameController.text.isNotEmpty) {
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
    // Validaciones básicas
    if (_invoiceNumberController.text.isEmpty) {
      Get.snackbar('Error', 'El número de factura es obligatorio');
      return;
    }

    // ✅ NUEVA VALIDACIÓN COMPLETA DEL CLIENTE PARA FACTURACIÓN ELECTRÓNICA
    if (_selectedClientType == 'CLIENTE REGISTRADO') {
      // Crear cliente temporal para validación
      final tempClient = Client(
        documentType: _selectedDocumentType,
        documentNumber: _clientNitController.text,
        businessName: _clientNameController.text,
        email: _clientEmailController.text,
        phone: _clientPhoneController.text,
        address: _clientAddressController.text,
        city: _clientCityController.text,
        department: _clientDepartmentController.text,
        fiscalResponsibility: 'Responsable de IVA', // Valor por defecto
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Validar si el cliente puede recibir facturación electrónica
      if (!ClientValidationService.canReceiveElectronicInvoice(tempClient)) {
        final missingFields =
            ClientValidationService.getMissingFields(tempClient);

        Get.dialog(
          AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Cliente Incompleto'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se puede emitir factura electrónica porque el cliente no cumple con los requisitos obligatorios:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Campos faltantes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...missingFields.map((field) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('• $field'),
                    )),
                const SizedBox(height: 16),
                Text(
                  'Por favor, complete todos los campos obligatorios antes de continuar.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Simular envío a DIAN
      await Future.delayed(const Duration(seconds: 2));

      Get.back();
      widget.onComplete(true);

      Get.snackbar(
        'Éxito',
        'Factura electrónica generada (pendiente de envío)',
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
