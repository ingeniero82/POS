import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:decimal/decimal.dart';
import '../models/product.dart';
import '../models/group.dart';
import '../services/sqlite_database_service.dart';
import '../services/image_service.dart';
import '../utils/puntos_miles_input_formatter.dart';
import 'dart:io';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

// ✅ NUEVO: Enum para modos de cálculo de precios
enum PriceCalculationMode {
  fixedPrice, // Precio fijo (comportamiento actual)
  fixedMargin // Utilidad fija (nueva funcionalidad)
}

enum WeightedPricingMode {
  manualSalePerKg,
  byProfitPercentage,
}

class _ProductFormDialogState extends State<ProductFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _shortCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _priceWithIvaController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  /// Al editar: cantidad a sumar al stock actual (no reemplaza el stock).
  final _ingresoController = TextEditingController();
  final _unitController = TextEditingController();
  final _groupController = TextEditingController();
  /// Marca del producto (independiente del grupo; no compartir con [_groupController]).
  final _brandController = TextEditingController();
  final _profitPerKgVisualController = TextEditingController();

  // ✅ NUEVO: Controlador para % de utilidad
  final _profitMarginController = TextEditingController();

  // ✅ NUEVO: Variables para manejo de imagen
  String? _currentImagePath;
  bool _isImageLoading = false;

  String? _selectedGroup;
  List<Group> _availableGroups = [];
  bool _isActive = true;

  bool _isLoading = false;

  // ✅ NUEVO: Modo de cálculo de precios (por defecto mantiene comportamiento actual)
  PriceCalculationMode _priceMode = PriceCalculationMode.fixedPrice;

  /// Producto exento de IVA (0%); si false, aplica 19%.
  bool _exentoIva = false;

  /// IVA configurado para facturación electrónica: 0, 5 o 19 (%). Se guarda en BD.
  int _ivaPercentage = 19;
  int _priceWithIvaType = 19;
  Decimal? _salePriceExact;
  bool _isUpdatingPriceFromIva = false;

  /// Marca visual para producto por peso.
  bool _isWeightedProduct = false;
  WeightedPricingMode _weightedPricingMode = WeightedPricingMode.manualSalePerKg;

  /// Producto pesado: inventario en kg ([true]) o en unidades ([false]).
  bool _weightedStockInKg = false;
  final _stockKgController = TextEditingController();

  // Controlador para las pestañas
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroups();
    if (widget.product != null) {
      _codeController.text = widget.product!.code;
      _shortCodeController.text = widget.product!.shortCode ?? '';
      _nameController.text = widget.product!.name;
      _priceController.text = formatMontoPuntosMiles(widget.product!.price);
      _salePriceExact = Decimal.parse(widget.product!.price.toString());
      _costController.text = formatMontoPuntosMiles(widget.product!.cost);
      _stockController.text = widget.product!.stock.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _ingresoController.text = '0';
      _unitController.text = widget.product!.unit;
      _selectedGroup = widget.product!.category;
      _groupController.text = _selectedGroup ?? '';
      _applyBrandFromStoredDescription(widget.product!.description);
      _isActive = widget.product!.isActive;
      _isWeightedProduct = widget.product!.isWeighted;
      _weightedStockInKg = widget.product!.weightedStockInKg;
      final sk = widget.product!.stockKg;
      _stockKgController.text =
          sk > 0 ? sk.toString().replaceAll(RegExp(r'\.0$'), '') : '';

      // ✅ NUEVO: Inicializar imagen del producto
      _currentImagePath = widget.product!.imageUrl;

      // ✅ NUEVO: Calcular % de utilidad inicial
      _calculateProfitMargin();
      _exentoIva = widget.product!.ivaPercentage == 0;
      // Cargar IVA de facturación electrónica (0, 5 o 19) para el dropdown "IVA *"
      final p = widget.product!.ivaPercentage;
      _ivaPercentage = (p == 0 || p == 5 || p == 19) ? p : 19;
      if (_ivaPercentage == 5 || _ivaPercentage == 19) {
        _priceWithIvaType = _ivaPercentage;
      }
    }

    // ✅ NUEVO: Agregar listeners para cálculo automático
    _priceController.addListener(_onPriceChanged);
    _priceWithIvaController.addListener(_onPriceWithIvaChanged);
    _costController.addListener(_onCostChanged);
    _profitMarginController.addListener(_onProfitMarginChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ingresoController.dispose();
    _stockKgController.dispose();
    _profitPerKgVisualController.dispose();
    _priceWithIvaController.dispose();
    // ✅ NUEVO: Dispose de los nuevos controladores
    _profitMarginController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await SQLiteDatabaseService.getAllGroups();
      setState(() {
        _availableGroups = groups;

        // Si estamos editando un producto y su grupo no existe en la lista actual,
        // lo agregamos temporalmente para evitar errores
        if (widget.product != null && _selectedGroup != null) {
          final groupExists =
              groups.any((group) => group.name == _selectedGroup);
          if (!groupExists) {
            // Crear un grupo temporal para el producto existente
            final tempGroup = Group(
              name: _selectedGroup!,
              description: 'Grupo temporal para producto existente',
              color: '#9E9E9E',
              icon: 'category',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _availableGroups.add(tempGroup);
          }
        }
      });
    } catch (e) {
      print('Error cargando grupos: $e');
    }
  }

  /// Si en BD la descripción empieza por `Marca: ...`, separa marca y el resto (pestaña Facturación).
  void _applyBrandFromStoredDescription(String raw) {
    final s = raw.trimLeft();
    if (s.startsWith('Marca:')) {
      var after = s.substring(6).trimLeft();
      final idx = after.indexOf('\n');
      if (idx < 0) {
        _brandController.text = after;
        _descriptionController.text = '';
      } else {
        _brandController.text = after.substring(0, idx).trim();
        _descriptionController.text = after.substring(idx + 1).trim();
      }
    } else {
      _brandController.clear();
      _descriptionController.text = raw;
    }
  }

  /// Guarda marca en la misma columna [description] con prefijo estable (sin columna `brand` en SQLite).
  String _composedDescriptionForSave() {
    final brand = _brandController.text.trim();
    final desc = _descriptionController.text.trim();
    if (brand.isEmpty) return desc;
    if (desc.isEmpty) return 'Marca: $brand';
    return 'Marca: $brand\n$desc';
  }

  /// Grupo: lista desplegable usa [_selectedGroup]; sin grupos en BD, el texto va en [_groupController].
  String _effectiveCategory() {
    if (_availableGroups.isEmpty) {
      return _groupController.text.trim();
    }
    return (_selectedGroup ?? '').trim();
  }

  void _showGroupManager() {
    Get.toNamed('/grupos')?.then((_) {
      // Recargar grupos cuando regrese de la pantalla de gestión
      _loadGroups();
    });
  }

  // ✅ NUEVO: Funciones de cálculo automático
  void _calculateProfitMargin() {
    final cost = parseMontoPuntosMiles(_costController.text);
    final exactPrice = _salePriceExact;
    final price = exactPrice != null
        ? double.tryParse(exactPrice.toString())
        : parseMontoPuntosMiles(_priceController.text);

    if (cost != null && price != null && price > 0) {
      // ✅ CORREGIDO: Fórmula estándar de POS: (Precio de venta - Costo) / Precio de venta × 100
      final margin = ((price - cost) / price) * 100;
      _profitMarginController.text = margin.toStringAsFixed(1);
    } else {
      _profitMarginController.text = '0.0';
    }
  }

  void _calculatePriceFromMargin() {
    final cost = parseMontoPuntosMiles(_costController.text);
    final margin = double.tryParse(
        _profitMarginController.text.trim().replaceAll(',', '.'));

    if (cost != null && margin != null && cost > 0) {
      // ✅ CORREGIDO: Fórmula inversa estándar de POS: Costo / (1 - Margen/100)
      final price = cost / (1 - margin / 100);
      _salePriceExact = Decimal.parse(price.toString());
      _priceController.text = formatMontoPuntosMiles(price);
    }
  }

  void _onPriceChanged() {
    if (_isUpdatingPriceFromIva) return;
    final typedValue = _parseMoneyAsDecimal(_priceController.text);
    if (typedValue != null) {
      _salePriceExact = typedValue;
    }
    if (_priceMode == PriceCalculationMode.fixedPrice) {
      _calculateProfitMargin();
    }
  }

  Decimal? _parseMoneyAsDecimal(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return Decimal.parse(digits);
  }

  Decimal _ivaFactor() {
    return _priceWithIvaType == 5
        ? Decimal.parse('1.05')
        : Decimal.parse('1.19');
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

  String _formatThousands(BigInt value) {
    final negative = value.isNegative;
    final raw = value.abs().toString();
    final formatted = raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return negative ? '-$formatted' : formatted;
  }

  void _onPriceWithIvaChanged() {
    final gross = _parseMoneyAsDecimal(_priceWithIvaController.text);
    if (gross == null) {
      _salePriceExact = _parseMoneyAsDecimal(_priceController.text);
      return;
    }

    final base =
        (gross / _ivaFactor()).toDecimal(scaleOnInfinitePrecision: 12);
    _salePriceExact = base;
    final roundedForView = _roundHalfUp(base);

    _isUpdatingPriceFromIva = true;
    _priceController.text = _formatThousands(roundedForView);
    _isUpdatingPriceFromIva = false;

    if (_priceMode == PriceCalculationMode.fixedPrice) {
      _calculateProfitMargin();
    }
  }

  void _onCostChanged() {
    if (_priceMode == PriceCalculationMode.fixedPrice) {
      _calculateProfitMargin();
    } else if (_priceMode == PriceCalculationMode.fixedMargin) {
      _calculatePriceFromMargin();
    }
  }

  void _onProfitMarginChanged() {
    if (_priceMode == PriceCalculationMode.fixedMargin) {
      _calculatePriceFromMargin();
    }
  }

  void _changePriceMode(PriceCalculationMode newMode) {
    setState(() {
      _priceMode = newMode;
    });

    // Recalcular según el nuevo modo
    if (newMode == PriceCalculationMode.fixedPrice) {
      _calculateProfitMargin();
    } else if (newMode == PriceCalculationMode.fixedMargin) {
      _calculatePriceFromMargin();
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ NUEVO: Validar y sincronizar datos según el modo
      if (_priceMode == PriceCalculationMode.fixedMargin) {
        // En modo utilidad fija, recalcular precio antes de guardar
        _calculatePriceFromMargin();
      } else {
        // En modo precio fijo, recalcular utilidad antes de guardar
        _calculateProfitMargin();
      }

      final code = _codeController.text.trim();
      final rawShortCode = _shortCodeController.text.trim();
      final String? shortCode =
          rawShortCode.isEmpty ? null : rawShortCode;
      final excludeId = widget.product?.id;

      // Validar código de barras único
      final exists = await SQLiteDatabaseService.existsProductCode(code,
          excludeId: excludeId);
      if (exists) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Ya existe un producto con ese código de barras.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Validar código corto único solo si el usuario ingresó uno
      if (rawShortCode.isNotEmpty) {
        final existsShort = await SQLiteDatabaseService.getAllProducts();
        if (existsShort.any((p) =>
            p.shortCode != null &&
            p.shortCode == shortCode &&
            p.id != excludeId)) {
          setState(() {
            _isLoading = false;
          });
          Get.snackbar(
            'Error',
            'Ya existe un producto con ese código corto.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      double? _parseKgInput(String input) {
        final v = input.trim().replaceAll(',', '.');
        if (v.isEmpty) return 0.0;
        return double.tryParse(v);
      }

      // Stock: producto no pesado = unidades; pesado + unidades = unidades; pesado + kg = stockKg.
      late final int newStock;
      late final double newStockKg;
      final bool invKg = _isWeightedProduct && _weightedStockInKg;

      if (!_isWeightedProduct) {
        newStock = widget.product != null
            ? (widget.product!.stock +
                    (int.tryParse(_ingresoController.text.trim()) ?? 0))
                .clamp(0, 0x7fffffff)
            : int.parse(_stockController.text);
        newStockKg = 0.0;
      } else if (invKg) {
        newStock = 0;
        if (widget.product != null) {
          final delta = _parseKgInput(_ingresoController.text) ?? 0.0;
          newStockKg = (widget.product!.stockKg + delta).clamp(0.0, 1e15);
        } else {
          final kg = _parseKgInput(_stockKgController.text);
          if (kg == null || kg < 0) {
            setState(() => _isLoading = false);
            Get.snackbar(
              'Stock inválido',
              'Ingresa los kilogramos iniciales (puede ser 0).',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
            return;
          }
          newStockKg = kg;
        }
      } else {
        newStock = widget.product != null
            ? (widget.product!.stock +
                    (int.tryParse(_ingresoController.text.trim()) ?? 0))
                .clamp(0, 0x7fffffff)
            : int.parse(_stockController.text);
        newStockKg = 0.0;
      }

      final categoryName = _effectiveCategory();
      if (categoryName.isEmpty) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Grupo requerido',
          _availableGroups.isEmpty
              ? 'Escriba el nombre del grupo o cree grupos en el menú correspondiente.'
              : 'Seleccione un grupo en la lista.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final typedPrice = parseMontoPuntosMiles(_priceController.text) ?? 0;
      final salePrice =
          double.tryParse((_salePriceExact ?? Decimal.parse(typedPrice.toString())).toString()) ??
              typedPrice;
      final costValue = parseMontoPuntosMiles(_costController.text) ?? 0;
      if (_isWeightedProduct) {
        if (salePrice <= 0) {
          setState(() => _isLoading = false);
          Get.snackbar(
            'Dato requerido',
            'Para producto pesado ingresa una venta por kg mayor que 0.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
        if (costValue <= 0) {
          setState(() => _isLoading = false);
          Get.snackbar(
            'Dato requerido',
            'Para producto pesado ingresa un costo por kg mayor que 0.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
      }
      final product = Product(
        code: code,
        shortCode: shortCode,
        name: _nameController.text.trim(),
        description: _composedDescriptionForSave(),
        price: salePrice,
        cost: costValue,
        stock: newStock,
        minStock: int.parse(_minStockController.text),
        unit: _unitController.text.trim(),
        category: categoryName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: _isActive,
        imageUrl: _currentImagePath,
        // Si marcó "Exento de IVA" en información básica, se guarda 0%; si no, el % de la pestaña Facturación electrónica (5 o 19).
        ivaPercentage: _exentoIva ? 0 : _ivaPercentage,
        isWeighted: _isWeightedProduct,
        pricePerKg: _isWeightedProduct ? salePrice : null,
        weightedStockInKg: invKg,
        stockKg: newStockKg,
      );

      if (widget.product == null) {
        // Nuevo producto
        product.createdAt = DateTime.now();
        await SQLiteDatabaseService.createProduct(product);
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          '✅ Producto Creado',
          'El producto "${product.name}" ha sido creado correctamente\n'
              'Modo: ${_priceMode == PriceCalculationMode.fixedPrice ? "Precio Fijo" : "Utilidad Fija"}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
        // Preguntar si desea ingresar otro producto
        Future.delayed(const Duration(milliseconds: 300), () {
          Get.defaultDialog(
            title: '¿Ingresar otro producto?',
            middleText: '¿Deseas registrar otro producto nuevo?',
            textCancel: 'No',
            textConfirm: 'Sí',
            onCancel: () {
              Get.back(); // Cierra el diálogo de confirmación
              Get.back(); // Cierra el formulario
            },
            onConfirm: () {
              Get.back(); // Cierra el diálogo de confirmación
              _formKey.currentState?.reset();
              _codeController.clear();
              _shortCodeController.clear();
              _nameController.clear();
              _descriptionController.clear();
              _priceController.clear();
              _priceWithIvaController.clear();
              _costController.clear();
              _stockController.clear();
              _stockKgController.clear();
              _minStockController.clear();
              _unitController.clear();

              setState(() {
                _selectedGroup = null;
                _groupController.text = '';
                _brandController.clear();
                _isActive = true;
                _isWeightedProduct = false;
                _weightedStockInKg = false;
                _weightedPricingMode = WeightedPricingMode.manualSalePerKg;
                _profitPerKgVisualController.clear();
                _salePriceExact = null;
                _priceWithIvaType = 19;
              });
            },
            barrierDismissible: false,
          );
        });
      } else {
        // Actualizar producto existente
        product.id = widget.product!.id;
        product.createdAt = widget.product!.createdAt;
        await SQLiteDatabaseService.updateProduct(product);
        setState(() {
          _isLoading = false;
        });

        // Cerrar el modal inmediatamente y mostrar confirmación
        Get.back(); // Cierra el modal primero

        // Mostrar confirmación después de cerrar el modal
        Future.delayed(const Duration(milliseconds: 100), () {
          Get.snackbar(
            '✅ Producto Actualizado',
            'El producto "${product.name}" ha sido actualizado correctamente\n'
                'Modo: ${_priceMode == PriceCalculationMode.fixedPrice ? "Precio Fijo" : "Utilidad Fija"}',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            snackPosition: SnackPosition.TOP,
          );
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Error al guardar producto: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // ✅ NUEVO: Método para seleccionar imagen del producto
  Future<void> _selectProductImage() async {
    setState(() {
      _isImageLoading = true;
    });

    try {
      final String? imagePath = await ImageService.pickProductImage(context);

      if (imagePath != null) {
        setState(() {
          _currentImagePath = imagePath;
        });

        Get.snackbar(
          '✅ Imagen Seleccionada',
          'La imagen del producto ha sido seleccionada correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Error al seleccionar imagen: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isImageLoading = false;
      });
    }
  }

  // ✅ NUEVO: Método para eliminar imagen del producto
  Future<void> _removeProductImage() async {
    if (_currentImagePath == null) return;

    try {
      await ImageService.deleteProductImage(_currentImagePath);
      setState(() {
        _currentImagePath = null;
      });

      Get.snackbar(
        '✅ Imagen Eliminada',
        'La imagen del producto ha sido eliminada',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Error al eliminar imagen: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // ✅ NUEVO: Widget para la sección de imagen del producto
  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Imagen del Producto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vista previa de la imagen
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _currentImagePath != null
                      ? Image.file(
                          File(_currentImagePath!),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isImageLoading ? null : _selectProductImage,
                  icon: _isImageLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(
                      _isImageLoading ? 'Cargando...' : 'Seleccionar Imagen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_currentImagePath != null) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _removeProductImage,
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Widget placeholder para cuando no hay imagen
  Widget _buildImagePlaceholder() {
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin imagen',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                widget.product == null ? 'Nuevo Producto' : 'Editar Producto',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Pestañas
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[700],
                  tabs: const [
                    Tab(text: 'Información Básica'),
                    Tab(text: 'Facturación Electrónica'),
                    Tab(text: 'Inventario'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contenido de las pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildElectronicInvoicingTab(),
                    _buildInventoryTab(),
                  ],
                ),
              ),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.product == null
                            ? 'Crear Producto'
                            : 'Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pestaña de Información Básica
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Primera fila - Código de Barras y Código Corto
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Barras *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 1234567890123',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El código es obligatorio';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _shortCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código Corto (opcional)',
                    border: OutlineInputBorder(),
                    hintText:
                        'Ej: PROD001 - si no lo ingresas se usará el código de barras',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ NUEVO: Sección de imagen del producto
          _buildImageSection(),
          const SizedBox(height: 16),

          // Segunda fila - Nombre del Producto y Grupo
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Papas Fritas Margarita 150g',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _availableGroups.isEmpty
                    ? TextFormField(
                        controller: _groupController,
                        decoration: const InputDecoration(
                          labelText: 'Grupo',
                          border: OutlineInputBorder(),
                          hintText: 'Escribe el nombre del grupo',
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedGroup != null &&
                                _availableGroups.any(
                                    (group) => group.name == _selectedGroup)
                            ? _selectedGroup
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Grupo',
                          border: OutlineInputBorder(),
                          hintText: 'Seleccionar grupo',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Seleccionar grupo'),
                          ),
                          ..._availableGroups.map((group) {
                            return DropdownMenuItem(
                              value: group.name,
                              child: Text(group.name),
                            );
                          }),
                          // ✅ NUEVO: Opción para crear nuevo grupo
                          const DropdownMenuItem(
                            value: 'CREATE_NEW_GROUP',
                            child: Row(
                              children: [
                                Icon(Icons.add, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Nuevo grupo',
                                    style: TextStyle(color: Colors.blue)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == 'CREATE_NEW_GROUP') {
                            // ✅ NUEVO: Mostrar modal para crear nuevo grupo
                            _showCreateGroupDialog();
                          } else {
                            setState(() {
                              _selectedGroup = value;
                            });
                          }
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tercera fila - Marca y Precio de Venta
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Margarita',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText:
                        _isWeightedProduct ? 'Venta por kg *' : 'Precio de Venta *',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                    hintText:
                        _isWeightedProduct ? 'Ej: 3.000' : 'Ej: 15.000',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [PuntosMilesInputFormatter()],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _isWeightedProduct
                          ? 'La venta por kg es obligatoria'
                          : 'El precio es obligatorio';
                    }
                    final p = parseMontoPuntosMiles(value);
                    if (p == null) {
                      return _isWeightedProduct
                          ? 'Venta por kg inválida'
                          : 'Precio inválido';
                    }
                    if (_isWeightedProduct && p <= 0) {
                      return 'La venta por kg debe ser mayor que 0';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cuarta fila - Precio con IVA y tipo de IVA para autocálculo
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceWithIvaController,
                  decoration: const InputDecoration(
                    labelText: 'Precio con IVA (opcional)',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                    hintText: 'Ej: 11.900',
                    helperText:
                        'Si lo llenas, se calcula automáticamente el precio de venta base.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [PuntosMilesInputFormatter()],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _priceWithIvaType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de IVA',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 19, child: Text('19%')),
                    DropdownMenuItem(value: 5, child: Text('5%')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _priceWithIvaType = value;
                      if (!_exentoIva) {
                        _ivaPercentage = value;
                      }
                    });
                    _onPriceWithIvaChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ NUEVO: Selector de modo de cálculo de precios
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modo de Cálculo de Precios',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<PriceCalculationMode>(
                        title: const Text('Precio Fijo'),
                        subtitle: const Text('Ingresa precio de venta y costo'),
                        value: PriceCalculationMode.fixedPrice,
                        groupValue: _priceMode,
                        onChanged: (value) => _changePriceMode(value!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<PriceCalculationMode>(
                        title: const Text('Utilidad Fija'),
                        subtitle: const Text('Ingresa costo y % de utilidad'),
                        value: PriceCalculationMode.fixedMargin,
                        groupValue: _priceMode,
                        onChanged: (value) => _changePriceMode(value!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CheckboxListTile(
            value: _isWeightedProduct,
            onChanged: (value) {
              setState(() {
                _isWeightedProduct = value ?? false;
                if (!_isWeightedProduct) {
                  _weightedPricingMode = WeightedPricingMode.manualSalePerKg;
                  _profitPerKgVisualController.clear();
                  _weightedStockInKg = false;
                }
              });
            },
            title: const Text('Producto pesado (báscula)'),
            subtitle: const Text(
                'Para este paso solo cambia la etiqueta visual de costo a costo por kg.'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_isWeightedProduct) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<WeightedPricingMode>(
                      value: WeightedPricingMode.manualSalePerKg,
                      groupValue: _weightedPricingMode,
                      onChanged: (value) {
                        setState(() {
                          _weightedPricingMode = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Venta por kg manual'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<WeightedPricingMode>(
                      value: WeightedPricingMode.byProfitPercentage,
                      groupValue: _weightedPricingMode,
                      onChanged: (value) {
                        setState(() {
                          _weightedPricingMode = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Por % utilidad'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Producto exento de IVA (visible al crear/editar). Si se marca, se guarda IVA 0% y no hace falta marcarlo en Facturación electrónica.
          CheckboxListTile(
            value: _exentoIva,
            onChanged: (value) {
              setState(() {
                _exentoIva = value ?? false;
                if (_exentoIva) {
                  _ivaPercentage = 0; // exento en básica = 0% en ventas y FE
                } else {
                  _ivaPercentage = _priceWithIvaType; // al desmarcar, usa el IVA activo del cálculo desde precio con IVA
                }
              });
            },
            title: const Text('Producto exento de IVA'),
            subtitle: const Text(
                'Marcar si el producto no lleva IVA (0%). En ventas aparecerá como exento. Para 5% o 19% use la pestaña Facturación electrónica.'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),

          // Cuarta fila - Precio de Costo
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText:
                        _isWeightedProduct ? 'Costo por kg *' : 'Precio de Costo',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                    hintText:
                        _isWeightedProduct ? 'Ej: 2.000' : 'Ej: 10.000',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [PuntosMilesInputFormatter()],
                  validator: _isWeightedProduct
                      ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El costo por kg es obligatorio';
                          }
                          final c = parseMontoPuntosMiles(value);
                          if (c == null || c <= 0) {
                            return 'El costo por kg debe ser mayor que 0';
                          }
                          return null;
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Container()), // Espacio vacío para mantener el layout
            ],
          ),
          if (_isWeightedProduct &&
              _weightedPricingMode == WeightedPricingMode.byProfitPercentage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _profitPerKgVisualController,
                    decoration: const InputDecoration(
                      labelText: '% utilidad por kg',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: 30',
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Container()),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Descripción
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
              hintText: 'Descripción detallada del producto...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Checkboxes
          Row(
            children: [
              Checkbox(
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value ?? true;
                  });
                },
              ),
              const Text('Producto activo'),
            ],
          ),
        ],
      ),
    );
  }

  // Pestaña de Facturación Electrónica
  Widget _buildElectronicInvoicingTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración DIAN',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Primera fila - Clasificación Fiscal e IVA
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Clasificación Fiscal *',
                    border: OutlineInputBorder(),
                    helperText: 'Según normativa DIAN',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'GRAVADO', child: Text('Gravado')),
                    DropdownMenuItem(value: 'EXENTO', child: Text('Exento')),
                    DropdownMenuItem(
                        value: 'EXCLUIDO', child: Text('Excluido')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'IVA *',
                    border: OutlineInputBorder(),
                    helperText: 'Se guarda al dar Actualizar',
                  ),
                  value: _ivaPercentage == 0 ? '0' : (_ivaPercentage == 5 ? '5' : '19'),
                  items: const [
                    DropdownMenuItem(value: '19', child: Text('19%')),
                    DropdownMenuItem(value: '5', child: Text('5%')),
                    DropdownMenuItem(value: '0', child: Text('0% (Exento)')),
                    DropdownMenuItem(value: 'EXCLUIDO', child: Text('Excluido')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        if (value == '19') _ivaPercentage = 19;
                        else if (value == '5') _ivaPercentage = 5;
                        else _ivaPercentage = 0; // 0% o Excluido
                        _exentoIva = (_ivaPercentage == 0);
                        if (_ivaPercentage == 5 || _ivaPercentage == 19) {
                          _priceWithIvaType = _ivaPercentage;
                        }
                      });
                      _onPriceWithIvaChanged();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segunda fila - Indicador de Producto y Unidad de Medida DIAN
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Indicador de Producto *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                    DropdownMenuItem(value: 'COMBO', child: Text('Combo')),
                    DropdownMenuItem(
                        value: 'SERVICIO', child: Text('Servicio')),
                    DropdownMenuItem(
                        value: 'PESADO', child: Text('Pesado (Báscula)')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Unidad de Medida DIAN *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unidad', child: Text('Unidad')),
                    DropdownMenuItem(
                        value: 'kilogramo', child: Text('Kilogramo')),
                    DropdownMenuItem(value: 'litro', child: Text('Litro')),
                    DropdownMenuItem(value: 'paquete', child: Text('Paquete')),
                    DropdownMenuItem(value: 'metro', child: Text('Metro')),
                    DropdownMenuItem(value: 'gramo', child: Text('Gramo')),
                    DropdownMenuItem(
                        value: 'centimetro', child: Text('Centímetro')),
                    DropdownMenuItem(
                        value: 'mililitro', child: Text('Mililitro')),
                    DropdownMenuItem(value: 'docena', child: Text('Docena')),
                    DropdownMenuItem(value: 'caja', child: Text('Caja')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tercera fila - Impuestos Adicionales y Marca
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Impuestos Adicionales',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'NINGUNO',
                        child: Text('Sin impuestos adicionales')),
                    DropdownMenuItem(
                        value: 'IMPUESTO_BOLSA', child: Text('Impuesto Bolsa')),
                    DropdownMenuItem(
                        value: 'RETEFUENTE_2_5',
                        child: Text('Retefuente 2.5%')),
                    DropdownMenuItem(
                        value: 'RETEIVA_15', child: Text('ReteIVA 15%')),
                    DropdownMenuItem(
                        value: 'IMPUESTO_CONSUMO',
                        child: Text('Impuesto al Consumo')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Coca-Cola',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cuarta fila - Modelo y Código EAN/UPC
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 2024',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Código EAN/UPC',
                    border: OutlineInputBorder(),
                    hintText: '1234567890123',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quinta fila - Fabricante y País de origen
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Fabricante',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Coca-Cola Company',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'País de Origen',
                    border: OutlineInputBorder(),
                    hintText: 'CO',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sexta fila - Código arancelario y Peso neto
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Código Arancelario',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 2202.10.00.00',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Peso Neto (kg)',
                    border: OutlineInputBorder(),
                    hintText: '0.5',
                    suffixText: 'kg',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Séptima fila - Peso bruto y Dimensiones
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Peso Bruto (kg)',
                    border: OutlineInputBorder(),
                    hintText: '0.6',
                    suffixText: 'kg',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Dimensiones',
                    border: OutlineInputBorder(),
                    hintText: '10x5x2 cm',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Octava fila - Material y Garantía
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Material',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Plástico, Vidrio',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Garantía',
                    border: OutlineInputBorder(),
                    hintText: '1 año',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Novena fila - Fecha de vencimiento y SKU
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Vencimiento',
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/YYYY',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () {
                    // TODO: Implementar selector de fecha
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    border: OutlineInputBorder(),
                    hintText: 'Código interno del producto',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Checkboxes
          Row(
            children: [
              Checkbox(
                value: false, // TODO: Implementar estado
                onChanged: (value) {
                  // TODO: Implementar lógica
                },
              ),
              const Text('Exento de impuestos'),
              const SizedBox(width: 32),
              Checkbox(
                value: false, // TODO: Implementar estado
                onChanged: (value) {
                  // TODO: Implementar lógica
                },
              ),
              const Text('Es un servicio'),
            ],
          ),
          const SizedBox(height: 16),

          // Información adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estos campos son requeridos para la facturación electrónica según normativa DIAN. Los campos marcados con * son obligatorios.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pestaña de Inventario
  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración de Inventario',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ✅ NUEVO: Indicador del modo actual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _priceMode == PriceCalculationMode.fixedPrice
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _priceMode == PriceCalculationMode.fixedPrice
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _priceMode == PriceCalculationMode.fixedPrice
                      ? Icons.calculate
                      : Icons.percent,
                  color: _priceMode == PriceCalculationMode.fixedPrice
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _priceMode == PriceCalculationMode.fixedPrice
                        ? 'Modo Precio Fijo: El % de utilidad se calcula automáticamente'
                        : 'Modo Utilidad Fija: El precio de venta se calcula automáticamente',
                    style: TextStyle(
                      color: _priceMode == PriceCalculationMode.fixedPrice
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primera fila - Al editar: Stock actual (solo lectura) + Ingreso. Al crear: Stock actual editable.
          Row(
            children: [
              Expanded(
                child: _isWeightedProduct
                    ? (widget.product != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return ToggleButtons(
                                    borderRadius: BorderRadius.circular(8),
                                    constraints: BoxConstraints(
                                      minHeight: 40,
                                      minWidth: (constraints.maxWidth - 8) / 2,
                                    ),
                                    isSelected: [
                                      !_weightedStockInKg,
                                      _weightedStockInKg,
                                    ],
                                    onPressed: (i) {
                                      setState(
                                          () => _weightedStockInKg = i == 1);
                                    },
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('Unidades'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('kg'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Stock actual',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade100,
                                ),
                                child: Text(
                                  _weightedStockInKg
                                      ? '${widget.product!.stockKg} kg'
                                      : '${widget.product!.stock} unidades',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _ingresoController,
                                decoration: InputDecoration(
                                  labelText: _weightedStockInKg
                                      ? 'Ingreso (kg a sumar o restar)'
                                      : 'Ingreso (unidades a agregar o quitar)',
                                  border: const OutlineInputBorder(),
                                  hintText: '0',
                                  suffixText:
                                      _weightedStockInKg ? 'kg' : 'unidades',
                                  helperText: _weightedStockInKg
                                      ? 'Ej: 2,5 suma; -1 resta kg'
                                      : 'Ej: 10 suma 10 al stock',
                                ),
                                keyboardType: _weightedStockInKg
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true, signed: true)
                                    : TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  if (_weightedStockInKg) {
                                    if (double.tryParse(value
                                            .trim()
                                            .replaceAll(',', '.')) ==
                                        null) {
                                      return 'Número inválido';
                                    }
                                  } else {
                                    if (int.tryParse(value) == null) {
                                      return 'Ingrese un número entero';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return ToggleButtons(
                                    borderRadius: BorderRadius.circular(8),
                                    constraints: BoxConstraints(
                                      minHeight: 40,
                                      minWidth: (constraints.maxWidth - 8) / 2,
                                    ),
                                    isSelected: [
                                      !_weightedStockInKg,
                                      _weightedStockInKg,
                                    ],
                                    onPressed: (i) {
                                      setState(
                                          () => _weightedStockInKg = i == 1);
                                    },
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('Unidades'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('kg'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              if (!_weightedStockInKg)
                                TextFormField(
                                  controller: _stockController,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock Actual *',
                                    border: OutlineInputBorder(),
                                    hintText: '0',
                                    suffixText: 'unidades',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'El stock es obligatorio';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Stock inválido';
                                    }
                                    return null;
                                  },
                                )
                              else
                                TextFormField(
                                  controller: _stockKgController,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock inicial (kg) *',
                                    border: OutlineInputBorder(),
                                    hintText: 'Ej: 25,5',
                                    suffixText: 'kg',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Ingresa el stock en kg (0 si no aplica)';
                                    }
                                    final x = double.tryParse(value
                                        .trim()
                                        .replaceAll(',', '.'));
                                    if (x == null || x < 0) {
                                      return 'Valor inválido';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ))
                    : (widget.product != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock actual',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade100,
                                ),
                                child: Text(
                                  '${widget.product!.stock} unidades',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _ingresoController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Ingreso (unidades a agregar o quitar)',
                                  border: OutlineInputBorder(),
                                  hintText: '0',
                                  suffixText: 'unidades',
                                  helperText:
                                      'Ej: 10 para sumar 10 al stock actual',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Ingrese un número';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          )
                        : TextFormField(
                            controller: _stockController,
                            decoration: const InputDecoration(
                              labelText: 'Stock Actual *',
                              border: OutlineInputBorder(),
                              hintText: '0',
                              suffixText: 'unidades',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El stock es obligatorio';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Stock inválido';
                              }
                              return null;
                            },
                          )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _minStockController,
                  decoration: InputDecoration(
                    labelText: 'Stock Mínimo *',
                    border: const OutlineInputBorder(),
                    hintText: '5',
                    suffixText: _isWeightedProduct && _weightedStockInKg
                        ? 'kg (alerta)'
                        : 'unidades',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El stock mínimo es obligatorio';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Stock mínimo inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segunda fila - Precio mínimo y % de utilidad
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Precio Mínimo Permitido',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                    hintText: '0.00',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _profitMarginController,
                  decoration: InputDecoration(
                    labelText: '% de Utilidad',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    hintText: '30',
                    // ✅ NUEVO: Indicar si el campo es editable según el modo
                    filled: _priceMode == PriceCalculationMode.fixedPrice,
                    fillColor: _priceMode == PriceCalculationMode.fixedPrice
                        ? Colors.grey.shade100
                        : null,
                    helperText: _priceMode == PriceCalculationMode.fixedPrice
                        ? 'Calculado automáticamente: (Precio - Costo) / Precio × 100'
                        : 'Ingresa el % de utilidad deseado (sobre precio de venta)',
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: _priceMode == PriceCalculationMode.fixedPrice,
                  validator: (value) {
                    if (_priceMode == PriceCalculationMode.fixedMargin) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El % de utilidad es obligatorio';
                      }
                      final margin = double.tryParse(value);
                      if (margin == null || margin < 0) {
                        return 'Utilidad inválida';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tercera fila - Precio sin IVA (calculado) y Costo total
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Precio sin IVA (Calculado)',
                    border: const OutlineInputBorder(),
                    prefixText: '\$',
                    hintText: '0.00',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Costo Total (Costo × Stock)',
                    border: const OutlineInputBorder(),
                    prefixText: '\$',
                    hintText: '0.00',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cuarta fila - Manejo de decimales y Estado
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Manejo de Decimales',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'NO', child: Text('No (Productos enteros)')),
                    DropdownMenuItem(
                        value: 'SI',
                        child: Text('Sí (Productos fraccionables)')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Estado del Producto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVO', child: Text('Activo')),
                    DropdownMenuItem(
                        value: 'INACTIVO', child: Text('Inactivo')),
                    DropdownMenuItem(
                        value: 'DESCONTINUADO', child: Text('Descontinuado')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quinta fila - Proveedor principal y Código del proveedor
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Proveedor Principal',
                    border: OutlineInputBorder(),
                    hintText: 'Nombre del proveedor',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Código del Proveedor',
                    border: OutlineInputBorder(),
                    hintText: 'Código interno del proveedor',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sexta fila - Cuenta contable y Ubicación
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Cuenta Contable',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 1405 - Inventarios',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Ubicación en Almacén',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Estante A, Nivel 2',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Checkboxes
          Row(
            children: [
              const SizedBox(width: 32),
              Checkbox(
                value: false, // TODO: Implementar estado
                onChanged: (value) {
                  // TODO: Implementar lógica
                },
              ),
              const Text('Combustible'),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Checkbox(
                value: false, // TODO: Implementar estado
                onChanged: (value) {
                  // TODO: Implementar lógica
                },
              ),
              const Text('Control de lotes'),
              const SizedBox(width: 32),
              Checkbox(
                value: false, // TODO: Implementar estado
                onChanged: (value) {
                  // TODO: Implementar lógica
                },
              ),
              const Text('Control de vencimiento'),
            ],
          ),
          const SizedBox(height: 24),

          // Información adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Los campos marcados con * son obligatorios. Los precios calculados se actualizan automáticamente.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Mostrar modal para crear nuevo grupo
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    String selectedColor = '#FF5722'; // Color por defecto

    final List<Map<String, String>> availableColors = [
      {'name': 'Rojo', 'value': '#FF5722'},
      {'name': 'Verde', 'value': '#4CAF50'},
      {'name': 'Azul', 'value': '#2196F3'},
      {'name': 'Naranja', 'value': '#FF9800'},
      {'name': 'Morado', 'value': '#9C27B0'},
      {'name': 'Marrón', 'value': '#795548'},
      {'name': 'Gris', 'value': '#9E9E9E'},
      {'name': 'Amarillo', 'value': '#FFEB3B'},
    ];

    Get.dialog(
      AlertDialog(
        title: const Text('Crear Nuevo Grupo'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Grupo *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Frutas y Verduras',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Color del grupo:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: availableColors.map((color) {
                    final isSelected = selectedColor == color['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = color['value']!;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(
                              color['value']!.replaceAll('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  // Crear el nuevo grupo
                  final newGroup = Group(
                    name: nameController.text.trim(),
                    description: 'Grupo creado por el usuario',
                    color: selectedColor,
                    icon: 'category', // Icono por defecto
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await SQLiteDatabaseService.createGroup(newGroup);

                  // Recargar grupos y seleccionar el nuevo
                  await _loadGroups();
                  setState(() {
                    _selectedGroup = newGroup.name;
                  });

                  Get.back(); // Cerrar modal
                  Get.snackbar(
                    '✅ Grupo Creado',
                    'El grupo "${newGroup.name}" ha sido creado exitosamente',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                } catch (e) {
                  Get.snackbar(
                    '❌ Error',
                    'Error creando grupo: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              } else {
                Get.snackbar(
                  '⚠️ Campo requerido',
                  'El nombre del grupo es obligatorio',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
