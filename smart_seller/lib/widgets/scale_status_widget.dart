import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/scale_service.dart';

class ScaleStatusWidget extends StatelessWidget {
  final ScaleService scaleService;
  final bool showControls;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onTare;
  final VoidCallback? onStartReading;
  final VoidCallback? onStopReading;

  const ScaleStatusWidget({
    Key? key,
    required this.scaleService,
    this.showControls = true,
    this.onConnect,
    this.onDisconnect,
    this.onTare,
    this.onStartReading,
    this.onStopReading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y estado
            Row(
              children: [
                Icon(
                  Icons.scale,
                  size: 28,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de Balanza',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Obx(() => Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scaleService.isConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            scaleService.isConnected ? 'Conectado' : 'Desconectado',
                            style: TextStyle(
                              color: scaleService.isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Peso actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Peso Actual',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => Text(
                    scaleService.formatWeight(scaleService.currentWeight),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  )),
                ],
              ),
            ),
            
            if (showControls) ...[
              const SizedBox(height: 20),
              
              // Controles
              Row(
                children: [
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: scaleService.isConnected ? onDisconnect : onConnect,
                      icon: Icon(scaleService.isConnected ? Icons.link_off : Icons.link),
                      label: Text(scaleService.isConnected ? 'Desconectar' : 'Conectar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scaleService.isConnected ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: !scaleService.isConnected ? null : onTare,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tarar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: !scaleService.isConnected ? null : 
                        (scaleService.isReading ? onStopReading : onStartReading),
                      icon: Icon(scaleService.isReading ? Icons.stop : Icons.play_arrow),
                      label: Text(scaleService.isReading ? 'Detener' : 'Iniciar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scaleService.isReading ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() => Column(
                    children: [
                      _buildInfoRow('Puerto', scaleService.isConnected ? 'COM3' : 'No conectado'),
                      _buildInfoRow('Baud Rate', '9600'),
                      _buildInfoRow('Protocolo', 'Aclas OS2X'),
                      _buildInfoRow('Lectura', scaleService.isReading ? 'Activa' : 'Inactiva'),
                    ],
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 