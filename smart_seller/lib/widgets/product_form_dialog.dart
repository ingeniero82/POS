import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/product.dart';
import '../models/group.dart';
import '../services/sqlite_database_service.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  
  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> with SingleTickerProviderStateMixin {
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
  
  String? _selectedGroup;
  List<Group> _availableGroups = [];
  bool _isActive = true;
  bool _isWeighted = false;
  bool _isLoading = false;
  
  // Controlador para las pestañas
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _groupController.text = _selectedGroup ?? '';
      _isActive = widget.product!.isActive;
      
      // Campos para productos pesados
      _isWeighted = widget.product!.isWeighted;
      _pricePerKgController.text = widget.product!.pricePerKg?.toString() ?? '';
      _weightController.text = widget.product!.weight?.toString() ?? '';
      _minWeightController.text = widget.product!.minWeight?.toString() ?? '';
      _maxWeightController.text = widget.product!.maxWeight?.toString() ?? '';
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        category: _getCategoryFromName(_selectedGroup ?? 'Otros'),
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
                _selectedGroup = null;
                _groupController.text = '';
                _isActive = true;
                _isWeighted = false;
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
        Get.snackbar(
          'Éxito',
          'Producto actualizado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        Get.back();
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                        : Text(widget.product == null ? 'Crear Producto' : 'Actualizar'),
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
                    labelText: 'Código Corto *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: PROD001',
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
                        value: _selectedGroup,
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
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGroup = value;
                          });
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
                  controller: _groupController, // Usamos el mismo controlador para marca
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
            ],
          ),
          const SizedBox(height: 16),
          
          // Cuarta fila - Precio de Costo
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: 'Precio de Costo',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Container()), // Espacio vacío para mantener el layout
            ],
          ),
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
              const SizedBox(width: 32),
              Checkbox(
                value: _isWeighted,
                onChanged: (value) {
                  setState(() {
                    _isWeighted = value ?? false;
                  });
                },
              ),
              const Text('Producto pesado (se vende por peso)'),
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
                    DropdownMenuItem(value: 'EXCLUIDO', child: Text('Excluido')),
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
                  ),
                  items: const [
                    DropdownMenuItem(value: '19', child: Text('19%')),
                    DropdownMenuItem(value: '5', child: Text('5%')),
                    DropdownMenuItem(value: '0', child: Text('0% (Exento)')),
                    DropdownMenuItem(value: 'EXCLUIDO', child: Text('Excluido')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
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
                    DropdownMenuItem(value: 'SERVICIO', child: Text('Servicio')),
                    DropdownMenuItem(value: 'PESADO', child: Text('Pesado (Báscula)')),
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
                    DropdownMenuItem(value: 'kilogramo', child: Text('Kilogramo')),
                    DropdownMenuItem(value: 'litro', child: Text('Litro')),
                    DropdownMenuItem(value: 'paquete', child: Text('Paquete')),
                    DropdownMenuItem(value: 'metro', child: Text('Metro')),
                    DropdownMenuItem(value: 'gramo', child: Text('Gramo')),
                    DropdownMenuItem(value: 'centimetro', child: Text('Centímetro')),
                    DropdownMenuItem(value: 'mililitro', child: Text('Mililitro')),
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
                    DropdownMenuItem(value: 'NINGUNO', child: Text('Sin impuestos adicionales')),
                    DropdownMenuItem(value: 'IMPUESTO_BOLSA', child: Text('Impuesto Bolsa')),
                    DropdownMenuItem(value: 'RETEFUENTE_2_5', child: Text('Retefuente 2.5%')),
                    DropdownMenuItem(value: 'RETEIVA_15', child: Text('ReteIVA 15%')),
                    DropdownMenuItem(value: 'IMPUESTO_CONSUMO', child: Text('Impuesto al Consumo')),
                  ],
                  onChanged: (value) {
                    // TODO: Implementar lógica
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
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
    return const Center(
      child: Text(
        'Configuración de Inventario\n\nPróximamente...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
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