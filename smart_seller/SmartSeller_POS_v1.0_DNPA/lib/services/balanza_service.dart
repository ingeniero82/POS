import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EstadoConexionBalanza { desconectado, conectando, conectado, error }

/// Quita STX/ETX y bytes de control; evita que el regex tome dígitos de basura antes del peso real.
String _sanearTramaBalanza(String s) =>
    s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

class BalanzaService extends ChangeNotifier {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _serialSub;
  Timer? _watchdog;
  Timer? _pollingTimer;
  Timer? _flushTimer;
  bool _manualDisconnect = false;
  DateTime? _ultimoSolicitarPeso;

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

  /// Intervalo (ms) del último `configurarLecturaActiva` / prefs; sirve al POS para alinear sondeo con diagnóstico.
  int get intervaloLecturaMsConfigurado => _intervaloLecturaMs;

  /// Si el servicio ya está haciendo polling (lectura activa + comando), no hace falta duplicar pedidos desde el POS.
  bool get lecturaContinuaDelServicioActiva =>
      _pollingHabilitado &&
      _comandoLectura.isNotEmpty &&
      _estado == EstadoConexionBalanza.conectado;

  final List<int> _byteBuffer = <int>[];

  static List<String> puertosDisponibles() => SerialPort.availablePorts;

  static const _kPrefPort = 'balanza_pref_puerto';
  static const _kPrefBaud = 'balanza_pref_baud';
  static const _kPrefBits = 'balanza_pref_bits';
  static const _kPrefStop = 'balanza_pref_stop';
  static const _kPrefParity = 'balanza_pref_parity';
  static const _kPrefComando = 'balanza_pref_comando';
  static const _kPrefTermIdx = 'balanza_pref_term_idx';
  static const _kPrefPoll = 'balanza_pref_poll';
  static const _kPrefInterval = 'balanza_pref_interval_ms';

  static String _terminadorDesdeIndice(int idx) {
    return switch (idx) {
      1 => '\r',
      2 => '\n',
      3 => '\r\n',
      _ => '',
    };
  }

  static int _indiceTerminador(String t) {
    if (t == '\r') return 1;
    if (t == '\n') return 2;
    if (t == '\r\n') return 3;
    return 0;
  }

  /// Guarda la última conexión exitosa (diagnóstico) para reconectar en POS al abrir ventas.
  Future<void> persistirUltimaConfigExitosa({
    required String puerto,
    required int baudRate,
    required int bits,
    required int stopBits,
    required int parity,
    required String comando,
    required String terminador,
    required bool lecturaActiva,
    required int intervaloMs,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefPort, puerto);
    await p.setInt(_kPrefBaud, baudRate);
    await p.setInt(_kPrefBits, bits);
    await p.setInt(_kPrefStop, stopBits);
    await p.setInt(_kPrefParity, parity);
    await p.setString(_kPrefComando, comando.trim());
    await p.setInt(_kPrefTermIdx, _indiceTerminador(terminador));
    await p.setBool(_kPrefPoll, lecturaActiva);
    await p.setInt(_kPrefInterval, intervaloMs < 200 ? 200 : intervaloMs);
  }

  /// Si hay prefs guardadas y no hay COM abierto, reconecta (útil al entrar al POS).
  Future<void> intentarReconexionDesdePrefs() async {
    if (_estado == EstadoConexionBalanza.conectado) return;
    final p = await SharedPreferences.getInstance();
    final puerto = p.getString(_kPrefPort);
    if (puerto == null || puerto.isEmpty) return;
    final baud = p.getInt(_kPrefBaud) ?? 9600;
    final bits = p.getInt(_kPrefBits) ?? 8;
    final stop = p.getInt(_kPrefStop) ?? 1;
    final parity = p.getInt(_kPrefParity) ?? SerialPortParity.none;
    final cmd = p.getString(_kPrefComando) ?? 'W';
    final term = _terminadorDesdeIndice(p.getInt(_kPrefTermIdx) ?? 3);
    // Por defecto lectura continua (como en fruver); si el usuario la desactivó en prefs, se respeta false guardado.
    final poll = p.getBool(_kPrefPoll) ?? true;
    final interval = p.getInt(_kPrefInterval) ?? 1000;
    final ok = await conectar(
      puerto: puerto,
      baudRate: baud,
      bits: bits,
      stopBits: stop,
      parity: parity,
    );
    if (ok) {
      configurarLecturaActiva(
        habilitado: poll,
        comando: cmd,
        terminador: term,
        intervaloMs: interval,
      );
    }
  }

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
    final ahora = DateTime.now();
    // Muy agresivo en ventas: muchas balanzas toleran ~30–60 ms entre W; 200 ms retrasaba demasiado el peso en POS.
    if (_ultimoSolicitarPeso != null &&
        ahora.difference(_ultimoSolicitarPeso!).inMilliseconds < 45) {
      return true;
    }
    _ultimoSolicitarPeso = ahora;
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
    final r = _reader;
    if (r == null) return;
    unawaited(_serialSub?.cancel());
    _serialSub = r.stream.listen(
      (Uint8List data) {
        _byteBuffer.addAll(data);
        _emitirChunkCrudo(data);
        _procesarBuffer();
        _intentarPesoDesdeBufferSinSaltoLinea();
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
    _flushTimer = Timer(const Duration(milliseconds: 70), () {
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
    // Formatos comunes: +001.234kg, ST,GS,+1.234kg, 1.234 (sin kg).
    // No usar el *primer* `kg` en la trama: a veces hay un peso residual/tara y luego el real (p. ej. 0.01 + 00.150).
    final limpia = _sanearTramaBalanza(trama.trim());
    final conPuntos = limpia.replaceAll(',', '.');
    double? valor;

    final kgRe = RegExp(
      r'([+-]?\d+\.?\d*)\s*kge?\b',
      caseSensitive: false,
    );
    final kgMatches = kgRe.allMatches(conPuntos).toList();
    if (kgMatches.isNotEmpty) {
      valor = double.tryParse(kgMatches.last.group(1)!);
    }

    if (valor == null) {
      final compacto = conPuntos.replaceAll(' ', '');
      final re = RegExp(r'[+-]?\d+\.\d+|[+-]?\d+');
      final ms = re.allMatches(compacto).toList();
      for (var i = ms.length - 1; i >= 0; i--) {
        final raw = ms[i].group(0);
        if (raw == null) continue;
        final v = double.tryParse(raw);
        if (v != null && v >= -9999 && v <= 99999) {
          valor = v;
          break;
        }
      }
    }

    if (valor != null && valor >= -9999 && valor <= 99999) {
      if (_ultimoPeso != null && (valor - _ultimoPeso!).abs() < 1e-6) {
        return;
      }
      _ultimoPeso = valor;
      _pesoController.add(valor);
      notifyListeners();
    }
  }

  /// Si la trama llega partida y aún no hay CR/LF, intenta extraer `…00.270kg` del buffer acumulado.
  void _intentarPesoDesdeBufferSinSaltoLinea() {
    if (_byteBuffer.length < 6) return;
    final s = _sanearTramaBalanza(String.fromCharCodes(_byteBuffer));
    final lower = s.toLowerCase();
    if (!lower.contains('kg')) return;
    final ki = lower.lastIndexOf('kg');
    if (ki < 1) return;
    final start = ki >= 40 ? ki - 40 : 0;
    final window = s.substring(start, ki + 2).replaceAll(',', '.');
    final matches = RegExp(
      r'([+-]?\d+\.?\d*)\s*kge?\b',
      caseSensitive: false,
    ).allMatches(window);
    if (matches.isEmpty) return;
    final raw = matches.last.group(1) ?? '';
    final v = double.tryParse(raw);
    if (v == null || v < -9999 || v > 99999) return;
    if (_ultimoPeso != null && (v - _ultimoPeso!).abs() < 1e-6) {
      return;
    }
    _ultimoPeso = v;
    _pesoController.add(v);
    notifyListeners();
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
      await _serialSub?.cancel();
    } catch (_) {}
    _serialSub = null;

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
