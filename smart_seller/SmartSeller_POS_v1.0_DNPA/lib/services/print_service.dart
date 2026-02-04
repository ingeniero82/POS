import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../screens/pos_controller.dart';
import '../services/company_config_service.dart';
import '../models/company_config.dart';

/// Clave para guardar el nombre de la impresora seleccionada (mantenimiento).
const String _kPrinterNameKey = 'pos_printer_name';

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

  /// Nombre de la impresora guardada por el usuario (configuración/mantenimiento).
  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterNameKey);
  }

  /// Guardar impresora seleccionada para que la use el POS sin tocar código.
  Future<void> setSavedPrinterName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove(_kPrinterNameKey);
    } else {
      await prefs.setString(_kPrinterNameKey, name);
    }
    _printerName = name ?? 'Citizen TZ30-M01';
  }

  // Configuración de impresora
  static const int _paperWidth =
      48; // Ancho en caracteres para impresora de 80mm
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

  // Comandos para cajón monedero
  static const List<int> _openDrawer1 = [
    0x1B,
    0x70,
    0x00,
    0x32,
    0x96
  ]; // ESC p 0 50 150 (cajón 1)
  static const List<int> _openDrawer2 = [
    0x1B,
    0x70,
    0x01,
    0x32,
    0x96
  ]; // ESC p 1 50 150 (cajón 2)

  // Configuración de métodos de pago que requieren duplicado
  // TODOS los métodos diferentes a "Efectivo" requieren duplicado
  static const Map<String, bool> _paymentMethodsRequiringDuplicate = {
    // Efectivo - NO requiere duplicado
    'efectivo': false,
    'Efectivo': false,
    'Efectivo (Cash)': false,

    // TODOS los demás métodos SÍ requieren duplicado
    'tarjeta': true,
    'Tarjeta': true,
    'tarjeta crédito': true,
    'Tarjeta Crédito': true,
    'tarjeta débito': true,
    'Tarjeta Débito': true,
    'tarjeta debito': true,
    'Tarjeta Debito': true,
    'credito': true,
    'Crédito': true,
    'Credito': true,
    'debito': true,
    'Débito': true,
    'Debito': true,

    'transferencia': true,
    'Transferencia': true,
    'pse': true,
    'PSE': true,
    'bancolombia': true,
    'Bancolombia': true,

    'qr': true,
    'QR': true,
    'nequi': true,
    'Nequi': true,
    'daviplata': true,
    'Daviplata': true,

    'cheque': true,
    'Cheque': true,
    'pago_movil': true,
    'Pago Móvil': true,
    'pago movil': true,
    'Pago Movil': true,
    'crypto': true,
    'Crypto': true,
    'bitcoin': true,
    'Bitcoin': true,
    'ethereum': true,
    'Ethereum': true,
  };

  // Inicializar servicio
  Future<void> initialize() async {
    try {
      print('🖨️ Inicializando PrintService...');
      _channel.setMethodCallHandler(_handleMethodCall);
      final savedName = await getSavedPrinterName();
      if (savedName != null && savedName.isNotEmpty) {
        _printerName = savedName;
        print('🖨️ Impresora configurada: $savedName');
      }
      // Intentar detectar/conectar la impresora (USB/Serial o por nombre en Windows)
      bool detected = await _detectPrinter();
      if (!detected) {
        print('⚠️ Impresora no detectada - Funcionará en modo simulación');
        _isConnected = true;
        _printerPort = 'SIMULATION';
      }
      print('✅ PrintService inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando PrintService: $e');
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
      final printers = await listPrinters();
      print('📋 Impresoras encontradas en el sistema: ${printers.length}');
      for (var printer in printers) {
        print('   - ${printer['name']}');
      }
      // En Windows: si el usuario configuró una impresora por nombre, intentar conectar a esa primero
      if (Platform.isWindows) {
        final savedName = await getSavedPrinterName();
        if (savedName != null && savedName.isNotEmpty) {
          final connected = await connectToPrinterByName(savedName);
          if (connected) {
            print('✅ Impresora conectada por nombre: $savedName');
            return true;
          }
        }
      }
      // Intentar conectar a través de USB
      print('📱 Intentando conexión USB...');
      bool connected = await _connectUSB();
      if (connected) return true;
      // Si no funciona USB, intentar puertos serie
      print('🔌 Intentando conexión por puerto serie...');
      bool serialConnected = await _connectSerial();
      if (serialConnected) return true;
      print('❌ No se pudo detectar la impresora');
      return false;
    } catch (e) {
      print('❌ Error detectando impresora: $e');
      return false;
    }
  }

  /// Conectar a una impresora por nombre (Windows). Usado cuando el usuario eligió impresora en configuración.
  Future<bool> connectToPrinterByName(String printerName) async {
    try {
      final result = await _channel
          .invokeMethod<bool>('connectToPrinterByName', {'name': printerName});
      if (result == true) {
        _isConnected = true;
        _printerPort = 'WIN:$printerName';
        _printerName = printerName;
        return true;
      }
      return false;
    } catch (e) {
      print('⚠️ connectToPrinterByName no disponible o error: $e');
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
      final ports = [
        'COM1',
        'COM2',
        'COM3',
        'COM4',
        'COM5',
        'COM6',
        'COM7',
        'COM8'
      ];

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

  Map<String, dynamic> _printRawArgs(List<int> commands) {
    final args = <String, dynamic>{'data': Uint8List.fromList(commands)};
    if (Platform.isWindows && _printerName.isNotEmpty) {
      args['printerName'] = _printerName;
    }
    return args;
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

  // Imprimir recibo completo con lógica de doble impresión
  Future<bool> printReceipt(Sale sale, List<CartItem> items, double subtotal,
      double taxes, double total,
      {Customer? customer,
      bool isReprint = false,
      String? reprintReason,
      String? paymentMethod}) async {
    if (!_isConnected) {
      print('❌ Impresora no conectada');
      return false;
    }

    try {
      print('🖨️ Iniciando impresión de recibo...');
      _isPrinting = true;

      // Determinar si necesita duplicado basado en el método de pago
      bool needsDuplicate =
          _paymentMethodsRequiringDuplicate[paymentMethod] ?? false;

      // ✅ MEJORADO: Si no está en la lista, verificar si NO es "Efectivo"
      if (!_paymentMethodsRequiringDuplicate.containsKey(paymentMethod)) {
        needsDuplicate = paymentMethod != null &&
            paymentMethod.toLowerCase() != 'efectivo' &&
            paymentMethod.toLowerCase() != 'cash';
      }

      // Log para debugging
      print('🔍 Método de pago detectado: "$paymentMethod"');
      print('🔍 Necesita duplicado: $needsDuplicate');
      print(
          '🔍 Es diferente a efectivo: ${paymentMethod?.toLowerCase() != 'efectivo'}');

      if (needsDuplicate) {
        print('📋 Método de pago requiere duplicado: $paymentMethod');
        return await _printReceiptWithDuplicate(
            sale, items, subtotal, taxes, total,
            customer: customer,
            isReprint: isReprint,
            reprintReason: reprintReason);
      } else {
        print('📄 Método de pago requiere copia única: $paymentMethod');
        return await _printSingleReceipt(sale, items, subtotal, taxes, total,
            customer: customer,
            isReprint: isReprint,
            reprintReason: reprintReason);
      }
    } catch (e) {
      print('❌ Error en impresión: $e');
      _isPrinting = false;
      return false;
    }
  }

  // Imprimir recibo con duplicado
  Future<bool> _printReceiptWithDuplicate(Sale sale, List<CartItem> items,
      double subtotal, double taxes, double total,
      {Customer? customer,
      bool isReprint = false,
      String? reprintReason}) async {
    try {
      // Primera copia (CLIENTE)
      print('🖨️ Imprimiendo copia CLIENTE...');
      bool firstCopySuccess = await _printSingleReceipt(
          sale, items, subtotal, taxes, total,
          customer: customer,
          isReprint: isReprint,
          reprintReason: reprintReason,
          copyType: 'CLIENTE');

      if (!firstCopySuccess) {
        print('❌ Error imprimiendo primera copia');
        return false;
      }

      // Pausa entre impresiones
      await Future.delayed(Duration(milliseconds: 800));

      // Segunda copia (NEGOCIO)
      print('🖨️ Imprimiendo copia NEGOCIO...');
      bool secondCopySuccess = await _printSingleReceipt(
          sale, items, subtotal, taxes, total,
          customer: customer,
          isReprint: isReprint,
          reprintReason: reprintReason,
          copyType: 'NEGOCIO');

      if (!secondCopySuccess) {
        print('⚠️ Error imprimiendo segunda copia, pero primera fue exitosa');
        // Retornar true porque al menos una copia se imprimió
        return true;
      }

      print('✅ Doble impresión completada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error en doble impresión: $e');
      return false;
    }
  }

  // Imprimir recibo único
  Future<bool> _printSingleReceipt(Sale sale, List<CartItem> items,
      double subtotal, double taxes, double total,
      {Customer? customer,
      bool isReprint = false,
      String? reprintReason,
      String? copyType}) async {
    if (!_isConnected) {
      print('❌ Impresora no conectada');
      return false;
    }

    try {
      print('🖨️ Iniciando impresión de recibo...');
      _isPrinting = true;

      // Obtener configuración de empresa con fallback
      CompanyConfig? companyConfig;
      try {
        companyConfig = await CompanyConfigService.getCompanyConfig();
        print('✅ Configuración de empresa cargada correctamente');
      } catch (configError) {
        print('⚠️ Error cargando configuración de empresa: $configError');
        // Crear configuración por defecto si falla
        companyConfig = CompanyConfig(
          companyName: 'SMART SELLER',
          address: 'Dirección de la empresa',
          phone: 'Teléfono de contacto',
          headerText: 'FACTURA DE VENTA',
          footerText: 'Gracias por su compra\nVuelva pronto',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      // Si está en modo simulación, simular la impresión
      if (_printerPort == 'SIMULATION') {
        print('📝 Simulando impresión del recibo:');
        _simulatePrintReceipt(sale, items, subtotal, taxes, total,
            companyConfig: companyConfig,
            customer: customer,
            isReprint: isReprint,
            reprintReason: reprintReason);
        _isPrinting = false;
        return true;
      }

      List<int> commands = [];

      // Inicializar impresora
      commands.addAll(_initPrinter);

      // Encabezado personalizado con datos de empresa
      commands.addAll(_alignCenter);
      commands.addAll(_boldOn);
      commands.addAll(_doubleHeight);
      commands.addAll(_formatText(companyConfig.companyName));
      commands.addAll(_newLine());
      commands.addAll(_normalSize);
      commands.addAll(_formatText(companyConfig.address));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Tel: ${companyConfig.phone}'));
      commands.addAll(_newLine());
      if (companyConfig.email != null) {
        commands.addAll(_formatText(companyConfig.email!));
        commands.addAll(_newLine());
      }
      if (companyConfig.taxId != null) {
        commands.addAll(_formatText('NIT: ${companyConfig.taxId}'));
        commands.addAll(_newLine());
      }
      commands.addAll(_newLine());
      commands.addAll(_boldOn);
      commands.addAll(_formatText(companyConfig.headerText));
      commands.addAll(_newLine());
      commands.addAll(_formatText('No. ${_generateInvoiceNumber()}'));
      commands.addAll(_newLine());

      // Mostrar tipo de copia si es duplicado
      if (copyType != null) {
        commands.addAll(_alignCenter);
        commands.addAll(_boldOn);
        commands.addAll(_formatText('COPIA: $copyType'));
        commands.addAll(_newLine());
        commands.addAll(_boldOff);
      }

      commands.addAll(_boldOff);

      // Fecha y información de caja
      final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
      commands.addAll(_alignLeft);
      commands.addAll(_formatText(
          '${dateFormatter.format(sale.date)} Caja: 01 Us.: ${sale.user.toUpperCase()}'));
      commands.addAll(_newLine());

      // Información del cliente (si está seleccionado)
      if (customer != null) {
        commands.addAll(_newLine());
        commands.addAll(_boldOn);
        commands.addAll(_formatText('CLIENTE:'));
        commands.addAll(_boldOff);
        commands.addAll(_newLine());
        commands.addAll(_formatText('${customer.name}'));
        commands.addAll(_newLine());
        if (customer.documentNumber != null) {
          commands.addAll(_formatText('Doc: ${customer.documentNumber}'));
          commands.addAll(_newLine());
        }
        commands.addAll(_formatText('Tel: ${customer.phone}'));
        commands.addAll(_newLine());
      }

      // Línea separadora
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());

      // Encabezado de productos estilo MURICATA
      commands.addAll(_formatText('DESCRIPCION PRECIO_ MED CANT._ SUBTOTAL_'));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_createEqualsLine()));
      commands.addAll(_newLine());

      // Productos estilo MURICATA
      final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');

      for (CartItem item in items) {
        // Formato: AVENA        4.000 KG 3.00      12.000
        String productName = item.name.toUpperCase().padRight(12);
        String unitPrice = '${currencyFormat.format(item.price)}'.padLeft(7);
        String measure = item.unit; // Usar la unidad real del producto
        String medUnit =
            '$measure ${item.quantity.toStringAsFixed(2)}'.padRight(9);
        String subtotalItem = currencyFormat.format(item.total).padLeft(10);

        commands.addAll(
            _formatText('$productName$unitPrice $medUnit$subtotalItem'));
        commands.addAll(_newLine());
      }

      // Línea separadora y totales estilo MURICATA
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());

      // Totales detallados
      commands.addAll(_alignLeft);
      String subtotalStr = currencyFormat.format(subtotal);
      String taxesStr = currencyFormat.format(taxes);
      String totalStr = currencyFormat.format(total);

      commands
          .addAll(_formatText('SUB.T.: \$ $subtotalStr -DESC.: \$        0'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('+IVA : \$        0 AJUST.: \$        0'));
      commands.addAll(_newLine());
      commands.addAll(_boldOn);
      commands.addAll(_formatText('         TOTAL: \$ $totalStr'));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);
      commands.addAll(_formatText(
          'VENDED.: GENERICO    CAJERO: ${sale.user.toUpperCase()}'));
      commands.addAll(_newLine());
      commands
          .addAll(_formatText('CAJA : 001                CAMBIO: \$        0'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('RECIBE: \$ $totalStr'));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      commands.addAll(_formatText('EFECTIVO O CONTADO'));
      commands.addAll(_newLine());
      commands.addAll(_alignCenter);
      commands.addAll(_formatText('<< FORMAS DE PAGO >>     \$ $totalStr'));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());

      // Pie de página personalizado
      commands.addAll(_alignCenter);
      commands.addAll(_newLine());

      // Usar texto de pie personalizable
      final footerLines = companyConfig.footerText.split('\n');
      for (final line in footerLines) {
        commands.addAll(_formatText('***${line.toUpperCase()}***'));
        commands.addAll(_newLine());
      }

      commands.addAll(_formatText(_createLine()));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      commands.addAll(_formatText('Software POS: SMART SELLER'));
      commands.addAll(_newLine());

      // Alimentar papel y cortar
      commands.addAll(_feedLines);
      commands.addAll(_cutPaper);

      // Enviar comandos a la impresora (printerName para Windows cuando está configurada)
      final result =
          await _channel.invokeMethod('printRaw', _printRawArgs(commands));
      _isPrinting = false;
      print('✅ Impresión completada, resultado: $result');
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
      commands
          .addAll(_formatText('Fecha: ${formatter.format(DateTime.now())}'));
      commands.addAll(_newLine());
      commands.addAll(_newLine());

      // Mensaje de prueba
      commands.addAll(_formatText('¡Impresora funcionando!'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Test completado exitosamente'));
      commands.addAll(_newLine());

      commands.addAll(_feedLines);
      commands.addAll(_cutPaper);
      final result =
          await _channel.invokeMethod('printRaw', _printRawArgs(commands));
      _isPrinting = false;
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

  String _createEqualsLine() {
    return '=' * _paperWidth;
  }

  // Generar número de factura incremental
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return timestamp;
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
        return result
            .map((printer) => Map<String, dynamic>.from(printer))
            .toList();
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

  // Simular impresión para pruebas - Formato personalizado
  void _simulatePrintReceipt(Sale sale, List<CartItem> items, double subtotal,
      double taxes, double total,
      {CompanyConfig? companyConfig,
      Customer? customer,
      bool isReprint = false,
      String? reprintReason}) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');

    print('');
    print('=====================================');
    print('        ${companyConfig?.companyName ?? 'SMART SELLER'}');
    print('        ${companyConfig?.address ?? 'Dirección'}');
    print('        Tel: ${companyConfig?.phone ?? 'Teléfono'}');
    if (companyConfig?.email != null) {
      print('        ${companyConfig!.email}');
    }
    if (companyConfig?.taxId != null) {
      print('        NIT: ${companyConfig!.taxId}');
    }
    print('');
    print(
        '   ${companyConfig?.headerText ?? 'FACTURA DE VENTA'} No. ${_generateInvoiceNumber()}');
    print(
        '${dateFormatter.format(sale.date)} Caja: 01 Us.: ${sale.user.toUpperCase()}');

    // Información del cliente (si está seleccionado)
    if (customer != null) {
      print('');
      print('CLIENTE:');
      print('${customer.name}');
      if (customer.documentNumber != null) {
        print('Doc: ${customer.documentNumber}');
      }
      print('Tel: ${customer.phone}');
    }

    print('-------------------------------------');
    print('DESCRIPCION PRECIO_ MED CANT._ SUBTOTAL_');
    print('=====================================');

    for (CartItem item in items) {
      String productName = item.name.toUpperCase().padRight(12);
      String unitPrice = '${currencyFormat.format(item.price)}'.padLeft(7);
      String measure = item.unit; // Usar la unidad real del producto
      String medUnit =
          '$measure ${item.quantity.toStringAsFixed(2)}'.padRight(9);
      String subtotalItem = currencyFormat.format(item.total).padLeft(10);

      print('$productName$unitPrice $medUnit$subtotalItem');
    }

    String subtotalStr = currencyFormat.format(subtotal);
    String totalStr = currencyFormat.format(total);

    print('-------------------------------------');
    print('SUB.T.: \$ $subtotalStr -DESC.: \$        0');
    print('+IVA : \$        0 AJUST.: \$        0');
    print('         TOTAL: \$ $totalStr');
    print('VENDED.: GENERICO    CAJERO: ${sale.user.toUpperCase()}');
    print('CAJA : 001                CAMBIO: \$        0');
    print('RECIBE: \$ $totalStr');
    print('-------------------------------------');
    print('EFECTIVO O CONTADO');
    print('<< FORMAS DE PAGO >>     \$ $totalStr');
    print('-------------------------------------');
    print('');
    print('         CALLE 123 #45-67');
    print('       TU CIUDAD - COLOMBIA');
    print('         Tel.: 300-123-4567');
    print('');
    // Usar texto de pie personalizable
    final footerLines =
        (companyConfig?.footerText ?? 'GRACIAS POR SU COMPRA\nREGRESE PRONTO')
            .split('\n');
    for (final line in footerLines) {
      print('        ***${line.toUpperCase()}***');
    }
    print('-------------------------------------');
    print('');
    print('        Software POS: SMART SELLER');
    print('=====================================');
    print('');
  }

  // Abrir cajón monedero
  Future<bool> openCashDrawer({int drawer = 1}) async {
    try {
      print('💰 Abriendo cajón monedero ${drawer}...');

      if (!_isConnected) {
        print('❌ Impresora no conectada - Simulando apertura de cajón');
        print('💰 SIMULACIÓN: Cajón monedero abierto');
        return true;
      }

      List<int> commands = [];

      // Seleccionar cajón (1 o 2)
      if (drawer == 2) {
        commands.addAll(_openDrawer2);
      } else {
        commands.addAll(_openDrawer1);
      }

      final result =
          await _channel.invokeMethod('printRaw', _printRawArgs(commands));
      print('✅ Comando de apertura de cajón enviado, resultado: $result');
      return result == true;
    } catch (e) {
      print('❌ Error abriendo cajón monedero: $e');
      return false;
    }
  }

  // Limpiar recursos
  void dispose() {
    disconnect();
  }
}
