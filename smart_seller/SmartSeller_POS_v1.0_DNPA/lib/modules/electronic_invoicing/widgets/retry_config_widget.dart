import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/pending_invoice_queue_controller.dart';
import '../models/pending_invoice_queue.dart';

class RetryConfigWidget extends StatefulWidget {
  final PendingInvoiceQueueController controller;

  const RetryConfigWidget({
    super.key,
    required this.controller,
  });

  @override
  State<RetryConfigWidget> createState() => _RetryConfigWidgetState();
}

class _RetryConfigWidgetState extends State<RetryConfigWidget> {
  late int _maxRetries;
  late int _initialDelayMinutes;
  late int _maxDelayHours;
  late double _backoffMultiplier;
  late bool _exponentialBackoff;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  // ✅ Cargar configuración actual
  void _loadCurrentConfig() {
    final config = widget.controller.retryConfig;
    if (config != null) {
      _maxRetries = config.maxRetries;
      _initialDelayMinutes = config.initialDelay.inMinutes;
      _maxDelayHours = config.maxDelay.inHours;
      _backoffMultiplier = config.backoffMultiplier;
      _exponentialBackoff = config.exponentialBackoff;
    } else {
      // ✅ Valores por defecto
      _maxRetries = 3;
      _initialDelayMinutes = 1;
      _maxDelayHours = 24;
      _backoffMultiplier = 2.0;
      _exponentialBackoff = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.settings,
            color: Get.theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Configuración de Reintentos'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Máximo número de reintentos
            Text(
              'Máximo de Reintentos',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxRetries.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: _maxRetries.toString(),
              onChanged: (value) {
                setState(() {
                  _maxRetries = value.round();
                });
              },
            ),
            Text(
              '$_maxRetries reintentos máximo',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ✅ Delay inicial
            Text(
              'Delay Inicial (minutos)',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _initialDelayMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '${_initialDelayMinutes}min',
              onChanged: (value) {
                setState(() {
                  _initialDelayMinutes = value.round();
                });
              },
            ),
            Text(
              '${_initialDelayMinutes} minuto(s)',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ✅ Delay máximo
            Text(
              'Delay Máximo (horas)',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxDelayHours.toDouble(),
              min: 1,
              max: 168, // 1 semana
              divisions: 167,
              label: '${_maxDelayHours}h',
              onChanged: (value) {
                setState(() {
                  _maxDelayHours = value.round();
                });
              },
            ),
            Text(
              '${_maxDelayHours} hora(s)',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ✅ Multiplicador de backoff
            Text(
              'Multiplicador de Backoff',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _backoffMultiplier,
              min: 1.0,
              max: 5.0,
              divisions: 40,
              label: _backoffMultiplier.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _backoffMultiplier = value;
                });
              },
            ),
            Text(
              '${_backoffMultiplier.toStringAsFixed(1)}x',
              style: Get.textTheme.bodySmall?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ✅ Backoff exponencial
            Row(
              children: [
                Checkbox(
                  value: _exponentialBackoff,
                  onChanged: (value) {
                    setState(() {
                      _exponentialBackoff = value ?? true;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backoff Exponencial',
                    style: Get.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // ✅ Configuraciones predefinidas
            Text(
              'Configuraciones Predefinidas',
              style: Get.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _loadPresetConfig(RetryConfig.defaultConfig),
                    child: const Text('Por Defecto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _loadPresetConfig(RetryConfig.aggressiveConfig),
                    child: const Text('Agresiva'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _loadPresetConfig(RetryConfig.conservativeConfig),
                    child: const Text('Conservadora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // ✅ Información de la configuración
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Get.theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Get.theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de la Configuración',
                    style: Get.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Máximo de reintentos: $_maxRetries\n'
                    '• Delay inicial: ${_initialDelayMinutes} minuto(s)\n'
                    '• Delay máximo: ${_maxDelayHours} hora(s)\n'
                    '• Multiplicador: ${_backoffMultiplier.toStringAsFixed(1)}x\n'
                    '• Backoff exponencial: ${_exponentialBackoff ? 'Sí' : 'No'}',
                    style: Get.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saveConfig,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  // ✅ Cargar configuración predefinida
  void _loadPresetConfig(RetryConfig config) {
    setState(() {
      _maxRetries = config.maxRetries;
      _initialDelayMinutes = config.initialDelay.inMinutes;
      _maxDelayHours = config.maxDelay.inHours;
      _backoffMultiplier = config.backoffMultiplier;
      _exponentialBackoff = config.exponentialBackoff;
    });
  }

  // ✅ Guardar configuración
  void _saveConfig() {
    final newConfig = RetryConfig(
      maxRetries: _maxRetries,
      initialDelay: Duration(minutes: _initialDelayMinutes),
      maxDelay: Duration(hours: _maxDelayHours),
      backoffMultiplier: _backoffMultiplier,
      exponentialBackoff: _exponentialBackoff,
    );
    
    widget.controller.updateRetryConfig(newConfig);
    Navigator.of(context).pop();
  }
}
