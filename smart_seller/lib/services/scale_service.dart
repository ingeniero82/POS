import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

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
  String _protocol = 'standard'; // standard, cas, mettler, etc.
  
  // Inicializar el servicio
  Future<void> initialize() async {
    try {
      print('🔧 Inicializando ScaleService...');
      
      // Configurar el canal de método
      _channel.setMethodCallHandler(_handleMethodCall);
      print('✅ Canal de método configurado');
      
      // Intentar conectar automáticamente
      await _autoConnect();
      print('✅ ScaleService inicializado');
    } catch (e) {
      print('❌ Error inicializando ScaleService: $e');
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
  
  // Desconectar
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _isConnected = false;
      _isReading = false;
      _currentWeight = 0.0;
      _connectionController.add(false);
    } catch (e) {
      print('Error desconectando: $e');
    }
  }
  
  // Iniciar lectura de peso
  Future<void> startReading() async {
    if (!_isConnected) return;
    
    try {
      await _channel.invokeMethod('startReading');
      _isReading = true;
    } catch (e) {
      print('Error iniciando lectura: $e');
    }
  }
  
  // Detener lectura de peso
  Future<void> stopReading() async {
    try {
      await _channel.invokeMethod('stopReading');
      _isReading = false;
    } catch (e) {
      print('Error deteniendo lectura: $e');
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
  
  // Tare (tarar la balanza)
  Future<void> tare() async {
    try {
      await _channel.invokeMethod('tare');
      _currentWeight = 0.0;
      _weightController.add(0.0);
    } catch (e) {
      print('Error tarando: $e');
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
  
  // Limpiar recursos
  void dispose() {
    _weightController.close();
    _connectionController.close();
    disconnect();
  }
} 