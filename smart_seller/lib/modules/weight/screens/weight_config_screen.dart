import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/weight_controller.dart';
import '../widgets/scale_widget.dart';
import '../widgets/weight_product_card.dart';
import '../../../models/product.dart';

class WeightConfigScreen extends StatelessWidget {
  const WeightConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final WeightController controller = Get.put(WeightController());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Peso'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          // ✅ NUEVO: Botón para configuración de balanza
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed('/scale-config'),
            tooltip: 'Configurar Balanza',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget de balanza
            ScaleWidget(
              controller: controller,
              showControls: true,
            ),
            
            const SizedBox(height: 24),
            
            // Lista de productos pesados
            _buildProductsList(controller),
            
            const SizedBox(height: 80), // Espacio para FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  Widget _buildProductsList(WeightController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 12),
        
        // Barra de búsqueda
        TextField(
          onChanged: controller.filterProducts,
          decoration: InputDecoration(
            hintText: 'Buscar productos...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Lista de productos
        Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (controller.filteredProducts.isEmpty) {
            return Center(
              child: Column(
                children: [
                  Icon(
                    Icons.scale,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay productos pesados',
                    style: Get.textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega productos que se vendan por peso',
                    style: Get.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.filteredProducts.length,
            itemBuilder: (context, index) {
              final product = controller.filteredProducts[index];
              return Obx(() => WeightProductCard(
                product: product,
                isSelected: controller.selectedProduct.value?.id == product.id,
                onTap: () => controller.selectProduct(product),
                onEdit: () => _showEditProductDialog(context, controller, product),
                onDelete: () => _showDeleteConfirmation(context, controller, product),
              ));
            },
          );
        }),
      ],
    );
  }

  void _showAddProductDialog(BuildContext context, WeightController controller) {
    _showProductDialog(context, controller, null);
  }

  void _showEditProductDialog(BuildContext context, WeightController controller, Product product) {
    _showProductDialog(context, controller, product);
  }

  void _showProductDialog(BuildContext context, WeightController controller, Product? product) {
    final isEdit = product != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: product?.name ?? '');
    final codeController = TextEditingController(text: product?.code ?? '');
    final priceController = TextEditingController(
      text: product?.pricePerKg?.toString() ?? '',
    );
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final minWeightController = TextEditingController(
      text: product?.minWeight?.toString() ?? '',
    );
    final maxWeightController = TextEditingController(
      text: product?.maxWeight?.toString() ?? '',
    );
    
    ProductCategory selectedCategory = product?.category ?? ProductCategory.frutasVerduras;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Editar Producto' : 'Nuevo Producto'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    hintText: 'Ej: Manzanas rojas',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código del producto',
                    hintText: 'Ej: MANZ001',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El código es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Precio por kilogramo',
                    hintText: 'Ej: 8000',
                    prefixText: '\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El precio es requerido';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Precio inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<ProductCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                  ),
                  items: ProductCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedCategory = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Descripción del producto',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: minWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Peso mínimo (kg)',
                          hintText: '0.100',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value) == null) {
                              return 'Peso inválido';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: maxWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Peso máximo (kg)',
                          hintText: '5.000',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value) == null) {
                              return 'Peso inválido';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                final price = double.parse(priceController.text);
                final description = descriptionController.text.trim();
                final minWeight = minWeightController.text.isEmpty 
                    ? null 
                    : double.parse(minWeightController.text);
                final maxWeight = maxWeightController.text.isEmpty 
                    ? null 
                    : double.parse(maxWeightController.text);
                
                Navigator.of(context).pop();
                
                if (isEdit) {
                  final updatedProduct = product!.copyWith(
                    name: name,
                    code: code,
                    pricePerKg: price,
                    category: selectedCategory,
                    description: description,
                    minWeight: minWeight,
                    maxWeight: maxWeight,
                    updatedAt: DateTime.now(),
                  );
                  await controller.updateWeightProduct(updatedProduct);
                } else {
                  await controller.createWeightProduct(
                    name: name,
                    code: code,
                    pricePerKg: price,
                    category: selectedCategory,
                    description: description,
                    minWeight: minWeight,
                    maxWeight: maxWeight,
                  );
                }
              }
            },
            child: Text(isEdit ? 'Actualizar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WeightController controller, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (product.id != null) {
                await controller.deleteWeightProduct(product.id!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
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