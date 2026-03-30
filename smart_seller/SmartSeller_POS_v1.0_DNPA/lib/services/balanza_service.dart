import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

enum EstadoConexionBalanza { desconectado, conectando, conectado, error }

class BalanzaService extends ChangeNotifier {
  SerialPort? _port;
  SerialPortReader? _reader;
  Timer? _watchdog;
  bool _manualDisconnect = false;

  final _pesoController = StreamController<double?>.broadcast();
  Stream<double?> get pesosStream => _pesoController.stream;

  EstadoConexionBalanza _estado = EstadoConexionBalanza.desconectado;
  EstadoConexionBalanza get estado => _estado;

  double? _ultimoPeso;
  double? get ultimoPeso => _ultimoPeso;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  String? _puertoActual;
  int _baudRateActual = 9600;

  final List<int> _byteBuffer = <int>[];

  static List<String> puertosDisponibles() => SerialPort.availablePorts;

  Future<bool> conectar({
    required String puerto,
    int baudRate = 9600,
    int bits = 8,
    int stopBits = 1,
    int parity = SerialPortParity.none,
  }) async {
    _manualDisconnect = false;
    _setEstado(EstadoConexionBalanza.conectando);
    _errorMsg = null;
    _puertoActual = puerto;
    _baudRateActual = baudRate;

    try {
      await desconectar(notify: false);

      _port = SerialPort(puerto);
      final config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = bits
        ..stopBits = stopBits
        ..parity = parity
        ..setFlowControl(SerialPortFlowControl.none);

      if (!_port!.openReadWrite()) {
        throw Exception(
          'No se pudo abrir $puerto. Verifica permisos o uso por otra app.',
        );
      }

      _port!.config = config;
      _reader = SerialPortReader(_port!, timeout: 2000);
      _leerDatos();
      _iniciarWatchdog();
      _setEstado(EstadoConexionBalanza.conectado);
      return true;
    } catch (e) {
      _errorMsg = e.toString();
      _setEstado(EstadoConexionBalanza.error);
      return false;
    }
  }

  void _leerDatos() {
    _byteBuffer.clear();
    _reader?.stream.listen(
      (Uint8List data) {
        _byteBuffer.addAll(data);
        _procesarBuffer();
      },
      onError: (Object e) {
        _errorMsg = 'Error de lectura serial: $e';
        _setEstado(EstadoConexionBalanza.error);
      },
      onDone: () {
        if (!_manualDisconnect &&
            _estado == EstadoConexionBalanza.conectado) {
          _setEstado(EstadoConexionBalanza.desconectado);
        }
      },
    );
  }

  void _procesarBuffer() {
    while (true) {
      int idx = -1;
      for (int i = 0; i < _byteBuffer.length; i++) {
        if (_byteBuffer[i] == 0x0A || _byteBuffer[i] == 0x0D) {
          idx = i;
          break;
        }
      }
      if (idx == -1) break;

      final trama =
          String.fromCharCodes(_byteBuffer.sublist(0, idx)).trim();
      _byteBuffer.removeRange(0, idx + 1);

      if (_byteBuffer.isNotEmpty &&
          (_byteBuffer[0] == 0x0A || _byteBuffer[0] == 0x0D)) {
        _byteBuffer.removeAt(0);
      }

      if (trama.isNotEmpty) {
        _parsearTrama(trama);
      }
    }
  }

  void _parsearTrama(String trama) {
    // Formatos comunes:
    //   +001.234kg
    //   ST,GS,+1.234kg
    //   -000.050 kg
    final normalized = trama.replaceAll(' ', '');
    final regex = RegExp(r'([+-]?\d+[.,]?\d*)');
    final matches = regex.allMatches(normalized);

    for (final m in matches) {
      final raw = (m.group(1) ?? '').replaceAll(',', '.');
      final valor = double.tryParse(raw);
      if (valor != null && valor >= -9999 && valor <= 99999) {
        _ultimoPeso = valor;
        _pesoController.add(valor);
        return;
      }
    }
  }

  void _iniciarWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_manualDisconnect) return;
      if (_estado == EstadoConexionBalanza.error ||
          _estado == EstadoConexionBalanza.desconectado) {
        final port = _puertoActual;
        if (port == null || port.isEmpty) return;
        await Future.delayed(const Duration(milliseconds: 800));
        await conectar(puerto: port, baudRate: _baudRateActual);
      }
    });
  }

  Future<void> desconectar({bool notify = true}) async {
    _manualDisconnect = true;
    _watchdog?.cancel();
    _watchdog = null;

    try {
      _reader?.close();
    } catch (_) {}
    _reader = null;

    try {
      if (_port?.isOpen ?? false) {
        _port?.close();
      }
    } catch (_) {}

    try {
      _port?.dispose();
    } catch (_) {}
    _port = null;

    _byteBuffer.clear();
    _ultimoPeso = null;

    if (notify) {
      _setEstado(EstadoConexionBalanza.desconectado);
    } else {
      _estado = EstadoConexionBalanza.desconectado;
    }
  }

  void _setEstado(EstadoConexionBalanza nuevo) {
    _estado = nuevo;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(desconectar());
    unawaited(_pesoController.close());
    super.dispose();
  }
}
