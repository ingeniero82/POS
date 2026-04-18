import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

enum EstadoConexionBalanza { desconectado, conectando, conectado, error }

class BalanzaService extends ChangeNotifier {
  SerialPort? _port;
  SerialPortReader? _reader;
  Timer? _watchdog;
  Timer? _pollingTimer;
  Timer? _flushTimer;
  bool _manualDisconnect = false;

  final _pesoController = StreamController<double?>.broadcast();
  Stream<double?> get pesosStream => _pesoController.stream;
  final _tramasController = StreamController<String>.broadcast();
  Stream<String> get tramasStream => _tramasController.stream;

  EstadoConexionBalanza _estado = EstadoConexionBalanza.desconectado;
  EstadoConexionBalanza get estado => _estado;

  double? _ultimoPeso;
  double? get ultimoPeso => _ultimoPeso;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  String? _puertoActual;
  int _baudRateActual = 9600;
  int _bitsActual = 8;
  int _stopBitsActual = 1;
  int _parityActual = SerialPortParity.none;
  String _comandoLectura = '';
  String _terminadorLectura = '\r\n';
  int _intervaloLecturaMs = 1000;
  bool _pollingHabilitado = false;

  final List<int> _byteBuffer = <int>[];

  static List<String> puertosDisponibles() => SerialPort.availablePorts;

  void configurarLecturaActiva({
    required bool habilitado,
    required String comando,
    String terminador = '\r\n',
    int intervaloMs = 1000,
  }) {
    _pollingHabilitado = habilitado;
    _comandoLectura = comando.trim();
    _terminadorLectura = terminador;
    _intervaloLecturaMs = intervaloMs < 200 ? 200 : intervaloMs;
    _iniciarPollingSiAplica();
  }

  /// Pide una lectura a la balanza (comando configurado o `W` si no hay comando).
  Future<bool> solicitarLecturaPeso() async {
    if (_estado != EstadoConexionBalanza.conectado) {
      _errorMsg = 'No hay conexión activa para enviar comandos.';
      notifyListeners();
      return false;
    }
    if (_comandoLectura.isNotEmpty) {
      return enviarComando(_comandoLectura, terminador: _terminadorLectura);
    }
    return enviarComando('W', terminador: _terminadorLectura);
  }

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
    _bitsActual = bits;
    _stopBitsActual = stopBits;
    _parityActual = parity;

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
      _iniciarPollingSiAplica();
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
        _emitirChunkCrudo(data);
        _procesarBuffer();
        _programarFlushBuffer();
      },
      onError: (Object e) {
        _errorMsg = 'Error de lectura serial: $e';
        _setEstado(EstadoConexionBalanza.error);
      },
      onDone: () {
        if (!_manualDisconnect && _estado == EstadoConexionBalanza.conectado) {
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

      final trama = String.fromCharCodes(_byteBuffer.sublist(0, idx)).trim();
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

  void _emitirChunkCrudo(Uint8List data) {
    // Algunas balanzas no mandan CR/LF; este canal ayuda a diagnosticar
    // que sí hay bytes entrantes aunque no haya "tramas" delimitadas.
    final ascii = String.fromCharCodes(data)
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n');
    if (ascii.trim().isNotEmpty) {
      _tramasController.add('[RAW] $ascii');
    } else {
      final hex =
          data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      _tramasController.add('[HEX] $hex');
    }
  }

  void _programarFlushBuffer() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 180), () {
      if (_byteBuffer.isEmpty) return;
      final trama = String.fromCharCodes(_byteBuffer).trim();
      _byteBuffer.clear();
      if (trama.isNotEmpty) {
        _parsearTrama(trama);
      }
    });
  }

  void _parsearTrama(String trama) {
    _tramasController.add(trama);
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
        await conectar(
          puerto: port,
          baudRate: _baudRateActual,
          bits: _bitsActual,
          stopBits: _stopBitsActual,
          parity: _parityActual,
        );
      }
    });
  }

  void _iniciarPollingSiAplica() {
    _pollingTimer?.cancel();
    if (!_pollingHabilitado || _comandoLectura.isEmpty) return;
    if (_estado != EstadoConexionBalanza.conectado) return;

    _pollingTimer =
        Timer.periodic(Duration(milliseconds: _intervaloLecturaMs), (
      _,
    ) {
      unawaited(enviarComandoLectura());
    });
  }

  Future<bool> enviarComandoLectura() async {
    if (_estado != EstadoConexionBalanza.conectado) {
      _errorMsg = 'No hay conexión activa para enviar comandos.';
      notifyListeners();
      return false;
    }
    if (_comandoLectura.isEmpty) {
      _errorMsg = 'No hay comando configurado.';
      notifyListeners();
      return false;
    }
    return enviarComando(_comandoLectura, terminador: _terminadorLectura);
  }

  Future<bool> enviarComando(
    String comando, {
    String terminador = '\r\n',
  }) async {
    final port = _port;
    if (port == null || !(port.isOpen)) {
      _errorMsg = 'Puerto serial no disponible.';
      notifyListeners();
      return false;
    }

    try {
      final payload = '$comando$terminador';
      final bytes = payload.codeUnits;
      final enviados = port.write(Uint8List.fromList(bytes));
      if (enviados <= 0) {
        _errorMsg = 'El puerto no aceptó datos.';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      _errorMsg = 'Error enviando comando serial: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> desconectar({bool notify = true}) async {
    _manualDisconnect = true;
    _watchdog?.cancel();
    _watchdog = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;

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
    unawaited(_tramasController.close());
    super.dispose();
  }
}
