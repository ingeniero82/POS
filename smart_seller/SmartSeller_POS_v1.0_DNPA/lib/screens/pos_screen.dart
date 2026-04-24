import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:decimal/decimal.dart';
import 'dart:async';
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
import '../services/print_service.dart';
import '../services/balanza_service.dart';

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

  /// Según ventas reales (cantidades en historial); se actualiza al vender.
  List<Product> _frequentProducts = [];
  bool _isLoading = true;
  String _currentMode = 'barcode'; // barcode, quantity, payment
  Product? _selectedProduct;
  bool _isTactileMode = false; // Modo táctil activado/desactivado

  // Controlador del POS
  late PosController _posController;
  late BalanzaService _balanzaService;
  StreamSubscription<double?>? _pesoSub;
  double? _pesoEnVivoKg;

  /// Peso mostrado y cobrado: [BalanzaService.ultimoPeso] es síncrono con el parser; el stream puede ir un frame atrás.
  double? _kgPreferidoBalanza() {
    if (_balanzaService.estado == EstadoConexionBalanza.conectado) {
      return _balanzaService.ultimoPeso ?? _pesoEnVivoKg;
    }
    return _pesoEnVivoKg;
  }

  /// Sondeo de lectura en todo el POS mientras el COM esté abierto (misma idea que diagnóstico).
  Timer? _balanzaPollPosGlobal;

  // Variables para autorización
  bool _isAuthorized = false;
  DateTime? _authorizationTime;
  String? _authorizedUser;

  @override
  void initState() {
    super.initState();
    // Permanente / reutilizar: tras imprimir se usa Get.offAllNamed('/pos'); si el
    // controlador se destruye, se pierde canje pendiente (remanente) en memoria.
    _posController = Get.isRegistered<PosController>()
        ? Get.find<PosController>()
        : Get.put(PosController(), permanent: true);
    _balanzaService = Get.find<BalanzaService>();
    _pesoEnVivoKg = _balanzaService.ultimoPeso;
    _pesoSub = _balanzaService.pesosStream.listen((peso) {
      if (!mounted) return;
      setState(() {
        _pesoEnVivoKg = peso;
      });
    });
    _balanzaService.addListener(_onBalanzaServiceChangedForPos);

    // ✅ NUEVO: Configurar callback para limpiar campo de búsqueda
    _posController.onClearSearchField = () {
      print('🔧 DEBUG: Callback ejecutado - Limpiando campo de búsqueda...');
      _barcodeController.clear();
      print('🔧 DEBUG: Campo limpiado, restaurando foco...');
      _ensureBarcodeFocus();
      print('🔧 DEBUG: Foco restaurado correctamente');
    };

    _posController.onSaleCompleted = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshFrequentProducts();
      });
    };

    _loadProducts();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _balanzaService.intentarReconexionDesdePrefs();
      if (mounted) {
        setState(() {});
        _syncBalanzaPollGlobal();
      }
    });

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
    _balanzaService.removeListener(_onBalanzaServiceChangedForPos);
    _stopBalanzaPollGlobal();
    unawaited(_pesoSub?.cancel());
    _posController.onSaleCompleted = null;
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
      _frequentProducts =
          await SQLiteDatabaseService.getFrequentProductsForPos(limit: 12);
    } catch (e) {
      Get.snackbar('Error', 'Error cargando productos: $e');
    } finally {
      setState(() => _isLoading = false);
      // ✅ Asegurar focus después de cargar productos
      _ensureBarcodeFocus();
    }
  }

  Future<void> _refreshFrequentProducts() async {
    try {
      final next =
          await SQLiteDatabaseService.getFrequentProductsForPos(limit: 12);
      if (mounted) setState(() => _frequentProducts = next);
    } catch (_) {}
  }

  String _labelEstadoBalanza(EstadoConexionBalanza estado) {
    return switch (estado) {
      EstadoConexionBalanza.conectado => 'Conectada',
      EstadoConexionBalanza.conectando => 'Conectando',
      EstadoConexionBalanza.error => 'Error',
      EstadoConexionBalanza.desconectado => 'Desconectada',
    };
  }

  void _onBalanzaServiceChangedForPos() {
    if (!mounted) return;
    setState(() {});
    _syncBalanzaPollGlobal();
  }

  void _stopBalanzaPollGlobal() {
    _balanzaPollPosGlobal?.cancel();
    _balanzaPollPosGlobal = null;
  }

  /// Pide lecturas mientras haya COM abierto. Si en diagnóstico está **lectura activa**,
  /// el propio [BalanzaService] ya envía el comando en intervalo; aquí no duplicamos.
  void _syncBalanzaPollGlobal() {
    _stopBalanzaPollGlobal();
    if (_balanzaService.estado != EstadoConexionBalanza.conectado) return;

    if (_balanzaService.lecturaContinuaDelServicioActiva) {
      unawaited(_balanzaService.solicitarLecturaPeso());
      return;
    }

    // Ventas: más frecuente que el intervalo “documento” de prefs (a menudo 1000 ms), sin duplicar el timer del servicio.
    final base = _balanzaService.intervaloLecturaMsConfigurado;
    final ms = (base / 3).round().clamp(220, 450);

    void tick(_) {
      if (!mounted) {
        _stopBalanzaPollGlobal();
        return;
      }
      if (_balanzaService.estado != EstadoConexionBalanza.conectado) {
        _stopBalanzaPollGlobal();
        return;
      }
      if (_balanzaService.lecturaContinuaDelServicioActiva) {
        _stopBalanzaPollGlobal();
        return;
      }
      unawaited(_balanzaService.solicitarLecturaPeso());
    }

    unawaited(_balanzaService.solicitarLecturaPeso());
    _balanzaPollPosGlobal = Timer.periodic(Duration(milliseconds: ms), tick);
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
              _selectedProduct!.isWeighted &&
                      (_selectedProduct!.pricePerKg ?? 0) > 0
                  ? 'Precio: \$${NumberFormat('#,###').format(_selectedProduct!.pricePerKg!)} / kg'
                  : 'Precio: \$${NumberFormat('#,###').format(_selectedProduct!.price)}',
            ),
            Text(
              _selectedProduct!.isWeighted &&
                      _selectedProduct!.weightedStockInKg
                  ? 'Stock: ${_selectedProduct!.stockKg.toStringAsFixed(3)} kg'
                  : 'Stock: ${_selectedProduct!.stock} ${_selectedProduct!.unit}',
            ),
            if (_selectedProduct!.isWeighted) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.scale,
                          color: _balanzaService.estado ==
                                  EstadoConexionBalanza.conectado
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Balanza ${_labelEstadoBalanza(_balanzaService.estado)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed('/balanza-diagnostico'),
                          child: const Text('Diagnóstico'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final kgText = _kgPreferidoBalanza();
                        return Center(
                          child: Text(
                            kgText != null
                                ? '${kgText.toStringAsFixed(3)} kg'
                                : '— kg',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: (kgText != null && kgText > 0)
                                  ? Colors.black87
                                  : Colors.grey,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final ppk = _selectedProduct!.pricePerKg ?? 0;
                        final ok = _balanzaService.estado ==
                                EstadoConexionBalanza.conectado &&
                            ppk > 0;
                        final kg = _kgPreferidoBalanza();
                        final canAdd =
                            ok && kg != null && kg > 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: canAdd
                                  ? () {
                                      if (!_tryCommitWeightedFromBalanca()) {
                                        Get.snackbar(
                                          'Balanza',
                                          'No se pudo agregar. Revisa el peso o usa «Peso manual».',
                                          backgroundColor: Colors.orange,
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 3),
                                        );
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.add_shopping_cart, size: 26),
                              label: Text(
                                canAdd
                                    ? 'Agregar al carrito (${kg.toStringAsFixed(3)} kg)'
                                    : (ok
                                        ? 'Coloque el producto en la balanza'
                                        : 'Conecte la balanza en Diagnóstico'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showWeightedAddDialog(),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Peso manual o corregir'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelSelection(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver a búsqueda'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
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
                      onPressed: () => _addToCart(
                          int.tryParse(_quantityController.text) ?? 1),
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
                      itemCount: _frequentProducts.length,
                      itemBuilder: (context, index) {
                        final product = _frequentProducts[index];

                        return _ProductButton(
                          key: ValueKey<int>(product.id ?? index),
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
        const fixedHeights =
            16.0 * 3 + 80 + 120 + 80; // aprox. clientes + totales + botones
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
            Obx(() {
              if (_posController.cartDiscountAmount <= 0) {
                return const SizedBox.shrink();
              }
              final p = _posController.cartDiscountPercent.value;
              final pctStr = p == p.roundToDouble()
                  ? p.round().toString()
                  : p.toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Descuento ($pctStr%):',
                      style: TextStyle(fontSize: 15, color: Colors.red[800]),
                    ),
                    Text(
                      '-\$${_posController.cartDiscountAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                  ],
                ),
              );
            }),
            Obx(() {
              final applied = _posController.immediateExchangeApplied;
              if (applied <= 1e-9) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Canje inmediato:',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.deepOrange.shade800,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '-\$${applied.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL A COBRAR:',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Obx(() => Text(
                      '\$${_posController.totalToCollect.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    )),
              ],
            ),
            Obx(() {
              if (_posController.immediateExchangeApplied <= 1e-9) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total mercancía:',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      '\$${_posController.total.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              );
            }),
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
                    final double? wKg = item.weightKg;
                    final bool porPeso =
                        wKg != null && wKg > 0 && item.quantity > 0;
                    final double kgLinea = porPeso ? wKg * item.quantity : 0;
                    final String subtitulo = porPeso
                        ? '${kgLinea.toStringAsFixed(3)} kg × \$${NumberFormat('#,###').format(item.total / kgLinea)}/kg · $ivaLabel'
                        : '${item.unit} x \$${item.price.toStringAsFixed(0)} · $ivaLabel';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: porPeso
                            ? Icon(Icons.scale,
                                size: 20, color: Colors.blue.shade800)
                            : Text('${item.quantity}'),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(subtitulo),
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
            Obx(() {
              final activeCredit = _posController.immediateExchangeCredit.value;
              if (activeCredit <= 1e-9) {
                return const SizedBox.shrink();
              }
              final sourceId = _posController.immediateExchangeSourceSaleId.value;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showImmediateExchangeStatusDialog,
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(
                          sourceId != null
                              ? 'Canje activo #${sourceId.toString().padLeft(6, '0')} · \$${activeCredit.toStringAsFixed(0)}'
                              : 'Canje activo · \$${activeCredit.toStringAsFixed(0)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: isNarrow ? 11 : 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange.shade50,
                          foregroundColor: Colors.deepOrange.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: isNarrow ? 110 : 150,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _posController.clearImmediateExchangeCredit(showSnack: true);
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(
                          'Quitar',
                          style: TextStyle(fontSize: isNarrow ? 11 : 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange.shade800,
                          side: BorderSide(color: Colors.deepOrange.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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

  void _showImmediateExchangeStatusDialog() {
    String refundMethod = 'Efectivo';
    bool isRefunding = false;
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          final activeCredit = _posController.immediateExchangeCredit.value;
          final sourceId = _posController.immediateExchangeSourceSaleId.value;
          final applied = _posController.immediateExchangeApplied;
          final pending =
              (activeCredit - applied).clamp(0.0, double.infinity);
          final remainder = _posController.immediateExchangeUnusedRemainder;
          return AlertDialog(
            title: const Text('Canje inmediato activo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sourceId != null)
                  Text(
                      'Factura origen: #${sourceId.toString().padLeft(6, '0')}'),
                Text('Crédito disponible: \$${activeCredit.toStringAsFixed(0)}'),
                Text(
                    'Aplicado en venta actual: \$${applied.toStringAsFixed(0)}'),
                Text(
                    'Saldo pendiente en este canje: \$${pending.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                Text(
                  'El POS cobrará solo la diferencia real para no afectar el cierre de caja.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (remainder > 1e-9) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Si el producto de cambio vale menos y sobra plata a favor del cliente, '
                    'registre aquí la devolución del remanente (\$${remainder.toStringAsFixed(0)}) '
                    'para que caja y contabilidad cuadren.',
                    style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(refundMethod),
                    initialValue: refundMethod,
                    decoration: const InputDecoration(
                      labelText: 'Medio de devolución del remanente',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'Tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(
                          value: 'Transferencia',
                          child: Text('Transferencia')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => refundMethod = v);
                      }
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cerrar'),
              ),
              if (remainder > 1e-9)
                ElevatedButton.icon(
                  onPressed: isRefunding
                      ? null
                      : () async {
                          setDialogState(() => isRefunding = true);
                          final ok = await _posController
                              .refundImmediateExchangeUnusedRemainder(
                                  refundMethod);
                          if (!context.mounted) return;
                          setDialogState(() => isRefunding = false);
                          if (ok) {
                            Get.back();
                            setState(() {});
                          }
                        },
                  icon: isRefunding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payments_outlined, size: 20),
                  label: Text(isRefunding
                      ? 'Registrando devolución...'
                      : 'Devolver remanente (\$${remainder.toStringAsFixed(0)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  _posController.clearImmediateExchangeCredit(showSnack: true);
                  Get.back();
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar canje'),
              ),
            ],
          );
        },
      ),
    );
  }

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
    _syncBalanzaPollGlobal();

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
    final exactMatch = _products
        .where((p) =>
            p.code == code || (p.shortCode != null && p.shortCode == code))
        .toList();

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

    _quantityController.text = '1';
    _quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _quantityController.text.length,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!product.isWeighted) {
        _quantityFocus.requestFocus();
      }
    });

    _barcodeController.clear();

    _syncBalanzaPollGlobal();
  }

  /// Si hay balanza conectada y peso en vivo válido, agrega al carrito sin abrir el diálogo.
  bool _tryCommitWeightedFromBalanca() {
    final product = _selectedProduct;
    if (product == null || !product.isWeighted) return false;
    final ppk = product.pricePerKg;
    if (ppk == null || ppk <= 0) return false;
    if (_balanzaService.estado != EstadoConexionBalanza.conectado) return false;
    final kg = _kgPreferidoBalanza();
    if (kg == null || kg <= 0) return false;

    final total = kg * ppk;
    final useKgStock = product.weightedStockInKg;
    _posController.addToCart(
      product.name,
      total,
      product.unit,
      quantity: 1,
      availableStock: useKgStock ? null : product.stock,
      availableStockKg: useKgStock ? product.stockKg : null,
      weightKg: kg,
      ivaPercentage: product.ivaPercentage,
      productId: product.id,
      mergeExisting: false,
    );
    Get.snackbar(
      '✅ Agregado por balanza',
      '${product.name} · ${kg.toStringAsFixed(3)} kg · \$${NumberFormat('#,###').format(total)}',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    _cancelSelection();
    return true;
  }

  void _addToCart(int quantity) {
    if (_selectedProduct == null) {
      Get.snackbar('Error', 'No hay producto seleccionado');
      return;
    }

    // Producto pesado: si hay lectura en vivo, un solo paso (sin diálogo).
    if (_selectedProduct!.isWeighted) {
      if (_tryCommitWeightedFromBalanca()) return;
      _showWeightedAddDialog();
      return;
    }

    _posController.addToCart(
      _selectedProduct!.name,
      _selectedProduct!.price,
      _selectedProduct!.unit,
      quantity: quantity,
      availableStock: _selectedProduct!.stock,
      ivaPercentage: _selectedProduct!.ivaPercentage,
      productId: _selectedProduct!.id,
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

  void _showWeightedAddDialog() {
    final product = _selectedProduct;
    if (product == null) return;

    final pricePerKg = product.pricePerKg;
    if (pricePerKg == null || pricePerKg <= 0) {
      Get.snackbar(
        'Configurar producto pesado',
        'Este producto no tiene precio por kg válido en inventario.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _WeightedAddDialog(
        product: product,
        posController: _posController,
        balanza: _balanzaService,
        onSuccess: _cancelSelection,
      ),
    ).then((_) {
      if (mounted) _syncBalanzaPollGlobal();
    });
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
              leading: Icon(Icons.percent, color: Colors.teal.shade700),
              title: const Text('Descuento % al total de la venta'),
              subtitle: const Text(
                  'Sobre subtotal + IVA; mismo ajuste que en Método de pago'),
              onTap: () {
                Navigator.of(context).pop();
                if (_posController.selectedCustomer.value == null &&
                    _posController.selectedClient.value == null) {
                  Get.snackbar(
                    'Cliente requerido',
                    'Seleccione cliente de puntos o de facturación para aplicar descuento %.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                final copFormat = NumberFormat.currency(
                  locale: 'es_CO',
                  symbol: '\$ ',
                  decimalDigits: 0,
                  customPattern: '\u00A4#,##0',
                );
                _posController.showCartGlobalDiscountDialog(copFormat);
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
    final printService = PrintService.instance;
    printService.openCashDrawer().then((opened) {
      if (opened) {
        Get.snackbar(
          'Cajón abierto',
          'Cajón monedero abierto correctamente',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'No se pudo abrir',
          'Verifica impresora/cajón y configuración de puerto',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }).catchError((_) {
      Get.snackbar(
        'Error',
        'Ocurrió un error al intentar abrir el cajón',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    });
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
      final currentClient = _posController.currentClient;
      if (currentClient == null) {
        Get.snackbar(
          'Cliente requerido',
          'Para facturación electrónica selecciona o crea un cliente.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        _showClientSelectionDialog(continueToElectronic: true);
        return;
      }
      final validationSummary =
          ClientValidationService.getClientValidationSummary(currentClient);
      final canReceiveElectronicInvoice =
          validationSummary['canReceiveElectronicInvoice'] as bool? ?? false;
      if (!canReceiveElectronicInvoice) {
        Get.snackbar(
          'Cliente incompleto',
          'Completa datos del cliente o selecciona otro para facturación electrónica.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        _showClientSelectionDialog(continueToElectronic: true);
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
        'ivaPercentage': item.ivaPercentage,
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
            Text(
                'F3: Facturación electrónica (selecciona/crea cliente si falta)'),
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
  void _showClientSelectionDialog({bool continueToElectronic = false}) {
    // Mostrar clientes activos al abrir, sin necesidad de teclear.
    _posController.searchClients('');
    Get.dialog(
      Dialog(
        child: Container(
          width: 720,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Seleccionar Cliente para Facturación Electrónica',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showQuickCreateElectronicClientDialog(
                            continueToElectronic: continueToElectronic),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Crear cliente'),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
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
              const SizedBox(height: 6),
              Text(
                'Esta búsqueda es para clientes de Facturación Electrónica (DIAN).',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // Lista de resultados
              Expanded(
                child: Obx(() {
                  if (_posController.isSearchingClient.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_posController.clientSearchResults.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No se encontraron clientes',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showQuickCreateElectronicClientDialog(
                                    continueToElectronic: continueToElectronic),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Crear cliente ahora'),
                          ),
                        ],
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
                            if (continueToElectronic) {
                              _continueElectronicFlowAfterClientSelected();
                            }
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

  // Alta rápida desde POS para usar facturación electrónica sin salir del flujo.
  void _showQuickCreateElectronicClientDialog(
      {bool continueToElectronic = false}) {
    final docType = ValueNotifier<String>('NIT');
    final docController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final departmentController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Crear cliente FE'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: docType,
                  builder: (_, value, __) => DropdownButtonFormField<String>(
                    initialValue: value,
                    items: const [
                      DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                      DropdownMenuItem(value: 'CC', child: Text('CC')),
                      DropdownMenuItem(value: 'CE', child: Text('CE')),
                      DropdownMenuItem(value: 'TI', child: Text('TI')),
                      DropdownMenuItem(
                          value: 'PASAPORTE', child: Text('PASAPORTE')),
                    ],
                    onChanged: (v) => docType.value = v ?? 'NIT',
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: docController,
                  decoration: const InputDecoration(
                    labelText: 'Documento *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o razón social *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Departamento *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final document = docController.text.trim();
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final address = addressController.text.trim();
              final city = cityController.text.trim();
              final department = departmentController.text.trim();

              if (document.isEmpty ||
                  name.isEmpty ||
                  email.isEmpty ||
                  address.isEmpty ||
                  city.isEmpty ||
                  department.isEmpty) {
                Get.snackbar(
                  'Campos obligatorios',
                  'Complete documento, razón social, email, dirección, ciudad y departamento.',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                return;
              }

              try {
                final existing =
                    await SQLiteDatabaseService.getClientByDocument(document);
                if (existing != null) {
                  _posController.selectClient(existing);
                  Get.back();
                  if (continueToElectronic) {
                    _continueElectronicFlowAfterClientSelected();
                  }
                  Get.snackbar(
                    'Cliente existente',
                    'Ya existía y quedó seleccionado.',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                  );
                  return;
                }

                final now = DateTime.now();
                final client = Client(
                  documentType: docType.value,
                  documentNumber: document,
                  businessName: name,
                  email: email,
                  phone: phoneController.text.trim(),
                  address: address,
                  city: city,
                  department: department,
                  country: 'Colombia',
                  fiscalResponsibility: 'Responsable de IVA',
                  createdAt: now,
                  updatedAt: now,
                );

                await SQLiteDatabaseService.createClient(client);
                final created =
                    await SQLiteDatabaseService.getClientByDocument(document);
                if (created != null) {
                  _posController.selectClient(created);
                  if (continueToElectronic) {
                    _continueElectronicFlowAfterClientSelected();
                  }
                }
                await _posController.searchClients('');
                Get.back();
                Get.snackbar(
                  'Cliente creado',
                  'Cliente FE creado y seleccionado.',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'No se pudo crear el cliente: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Guardar y seleccionar'),
          ),
        ],
      ),
    );
  }

  void _continueElectronicFlowAfterClientSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _finalizeSaleElectronic();
      });
    });
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
          child: const ReprintMenuWidget(),
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
        onStartCashCount: _openCashDrawer,
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

  Decimal? _parseMoneyDigitsAsDecimal(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return Decimal.parse(digits);
  }

  String _formatThousands(BigInt value) {
    final negative = value.isNegative;
    final raw = value.abs().toString();
    final formatted = raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return negative ? '-$formatted' : formatted;
  }

  BigInt _roundHalfUp(Decimal value) {
    final normalized = value.toString();
    final negative = normalized.startsWith('-');
    final clean = negative ? normalized.substring(1) : normalized;
    final parts = clean.split('.');
    var intPart = BigInt.parse(parts[0]);
    if (parts.length > 1 && parts[1].isNotEmpty) {
      final firstDigit = int.tryParse(parts[1][0]) ?? 0;
      if (firstDigit >= 5) {
        intPart += BigInt.one;
      }
    }
    return negative ? -intPart : intPart;
  }

  void _showPriceDialog(item, int index) {
    final basePriceController = TextEditingController(
        text: _formatThousands(BigInt.from(item.price.round())));
    final priceWithIvaController = TextEditingController();
    final oldPrice = item.price;
    final supportsIvaPricing =
        item.ivaPercentage == 5 || item.ivaPercentage == 19;
    final ivaPctByDialog = (item.ivaPercentage == 5) ? 5 : 19;
    int selectedIva = ivaPctByDialog;
    double candidatePrice = oldPrice;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          void applyPriceFromIva() {
            final digits =
                priceWithIvaController.text.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.isEmpty) return;
            final gross = Decimal.parse(digits);
            final formattedGross = _formatThousands(BigInt.parse(digits));
            if (priceWithIvaController.text != formattedGross) {
              priceWithIvaController.value = TextEditingValue(
                text: formattedGross,
                selection:
                    TextSelection.collapsed(offset: formattedGross.length),
              );
            }
            final divisor = selectedIva == 5
                ? Decimal.parse('1.05')
                : Decimal.parse('1.19');
            final base =
                (gross / divisor).toDecimal(scaleOnInfinitePrecision: 12);
            candidatePrice = double.tryParse(base.toString()) ?? oldPrice;
            basePriceController.text = _formatThousands(_roundHalfUp(base));
          }

          return AlertDialog(
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
                  controller: basePriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo precio (base)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = _parseMoneyDigitsAsDecimal(value);
                    if (parsed != null) {
                      candidatePrice = parsed.toDouble();
                    }
                  },
                  onSubmitted: (value) {
                    final parsed = _parseMoneyDigitsAsDecimal(value);
                    final newPrice = parsed?.toDouble() ?? candidatePrice;
                    final editedFromIva = supportsIvaPricing &&
                        _parseMoneyDigitsAsDecimal(
                                priceWithIvaController.text) !=
                            null;
                    Navigator.of(context).pop();
                    _posController.updateItemPrice(
                      index,
                      newPrice,
                      editedFromIva: editedFromIva,
                    );
                    Get.snackbar(
                      '💰 Precio modificado',
                      '${item.name}: \$${oldPrice.toStringAsFixed(0)} → \$${newPrice.toStringAsFixed(0)}',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (supportsIvaPricing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceWithIvaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Precio con IVA',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => applyPriceFromIva(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedIva,
                          decoration: const InputDecoration(
                            labelText: 'IVA',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 19, child: Text('19%')),
                            DropdownMenuItem(value: 5, child: Text('5%')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() {
                              selectedIva = value;
                            });
                            applyPriceFromIva();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Si usas "Precio con IVA", el carrito guarda precio base para evitar doble IVA.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ] else ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Producto exento de IVA: solo se permite editar precio base.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed =
                      _parseMoneyDigitsAsDecimal(basePriceController.text);
                  final newPrice = parsed?.toDouble() ?? candidatePrice;
                  final editedFromIva = supportsIvaPricing &&
                      _parseMoneyDigitsAsDecimal(priceWithIvaController.text) !=
                          null;
                  Navigator.of(context).pop();
                  _posController.updateItemPrice(
                    index,
                    newPrice,
                    editedFromIva: editedFromIva,
                  );
                  Get.snackbar(
                    '💰 Precio modificado',
                    '${item.name}: \$${oldPrice.toStringAsFixed(0)} → \$${newPrice.toStringAsFixed(0)}',
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
          );
        },
      ),
    );
  }
}

String _weightedDialogEstadoBalanza(EstadoConexionBalanza estado) {
  return switch (estado) {
    EstadoConexionBalanza.conectado => 'Conectada',
    EstadoConexionBalanza.conectando => 'Conectando',
    EstadoConexionBalanza.error => 'Error',
    EstadoConexionBalanza.desconectado => 'Desconectada',
  };
}

/// Diálogo producto por kg con peso en vivo desde [BalanzaService].
class _WeightedAddDialog extends StatefulWidget {
  const _WeightedAddDialog({
    required this.product,
    required this.posController,
    required this.balanza,
    required this.onSuccess,
  });

  final Product product;
  final PosController posController;
  final BalanzaService balanza;
  final VoidCallback onSuccess;

  @override
  State<_WeightedAddDialog> createState() => _WeightedAddDialogState();
}

class _WeightedAddDialogState extends State<_WeightedAddDialog> {
  late final TextEditingController _weightController;
  double _calculated = 0;
  bool _vincularPeso = true;
  StreamSubscription<double?>? _pesoSub;
  Timer? _pollTimer;

  double? get _livePeso =>
      widget.balanza.ultimoPeso; // último valor parseado del servicio

  @override
  void initState() {
    super.initState();
    final initial = widget.balanza.ultimoPeso;
    _weightController = TextEditingController(
      text: initial != null && initial > 0 ? initial.toStringAsFixed(3) : '',
    );
    _recalc();
    widget.balanza.addListener(_onBalanzaChanged);
    _pesoSub = widget.balanza.pesosStream.listen((p) {
      if (!mounted || !_vincularPeso) return;
      if (widget.balanza.estado != EstadoConexionBalanza.conectado) return;
      if (p == null || p.isNaN || p < 0) return;
      final next = p.toStringAsFixed(3);
      if (_weightController.text == next) return;
      _weightController.text = next;
      _recalc();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.balanza.estado == EstadoConexionBalanza.conectado) {
        unawaited(widget.balanza.solicitarLecturaPeso());
      }
    });
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || !_vincularPeso) return;
      if (widget.balanza.estado != EstadoConexionBalanza.conectado) return;
      unawaited(widget.balanza.solicitarLecturaPeso());
    });
  }

  void _onBalanzaChanged() {
    if (mounted) setState(() {});
  }

  void _recalc() {
    final kg =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final pricePerKg = widget.product.pricePerKg ?? 0;
    setState(() {
      _calculated = (kg != null && kg > 0) ? kg * pricePerKg : 0.0;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_pesoSub?.cancel());
    widget.balanza.removeListener(_onBalanzaChanged);
    _weightController.dispose();
    super.dispose();
  }

  void _tomarPesoManual() {
    Future<void>(() async {
      await widget.balanza.solicitarLecturaPeso();
      double? live;
      for (var i = 0; i < 45; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (i % 4 == 0) unawaited(widget.balanza.solicitarLecturaPeso());
        live = widget.balanza.ultimoPeso;
        if (live != null && live > 0) break;
      }
      if (!mounted) return;
      if (live == null || live <= 0) {
        Get.snackbar(
          'Sin peso disponible',
          'No llegó una lectura válida. Si hay peso en la balanza, revisa en '
              '«Configurar balanza»: tramas entrantes, terminador del comando '
              '(CR vs CRLF) y velocidad (baud). Si hay peso en la balanza, '
              'vuelve a intentar.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        return;
      }
      _weightController.text = live.toStringAsFixed(3);
      _recalc();
    });
  }

  void _submit() {
    final kg =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      Get.snackbar(
        'Peso inválido',
        'Ingresa un peso válido mayor que 0.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    final pricePerKg = widget.product.pricePerKg!;
    final total = kg * pricePerKg;
    final useKgStock = widget.product.weightedStockInKg;
    // [price] en carrito = subtotal de la línea (total a cobrar por ese peso).
    // [weightKg] siempre se guarda para ticket, venta en BD y trazabilidad del peso de la balanza.
    widget.posController.addToCart(
      widget.product.name,
      total,
      widget.product.unit,
      quantity: 1,
      availableStock: useKgStock ? null : widget.product.stock,
      availableStockKg: useKgStock ? widget.product.stockKg : null,
      weightKg: kg,
      ivaPercentage: widget.product.ivaPercentage,
      productId: widget.product.id,
      mergeExisting: false,
    );
    Navigator.of(context).pop();
    Get.snackbar(
      '✅ Agregado por peso',
      '${widget.product.name} · ${kg.toStringAsFixed(3)} kg · \$${NumberFormat('#,###').format(total)}',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final pricePerKg = widget.product.pricePerKg!;
    final live = _livePeso;
    return AlertDialog(
      title: Text('Producto pesado: ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Precio por kg: \$${NumberFormat('#,###').format(pricePerKg)}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.scale,
                  size: 18,
                  color:
                      widget.balanza.estado == EstadoConexionBalanza.conectado
                          ? Colors.green
                          : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Balanza ${_weightedDialogEstadoBalanza(widget.balanza.estado)}'
                    '${live != null && live > 0 ? ' · ${live.toStringAsFixed(3)} kg' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vincular peso en vivo'),
              subtitle: const Text(
                'Actualiza el campo con la balanza. Desactívalo para teclear el peso.',
              ),
              value: _vincularPeso,
              onChanged: (v) => setState(() => _vincularPeso = v),
            ),
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              onChanged: (_) => _recalc(),
              decoration: const InputDecoration(
                labelText: 'Peso (kg) *',
                hintText: 'Ej: 0.750',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      widget.balanza.estado == EstadoConexionBalanza.conectado
                          ? _tomarPesoManual
                          : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Tomar peso ahora'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Get.toNamed('/balanza-diagnostico'),
                  child: const Text('Configurar balanza'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total: \$${NumberFormat('#,###').format(_calculated)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// Widget para botón táctil de producto
class _ProductButton extends StatelessWidget {
  final Product product;
  final String teclaNumero;
  final VoidCallback onTap;

  const _ProductButton({
    super.key,
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
          cacheKey: 'pid_${product.id}_${product.imageUrl}',
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
          key: ValueKey<String>('file_${product.id}_${product.imageUrl}'),
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
    final subtotal = widget.cartProducts.fold<double>(
      0.0,
      (sum, p) => sum + ((p['total'] as num?)?.toDouble() ?? 0.0),
    );
    final iva19 = widget.cartProducts.fold<double>(0.0, (sum, p) {
      final pct = (p['ivaPercentage'] as num?)?.toInt() ?? 19;
      final base = ((p['total'] as num?)?.toDouble() ?? 0.0);
      return pct == 19 ? sum + (base * 0.19) : sum;
    });
    final iva5 = widget.cartProducts.fold<double>(0.0, (sum, p) {
      final pct = (p['ivaPercentage'] as num?)?.toInt() ?? 19;
      final base = ((p['total'] as num?)?.toDouble() ?? 0.0);
      return pct == 5 ? sum + (base * 0.05) : sum;
    });
    final ivaTotal = iva19 + iva5;
    final total = subtotal + ivaTotal;

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
                        Text('\$${NumberFormat('#,###').format(iva19)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('IVA (5%):'),
                        Text('\$${NumberFormat('#,###').format(iva5)}'),
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
