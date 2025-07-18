import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../screens/pos_controller.dart';

class PrintService {
  static const MethodChannel _channel = MethodChannel('print_channel');
  static PrintService? _instance;
  
  static PrintService get instance {
    _instance ??= PrintService._internal();
    return _instance!;
  }
  
  PrintService._internal();
  
  // Estados de la impresora
  bool _isConnected = false;
  bool _isPrinting = false;
  String _printerPort = '';
  String _printerName = 'Citizen TZ30-M01';
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isPrinting => _isPrinting;
  String get printerPort => _printerPort;
  String get printerName => _printerName;
  
  // Configuración de impresora
  static const int _paperWidth = 48; // Ancho en caracteres para impresora de 80mm
  static const String _currency = 'COP';
  
  // Comandos ESC/POS para Citizen TZ30-M01
  static const List<int> _initPrinter = [0x1B, 0x40]; // ESC @
  static const List<int> _cutPaper = [0x1D, 0x56, 0x42, 0x00]; // GS V B 0
  static const List<int> _feedLines = [0x1B, 0x64, 0x03]; // ESC d 3
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _alignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> _boldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _boldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> _doubleHeight = [0x1B, 0x21, 0x10]; // ESC ! 16
  static const List<int> _normalSize = [0x1B, 0x21, 0x00]; // ESC ! 0
  static const List<int> _underlineOn = [0x1B, 0x2D, 0x01]; // ESC - 1
  static const List<int> _underlineOff = [0x1B, 0x2D, 0x00]; // ESC - 0
  
  // Inicializar servicio
  Future<void> initialize() async {
    try {
      print('🖨️ Inicializando PrintService...');
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Intentar detectar la impresora
      bool detected = await _detectPrinter();
      if (!detected) {
        print('⚠️ Impresora no detectada - Funcionará en modo simulación');
        // En modo simulación, marcar como "conectada" para propósitos de desarrollo
        _isConnected = true;
        _printerPort = 'SIMULATION';
      }
      
      print('✅ PrintService inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando PrintService: $e');
      // Activar modo simulación como fallback
      _isConnected = true;
      _printerPort = 'SIMULATION';
    }
  }
  
  // Manejar llamadas del método nativo
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPrinterConnected':
        _isConnected = true;
        _printerPort = call.arguments['port'] ?? '';
        break;
      case 'onPrinterDisconnected':
        _isConnected = false;
        _printerPort = '';
        break;
      case 'onPrintComplete':
        _isPrinting = false;
        break;
      case 'onPrintError':
        _isPrinting = false;
        print('Error de impresión: ${call.arguments}');
        break;
    }
  }
  
  // Detectar impresora automáticamente
  Future<bool> _detectPrinter() async {
    try {
      print('🔍 Iniciando detección de impresora...');
      
      // Listar todas las impresoras disponibles
      final printers = await listPrinters();
      print('📋 Impresoras encontradas en el sistema:');
      for (var printer in printers) {
        print('   - ${printer['name']} ${printer['isCitizen'] == true ? '(✅ Citizen)' : ''}');
      }
      
      // Intentar conectar a través de USB
      print('📱 Intentando conexión USB...');
      bool connected = await _connectUSB();
      if (connected) {
        print('✅ Impresora conectada por USB');
        return true;
      }
      
      // Si no funciona USB, intentar puertos serie
      print('🔌 Intentando conexión por puerto serie...');
      bool serialConnected = await _connectSerial();
      if (serialConnected) {
        print('✅ Impresora conectada por puerto serie');
        return true;
      }
      
      print('❌ No se pudo detectar la impresora');
      return false;
    } catch (e) {
      print('❌ Error detectando impresora: $e');
      return false;
    }
  }
  
  // Conectar por USB
  Future<bool> _connectUSB() async {
    try {
      print('🔌 Intentando conectar impresora Citizen por USB...');
      final result = await _channel.invokeMethod('connectUSB', {
        'vendorId': 0x1CB0, // Citizen vendor ID
        'productId': 0x0003, // TZ30-M01 product ID
      });
      
      if (result == true) {
        _isConnected = true;
        _printerPort = 'USB';
        print('✅ Impresora Citizen conectada por USB');
        return true;
      }
      print('❌ No se encontró impresora Citizen por USB');
      return false;
    } catch (e) {
      print('❌ Error conectando USB: $e');
      return false;
    }
  }
  
  // Conectar por puerto serie
  Future<bool> _connectSerial() async {
    try {
      final ports = ['COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8'];
      
      for (String port in ports) {
        try {
          final result = await _channel.invokeMethod('connectSerial', {
            'port': port,
            'baudRate': 9600,
            'dataBits': 8,
            'stopBits': 1,
            'parity': 0, // No parity
          });
          
          if (result == true) {
            _isConnected = true;
            _printerPort = port;
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      
      return false;
    } catch (e) {
      print('Error conectando por serie: $e');
      return false;
    }
  }
  
  // Desconectar impresora
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _isConnected = false;
      _printerPort = '';
    } catch (e) {
      print('Error desconectando: $e');
    }
  }
  
  // Imprimir recibo completo
  Future<bool> printReceipt(Sale sale, List<CartItem> items, double subtotal, double taxes, double total) async {
    if (!_isConnected) {
      print('❌ Impresora no conectada');
      return false;
    }
    
    try {
      print('🖨️ Iniciando impresión de recibo...');
      _isPrinting = true;
      
      // Si está en modo simulación, simular la impresión
      if (_printerPort == 'SIMULATION') {
        print('📝 Simulando impresión del recibo:');
        _simulatePrintReceipt(sale, items, subtotal, taxes, total);
        _isPrinting = false;
        return true;
      }
      
      List<int> commands = [];
      
      // Inicializar impresora
      commands.addAll(_initPrinter);
      
      // Encabezado
      commands.addAll(_alignCenter);
      commands.addAll(_boldOn);
      commands.addAll(_doubleHeight);
      commands.addAll(_formatText('SMART SELLER'));
      commands.addAll(_newLine());
      commands.addAll(_normalSize);
      commands.addAll(_formatText('Sistema POS'));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);
      commands.addAll(_formatText('Recibo de Venta'));
      commands.addAll(_newLine());
      
      // Línea separadora
      commands.addAll(_alignLeft);
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      
      // Información de la venta
      final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
      commands.addAll(_formatText('Fecha: ${formatter.format(sale.date)}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Cajero: ${sale.user}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Método: ${sale.paymentMethod}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      
      // Encabezado de productos
      commands.addAll(_boldOn);
      commands.addAll(_formatText(_formatLine('PRODUCTO', 'CANT', 'PRECIO')));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      
      // Productos
      final NumberFormat currencyFormat = NumberFormat.currency(
        locale: 'es_CO', 
        symbol: '\$', 
        decimalDigits: 0
      );
      
      for (CartItem item in items) {
        // Nombre del producto
        commands.addAll(_formatText(item.name));
        commands.addAll(_newLine());
        
        // Cantidad, precio unitario y total
        String quantityStr = item.displayInfo;
        String priceStr = currencyFormat.format(item.price);
        String totalStr = currencyFormat.format(item.total);
        
        commands.addAll(_formatText(_formatLine(quantityStr, priceStr, totalStr)));
        commands.addAll(_newLine());
      }
      
      // Línea separadora
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      
      // Totales
      commands.addAll(_alignRight);
      commands.addAll(_formatText('Subtotal: ${currencyFormat.format(subtotal)}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('IVA (19%): ${currencyFormat.format(taxes)}'));
      commands.addAll(_newLine());
      commands.addAll(_boldOn);
      commands.addAll(_doubleHeight);
      commands.addAll(_formatText('TOTAL: ${currencyFormat.format(total)}'));
      commands.addAll(_newLine());
      commands.addAll(_normalSize);
      commands.addAll(_boldOff);
      
      // Pie de página
      commands.addAll(_alignCenter);
      commands.addAll(_newLine());
      commands.addAll(_formatText('¡Gracias por su compra!'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Vuelva pronto'));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      
      // Línea separadora final
      commands.addAll(_alignLeft);
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      
      // Fecha y hora actual
      commands.addAll(_alignCenter);
      commands.addAll(_formatText('Impreso: ${formatter.format(DateTime.now())}'));
      commands.addAll(_newLine());
      
      // Alimentar papel y cortar
      commands.addAll(_feedLines);
      commands.addAll(_cutPaper);
      
      // Enviar comandos a la impresora
      final result = await _channel.invokeMethod('printRaw', {
        'data': Uint8List.fromList(commands),
      });
      
      return result == true;
    } catch (e) {
      print('Error imprimiendo recibo: $e');
      _isPrinting = false;
      return false;
    }
  }
  
  // Imprimir recibo de prueba
  Future<bool> printTestReceipt() async {
    if (!_isConnected) {
      print('Impresora no conectada');
      return false;
    }
    
    try {
      _isPrinting = true;
      
      List<int> commands = [];
      
      // Inicializar impresora
      commands.addAll(_initPrinter);
      
      // Encabezado
      commands.addAll(_alignCenter);
      commands.addAll(_boldOn);
      commands.addAll(_doubleHeight);
      commands.addAll(_formatText('SMART SELLER'));
      commands.addAll(_newLine());
      commands.addAll(_normalSize);
      commands.addAll(_formatText('Sistema POS'));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);
      commands.addAll(_formatText('Recibo de Prueba'));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      
      // Información de la impresora
      commands.addAll(_alignLeft);
      commands.addAll(_formatText('Impresora: ${_printerName}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Puerto: ${_printerPort}'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Estado: Conectada'));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      
      // Fecha y hora
      final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
      commands.addAll(_alignCenter);
      commands.addAll(_formatText('Fecha: ${formatter.format(DateTime.now())}'));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      
      // Mensaje de prueba
      commands.addAll(_formatText('¡Impresora funcionando!'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Test completado exitosamente'));
      commands.addAll(_newLine());
      
      // Alimentar papel y cortar
      commands.addAll(_feedLines);
      commands.addAll(_cutPaper);
      
      // Enviar comandos a la impresora
      final result = await _channel.invokeMethod('printRaw', {
        'data': Uint8List.fromList(commands),
      });
      
      return result == true;
    } catch (e) {
      print('Error imprimiendo recibo de prueba: $e');
      _isPrinting = false;
      return false;
    }
  }
  
  // Métodos helper para formateo
  List<int> _formatText(String text) {
    return text.codeUnits;
  }
  
  List<int> _newLine() {
    return [0x0A]; // Line Feed
  }
  
  String _createLine() {
    return '=' * _paperWidth;
  }
  
  String _formatLine(String left, String center, String right) {
    int leftWidth = 16;
    int centerWidth = 12;
    int rightWidth = _paperWidth - leftWidth - centerWidth;
    
    return left.padRight(leftWidth).substring(0, leftWidth) +
           center.padRight(centerWidth).substring(0, centerWidth) +
           right.padLeft(rightWidth).substring(0, rightWidth);
  }
  
  // Verificar estado de la impresora
  Future<bool> checkPrinterStatus() async {
    if (!_isConnected) return false;
    
    try {
      final result = await _channel.invokeMethod('checkStatus');
      return result == true;
    } catch (e) {
      print('Error verificando estado: $e');
      return false;
    }
  }
  
  // Listar impresoras disponibles
  Future<List<Map<String, dynamic>>> listPrinters() async {
    try {
      final result = await _channel.invokeMethod('listPrinters');
      if (result is List) {
        return result.map((printer) => Map<String, dynamic>.from(printer)).toList();
      }
      return [];
    } catch (e) {
      print('Error listando impresoras: $e');
      return [];
    }
  }

  // Reconectar impresora
  Future<bool> reconnect() async {
    try {
      await disconnect();
      await Future.delayed(Duration(seconds: 1));
      return await _detectPrinter();
    } catch (e) {
      print('Error reconectando: $e');
      return false;
    }
  }
  
  // Simular impresión para pruebas
  void _simulatePrintReceipt(Sale sale, List<CartItem> items, double subtotal, double taxes, double total) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'es_CO', 
      symbol: '\$', 
      decimalDigits: 0
    );
    
    print('');
    print('=====================================');
    print('           SMART SELLER');
    print('            Sistema POS');
    print('          Recibo de Venta');
    print('=====================================');
    print('Fecha: ${formatter.format(sale.date)}');
    print('Cajero: ${sale.user}');
    print('Método: ${sale.paymentMethod}');
    print('=====================================');
    print('PRODUCTO         CANT      PRECIO');
    print('=====================================');
    
    for (CartItem item in items) {
      print('${item.name}');
      print('${item.displayInfo.padRight(16)}${currencyFormat.format(item.price).padLeft(10)}${currencyFormat.format(item.total).padLeft(10)}');
    }
    
    print('=====================================');
    print('                Subtotal: ${currencyFormat.format(subtotal)}');
    print('                IVA(19%): ${currencyFormat.format(taxes)}');
    print('');
    print('                TOTAL: ${currencyFormat.format(total)}');
    print('=====================================');
    print('');
    print('        ¡Gracias por su compra!');
    print('            Vuelva pronto');
    print('');
    print('=====================================');
    print('Impreso: ${formatter.format(DateTime.now())}');
    print('=====================================');
    print('');
  }

  // Limpiar recursos
  void dispose() {
    disconnect();
  }
} 