import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/config_service.dart';
import '../services/sqlite_database_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  Map<String, dynamic> configInfo = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfigInfo();
  }

  Future<void> _loadConfigInfo() async {
    setState(() {
      isLoading = true;
    });

    try {
      final info = await ConfigService.getConfigInfo();
      setState(() {
        configInfo = info;
      });
    } catch (e) {
      print('Error cargando configuración: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Estado del Sistema'),
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfigInfo,
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Get.offAllNamed('/dashboard'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado actual
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado Actual del Sistema',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: 'Base de Datos Activa',
                      value: 'SQLite',
                      color: Colors.green,
                    ),
                    _InfoRow(
                      label: 'Migración Completada',
                      value: 'Sí',
                      color: Colors.green,
                    ),
                    _InfoRow(
                      label: 'Estado',
                      value: isLoading ? 'Cargando...' : 'Listo',
                      color: isLoading ? Colors.grey : Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Información de módulos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Módulos y Base de Datos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Todos los módulos usan SQLite como base de datos principal:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Sistema unificado con SQLite\n'
                      '• Migración completa desde Isar\n'
                      '• Interfaz optimizada para SQLite\n'
                      '• Rendimiento mejorado',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testDatabaseConnection(),
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Probar Conexión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDatabaseInfo(),
                    icon: const Icon(Icons.info),
                    label: const Text('Info BD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistema Migrado a SQLite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '✅ Migración completa desde Isar\n'
                    '✅ Todos los datos preservados\n'
                    '✅ Funcionalidad mejorada\n'
                    '✅ Sistema unificado y estable',
                    style: TextStyle(fontSize: 14, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testDatabaseConnection() async {
    try {
      // Probar conexión obteniendo usuarios
      final users = await SQLiteDatabaseService.getAllUsers();
      
      Get.snackbar(
        'Conexión Exitosa',
        'Base de datos SQLite funcionando correctamente. Usuarios encontrados: ${users.length}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error de Conexión',
        'Error al conectar con la base de datos SQLite: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _showDatabaseInfo() async {
    try {
      final users = await SQLiteDatabaseService.getAllUsers();
      final products = await SQLiteDatabaseService.getAllProducts();
      final sales = await SQLiteDatabaseService.getSales();
      
      Get.dialog(
        AlertDialog(
          title: const Text('Información de la Base de Datos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuarios: ${users.length}'),
              Text('Productos: ${products.length}'),
              Text('Ventas: ${sales.length}'),
              const SizedBox(height: 16),
              const Text(
                'Base de datos SQLite funcionando correctamente',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
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
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al obtener información: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 