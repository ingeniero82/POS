import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/scale_service.dart';
import '../services/aclas_os2x_service.dart';
import '../widgets/scale_status_widget.dart';

class ScaleConfigScreen extends StatefulWidget {
  const ScaleConfigScreen({Key? key}) : super(key: key);

  @override
  State<ScaleConfigScreen> createState() => _ScaleConfigScreenState();
}

class _ScaleConfigScreenState extends State<ScaleConfigScreen> {
  final ScaleService _scaleService = Get.find<ScaleService>();
  final AclasOS2XService _aclasService = AclasOS2XService();
  
  // Estados reactivos
  var isConnected = false.obs;
  var isReading = false.obs;
  var currentWeight = 0.0.obs;
  var availablePorts = <String>[].obs;
  var isLoading = false.obs;
  var connectionStatus = 'Desconectado'.obs;
  
  // Configuración
  var selectedPort = 'COM3'.obs;
  var baudRate = 9600.obs;
  var dataBits = 8.obs;
  var parity = 'None'.obs;
  var stopBits = 1.obs;
  
  @override
  void initState() {
    super.initState();
    _setupStreams();
    _loadAvailablePorts();
  }
  
  void _setupStreams() {
    // Escuchar cambios de peso
    _scaleService.weightStream.listen((weight) {
      currentWeight.value = weight;
    });
    
    // Escuchar cambios de conexión
    _scaleService.connectionStream.listen((connected) {
      isConnected.value = connected;
      connectionStatus.value = connected ? 'Conectado' : 'Desconectado';
    });
    
    // Estado inicial
    isConnected.value = _scaleService.isConnected;
    isReading.value = _scaleService.isReading;
    currentWeight.value = _scaleService.currentWeight;
  }
  
  Future<void> _loadAvailablePorts() async {
    isLoading.value = true;
    try {
      // Simular puertos disponibles (en producción usar detección real)
      availablePorts.value = ['COM1', 'COM2', 'COM3', 'COM4', 'COM5'];
    } catch (e) {
      Get.snackbar('Error', 'Error cargando puertos: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _testConnection() async {
    try {
      isLoading.value = true;
      connectionStatus.value = 'Probando conexión...';
      
      final connected = await _aclasService.connect();
      
      if (connected) {
        Get.snackbar(
          'Éxito', 
          'Conexión exitosa con la balanza',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        connectionStatus.value = 'Conectado';
      } else {
        Get.snackbar(
          'Error', 
          'No se pudo conectar a la balanza',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        connectionStatus.value = 'Error de conexión';
      }
    } catch (e) {
      Get.snackbar('Error', 'Error probando conexión: $e');
      connectionStatus.value = 'Error';
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _connectToScale() async {
    try {
      isLoading.value = true;
      connectionStatus.value = 'Conectando...';
      
      final connected = await _scaleService.connect(
        port: selectedPort.value,
        baudRate: baudRate.value,
      );
      
      if (connected) {
        Get.snackbar(
          'Éxito', 
          'Balanza conectada exitosamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        connectionStatus.value = 'Conectado';
      } else {
        Get.snackbar(
          'Error', 
          'No se pudo conectar a la balanza',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        connectionStatus.value = 'Error de conexión';
      }
    } catch (e) {
      Get.snackbar('Error', 'Error conectando: $e');
      connectionStatus.value = 'Error';
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> _disconnectScale() async {
    try {
      await _scaleService.disconnect();
      Get.snackbar('Info', 'Balanza desconectada');
      connectionStatus.value = 'Desconectado';
    } catch (e) {
      Get.snackbar('Error', 'Error desconectando: $e');
    }
  }
  
  Future<void> _startReading() async {
    try {
      await _scaleService.startReading();
      isReading.value = true;
      Get.snackbar('Info', 'Lectura de peso iniciada');
    } catch (e) {
      Get.snackbar('Error', 'Error iniciando lectura: $e');
    }
  }
  
  Future<void> _stopReading() async {
    try {
      await _scaleService.stopReading();
      isReading.value = false;
      Get.snackbar('Info', 'Lectura de peso detenida');
    } catch (e) {
      Get.snackbar('Error', 'Error deteniendo lectura: $e');
    }
  }
  
  Future<void> _tareScale() async {
    try {
      final success = await _scaleService.tare();
      if (success) {
        Get.snackbar('Éxito', 'Balanza tarada correctamente');
      } else {
        Get.snackbar('Error', 'Error tarando balanza');
      }
    } catch (e) {
      Get.snackbar('Error', 'Error tarando: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Balanza'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget de estado de balanza
            ScaleStatusWidget(
              scaleService: _scaleService,
              showControls: true,
              onConnect: _connectToScale,
              onDisconnect: _disconnectScale,
              onTare: _tareScale,
              onStartReading: _startReading,
              onStopReading: _stopReading,
            ),
            
            const SizedBox(height: 16),
            
            // Configuración de puerto
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de Puerto',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    // Puerto
                    Row(
                      children: [
                        const Text('Puerto: '),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Obx(() => DropdownButton<String>(
                            value: selectedPort.value,
                            isExpanded: true,
                            items: availablePorts.map((port) {
                              return DropdownMenuItem(
                                value: port,
                                child: Text(port),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) selectedPort.value = value;
                            },
                          )),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Baud Rate
                    Row(
                      children: [
                        const Text('Baud Rate: '),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Obx(() => DropdownButton<int>(
                            value: baudRate.value,
                            isExpanded: true,
                            items: [9600, 19200, 38400, 57600, 115200].map((rate) {
                              return DropdownMenuItem(
                                value: rate,
                                child: Text(rate.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) baudRate.value = value;
                            },
                          )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botones de control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() => ElevatedButton(
                            onPressed: isLoading.value ? null : _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: isLoading.value 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Probar Conexión'),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Obx(() => ElevatedButton(
                            onPressed: isLoading.value ? null : (isConnected.value ? _disconnectScale : _connectToScale),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isConnected.value ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isConnected.value ? 'Desconectar' : 'Conectar'),
                          )),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() => ElevatedButton(
                            onPressed: !isConnected.value ? null : (isReading.value ? _stopReading : _startReading),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReading.value ? Colors.red : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isReading.value ? 'Detener Lectura' : 'Iniciar Lectura'),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Obx(() => ElevatedButton(
                            onPressed: !isConnected.value ? null : _tareScale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Tarar Balanza'),
                          )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Información adicional
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• La balanza debe estar conectada al puerto COM configurado\n'
                      '• Asegúrate de que no haya otros programas usando el puerto\n'
                      '• Si la conexión falla, prueba con diferentes puertos COM\n'
                      '• La balanza debe estar encendida y en modo de transmisión',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 