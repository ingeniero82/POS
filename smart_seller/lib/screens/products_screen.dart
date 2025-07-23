import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/product.dart';
import '../services/sqlite_database_service.dart';
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
  ProductCategory? _selectedCategory;
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
      setState(() {
        _products = products;
        _filteredProducts = products;
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
        
        final matchesCategory = _selectedCategory == null || 
            product.category == _selectedCategory;
        
        return matchesSearch && matchesCategory;
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

  void _showDeleteConfirmation(Product product) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _deleteProduct(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      await SQLiteDatabaseService.deleteProduct(product.id!);
      Get.snackbar(
        'Producto eliminado',
        '${product.name} ha sido eliminado',
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

  void _showImportDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Importar Productos'),
        content: const Text('Selecciona un archivo CSV para importar productos.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _importProducts();
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importProducts() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        // TODO: Implementar importación de productos desde CSV
        Get.snackbar(
          'Importación',
          'Funcionalidad de importación en desarrollo',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al importar productos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _showImportDialog,
            tooltip: 'Importar productos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar productos',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _filterProducts(),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButtonFormField<ProductCategory>(
                  value: _selectedCategory,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    ...ProductCategory.values.map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryName(category)),
                    )),
                  ],
                  onChanged: (category) {
                    setState(() => _selectedCategory = category);
                    _filterProducts();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
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
                    ? const Center(
                        child: Text(
                          'No se encontraron productos',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onEdit: () => _showEditProductDialog(product),
                            onDelete: () => _showDeleteConfirmation(product),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
      case ProductCategory.servicios:
        return 'Servicios';
      case ProductCategory.otros:
        return 'Otros';
    }
  }
}

// Widget para mostrar un producto en la lista
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            Text('Código: ${product.code}'),
            if (product.isWeighted) ...[
              Text('Precio/kg: \$${product.pricePerKg?.toStringAsFixed(0) ?? '0'}'),
              if (product.weight != null)
                Text('Peso:  ${product.weight!.toStringAsFixed(2)} kg'),
              if (product.minWeight != null && product.maxWeight != null)
                Text('Rango:  ${product.minWeight!.toStringAsFixed(2)} - ${product.maxWeight!.toStringAsFixed(2)} kg'),
            ] else ...[
              Text('Precio:  ${NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0, customPattern: '\u00A4#,##0').format(product.price)}'),
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
      case ProductCategory.servicios:
        return Colors.indigo;
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
      case ProductCategory.servicios:
        return Icons.miscellaneous_services;
      case ProductCategory.otros:
        return Icons.category;
    }
  }
}

// Widget para el formulario de producto
class _ProductFormDialog extends StatefulWidget {
  final Product? product;

  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controladores para campos básicos
  final _codeController = TextEditingController();
  final _shortCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _unitController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Controladores para campos de peso
  final _pricePerKgController = TextEditingController();
  final _weightController = TextEditingController();
  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  
  // Controladores para campos de facturación electrónica
  final _taxCodeController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _productTypeController = TextEditingController();
  final _serviceCodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _barcodeController = TextEditingController();
  
  // Controladores para campos adicionales
  final _manufacturerController = TextEditingController();
  final _countryOfOriginController = TextEditingController();
  final _customsCodeController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _materialController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _expirationDateController = TextEditingController();
  
  // Variables de estado
  ProductCategory _selectedCategory = ProductCategory.otros;
  bool _isWeighted = false;
  bool _isService = false;
  bool _isExempt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    if (widget.product != null) {
      _loadProductData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _shortCodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _pricePerKgController.dispose();
    _weightController.dispose();
    _minWeightController.dispose();
    _maxWeightController.dispose();
    _taxCodeController.dispose();
    _taxRateController.dispose();
    _productTypeController.dispose();
    _serviceCodeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _barcodeController.dispose();
    _manufacturerController.dispose();
    _countryOfOriginController.dispose();
    _customsCodeController.dispose();
    _netWeightController.dispose();
    _grossWeightController.dispose();
    _dimensionsController.dispose();
    _materialController.dispose();
    _warrantyController.dispose();
    _expirationDateController.dispose();
    super.dispose();
  }

  void _loadProductData() {
    final product = widget.product!;
    _codeController.text = product.code;
    _shortCodeController.text = product.shortCode;
    _nameController.text = product.name;
    _priceController.text = product.price.toString();
    _costController.text = product.cost.toString();
    _stockController.text = product.stock.toString();
    _minStockController.text = product.minStock.toString();
    _unitController.text = product.unit;
    _descriptionController.text = product.description ?? '';
    _selectedCategory = product.category;
    _isWeighted = product.isWeighted;
    
    // Campos de peso
    if (product.pricePerKg != null) {
      _pricePerKgController.text = product.pricePerKg.toString();
    }
    if (product.weight != null) {
      _weightController.text = product.weight.toString();
    }
    if (product.minWeight != null) {
      _minWeightController.text = product.minWeight.toString();
    }
    if (product.maxWeight != null) {
      _maxWeightController.text = product.maxWeight.toString();
    }
    
    // Campos de facturación electrónica
    _taxCodeController.text = product.taxCode ?? '';
    if (product.taxRate != null) {
      _taxRateController.text = product.taxRate.toString();
    }
    _productTypeController.text = product.productType ?? '';
    _serviceCodeController.text = product.serviceCode ?? '';
    _brandController.text = product.brand ?? '';
    _modelController.text = product.model ?? '';
    _barcodeController.text = product.barcode ?? '';
    _isService = product.isService;
    _isExempt = product.isExempt;
    
    // Campos adicionales
    _manufacturerController.text = product.manufacturer ?? '';
    _countryOfOriginController.text = product.countryOfOrigin ?? '';
    _customsCodeController.text = product.customsCode ?? '';
    if (product.netWeight != null) {
      _netWeightController.text = product.netWeight.toString();
    }
    if (product.grossWeight != null) {
      _grossWeightController.text = product.grossWeight.toString();
    }
    _dimensionsController.text = product.dimensions ?? '';
    _materialController.text = product.material ?? '';
    _warrantyController.text = product.warranty ?? '';
    _expirationDateController.text = product.expirationDate ?? '';
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id,
        code: _codeController.text.trim(),
        shortCode: _shortCodeController.text.trim(),
        name: _nameController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        cost: double.parse(_costController.text),
        stock: int.parse(_stockController.text),
        minStock: int.parse(_minStockController.text),
        unit: _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        isWeighted: _isWeighted,
        pricePerKg: _isWeighted ? double.tryParse(_pricePerKgController.text) : null,
        weight: _isWeighted ? double.tryParse(_weightController.text) : null,
        minWeight: _isWeighted ? double.tryParse(_minWeightController.text) : null,
        maxWeight: _isWeighted ? double.tryParse(_maxWeightController.text) : null,
        // Campos de facturación electrónica
        taxCode: _taxCodeController.text.trim().isEmpty ? null : _taxCodeController.text.trim(),
        taxRate: double.tryParse(_taxRateController.text) ?? 0.0,
        isExempt: _isExempt,
        productType: _productTypeController.text.trim().isEmpty ? null : _productTypeController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim(),
        countryOfOrigin: _countryOfOriginController.text.trim().isEmpty ? null : _countryOfOriginController.text.trim(),
        customsCode: _customsCodeController.text.trim().isEmpty ? null : _customsCodeController.text.trim(),
        netWeight: double.tryParse(_netWeightController.text),
        grossWeight: double.tryParse(_grossWeightController.text),
        dimensions: _dimensionsController.text.trim().isEmpty ? null : _dimensionsController.text.trim(),
        material: _materialController.text.trim().isEmpty ? null : _materialController.text.trim(),
        warranty: _warrantyController.text.trim().isEmpty ? null : _warrantyController.text.trim(),
        expirationDate: _expirationDateController.text.trim().isEmpty ? null : _expirationDateController.text.trim(),
        isService: _isService,
        serviceCode: _serviceCodeController.text.trim().isEmpty ? null : _serviceCodeController.text.trim(),
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.product == null) {
        await SQLiteDatabaseService.createProduct(product);
        Get.snackbar(
          'Producto creado',
          '${product.name} ha sido creado exitosamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        await SQLiteDatabaseService.updateProduct(product);
        Get.snackbar(
          'Producto actualizado',
          '${product.name} ha sido actualizado exitosamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al guardar producto: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.product == null ? Icons.add : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.product == null ? 'Nuevo Producto' : 'Editar Producto',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            
            // Pestañas
            Container(
              color: Colors.grey.shade100,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                tabs: const [
                  Tab(icon: Icon(Icons.info), text: 'Básico'),
                  Tab(icon: Icon(Icons.scale), text: 'Peso'),
                  Tab(icon: Icon(Icons.receipt), text: 'Facturación'),
                  Tab(icon: Icon(Icons.description), text: 'Detalles'),
                ],
              ),
            ),
            
            // Contenido del formulario
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicTab(),
                    _buildWeightTab(),
                    _buildInvoiceTab(),
                    _buildDetailsTab(),
                  ],
                ),
              ),
            ),
            
            // Botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(widget.product == null ? 'Crear' : 'Actualizar'),
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

  // ✅ NUEVO: Métodos para construir las pestañas del formulario
  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Básica',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
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
                flex: 2,
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
                child: DropdownButtonFormField<ProductCategory>(
                  value: _selectedCategory,
                  items: ProductCategory.values.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(_getCategoryName(category)),
                  )).toList(),
                  onChanged: (category) => setState(() => _selectedCategory = category!),
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
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
                    labelText: 'Costo *',
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
                    labelText: 'Stock Inicial *',
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
                    labelText: 'Stock Mínimo *',
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
          
          // Quinta fila
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sexta fila - Producto pesado
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Producto por Peso'),
                  value: _isWeighted,
                  onChanged: (value) => setState(() => _isWeighted = value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración de Peso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
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
                      if (_isWeighted && (value?.trim().isEmpty ?? true)) {
                        return 'El precio por kg es obligatorio';
                      }
                      if ((value?.isNotEmpty ?? false) && double.tryParse(value!) == null) {
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
                      labelText: 'Peso Actual (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                      labelText: 'Peso Mínimo (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Peso Máximo (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Habilita "Producto por Peso" en la pestaña Básico para configurar los parámetros de peso.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración de Facturación Electrónica',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Tipo de producto
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Es un Servicio'),
                  value: _isService,
                  onChanged: (value) => setState(() => _isService = value!),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Exento de Impuestos'),
                  value: _isExempt,
                  onChanged: (value) => setState(() => _isExempt = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Campos de impuestos
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _taxCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Impuesto',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: IVA, Exento',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Tasa de Impuesto (%)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Campos de producto
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _productTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Producto',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: PRODUCTO, SERVICIO',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _serviceCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Servicio',
                    border: OutlineInputBorder(),
                    hintText: 'Solo para servicios',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Campos de marca y modelo
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Código de barras
          TextFormField(
            controller: _barcodeController,
            decoration: const InputDecoration(
              labelText: 'Código de Barras EAN/UPC',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalles Adicionales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Fabricante y país de origen
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _manufacturerController,
                  decoration: const InputDecoration(
                    labelText: 'Fabricante',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _countryOfOriginController,
                  decoration: const InputDecoration(
                    labelText: 'País de Origen',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Código arancelario
          TextFormField(
            controller: _customsCodeController,
            decoration: const InputDecoration(
              labelText: 'Código Arancelario',
              border: OutlineInputBorder(),
              hintText: 'Código de clasificación arancelaria',
            ),
          ),
          const SizedBox(height: 16),
          
          // Pesos
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _netWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Peso Neto (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _grossWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Peso Bruto (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Dimensiones y material
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dimensionsController,
                  decoration: const InputDecoration(
                    labelText: 'Dimensiones',
                    border: OutlineInputBorder(),
                    hintText: 'Largo x Ancho x Alto',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _materialController,
                  decoration: const InputDecoration(
                    labelText: 'Material',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Garantía y fecha de vencimiento
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _warrantyController,
                  decoration: const InputDecoration(
                    labelText: 'Garantía',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 1 año, 6 meses',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _expirationDateController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Vencimiento',
                    border: OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
              ),
            ],
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
      case ProductCategory.servicios:
        return 'Servicios';
      case ProductCategory.otros:
        return 'Otros';
    }
  }
} 