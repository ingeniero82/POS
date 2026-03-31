import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/client.dart';
import '../screens/pos_controller.dart';
import '../services/company_config_service.dart';
import '../models/company_config.dart';

/// Clave para guardar el nombre de la impresora seleccionada (mantenimiento).
const String _kPrinterNameKey = 'pos_printer_name';

/// Claves para formato del recibo (márgenes y columnas).
const String _kReceiptPaperWidth = 'receipt_paper_width';
const String _kReceiptMarginLeft = 'receipt_margin_left';
const String _kReceiptColDesc = 'receipt_col_desc';
const String _kReceiptColCant = 'receipt_col_cant';
const String _kReceiptColPrice = 'receipt_col_price';
const String _kReceiptColSubtotal = 'receipt_col_subtotal';
const String _kReceiptSpacePriceCant = 'receipt_space_price_cant';

/// Formato configurable del recibo POS (ancho fijo para evitar descuadre en papel).
/// Por defecto 48 caracteres: CANT(4) + DESCRIPCIÓN(21) + P.UNIT(10) + TOTAL(10) + espacios(3) = 48.
class ReceiptFormat {
  final int paperWidth;
  final int marginLeft;
  final int colDesc;
  final int colCant;
  final int colPrice;
  final int colSubtotal;
  final int spaceBetweenPriceAndCant;
  const ReceiptFormat({
    this.paperWidth = 48,
    this.marginLeft = 0,
    this.colDesc = 21,
    this.colCant = 4,
    this.colPrice = 10,
    this.colSubtotal = 10,
    this.spaceBetweenPriceAndCant = 1,
  });
}

/// Opción de ancho de papel estándar POS.
class StandardPaperWidth {
  final String label;
  final int chars;
  const StandardPaperWidth(this.label, this.chars);
}

/// Anchos estándar de papel térmico POS.
const List<StandardPaperWidth> kStandardPaperWidths = [
  StandardPaperWidth('58 mm (estrecho)', 32),
  StandardPaperWidth('58 mm', 42),
  StandardPaperWidth('80 mm estándar', 48),
  StandardPaperWidth('80 mm ancho', 56),
  StandardPaperWidth('80 mm extra ancho', 72),
];

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

  /// Cargar ancho de papel desde preferencias.
  Future<int> _getPaperWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kReceiptPaperWidth) ?? 48;
  }

  /// Guardar formato del recibo (para configuración de impresora).
  Future<void> setReceiptFormat({
    int? paperWidth,
    int? marginLeft,
    int? colDesc,
    int? colCant,
    int? colPrice,
    int? colSubtotal,
    int? spaceBetweenPriceAndCant,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (paperWidth != null) await prefs.setInt(_kReceiptPaperWidth, paperWidth);
    if (marginLeft != null) {
      await prefs.setInt(_kReceiptMarginLeft, marginLeft.clamp(0, 10));
    }
    if (colDesc != null) await prefs.setInt(_kReceiptColDesc, colDesc);
    if (colCant != null) await prefs.setInt(_kReceiptColCant, colCant);
    if (colPrice != null) await prefs.setInt(_kReceiptColPrice, colPrice);
    if (colSubtotal != null) {
      await prefs.setInt(_kReceiptColSubtotal, colSubtotal);
    }
    if (spaceBetweenPriceAndCant != null) {
      await prefs.setInt(
          _kReceiptSpacePriceCant, spaceBetweenPriceAndCant.clamp(1, 4));
    }
  }

  /// Obtener formato actual del recibo (ancho fijo 48 para alineación correcta).
  Future<ReceiptFormat> getReceiptFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return ReceiptFormat(
      paperWidth: prefs.getInt(_kReceiptPaperWidth) ?? 48,
      marginLeft: prefs.getInt(_kReceiptMarginLeft) ?? 0,
      colDesc: prefs.getInt(_kReceiptColDesc) ?? 21,
      colCant: prefs.getInt(_kReceiptColCant) ?? 4,
      colPrice: prefs.getInt(_kReceiptColPrice) ?? 10,
      colSubtotal: prefs.getInt(_kReceiptColSubtotal) ?? 10,
      spaceBetweenPriceAndCant:
          (prefs.getInt(_kReceiptSpacePriceCant) ?? 1).clamp(1, 4),
    );
  }

  /// Sugiere anchos de columnas para un ancho de papel.
  static ReceiptFormat suggestedFormatForPaperWidth(int paperWidth,
      {int marginLeft = 0}) {
    final contentWidth = (paperWidth - marginLeft).clamp(20, 120);
    const spacesBetweenColumns = 3;
    final rest = (contentWidth - spacesBetweenColumns).clamp(12, 117);
    int colDesc = (rest * 48 ~/ 100).clamp(8, 40);
    int colPrice = (rest * 19 ~/ 100).clamp(6, 14);
    int colCant = (rest * 14 ~/ 100).clamp(4, 10);
    int colSubtotal = rest - colDesc - colPrice - colCant;
    if (colSubtotal < 6) {
      colDesc = (colDesc - (6 - colSubtotal)).clamp(8, 40);
      colSubtotal = rest - colDesc - colPrice - colCant;
    }
    colSubtotal = colSubtotal.clamp(6, 14);
    return ReceiptFormat(
      paperWidth: paperWidth,
      marginLeft: marginLeft,
      colDesc: colDesc,
      colPrice: colPrice,
      colCant: colCant,
      colSubtotal: colSubtotal,
    );
  }

  /// Genera vista previa del recibo con la misma plantilla que se imprime.
  static String buildReceiptPreview(ReceiptFormat fmt) {
    final cw = fmt.paperWidth - fmt.marginLeft;
    final margin = ' ' * fmt.marginLeft;
    final sep = '=' * cw;
    final dash = '-' * cw;
    final currencyFormat = NumberFormat('#,##0.00', 'es_CO');
    String lineLR(String left, String right) {
      final space = cw - left.length - right.length;
      return '$margin$left${' ' * (space > 0 ? space : 0)}$right';
    }

    /// Centra una línea en el ancho de contenido (cabecera y pie).
    String centerLine(String text) {
      final t = text.length > cw ? text.substring(0, cw) : text;
      final pad = (cw - t.length) ~/ 2;
      return margin + (' ' * pad) + t + (' ' * (cw - pad - t.length));
    }

    String itemRow(String cant, String desc, String pUnit, String total) {
      final gap = ' ' * fmt.spaceBetweenPriceAndCant.clamp(1, 4);
      final d = desc.length > fmt.colDesc
          ? desc.substring(0, fmt.colDesc)
          : desc.padRight(fmt.colDesc);
      final c = cant.padLeft(fmt.colCant);
      final p = pUnit.padLeft(fmt.colPrice);
      final t = total.padLeft(fmt.colSubtotal);
      return '$margin$c$gap$d$gap$p$gap$t';
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    final sb = StringBuffer();
    sb.writeln('$margin$sep');
    sb.writeln(centerLine('NOMBRE DEL NEGOCIO'));
    sb.writeln(centerLine('Dirección del Comercio'));
    sb.writeln(centerLine('Ciudad, Depto, País'));
    sb.writeln(centerLine('Tel: 300-1234567'));
    sb.writeln(centerLine('NIT/RFC: 900.123.456-7'));
    sb.writeln('$margin$sep');
    sb.writeln('');
    sb.writeln(lineLR('Fecha: $dateStr', 'Hora: $timeStr'));
    sb.writeln(lineLR('Ticket #: 00245', ''));
    sb.writeln(lineLR('Cajero: Juan Pérez', ''));
    sb.writeln(lineLR('Caja: 01', ''));
    sb.writeln('');
    sb.writeln('$margin$dash');
    sb.writeln('${margin}ARTÍCULOS');
    sb.writeln('$margin$dash');
    sb.writeln(itemRow('Cant.', 'Descripción', 'P.Unit', 'Total'));
    sb.writeln('$margin$dash');
    sb.writeln(itemRow('2x', 'Café Americano', '\$2.50', '\$5.00'));
    sb.writeln(itemRow('1x', 'Croissant', '\$3.00', '\$3.00'));
    sb.writeln('$margin$dash');
    sb.writeln('');
    sb.writeln(lineLR('SUBTOTAL:', '\$8.00'));
    sb.writeln(lineLR('IVA (16%):', '\$1.28'));
    sb.writeln(lineLR('DESCUENTO:', '\$0.00'));
    sb.writeln('$margin$dash');
    sb.writeln(lineLR('TOTAL A PAGAR:', '\$9.28'));
    sb.writeln('$margin$sep');
    sb.writeln('');
    sb.writeln('${margin}MEDIO DE PAGO');
    sb.writeln('$margin$dash');
    sb.writeln(lineLR('Efectivo', '\$9.28'));
    sb.writeln(lineLR('Cambio:', '\$0.00'));
    sb.writeln('$margin$dash');
    sb.writeln('');
    sb.writeln(lineLR('Cliente:', 'Público General'));
    sb.writeln(lineLR('Puntos acumulados:', '0'));
    sb.writeln('');
    sb.writeln('$margin$sep');
    sb.writeln(centerLine('¡GRACIAS POR SU COMPRA!'));
    sb.writeln(centerLine('www.tunegocio.com'));
    sb.writeln(centerLine('Conserve su ticket'));
    sb.writeln(centerLine('Válido para cambios: 7 días'));
    sb.writeln('$margin$sep');
    sb.writeln('');
    sb.writeln(centerLine('Software POS: SMART SELLER'));
    sb.writeln('');
    return sb.toString();
  }

  static const int _paperWidth = 48;
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
  // Solo Efectivo imprime una copia; cualquier otro método imprime doble (cliente + negocio)
  static const Map<String, bool> _paymentMethodsRequiringDuplicate = {
    // Efectivo - una sola copia
    'efectivo': false,
    'Efectivo': false,
    'Efectivo (Cash)': false,
    'cash': false,
    'Cash': false,

    // Cualquier otro método (Mixto, Crédito, Tarjeta, etc.) - doble factura
    'mixto': true,
    'Mixto': true,
    'crédito': true,
    'Crédito': true,
    'credito': true,
    'Credito': true,

    // Tarjeta, transferencia, etc. - doble factura
    'tarjeta': true,
    'Tarjeta': true,
    'tarjeta crédito': true,
    'Tarjeta Crédito': true,
    'tarjeta débito': true,
    'Tarjeta Débito': true,
    'tarjeta debito': true,
    'Tarjeta Debito': true,
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

  Map<String, dynamic> _printRawArgs(List<int> commands,
      {String? printerName}) {
    final args = <String, dynamic>{'data': Uint8List.fromList(commands)};
    final name = printerName ?? _printerName;
    if (Platform.isWindows && name.isNotEmpty) {
      args['printerName'] = name;
    }
    return args;
  }

  /// Envía datos en bruto (bytes) a la impresora indicada.
  /// [printerName]: si es null, usa la impresora POS configurada; si no, imprime en esa impresora por nombre (Windows).
  Future<bool> printRawToPrinter(List<int> data, {String? printerName}) async {
    try {
      if (Platform.isWindows) {
        final name = printerName ?? _printerName;
        if (name.isEmpty) {
          print('No hay impresora seleccionada para el reporte');
          return false;
        }
        final result = await _channel.invokeMethod(
            'printRaw', _printRawArgs(data, printerName: printerName));
        return result == true;
      }
      // En otros SO usar impresora POS si está conectada
      if (!_isConnected) return false;
      final result =
          await _channel.invokeMethod('printRaw', _printRawArgs(data));
      return result == true;
    } catch (e) {
      print('Error imprimiendo reporte: $e');
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

  // Imprimir recibo completo con lógica de doble impresión
  // vatAt19 y vatAt5 opcionales: si se pasan, se imprime desglose IVA 19% y 5%
  Future<bool> printReceipt(Sale sale, List<CartItem> items, double subtotal,
      double taxes, double total,
      {Customer? customer,
      Client? client,
      bool isReprint = false,
      String? reprintReason,
      String? paymentMethod,
      double? receivedAmount,
      double? changeAmount,
      double? creditDownPayment,
      double? creditPendingAmount,
      String? creditPaymentMethod,
      double? vatAt19,
      double? vatAt5}) async {
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
            client: client,
            isReprint: isReprint,
            reprintReason: reprintReason,
            receivedAmount: receivedAmount,
            changeAmount: changeAmount,
            creditDownPayment: creditDownPayment,
            creditPendingAmount: creditPendingAmount,
            creditPaymentMethod: creditPaymentMethod,
            vatAt19: vatAt19,
            vatAt5: vatAt5);
      } else {
        print('📄 Método de pago requiere copia única: $paymentMethod');
        return await _printSingleReceipt(sale, items, subtotal, taxes, total,
            customer: customer,
            client: client,
            isReprint: isReprint,
            reprintReason: reprintReason,
            receivedAmount: receivedAmount,
            changeAmount: changeAmount,
            creditDownPayment: creditDownPayment,
            creditPendingAmount: creditPendingAmount,
            creditPaymentMethod: creditPaymentMethod,
            vatAt19: vatAt19,
            vatAt5: vatAt5);
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
      Client? client,
      bool isReprint = false,
      String? reprintReason,
      double? receivedAmount,
      double? changeAmount,
      double? creditDownPayment,
      double? creditPendingAmount,
      String? creditPaymentMethod,
      double? vatAt19,
      double? vatAt5}) async {
    try {
      // Primera copia (CLIENTE)
      print('🖨️ Imprimiendo copia CLIENTE...');
      bool firstCopySuccess = await _printSingleReceipt(
          sale, items, subtotal, taxes, total,
          customer: customer,
          client: client,
          isReprint: isReprint,
          reprintReason: reprintReason,
          copyType: 'CLIENTE',
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
          creditDownPayment: creditDownPayment,
          creditPendingAmount: creditPendingAmount,
          creditPaymentMethod: creditPaymentMethod,
          vatAt19: vatAt19,
          vatAt5: vatAt5);

      if (!firstCopySuccess) {
        print('❌ Error imprimiendo primera copia');
        return false;
      }

      // Pausa entre impresiones
      await Future.delayed(const Duration(milliseconds: 800));

      // Segunda copia (NEGOCIO)
      print('🖨️ Imprimiendo copia NEGOCIO...');
      bool secondCopySuccess = await _printSingleReceipt(
          sale, items, subtotal, taxes, total,
          customer: customer,
          client: client,
          isReprint: isReprint,
          reprintReason: reprintReason,
          copyType: 'NEGOCIO',
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
          creditDownPayment: creditDownPayment,
          creditPendingAmount: creditPendingAmount,
          creditPaymentMethod: creditPaymentMethod,
          vatAt19: vatAt19,
          vatAt5: vatAt5);

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

  // Imprimir recibo único (modelo factura cliente: ancho fijo 48, IVA por tasa, Recibido/Su cambio)
  Future<bool> _printSingleReceipt(Sale sale, List<CartItem> items,
      double subtotal, double taxes, double total,
      {Customer? customer,
      Client? client,
      bool isReprint = false,
      String? reprintReason,
      String? copyType,
      double? receivedAmount,
      double? changeAmount,
      double? creditDownPayment,
      double? creditPendingAmount,
      String? creditPaymentMethod,
      double? vatAt19,
      double? vatAt5}) async {
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

      final fmt = await getReceiptFormat();

      // Si está en modo simulación, simular la impresión
      if (_printerPort == 'SIMULATION') {
        print('📝 Simulando impresión del recibo:');
        _simulatePrintReceipt(sale, items, subtotal, taxes, total,
            companyConfig: companyConfig,
            customer: customer,
            client: client,
            isReprint: isReprint,
            reprintReason: reprintReason,
            fmt: fmt,
            vatAt19: vatAt19,
            vatAt5: vatAt5);
        _isPrinting = false;
        return true;
      }

      // Montos sin decimales en recibo (modelo factura cliente)
      final NumberFormat currencyFormat = NumberFormat('#,##0', 'es_CO');
      final dateFormatter = DateFormat('dd/MM/yyyy');
      final timeFormatter = DateFormat('HH:mm:ss');
      String subtotalStr = currencyFormat.format(subtotal);
      String taxesStr = currencyFormat.format(taxes);
      String totalStr = currencyFormat.format(total);
      final invoiceNro = sale.id != null
          ? (sale.id!.toString().padLeft(5, '0'))
          : _generateInvoiceNumber();

      List<int> commands = [];
      commands.addAll(_initPrinter);

      // Encabezado empresa (centrado, modelo factura)
      commands.addAll(_alignCenter);
      commands.addAll(_boldOn);
      commands.addAll(_doubleHeight);
      commands.addAll(_formatText(companyConfig.companyName));
      commands.addAll(_newLine());
      commands.addAll(_normalSize);
      commands.addAll(_formatText(companyConfig.address));
      commands.addAll(_newLine());
      if (companyConfig.city != null && companyConfig.city!.trim().isNotEmpty) {
        commands.addAll(_formatText(companyConfig.city!.trim()));
        commands.addAll(_newLine());
      }
      commands.addAll(_formatText('Tel: ${companyConfig.phone}'));
      commands.addAll(_newLine());
      if (companyConfig.taxId != null) {
        commands.addAll(_formatText('NIT: ${companyConfig.taxId}'));
        commands.addAll(_newLine());
      }
      if (companyConfig.fiscalRegime != null &&
          companyConfig.fiscalRegime!.trim().isNotEmpty) {
        commands.addAll(_formatText(companyConfig.fiscalRegime!.trim()));
        commands.addAll(_newLine());
      }
      commands.addAll(_formatText(_separatorLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_boldOn);
      // Texto de cabecera desde configuración de empresa (ej. FACTURA DE VENTA, RECIBO, etc.)
      final headerText = (companyConfig.headerText.trim().isEmpty)
          ? 'FACTURA DE VENTA'
          : companyConfig.headerText.trim();
      commands.addAll(_formatText(headerText));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Nro: $invoiceNro'));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_separatorLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);

      if (copyType != null) {
        commands.addAll(_boldOn);
        commands.addAll(_formatText('COPIA: $copyType'));
        commands.addAll(_newLine());
        commands.addAll(_boldOff);
      }

      commands.addAll(_alignLeft);
      commands.addAll(_formatText(_lineLeftRight(
          fmt,
          'Fecha: ${dateFormatter.format(sale.date)}',
          'Hora: ${timeFormatter.format(sale.date)}')));
      commands.addAll(_newLine());
      commands.addAll(
          _formatText(_lineLeftRight(fmt, 'Cajero: ${sale.user}', 'Caja: 01')));
      commands.addAll(_newLine());
      // Bloque cliente en ticket: prioridad 1 = Cliente del sistema (Customer, sin facturación electrónica);
      // prioridad 2 = Cliente facturación (Client). Así los datos del cliente salen siempre que esté seleccionado.
      final cw = fmt.paperWidth - fmt.marginLeft;
      const clientLabel = 'Cliente:';
      final cust =
          customer; // Cliente del sistema (mayoría sin facturación electrónica)
      final clientForTicket = client;
      String clientValue;
      if (cust != null) {
        clientValue = cust.name.trim().length > cw - clientLabel.length - 2
            ? cust.name.trim().substring(0, cw - clientLabel.length - 2)
            : cust.name.trim();
      } else if (clientForTicket != null) {
        clientValue = clientForTicket.businessName.trim().length >
                cw - clientLabel.length - 2
            ? clientForTicket.businessName
                .trim()
                .substring(0, cw - clientLabel.length - 2)
            : clientForTicket.businessName.trim();
      } else {
        clientValue = 'Venta en mostrador';
      }
      commands
          .addAll(_formatText(_lineLeftRight(fmt, clientLabel, clientValue)));
      commands.addAll(_newLine());
      if (cust != null) {
        final nitCc = [cust.documentType, cust.documentNumber]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(' ')
            .trim();
        if (nitCc.isNotEmpty) {
          final nitVal =
              nitCc.length > cw - 8 ? nitCc.substring(0, cw - 8) : nitCc;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'NIT/CC:', nitVal)));
          commands.addAll(_newLine());
        }
        final clientAddress = cust.address?.trim() ?? '';
        if (clientAddress.isNotEmpty) {
          final addr = clientAddress.length > cw - 12
              ? clientAddress.substring(0, cw - 12)
              : clientAddress;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'Direccion:', addr)));
          commands.addAll(_newLine());
        }
        final tel = cust.phone.trim();
        if (tel.isNotEmpty) {
          final telVal = tel.length > cw - 6 ? tel.substring(0, cw - 6) : tel;
          commands
              .addAll(_formatText(_lineLeftRight(fmt, 'Telefono:', telVal)));
          commands.addAll(_newLine());
        }
        final city = cust.city?.trim() ?? '';
        if (city.isNotEmpty) {
          final cityVal =
              city.length > cw - 8 ? city.substring(0, cw - 8) : city;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'Ciudad:', cityVal)));
          commands.addAll(_newLine());
        }
      } else if (clientForTicket != null) {
        final nitCc =
            '${clientForTicket.documentType} ${clientForTicket.documentNumber}'
                .trim();
        if (nitCc.isNotEmpty) {
          final nitVal =
              nitCc.length > cw - 8 ? nitCc.substring(0, cw - 8) : nitCc;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'NIT/CC:', nitVal)));
          commands.addAll(_newLine());
        }
        final clientAddress = clientForTicket.address?.trim() ?? '';
        if (clientAddress.isNotEmpty) {
          final addr = clientAddress.length > cw - 12
              ? clientAddress.substring(0, cw - 12)
              : clientAddress;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'Direccion:', addr)));
          commands.addAll(_newLine());
        }
        final tel = clientForTicket.phone?.trim() ?? '';
        if (tel.isNotEmpty) {
          final telVal = tel.length > cw - 6 ? tel.substring(0, cw - 6) : tel;
          commands
              .addAll(_formatText(_lineLeftRight(fmt, 'Telefono:', telVal)));
          commands.addAll(_newLine());
        }
        final city = clientForTicket.city?.trim() ?? '';
        if (city.isNotEmpty) {
          final cityVal =
              city.length > cw - 8 ? city.substring(0, cw - 8) : city;
          commands.addAll(_formatText(_lineLeftRight(fmt, 'Ciudad:', cityVal)));
          commands.addAll(_newLine());
        }
      }
      commands.addAll(_newLine());

      commands.addAll(_formatText(_dashLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_formatText(
          _buildTicketItemRow(fmt, 'CANT', 'DESCRIPCION', 'P.UNIT', 'TOTAL')));
      commands.addAll(_newLine());
      commands.addAll(_formatText(_dashLine(fmt)));
      commands.addAll(_newLine());

      for (CartItem item in items) {
        final cant = item.quantity == item.quantity.truncateToDouble()
            ? '${item.quantity.toInt()}'
            : item.quantity.toString();
        final desc = item.name.length > fmt.colDesc
            ? item.name.substring(0, fmt.colDesc)
            : item.name;
        final pUnit = currencyFormat.format(item.price);
        final t = currencyFormat.format(item.total);
        commands.addAll(
            _formatText(_buildTicketItemRow(fmt, cant, desc, pUnit, t)));
        commands.addAll(_newLine());
      }

      commands.addAll(_formatText(_dashLine(fmt)));
      commands.addAll(_newLine());
      commands
          .addAll(_formatText(_lineLeftRight(fmt, 'SUBTOTAL:', subtotalStr)));
      commands.addAll(_newLine());
      final hasVat19 = (vatAt19 ?? 0) > 0;
      final hasVat5 = (vatAt5 ?? 0) > 0;
      if (hasVat19) {
        commands.addAll(_formatText(_lineLeftRight(
            fmt, 'IVA (19%):', currencyFormat.format(vatAt19!))));
        commands.addAll(_newLine());
      }
      if (hasVat5) {
        commands.addAll(_formatText(
            _lineLeftRight(fmt, 'IVA (5%):', currencyFormat.format(vatAt5!))));
        commands.addAll(_newLine());
      }
      if (!hasVat19 && !hasVat5) {
        if (taxes > 0) {
          commands.addAll(_formatText(_lineLeftRight(fmt, 'IVA:', taxesStr)));
          commands.addAll(_newLine());
        } else {
          commands.addAll(_formatText(_lineLeftRight(fmt, 'IVA:', '\$0')));
          commands.addAll(_newLine());
        }
      }
      commands.addAll(_formatText(_dashLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_boldOn);
      commands.addAll(_formatText(_lineLeftRight(fmt, 'TOTAL:', totalStr)));
      commands.addAll(_newLine());
      commands.addAll(_boldOff);
      commands.addAll(_formatText(_separatorLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_newLine());
      final saleMethod = (sale.paymentMethod ?? '').toLowerCase();
      final isCreditSale = saleMethod == 'crédito' || saleMethod == 'credito';
      final creditAbono = (creditDownPayment ?? 0).clamp(0.0, total);
      final creditPending =
          (creditPendingAmount ?? (total - creditAbono)).clamp(0.0, total);
      final creditMethodLabel =
          creditAbono > 0 ? (creditPaymentMethod ?? 'NO DEFINIDO') : 'N/A';
      final paymentLabel = isCreditSale
          ? (creditAbono > 0
              ? (creditPaymentMethod ?? 'ABONO').toUpperCase()
              : 'CREDITO SIN ABONO')
          : (sale.paymentMethod ?? 'EFECTIVO').toUpperCase();
      commands
          .addAll(_formatText(_lineLeftRight(fmt, 'FORMA DE PAGO:', paymentLabel)));
      commands.addAll(_newLine());
      if (isCreditSale) {
        commands.addAll(_boldOn);
        commands
            .addAll(_formatText('*** VENTA A CRÉDITO - FIRMA DEL CLIENTE ***'));
        commands.addAll(_newLine());
        commands.addAll(_boldOff);
        commands.addAll(_formatText(
            _lineLeftRight(fmt, 'TOTAL A CREDITO:', currencyFormat.format(total))));
        commands.addAll(_newLine());
        commands.addAll(_formatText(_lineLeftRight(
            fmt, 'ABONO INICIAL:', currencyFormat.format(creditAbono))));
        commands.addAll(_newLine());
        commands.addAll(_formatText(_lineLeftRight(fmt, 'MEDIO PAGO ABONO:',
            creditMethodLabel.toUpperCase())));
        commands.addAll(_newLine());
        commands.addAll(_boldOn);
        commands.addAll(_formatText(_lineLeftRight(
            fmt, 'SALDO PENDIENTE:', currencyFormat.format(creditPending))));
        commands.addAll(_newLine());
        commands.addAll(_boldOff);
      }
      if (!isCreditSale && receivedAmount != null && receivedAmount >= 0) {
        commands.addAll(_formatText(_lineLeftRight(
            fmt, 'Recibido:', currencyFormat.format(receivedAmount))));
        commands.addAll(_newLine());
      }
      if (!isCreditSale && changeAmount != null && changeAmount >= 0) {
        commands.addAll(_formatText(_lineLeftRight(
            fmt, 'Su cambio:', currencyFormat.format(changeAmount))));
        commands.addAll(_newLine());
      }
      commands.addAll(_newLine());
      commands.addAll(_formatText(_separatorLine(fmt)));
      commands.addAll(_newLine());
      commands.addAll(_alignCenter);
      // Pie de página desde configuración de empresa (cada línea del texto de pie)
      final footerText = companyConfig.footerText.trim();
      if (footerText.isNotEmpty) {
        for (final line in footerText.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            commands.addAll(_formatText(trimmed));
            commands.addAll(_newLine());
          }
        }
      } else {
        commands.addAll(_formatText('Gracias por su compra'));
        commands.addAll(_newLine());
      }
      commands.addAll(_formatText(_separatorLine(fmt)));
      commands.addAll(_newLine());

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
      commands.addAll(_formatText('Impresora: $_printerName'));
      commands.addAll(_newLine());
      commands.addAll(_formatText('Puerto: $_printerPort'));
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

  /// Convierte texto a ASCII para impresoras térmicas que no soportan UTF-8 (evita Ó→caracter raro, cortes de CANT/TOTAL).
  static String _toReceiptAscii(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('Á', 'A')
        .replaceAll('á', 'a')
        .replaceAll('É', 'E')
        .replaceAll('é', 'e')
        .replaceAll('Í', 'I')
        .replaceAll('í', 'i')
        .replaceAll('Ó', 'O')
        .replaceAll('ó', 'o')
        .replaceAll('Ú', 'U')
        .replaceAll('ú', 'u')
        .replaceAll('Ñ', 'N')
        .replaceAll('ñ', 'n')
        .replaceAll('¡', '')
        .replaceAll('¿', '');
  }

  List<int> _formatText(String text) {
    return _toReceiptAscii(text).codeUnits;
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
    int rightWidth = 48 - leftWidth - centerWidth;
    return left.padRight(leftWidth).substring(0, leftWidth) +
        center.padRight(centerWidth).substring(0, centerWidth) +
        right.padLeft(rightWidth).substring(0, rightWidth);
  }

  String _lineWithMargin(ReceiptFormat fmt, String char) {
    final cw = fmt.paperWidth - fmt.marginLeft;
    return (' ' * fmt.marginLeft) + (char * cw);
  }

  String _separatorLine(ReceiptFormat fmt) => _lineWithMargin(fmt, '=');
  String _dashLine(ReceiptFormat fmt) => _lineWithMargin(fmt, '-');

  /// Línea con texto izquierda y derecha. Siempre devuelve exactamente paperWidth caracteres para evitar descuadre.
  String _lineLeftRight(ReceiptFormat fmt, String left, String right) {
    final cw = fmt.paperWidth - fmt.marginLeft;
    String l = left.length > cw ? left.substring(0, cw) : left;
    String r = right.length > cw ? right.substring(0, cw) : right;
    if (l.length + r.length > cw) {
      if (r.length >= cw ~/ 2) {
        l = l.substring(0, (cw - r.length).clamp(1, cw));
      } else {
        r = r.padLeft(cw - l.length);
      }
    }
    final space = cw - l.length - r.length;
    return (' ' * fmt.marginLeft) + l + (' ' * (space > 0 ? space : 0)) + r;
  }

  /// Fila de ítem: CANT + DESCRIPCIÓN + P.UNIT + TOTAL. Siempre paperWidth caracteres.
  String _buildTicketItemRow(
      ReceiptFormat fmt, String cant, String desc, String pUnit, String total) {
    final gap = ' ' * fmt.spaceBetweenPriceAndCant.clamp(1, 4);
    final d = desc.length > fmt.colDesc
        ? desc.substring(0, fmt.colDesc)
        : desc.padRight(fmt.colDesc);
    final c = cant.length > fmt.colCant
        ? cant.substring(0, fmt.colCant)
        : cant.padLeft(fmt.colCant);
    final p = pUnit.length > fmt.colPrice
        ? pUnit.substring(pUnit.length - fmt.colPrice)
        : pUnit.padLeft(fmt.colPrice);
    final t = total.length > fmt.colSubtotal
        ? total.substring(total.length - fmt.colSubtotal)
        : total.padLeft(fmt.colSubtotal);
    final row = (' ' * fmt.marginLeft) + c + gap + d + gap + p + gap + t;
    return row.length > fmt.paperWidth
        ? row.substring(0, fmt.paperWidth)
        : row.padRight(fmt.paperWidth);
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
      await Future.delayed(const Duration(seconds: 1));
      return await _detectPrinter();
    } catch (e) {
      print('Error reconectando: $e');
      return false;
    }
  }

  // Simular impresión para pruebas - Misma plantilla que impresión real
  void _simulatePrintReceipt(Sale sale, List<CartItem> items, double subtotal,
      double taxes, double total,
      {CompanyConfig? companyConfig,
      Customer? customer,
      Client? client,
      bool isReprint = false,
      String? reprintReason,
      required ReceiptFormat fmt,
      double? vatAt19,
      double? vatAt5}) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('HH:mm:ss');
    final NumberFormat currencyFormat = NumberFormat('#,##0.00', 'es_CO');
    final subtotalStr = currencyFormat.format(subtotal);
    final taxesStr = currencyFormat.format(taxes);
    final totalStr = currencyFormat.format(total);

    print('');
    print(_separatorLine(fmt));
    print('        ${companyConfig?.companyName ?? 'SMART SELLER'}');
    print('        ${companyConfig?.address ?? 'Dirección'}');
    print('        Tel: ${companyConfig?.phone ?? 'Teléfono'}');
    if (companyConfig?.email != null) print('        ${companyConfig!.email}');
    if (companyConfig?.taxId != null) {
      print('        NIT: ${companyConfig!.taxId}');
    }
    print(_separatorLine(fmt));
    print(_lineLeftRight(fmt, 'Fecha: ${dateFormatter.format(sale.date)}',
        'Hora: ${timeFormatter.format(sale.date)}'));
    print(_lineLeftRight(fmt, 'Ticket #: ${_generateInvoiceNumber()}', ''));
    print(_lineLeftRight(fmt, 'Cajero: ${sale.user}', ''));
    print(_lineLeftRight(fmt, 'Caja: 01', ''));
    print('');
    print(_dashLine(fmt));
    print('${' ' * fmt.marginLeft}ARTÍCULOS');
    print(_dashLine(fmt));
    print(_buildTicketItemRow(fmt, 'Cant.', 'Descripción', 'P.Unit', 'Total'));
    print(_dashLine(fmt));
    for (CartItem item in items) {
      final cant =
          '${item.quantity.toStringAsFixed(item.quantity == item.quantity.truncateToDouble() ? 0 : 2)}x';
      final desc = item.name.length > fmt.colDesc
          ? item.name.substring(0, fmt.colDesc)
          : item.name;
      print(_buildTicketItemRow(
          fmt,
          cant,
          desc,
          '\$${currencyFormat.format(item.price)}',
          '\$${currencyFormat.format(item.total)}'));
    }
    print(_dashLine(fmt));
    print('');
    final discountVal = sale.discount ?? 0;
    final discountStr = currencyFormat.format(discountVal);
    print(_lineLeftRight(fmt, 'SUBTOTAL:', '\$$subtotalStr'));
    final hasVat19 = (vatAt19 ?? 0) > 0;
    final hasVat5 = (vatAt5 ?? 0) > 0;
    if (hasVat19)
      print(_lineLeftRight(
          fmt, 'IVA (19%):', '\$${currencyFormat.format(vatAt19!)}'));
    if (hasVat5)
      print(_lineLeftRight(
          fmt, 'IVA (5%):', '\$${currencyFormat.format(vatAt5!)}'));
    if (!hasVat19 && !hasVat5) {
      if (taxes > 0) {
        print(_lineLeftRight(fmt, 'IVA:', '\$$taxesStr'));
      } else {
        print(_lineLeftRight(fmt, 'IVA:', '\$0'));
      }
    }
    print(_lineLeftRight(fmt, 'DESCUENTO:', '\$$discountStr'));
    print(_dashLine(fmt));
    print(_lineLeftRight(fmt, 'TOTAL A PAGAR:', '\$$totalStr'));
    print(_separatorLine(fmt));
    print('');
    print('${' ' * fmt.marginLeft}MEDIO DE PAGO');
    print(_dashLine(fmt));
    if (sale.paymentBreakdown != null && sale.paymentBreakdown!.isNotEmpty) {
      for (final part in sale.paymentBreakdown!) {
        print(_lineLeftRight(
            fmt, part.method, '\$${currencyFormat.format(part.amount)}'));
      }
      print(_lineLeftRight(fmt, 'Cambio:', '\$0.00'));
    } else {
      final method = sale.paymentMethod ?? 'Efectivo';
      print(_lineLeftRight(fmt, method, '\$$totalStr'));
      print(_lineLeftRight(fmt, 'Cambio:', '\$0.00'));
    }
    print(_dashLine(fmt));
    print('');
    print(_lineLeftRight(fmt, 'Cliente:',
        customer?.name ?? client?.businessName ?? 'Público General'));
    print(_lineLeftRight(
        fmt, 'Puntos acumulados:', '${customer?.accumulatedPoints ?? 0}'));
    print('');
    print(_separatorLine(fmt));
    for (final line
        in (companyConfig?.footerText ?? 'Gracias por su compra').split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) print(t);
    }
    if (companyConfig?.website != null &&
        companyConfig!.website!.trim().isNotEmpty) {
      print(companyConfig.website!.trim());
    }
    print('Conserve su ticket');
    print('Válido para cambios: 7 días');
    print(_separatorLine(fmt));
    print('');
    print('${' ' * fmt.marginLeft}Software POS: SMART SELLER');
    print('');
  }

  // Abrir cajón monedero
  Future<bool> openCashDrawer({int drawer = 1}) async {
    try {
      print('💰 Abriendo cajón monedero $drawer...');

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
