import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/product.dart';
import '../models/group.dart';
import '../services/sqlite_database_service.dart';
import '../services/import_service.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Group> _groups = [];
  Group? _selectedGroup;
  bool _isLoading = true;

  final NumberFormat copFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cuando se regresa a esta pantalla
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await SQLiteDatabaseService.getAllProducts();
      final groups = await SQLiteDatabaseService.getAllGroups();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Error al cargar productos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesSearch = product.name
            .toLowerCase()
            .contains(_searchController.text.toLowerCase()) ||
            product.code.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesGroup = _selectedGroup == null || 
            product.category.toString().split('.').last == _selectedGroup!.name;
        
        return matchesSearch && matchesGroup;
      }).toList();
    });
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(),
    ).then((_) => _loadProducts());
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(product: product),
    ).then((_) => _loadProducts());
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SQLiteDatabaseService.deleteProduct(product.id!);
        Get.snackbar(
          'Éxito',
          'Producto eliminado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadProducts();
      } catch (e) {
        Get.snackbar(
          'Error',
          'Error al eliminar producto: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _importProductsFromExcel() async {
    try {
      Get.dialog(
        const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Importando productos...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      final products = await ImportService.importProductsFromFile();
      Get.back(); // Cerrar diálogo de carga

      if (products.isEmpty) {
        Get.snackbar(
          'Advertencia',
          'No se encontraron productos válidos en el archivo',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Detectar productos repetidos
      final existingProducts = await SQLiteDatabaseService.getAllProducts();
      final existingCodes = existingProducts.map((p) => p.code).toSet();
      final repeated = products.where((p) => existingCodes.contains(p.code)).toList();
      final newProducts = products.where((p) => !existingCodes.contains(p.code)).toList();

      // Mostrar resumen y opciones
      final action = await Get.dialog<String>(
        AlertDialog(
          title: const Text('Resumen de importación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Productos nuevos: ${newProducts.length}'),
              Text('Productos repetidos: ${repeated.length}'),
              if (repeated.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('¿Qué deseas hacer con los productos repetidos?'),
              ],
            ],
          ),
          actions: [
            if (repeated.isNotEmpty)
              TextButton(
                onPressed: () => Get.back(result: 'omit'),
                child: const Text('Omitir repetidos'),
              ),
            if (repeated.isNotEmpty)
              TextButton(
                onPressed: () => Get.back(result: 'overwrite'),
                child: const Text('Sobrescribir repetidos'),
              ),
            TextButton(
              onPressed: () => Get.back(result: 'cancel'),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) return;

      List<Product> toImport = [];
      if (action == 'omit') {
        toImport = newProducts;
      } else if (action == 'overwrite') {
        // Sobrescribir: mantener los nuevos y los repetidos (se actualizarán)
        toImport = products;
      }

      if (toImport.isEmpty) {
        Get.snackbar(
          'Sin cambios',
          'No hay productos nuevos para importar.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      await ImportService.saveImportedProducts(toImport);
      Get.snackbar(
        'Éxito',
        '${toImport.length} productos importados correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      _loadProducts();
    } catch (e) {
      Get.back(); // Cerrar diálogo de carga si hay error
      Get.snackbar(
        'Error',
        'Error al importar productos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _exportProductsToCsv() async {
    try {
      final products = await SQLiteDatabaseService.getAllProducts();
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar productos como...',
        fileName: 'productos_exportados.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (outputPath == null) return; // Usuario canceló
      await ImportService.exportProductsToCsv(products, outputPath);
      Get.snackbar(
        'Éxito',
        'Archivo exportado en: $outputPath',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo exportar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showExcelTemplate() {
    Get.dialog(
      AlertDialog(
        title: const Text('Plantilla Excel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para importar productos, usa esta estructura en tu archivo Excel:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                ImportService.getExcelTemplate(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• CÓDIGO y NOMBRE son obligatorios'),
            const Text('• PRECIO y STOCK se establecen en 0 si no se especifican'),
            const Text('• CATEGORÍA debe ser una de las categorías disponibles'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF22315B)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Gestión de Inventario',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF22315B)),
            onPressed: () => Get.offAllNamed('/dashboard'),
            tooltip: 'Ir al Dashboard',
          ),
        ],
      ),
      body: Column(
        children: [
          // Botones de acción
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Botón Plantilla Excel
                OutlinedButton.icon(
                  onPressed: _showExcelTemplate,
                  icon: Icon(Icons.description, color: Colors.blue[700]),
                  label: Text('Plantilla Excel', style: TextStyle(color: Colors.blue[700])),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón Importar Excel
                ElevatedButton.icon(
                  onPressed: _importProductsFromExcel,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Importar Excel/CSV', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportProductsToCsv,
                  icon: Icon(Icons.download, color: Colors.blue[700]),
                  label: Text('Exportar productos', style: TextStyle(color: Colors.blue[700])),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón Nuevo Producto
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                // Búsqueda
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _filterProducts(),
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Filtro por grupo
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<Group?>(
                    value: _selectedGroup,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos los grupos'),
                      ),
                      ..._groups.map((group) => DropdownMenuItem(
                        value: group,
                        child: Text(group.name),
                      )),
                    ],
                    onChanged: (group) {
                      setState(() {
                        _selectedGroup = group;
                      });
                      _filterProducts();
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                        ),
                      ),
                    ],
                  ),
                ),
          // Lista de productos
          Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                    ? const Center(child: Text('No hay productos para mostrar.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onEdit: () => _showEditProductDialog(product),
                            onDelete: () => _deleteProduct(product),
                              );
                        },
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return 'Frutas y Verduras';
      case ProductCategory.lacteos:
        return 'Lácteos';
      case ProductCategory.panaderia:
        return 'Panadería';
      case ProductCategory.carnes:
        return 'Carnes';
      case ProductCategory.bebidas:
        return 'Bebidas';
      case ProductCategory.abarrotes:
        return 'Abarrotes';
      case ProductCategory.limpieza:
        return 'Limpieza';
      case ProductCategory.cuidadoPersonal:
        return 'Cuidado Personal';
      case ProductCategory.otros:
        return 'Otros';
    }
  }
}

// Diálogo para agregar/editar productos
class _ProductFormDialog extends StatefulWidget {
  final Product? product;

  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _shortCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _unitController = TextEditingController();
  final _groupController = TextEditingController();
  
  // Controladores para productos pesados
  final _pricePerKgController = TextEditingController();
  final _weightController = TextEditingController();
  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  
  String _selectedGroup = 'Otros';
  List<Group> _availableGroups = [];
  bool _isActive = true;
  bool _isWeighted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    if (widget.product != null) {
      _codeController.text = widget.product!.code;
      _shortCodeController.text = widget.product!.shortCode;
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _costController.text = widget.product!.cost.toString();
      _stockController.text = widget.product!.stock.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _unitController.text = widget.product!.unit;
      _selectedGroup = _getCategoryName(widget.product!.category);
      _groupController.text = _selectedGroup;
      _isActive = widget.product!.isActive;
      
      // Campos para productos pesados
      _isWeighted = widget.product!.isWeighted;
      _pricePerKgController.text = widget.product!.pricePerKg?.toString() ?? '';
      _weightController.text = widget.product!.weight?.toString() ?? '';
      _minWeightController.text = widget.product!.minWeight?.toString() ?? '';
      _maxWeightController.text = widget.product!.maxWeight?.toString() ?? '';
    }
  }
  
  Future<void> _loadGroups() async {
    try {
      final groups = await SQLiteDatabaseService.getAllGroups();
      setState(() {
        _availableGroups = groups;
      });
    } catch (e) {
      print('Error cargando grupos: $e');
    }
  }
  
  void _showGroupManager() {
    Get.toNamed('/grupos')?.then((_) {
      // Recargar grupos cuando regrese de la pantalla de gestión
      _loadGroups();
    });
  }
  
  ProductCategory _getCategoryFromName(String name) {
    switch (name.toLowerCase()) {
      case 'frutas y verduras':
        return ProductCategory.frutasVerduras;
      case 'lácteos':
        return ProductCategory.lacteos;
      case 'panadería':
        return ProductCategory.panaderia;
      case 'carnes':
        return ProductCategory.carnes;
      case 'bebidas':
        return ProductCategory.bebidas;
      case 'abarrotes':
        return ProductCategory.abarrotes;
      case 'limpieza':
        return ProductCategory.limpieza;
      case 'cuidado personal':
        return ProductCategory.cuidadoPersonal;
      default:
        return ProductCategory.otros;
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim();
      final shortCode = _shortCodeController.text.trim();
      final excludeId = widget.product?.id;

      // Validar código de barras único
      final exists = await SQLiteDatabaseService.existsProductCode(code, excludeId: excludeId);
      if (exists) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Ya existe un producto con ese código de barras.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }

      // Validar código corto único
      final existsShort = await SQLiteDatabaseService.getAllProducts();
      if (existsShort.any((p) => p.shortCode == shortCode && p.id != excludeId)) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Ya existe un producto con ese código corto.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }

      final product = Product(
        code: code,
        shortCode: shortCode,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        cost: double.parse(_costController.text),
        stock: int.parse(_stockController.text),
        minStock: int.parse(_minStockController.text),
        unit: _unitController.text.trim(),
        category: _getCategoryFromName(_selectedGroup),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: _isActive,
        isWeighted: _isWeighted,
        pricePerKg: _pricePerKgController.text.isNotEmpty ? double.tryParse(_pricePerKgController.text) : null,
        weight: _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
        minWeight: _minWeightController.text.isNotEmpty ? double.tryParse(_minWeightController.text) : null,
        maxWeight: _maxWeightController.text.isNotEmpty ? double.tryParse(_maxWeightController.text) : null,
      );

      if (widget.product == null) {
        // Nuevo producto
        product.createdAt = DateTime.now();
        await SQLiteDatabaseService.createProduct(product);
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Éxito',
          'Producto creado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
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
              _costController.clear();
              _stockController.clear();
              _minStockController.clear();
              _unitController.clear();
              _pricePerKgController.clear();
              _weightController.clear();
              _minWeightController.clear();
              _maxWeightController.clear();
              setState(() {
                _selectedGroup = 'Otros';
                _groupController.text = 'Otros';
                _isActive = true;
                _isWeighted = false;
              });
            },
            barrierDismissible: false,
          );
        });
      } else {
        // Editar producto existente
        final updatedProduct = product.copyWith(
          id: widget.product!.id,
          createdAt: widget.product!.createdAt,
        );
        await SQLiteDatabaseService.updateProduct(updatedProduct);
        setState(() {
          _isLoading = false;
        });
        Get.back();
        Get.snackbar(
          'Éxito',
          'Producto actualizado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
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
        duration: Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product == null ? 'Nuevo Producto' : 'Editar Producto',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Primera fila
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de Barras *',
                        border: OutlineInputBorder(),
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
                        labelText: 'Código Corto *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El código corto es obligatorio';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Segunda fila
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                        labelText: 'Nombre del Producto *',
                  border: OutlineInputBorder(),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _availableGroups.isEmpty
                              ? TextFormField(
                                  controller: _groupController,
                                  decoration: const InputDecoration(
                                    labelText: 'Grupo',
                                    border: OutlineInputBorder(),
                                    hintText: 'Escribe el nombre del grupo',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'El grupo es obligatorio';
                                    }
                                    return null;
                                  },
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedGroup,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: 'Otros',
                                      child: Text('Otros'),
                                    ),
                                    ..._availableGroups.map((group) => DropdownMenuItem<String>(
                                      value: group.name,
                                      child: Text(
                                        group.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    )).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGroup = value!;
                                      _groupController.text = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Grupo',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'El grupo es obligatorio';
                                    }
                                    return null;
                                  },
                                  isExpanded: true,
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showGroupManager,
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Gestionar grupos',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Tercera fila
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio de Venta *',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El precio es obligatorio';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Precio de Costo *',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El costo es obligatorio';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Costo inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unidad *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La unidad es obligatoria';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Cuarta fila
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock Actual',
                        border: OutlineInputBorder(),
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock Mínimo',
                        border: OutlineInputBorder(),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Activo'),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Checkbox para productos pesados
              CheckboxListTile(
                title: const Text('Producto pesado (se vende por peso)'),
                value: _isWeighted,
                onChanged: (value) => setState(() => _isWeighted = value!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              
              // Campos para productos pesados (solo si está marcado)
              if (_isWeighted) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pricePerKgController,
                        decoration: const InputDecoration(
                          labelText: 'Precio por Kg *',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_isWeighted && (value == null || value.trim().isEmpty)) {
                            return 'El precio por kg es obligatorio para productos pesados';
                          }
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Precio por kg inválido';
                          }
                          return null;
                },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                decoration: const InputDecoration(
                          labelText: 'Peso actual (kg)',
                  border: OutlineInputBorder(),
                          suffixText: 'kg',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Peso inválido';
                          }
                          return null;
                        },
                      ),
                  ),
                  ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Peso mínimo (kg)',
                          border: OutlineInputBorder(),
                          suffixText: 'kg',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Peso mínimo inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Peso máximo (kg)',
                          border: OutlineInputBorder(),
                          suffixText: 'kg',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Peso máximo inválido';
                          }
                          return null;
                    },
                      ),
                    ),
                  ],
                  ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              
              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              // Botones
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
                        : Text(widget.product == null ? 'Crear' : 'Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryName(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return 'Frutas y Verduras';
      case ProductCategory.lacteos:
        return 'Lácteos';
      case ProductCategory.panaderia:
        return 'Panadería';
      case ProductCategory.carnes:
        return 'Carnes';
      case ProductCategory.bebidas:
        return 'Bebidas';
      case ProductCategory.abarrotes:
        return 'Abarrotes';
      case ProductCategory.limpieza:
        return 'Limpieza';
      case ProductCategory.cuidadoPersonal:
        return 'Cuidado Personal';
      case ProductCategory.otros:
        return 'Otros';
    }
  }
}

// Widget para las tarjetas de productos
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final copFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(product.category),
          child: Icon(
            _getCategoryIcon(product.category),
            color: Colors.white,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código:  ${product.code}'),
            if (product.isWeighted) ...[
              Text('Precio por Kg:  ${copFormat.format(product.pricePerKg ?? 0)}'),
              if (product.weight != null)
                Text('Peso:  ${product.weight!.toStringAsFixed(2)} kg'),
              if (product.minWeight != null && product.maxWeight != null)
                Text('Rango:  ${product.minWeight!.toStringAsFixed(2)} - ${product.maxWeight!.toStringAsFixed(2)} kg'),
            ] else ...[
              Text('Precio:  ${copFormat.format(product.price)}'),
            ],
            Text('Stock:  ${product.stock} ${product.unit}'),
            if (product.stock <= product.minStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Stock bajo',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (product.isWeighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Producto pesado',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return Colors.red;
      case ProductCategory.lacteos:
        return Colors.blue;
      case ProductCategory.panaderia:
        return Colors.orange;
      case ProductCategory.carnes:
        return Colors.brown;
      case ProductCategory.bebidas:
        return Colors.green;
      case ProductCategory.abarrotes:
        return Colors.purple;
      case ProductCategory.limpieza:
        return Colors.teal;
      case ProductCategory.cuidadoPersonal:
        return Colors.pink;
      case ProductCategory.otros:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return Icons.apple;
      case ProductCategory.lacteos:
        return Icons.local_drink;
      case ProductCategory.panaderia:
        return Icons.bakery_dining;
      case ProductCategory.carnes:
        return Icons.set_meal;
      case ProductCategory.bebidas:
        return Icons.local_bar;
      case ProductCategory.abarrotes:
        return Icons.inventory;
      case ProductCategory.limpieza:
        return Icons.cleaning_services;
      case ProductCategory.cuidadoPersonal:
        return Icons.person;
      case ProductCategory.otros:
        return Icons.category;
    }
  }
} 