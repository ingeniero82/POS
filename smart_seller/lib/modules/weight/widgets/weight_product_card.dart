import 'package:flutter/material.dart';
import '../../../models/product.dart';

class WeightProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;
  final bool showActions;

  const WeightProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected ? Colors.orange.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con nombre y código
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.orange.shade700 : null,
                          ),
                        ),
                        Text(
                          'Código: ${product.code}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Indicador de producto pesado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.scale,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pesado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Información de precios
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Precio por kg:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '\$${(product.pricePerKg ?? 0).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (product.weight != null && product.weight! > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Peso actual:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${product.weight!.toStringAsFixed(3)} kg',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Precio total:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '\$${product.calculatedPrice.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Límites de peso
              if (product.minWeight != null || product.maxWeight != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Límites: ${product.minWeight?.toStringAsFixed(3) ?? '0.000'} - ${product.maxWeight?.toStringAsFixed(3) ?? '∞'} kg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Categoría
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildCategoryChip(context),
                  if (product.isActive)
                    _buildActiveChip(context)
                  else
                    _buildInactiveChip(context),
                ],
              ),
              
              // Acciones
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Eliminar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCategoryColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getCategoryColor()),
      ),
      child: Text(
        _getCategoryName(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _getCategoryColor(),
        ),
      ),
    );
  }

  Widget _buildActiveChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Text(
        'Activo',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildInactiveChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(
        'Inactivo',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (product.category) {
      case ProductCategory.frutasVerduras:
        return Colors.green;
      case ProductCategory.carnes:
        return Colors.red;
      case ProductCategory.lacteos:
        return Colors.blue;
      case ProductCategory.panaderia:
        return Colors.orange;
      case ProductCategory.bebidas:
        return Colors.cyan;
      case ProductCategory.abarrotes:
        return Colors.brown;
      case ProductCategory.limpieza:
        return Colors.purple;
      case ProductCategory.cuidadoPersonal:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryName() {
    switch (product.category) {
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