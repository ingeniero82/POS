import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:libserialport/libserialport.dart';

class ScaleService {
  static const MethodChannel _channel = MethodChannel('scale_channel');
  
  // Estados de la balanza
  bool _isConnected = false;
  bool _isReading = false;
  double _currentWeight = 0.0;
  String _unit = 'kg';
  
  // Streams para notificar cambios
  final StreamController<double> _weightController = StreamController<double>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isReading => _isReading;
  double get currentWeight => _currentWeight;
  String get unit => _unit;
  Stream<double> get weightStream => _weightController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Configuración de la balanza
  String _port = '';
  int _baudRate = 9600;
  String _protocol = 'aclas'; // Específico para Aclas OS2X
  
  // Comunicación serie real
  SerialPort? _serialPort;
  SerialPortReader? _reader;
  Timer? _readTimer;
  
  // Inicializar el servicio
  Future<void> initialize() async {
    try {
      print('🔧 Inicializando ScaleService...');
      
      // Configurar el canal de método
      _channel.setMethodCallHandler(_handleMethodCall);
      print('✅ Canal de método configurado');
      
      // Conectar automáticamente a la balanza Aclas OS2X
      await _connectToAclasOS2X();
      
      // Si no se pudo conectar, usar simulación temporal
      if (!_isConnected) {
        print('⚠️ No se pudo conectar a balanza real, usando simulación temporal...');
        await _simulateConnectionForTesting();
      }
      print('✅ ScaleService inicializado');
    } catch (e) {
      print('❌ Error inicializando ScaleService: $e');
    }
  }
  
  // Conectar automáticamente a la balanza Aclas OS2X
  Future<void> _connectToAclasOS2X() async {
    try {
      print('🔍 Buscando balanza Aclas OS2X...');
      
      // Buscar puertos COM disponibles
      final availablePorts = SerialPort.availablePorts;
      print('📋 Puertos disponibles: $availablePorts');
      
      if (availablePorts.isEmpty) {
        print('❌ No se encontraron puertos COM');
        return;
      }
      
      // Intentar conectar a cada puerto
      for (final portName in availablePorts) {
        if (await _tryConnectToPort(portName)) {
          print('✅ Conectado a balanza Aclas OS2X en puerto $portName');
          return;
        }
      }
      
      print('❌ No se pudo conectar a ninguna balanza Aclas OS2X');
    } catch (e) {
      print('❌ Error buscando balanza: $e');
    }
  }
  
  // Intentar conectar a un puerto específico
  Future<bool> _tryConnectToPort(String portName) async {
    try {
      print('🔌 Probando puerto: $portName');
      
      final port = SerialPort(portName);
      
      // Configurar puerto para Aclas OS2X
      final config = SerialPortConfig();
      config.baudRate = _baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      
      port.config = config;
      
      // Intentar abrir el puerto
      if (!port.openReadWrite()) {
        print('❌ No se pudo abrir puerto $portName');
        port.dispose();
        return false;
      }
      
      // Probar comunicación con comando específico de Aclas
      if (await _testAclasCommunication(port)) {
        _serialPort = port;
        _port = portName;
        _isConnected = true;
        _connectionController.add(true);
        
        // Configurar lector
        _reader = SerialPortReader(port);
        
        return true;
      } else {
        print('❌ Puerto $portName no responde como Aclas OS2X');
        port.close();
        port.dispose();
        return false;
      }
    } catch (e) {
      print('❌ Error probando puerto $portName: $e');
      return false;
    }
  }
  
  // Probar comunicación específica con Aclas OS2X
  Future<bool> _testAclasCommunication(SerialPort port) async {
    try {
      // Comando específico para Aclas OS2X
      final command = 'W\r\n';
      final commandBytes = Uint8List.fromList(command.codeUnits);
      
      // Enviar comando
      port.write(commandBytes);
      
      // Esperar respuesta
      await Future.delayed(const Duration(milliseconds: 500));
      
             // Leer respuesta
       final reader = SerialPortReader(port);
       final List<int> responseBytes = [];
       
       await reader.stream.timeout(
         const Duration(seconds: 2),
         onTimeout: (sink) => sink.close(),
       ).take(1).forEach((data) {
         responseBytes.addAll(data);
       });
      
             if (responseBytes.isNotEmpty) {
         final responseStr = String.fromCharCodes(responseBytes);
         print('📡 Respuesta de ${port.name}: $responseStr');
         
         // Verificar si es respuesta válida de Aclas OS2X
         return responseStr.contains('ST,') || 
                responseStr.contains('kg') || 
                responseStr.contains('GS,') ||
                responseStr.contains('lb');
       }
      
      return false;
    } catch (e) {
      print('❌ Error probando comunicación con $port.name: $e');
      return false;
    }
  }
  
  // Método temporal para simular conexión (backup)
  Future<void> _simulateConnectionForTesting() async {
    try {
      print('🔌 Simulación temporal activada...');
      await Future.delayed(const Duration(milliseconds: 500));
      _isConnected = true;
      _connectionController.add(true);
      print('✅ Simulación temporal conectada');
    } catch (e) {
      print('❌ Error en simulación temporal: $e');
    }
  }
  
  // Manejar llamadas del método nativo
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWeightChanged':
        _currentWeight = call.arguments['weight'] ?? 0.0;
        _unit = call.arguments['unit'] ?? 'kg';
        _weightController.add(_currentWeight);
        break;
      case 'onConnectionChanged':
        _isConnected = call.arguments['connected'] ?? false;
        _connectionController.add(_isConnected);
        break;
      case 'onError':
        print('Error de balanza: ${call.arguments}');
        break;
    }
  }
  
  // Conectar automáticamente
  Future<bool> _autoConnect() async {
    try {
      // Buscar puertos disponibles
      final ports = await _getAvailablePorts();
      
      for (String port in ports) {
        if (await _connectToPort(port)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error en auto-connect: $e');
      return false;
    }
  }
  
  // Obtener puertos disponibles
  Future<List<String>> _getAvailablePorts() async {
    try {
      final List<dynamic> ports = await _channel.invokeMethod('getAvailablePorts');
      return ports.cast<String>();
    } catch (e) {
      print('Error obteniendo puertos: $e');
      return [];
    }
  }
  
  // Conectar a un puerto específico
  Future<bool> _connectToPort(String port) async {
    try {
      print('🔌 Conectando a puerto: $port');
      print('⚙️ Configuración: baudRate=$_baudRate, protocol=$_protocol');
      
      final bool connected = await _channel.invokeMethod('connectToPort', {
        'port': port,
        'baudRate': _baudRate,
        'protocol': _protocol,
      });
      
      print('📡 Respuesta de plugin nativo: $connected');
      
      if (connected) {
        _port = port;
        _isConnected = true;
        _connectionController.add(true);
        print('✅ Conexión exitosa al puerto $port');
        return true;
      } else {
        print('❌ Fallo en conexión al puerto $port');
      }
      
      return false;
    } catch (e) {
      print('❌ Error conectando a puerto $port: $e');
      return false;
    }
  }
  
  // Conectar manualmente
  Future<bool> connect({
    String? port,
    int? baudRate,
    String? protocol,
  }) async {
    try {
      print('🔌 Iniciando conexión manual...');
      
    if (port != null) _port = port;
    if (baudRate != null) _baudRate = baudRate;
    if (protocol != null) _protocol = protocol;
    
      // Si no hay puerto especificado, buscar automáticamente
      if (_port.isEmpty) {
        print('🔍 Buscando puertos disponibles...');
        final ports = await _getAvailablePorts();
        print('📋 Puertos encontrados: $ports');
        
        if (ports.isNotEmpty) {
          _port = ports.first;
          print('🎯 Usando puerto: $_port');
        } else {
          print('❌ No se encontraron puertos disponibles');
          return false;
        }
      }
      
      final result = await _connectToPort(_port);
      print('🔗 Resultado de conexión: $result');
      return result;
    } catch (e) {
      print('❌ Error en conexión manual: $e');
      return false;
    }
  }
  
  // Desconectar REAL
  Future<void> disconnect() async {
    try {
      print('🔌 Desconectando balanza Aclas OS2X...');
      
      _readTimer?.cancel();
      _readTimer = null;
      _isReading = false;
      
      if (_serialPort != null) {
        _serialPort!.close();
        _serialPort!.dispose();
        _serialPort = null;
      }
      
      _reader = null;
      _isConnected = false;
      _currentWeight = 0.0;
      _connectionController.add(false);
      
      print('✅ Balanza desconectada');
    } catch (e) {
      print('❌ Error desconectando: $e');
    }
  }
  
  // Iniciar lectura de peso REAL
  Future<void> startReading() async {
    if (!_isConnected) {
      print('❌ Balanza no conectada');
      return;
    }
    
    try {
      print('📖 Iniciando lectura de peso...');
      
      _isReading = true;
      
      if (_serialPort != null) {
        // Usar comunicación real
        _startRealReading();
        print('✅ Lectura de peso real iniciada');
      } else {
        // Usar simulación temporal
        _startSimulatedReading();
        print('✅ Lectura de peso simulada iniciada');
      }
    } catch (e) {
      print('❌ Error iniciando lectura: $e');
    }
  }
  
  // Método temporal para simular lectura (backup)
  Timer? _simulationTimer;
  
  void _startSimulatedReading() {
    if (_simulationTimer != null) {
      _simulationTimer!.cancel();
    }
    
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isReading || !_isConnected) {
        timer.cancel();
        return;
      }
      
      // Simular peso que varía ligeramente
      final baseWeight = _getSimulatedWeight();
      final variation = (Random().nextDouble() - 0.5) * 0.01;
      final newWeight = baseWeight + variation;
      
      _currentWeight = double.parse(newWeight.toStringAsFixed(3));
      _weightController.add(_currentWeight);
    });
  }
  
  // Simular diferentes pesos (backup)
  double _getSimulatedWeight() {
    final now = DateTime.now();
    final seconds = now.second;
    
    if (seconds < 10) {
      return 0.000;
    } else if (seconds < 20) {
      return 0.250;
    } else if (seconds < 30) {
      return 0.500;
    } else if (seconds < 40) {
      return 1.250;
    } else if (seconds < 50) {
      return 2.100;
    } else {
      return 0.750;
    }
  }
  
  // Iniciar lectura REAL de la balanza Aclas OS2X
  void _startRealReading() {
    if (_readTimer != null) {
      _readTimer!.cancel();
    }
    
    _readTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isReading || !_isConnected || _serialPort == null) {
        timer.cancel();
        return;
      }
      
      _requestWeightFromAclas();
    });
  }
  
  // Solicitar peso a la balanza Aclas OS2X
  void _requestWeightFromAclas() async {
    try {
      if (_serialPort == null) return;
      
      // Comando específico para Aclas OS2X
      final command = 'W\r\n';
      final commandBytes = Uint8List.fromList(command.codeUnits);
      
      // Enviar comando
      _serialPort!.write(commandBytes);
      
      // Leer respuesta
      if (_reader != null) {
        _reader!.stream.timeout(
          const Duration(milliseconds: 500),
          onTimeout: (sink) => sink.close(),
        ).listen((data) {
          final response = String.fromCharCodes(data);
          final weight = _parseAclasResponse(response);
          
          if (weight != null) {
            _currentWeight = weight;
            _weightController.add(_currentWeight);
            print('📊 Peso leído: ${_currentWeight.toStringAsFixed(3)} kg');
          }
        });
      }
    } catch (e) {
      print('❌ Error solicitando peso: $e');
    }
  }
  
  // Parsear respuesta de Aclas OS2X
  double? _parseAclasResponse(String response) {
    try {
      print('📡 Respuesta raw: $response');
      
      // Limpiar respuesta
      final cleanResponse = response.trim();
      
      // Patrones comunes de Aclas OS2X:
      // "ST,GS,   1.234kg"
      // "ST,NET,  0.500kg"
      // "1.234kg"
      
      // Buscar patrón de peso con kg
      final kgPattern = RegExp(r'([0-9]+\.?[0-9]*)\s*kg');
      final kgMatch = kgPattern.firstMatch(cleanResponse);
      
      if (kgMatch != null) {
        final weightStr = kgMatch.group(1)!;
        return double.tryParse(weightStr);
      }
      
      // Buscar patrón de peso con lb (convertir a kg)
      final lbPattern = RegExp(r'([0-9]+\.?[0-9]*)\s*lb');
      final lbMatch = lbPattern.firstMatch(cleanResponse);
      
      if (lbMatch != null) {
        final weightStr = lbMatch.group(1)!;
        final weightLb = double.tryParse(weightStr);
        if (weightLb != null) {
          return weightLb * 0.453592; // Convertir lb a kg
        }
      }
      
      // Buscar solo números (asumir kg)
      final numberPattern = RegExp(r'([0-9]+\.?[0-9]+)');
      final numberMatch = numberPattern.firstMatch(cleanResponse);
      
      if (numberMatch != null) {
        final weightStr = numberMatch.group(1)!;
        return double.tryParse(weightStr);
      }
      
      return null;
    } catch (e) {
      print('❌ Error parseando respuesta: $e');
      return null;
    }
  }
  
  // Detener lectura de peso REAL
  Future<void> stopReading() async {
    try {
      print('⏹️ Deteniendo lectura de peso...');
      
      _readTimer?.cancel();
      _readTimer = null;
      _simulationTimer?.cancel();
      _simulationTimer = null;
      _isReading = false;
      
      print('✅ Lectura de peso detenida');
    } catch (e) {
      print('❌ Error deteniendo lectura: $e');
    }
  }
  
  // Obtener peso actual
  Future<double> getCurrentWeight() async {
    try {
      final double weight = await _channel.invokeMethod('getCurrentWeight');
      _currentWeight = weight;
      return weight;
    } catch (e) {
      print('Error obteniendo peso: $e');
      return 0.0;
    }
  }
  
  // Tare (tarar la balanza) REAL
  Future<void> tare() async {
    try {
      print('⚖️ Tarando balanza Aclas OS2X...');
      
      if (_serialPort != null) {
        // Comando de tare específico para Aclas OS2X
        final tareCommand = 'T\r\n';
        final commandBytes = Uint8List.fromList(tareCommand.codeUnits);
        
        _serialPort!.write(commandBytes);
        
        // Esperar un momento para que la balanza procese
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Solicitar peso después del tare
        _requestWeightFromAclas();
      } else {
        // Si no hay conexión, simular tare
      _currentWeight = 0.0;
      _weightController.add(0.0);
      }
      
      print('✅ Balanza tarada');
    } catch (e) {
      print('❌ Error tarando: $e');
    }
  }
  
  // Calcular precio basado en peso y precio por kg
  double calculatePrice(double weight, double pricePerKg) {
    return weight * pricePerKg;
  }
  
  // Formatear peso para mostrar
  String formatWeight(double weight) {
    if (weight == 0.0) return '0.000 kg';
    return '${weight.toStringAsFixed(3)} kg';
  }
  
  // Formatear precio para mostrar
  String formatPrice(double price) {
    return '\$ ${price.toStringAsFixed(0)}';
  }
  
  // Limpiar recursos REAL
  void dispose() {
    _readTimer?.cancel();
    _readTimer = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _weightController.close();
    _connectionController.close();
    disconnect();
  }
} 