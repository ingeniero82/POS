import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/weight_controller.dart';
import '../widgets/scale_widget.dart';
import '../widgets/weight_product_card.dart';
import '../../../models/product.dart';

class WeightProductsScreen extends StatelessWidget {
  const WeightProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final WeightController controller = Get.put(WeightController());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos por Peso'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed('/peso/configuracion'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Row(
        children: [
          // Panel izquierdo - Lista de productos
          Expanded(
            flex: 2,
            child: _buildProductsList(controller),
          ),
          
          // Panel derecho - Balanza
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Widget de balanza
                  ScaleWidget(
                    controller: controller,
                    showControls: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Información adicional
                  _buildInfoPanel(controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(WeightController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productos Pesados',
                style: Get.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Obx(() => Text(
                '${controller.filteredProducts.length} productos',
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          // Barra de búsqueda
          TextField(
            onChanged: controller.filterProducts,
            decoration: InputDecoration(
              hintText: 'Buscar productos por nombre o código...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(controller),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Lista de productos
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (controller.filteredProducts.isEmpty) {
                return _buildEmptyState();
              }
              
              return ListView.builder(
                itemCount: controller.filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = controller.filteredProducts[index];
                  return Obx(() => WeightProductCard(
                    product: product,
                    isSelected: controller.selectedProduct.value?.id == product.id,
                    onTap: () => controller.selectProduct(product),
                    showActions: false, // Sin acciones de edición en esta pantalla
                  ));
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scale,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos pesados',
            style: Get.textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ve a la configuración para crear productos por peso',
            style: Get.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/peso/configuracion'),
            icon: const Icon(Icons.settings),
            label: const Text('Ir a Configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(WeightController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Estadísticas
            _buildStatItem(
              'Productos Pesados',
              controller.products.length.toString(),
              Icons.scale,
              Colors.blue,
            ),
            
            Obx(() => _buildStatItem(
              'Peso Actual',
              controller.formatWeight(controller.currentWeight.value),
              Icons.line_weight,
              Colors.green,
            )),
            
            Obx(() => _buildStatItem(
              'Estado Balanza',
              controller.isConnected.value ? 'Conectada' : 'Desconectada',
              controller.isConnected.value ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              controller.isConnected.value ? Colors.green : Colors.red,
            )),
            
            const SizedBox(height: 16),
            
            // Instrucciones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Instrucciones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Selecciona un producto de la lista\n'
                    '2. Coloca el item en la balanza\n'
                    '3. Verifica el peso y precio\n'
                    '4. Haz clic en "Agregar"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Get.textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Get.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(WeightController controller) {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Productos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filtrar por categoría:'),
            const SizedBox(height: 8),
            // Aquí puedes agregar filtros por categoría
            Wrap(
              spacing: 8,
              children: ProductCategory.values.map((category) {
                return FilterChip(
                  label: Text(_getCategoryName(category)),
                  selected: false, // Implementar lógica de selección
                  onSelected: (selected) {
                    // Implementar filtrado por categoría
                  },
                );
              }).toList(),
            ),
          ],
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

  String _getCategoryName(ProductCategory category) {
    switch (category) {
      case ProductCategory.frutasVerduras:
        return 'Frutas y Verduras';
      case ProductCategory.carnes:
        return 'Carnes';
      case ProductCategory.lacteos:
        return 'Lácteos';
      case ProductCategory.panaderia:
        return 'Panadería';
      case ProductCategory.bebidas:
        return 'Bebidas';
      case ProductCategory.abarrotes:
        return 'Abarrotes';
      case ProductCategory.limpieza:
        return 'Limpieza';
      case ProductCategory.cuidadoPersonal:
        return 'Cuidado Personal';
      default:
        return 'Otros';
    }
  }
} 