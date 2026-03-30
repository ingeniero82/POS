import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/product.dart';
import '../models/group.dart';
import '../services/sqlite_database_service.dart';
import '../services/import_service.dart';
import '../widgets/product_form_dialog.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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
        
        // Comparación de grupos dinámicos
        final matchesGroup = _selectedGroup == null || 
            product.category == _selectedGroup!.name;
        
        return matchesSearch && matchesGroup;
      }).toList();
    });
  }
  


  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => const ProductFormDialog(),
    ).then((_) async {
      // Recargar productos y aplicar filtro actual
      await _loadProducts();
      _filterProducts(); // Aplicar filtro actual después de recargar
    });
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductFormDialog(product: product),
    ).then((_) async {
      // Recargar productos y aplicar filtro actual
      await _loadProducts();
      _filterProducts(); // Aplicar filtro actual después de recargar
    });
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
            child: const Text('Eliminar'),
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

  Future<void> _importFromExcel() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Importar productos desde archivo
      final products = await ImportService.importProductsFromFile();
      
      if (products.isEmpty) {
        Get.snackbar(
          'Información',
          'No se encontraron productos válidos en el archivo',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Guardar productos importados
      await ImportService.saveImportedProducts(products);
      
      Get.snackbar(
        'Éxito',
        '${products.length} productos importados correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Recargar productos
      _loadProducts();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al importar productos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Seleccionar ubicación para guardar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar inventario como Excel',
        fileName: 'inventario_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        Get.snackbar(
          'Información',
          'Operación cancelada',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Exportar productos con formato Excel real (.xlsx)
      await ImportService.exportProductsToExcel(_products, outputFile);
      
      Get.snackbar(
        'Éxito',
        'Inventario exportado correctamente como archivo Excel (.xlsx)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al exportar inventario: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          // Header con acciones
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) => _filterProducts(),
                  ),
                ),
                const SizedBox(width: 16),
                // Botón Importar Excel
                ElevatedButton.icon(
                  onPressed: _importFromExcel,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Importar Excel', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón Exportar Excel
                ElevatedButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Exportar Excel', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Filtrar por grupo: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<Group?>(
                  value: _selectedGroup,
                  hint: const Text('Todos los grupos'),
                  items: [
                    const DropdownMenuItem<Group?>(
                      value: null,
                      child: Text('Todos los grupos'),
                    ),
                    ..._groups.map((group) => DropdownMenuItem<Group?>(
                      value: group,
                      child: Text(group.name),
                    )),
                  ],
                  onChanged: (Group? value) {
                    setState(() {
                      _selectedGroup = value;
                    });
                    _filterProducts();
                  },
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No hay productos',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Agrega tu primer producto usando el botón "Nuevo Producto"',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
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
                          backgroundColor: _getGroupColor(product.category),
          child: Icon(
                  _getGroupIcon(product.category),
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
            Text(
              product.isWeighted && product.weightedStockInKg
                  ? 'Stock:  ${product.stockKg} kg'
                  : 'Stock:  ${product.stock} ${product.unit}',
            ),
            if (product.isLowStock)
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

  Color _getGroupColor(String category) {
    // Colores predefinidos para grupos
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    
    // Usar el hash de la categoría para asignar un color consistente
    final index = category.hashCode % colors.length;
    return colors[index];
  }
  
  IconData _getGroupIcon(String category) {
    // Iconos predefinidos para grupos
    final lowerName = category.toLowerCase();
    
    if (lowerName.contains('fruta') || lowerName.contains('verdura')) {
        return Icons.apple;
    } else if (lowerName.contains('lácteo') || lowerName.contains('lacteo')) {
        return Icons.local_drink;
    } else if (lowerName.contains('pan') || lowerName.contains('panadería')) {
        return Icons.bakery_dining;
    } else if (lowerName.contains('carne')) {
        return Icons.set_meal;
    } else if (lowerName.contains('bebida')) {
        return Icons.local_bar;
    } else if (lowerName.contains('abarrote')) {
        return Icons.inventory;
    } else if (lowerName.contains('limpieza')) {
        return Icons.cleaning_services;
    } else if (lowerName.contains('cuidado')) {
        return Icons.person;
    } else {
        return Icons.category;
    }
  }
} 