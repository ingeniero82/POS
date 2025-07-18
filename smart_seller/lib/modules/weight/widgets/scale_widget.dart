import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/weight_controller.dart';

class ScaleWidget extends StatelessWidget {
  final WeightController controller;
  final bool showControls;
  final bool compact;

  const ScaleWidget({
    super.key,
    required this.controller,
    this.showControls = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título y estado de conexión
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balanza',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: controller.isConnected.value ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.isConnected.value ? 'Conectada' : 'Desconectada',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lectura de peso principal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    'Peso Actual',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => Text(
                    controller.formatWeight(controller.currentWeight.value),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: controller.isConnected.value ? Colors.green : Colors.grey,
                    ),
                  )),
                  const SizedBox(height: 8),
                  // Indicador de lectura
                  Obx(() => Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: controller.isReading.value ? Colors.blue : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: controller.isReading.value
                        ? const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          )
                        : null,
                  )),
                ],
              ),
            ),
            
            if (showControls) ...[
              const SizedBox(height: 16),
              _buildControlButtons(),
            ],
            
            // Información del producto seleccionado
            Obx(() {
              final product = controller.selectedProduct.value;
              if (product != null) {
                return Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Producto Seleccionado',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Precio/kg: ${controller.formatPrice(product.pricePerKg ?? 0)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'Total: ${controller.formatPrice(controller.calculatedPrice)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Botón Conectar/Desconectar
        Obx(() => ElevatedButton.icon(
          onPressed: controller.isConnected.value 
              ? controller.disconnectScale
              : controller.connectScale,
          icon: Icon(controller.isConnected.value 
              ? Icons.bluetooth_connected 
              : Icons.bluetooth_disabled),
          label: Text(controller.isConnected.value ? 'Desconectar' : 'Conectar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isConnected.value ? Colors.red : Colors.blue,
            foregroundColor: Colors.white,
          ),
        )),
        
        // Botón Iniciar/Detener lectura
        Obx(() => ElevatedButton.icon(
          onPressed: controller.isConnected.value
              ? (controller.isReading.value 
                  ? controller.stopReading 
                  : controller.startReading)
              : null,
          icon: Icon(controller.isReading.value ? Icons.pause : Icons.play_arrow),
          label: Text(controller.isReading.value ? 'Detener' : 'Iniciar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isReading.value ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
        )),
        
        // Botón Tare
        Obx(() => ElevatedButton.icon(
          onPressed: controller.isConnected.value ? controller.tare : null,
          icon: const Icon(Icons.horizontal_rule),
          label: const Text('Tare'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
        )),
        
        // Botón Agregar al carrito
        Obx(() => ElevatedButton.icon(
          onPressed: controller.selectedProduct.value != null && 
                    controller.currentWeight.value > 0
              ? controller.addToCart
              : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Agregar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        )),
      ],
    );
  }
} 