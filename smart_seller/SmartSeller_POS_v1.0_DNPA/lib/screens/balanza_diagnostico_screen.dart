import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:get/get.dart';

import '../services/balanza_service.dart';

class BalanzaDiagnosticoScreen extends StatefulWidget {
  const BalanzaDiagnosticoScreen({super.key});

  @override
  State<BalanzaDiagnosticoScreen> createState() =>
      _BalanzaDiagnosticoScreenState();
}

class _BalanzaDiagnosticoScreenState extends State<BalanzaDiagnosticoScreen> {
  final BalanzaService _balanza = Get.find<BalanzaService>();
  final List<int> _baudRates = const [2400, 4800, 9600, 19200, 38400];
  final List<int> _bitsOpciones = const [7, 8];
  final List<int> _stopBitsOpciones = const [1, 2];
  final List<MapEntry<int, String>> _paridadOpciones = const [
    MapEntry(SerialPortParity.none, 'None'),
    MapEntry(SerialPortParity.odd, 'Odd'),
    MapEntry(SerialPortParity.even, 'Even'),
  ];
  final List<MapEntry<String, String>> _terminadorOpciones = const [
    MapEntry('', 'Ninguno'),
    MapEntry('\r', 'CR'),
    MapEntry('\n', 'LF'),
    MapEntry('\r\n', 'CRLF'),
  ];
  final TextEditingController _comandoController = TextEditingController(
    text: 'W',
  );

  List<String> _puertos = <String>[];
  String? _puertoSeleccionado;
  int _baudRate = 9600;
  int _bits = 8;
  int _stopBits = 1;
  int _paridad = SerialPortParity.none;
  String _terminador = '\r\n';
  bool _lecturaActiva = false;
  int _intervaloMs = 1000;
  final List<String> _ultimasTramas = <String>[];
  StreamSubscription<String>? _tramasSub;

  @override
  void initState() {
    super.initState();
    _balanza.addListener(_onServiceChanged);
    _refrescarPuertos();
    _tramasSub = _balanza.tramasStream.listen((trama) {
      if (!mounted || trama.isEmpty) return;
      setState(() {
        if (_ultimasTramas.length >= 8) {
          _ultimasTramas.removeAt(0);
        }
        _ultimasTramas.add(trama);
      });
    });
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refrescarPuertos() async {
    final ports = BalanzaService.puertosDisponibles();
    setState(() {
      _puertos = ports;
      if (_puertoSeleccionado == null && ports.isNotEmpty) {
        _puertoSeleccionado = ports.first;
      } else if (_puertoSeleccionado != null &&
          !ports.contains(_puertoSeleccionado)) {
        _puertoSeleccionado = ports.isNotEmpty ? ports.first : null;
      }
    });
  }

  Future<void> _toggleConexion() async {
    if (_balanza.estado == EstadoConexionBalanza.conectado) {
      await _balanza.desconectar();
      return;
    }
    if (_puertoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un puerto COM.')),
      );
      return;
    }
    final ok = await _balanza.conectar(
      puerto: _puertoSeleccionado!,
      baudRate: _baudRate,
      bits: _bits,
      stopBits: _stopBits,
      parity: _paridad,
    );
    if (!ok || !mounted) return;
    _aplicarConfiguracionLectura();
  }

  void _aplicarConfiguracionLectura() {
    _balanza.configurarLecturaActiva(
      habilitado: _lecturaActiva,
      comando: _comandoController.text,
      terminador: _terminador,
      intervaloMs: _intervaloMs,
    );
    _persistenciaSiConectado();
  }

  void _persistenciaSiConectado() {
    if (_balanza.estado != EstadoConexionBalanza.conectado) return;
    final puerto = _puertoSeleccionado;
    if (puerto == null || puerto.isEmpty) return;
    unawaited(_balanza.persistirUltimaConfigExitosa(
      puerto: puerto,
      baudRate: _baudRate,
      bits: _bits,
      stopBits: _stopBits,
      parity: _paridad,
      comando: _comandoController.text,
      terminador: _terminador,
      lecturaActiva: _lecturaActiva,
      intervaloMs: _intervaloMs,
    ));
  }

  Future<void> _enviarComandoManual() async {
    final ok = await _balanza.enviarComando(
      _comandoController.text,
      terminador: _terminador,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_balanza.errorMsg ?? 'No se pudo enviar comando')),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_tramasSub?.cancel());
    _balanza.removeListener(_onServiceChanged);
    _comandoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conectado = _balanza.estado == EstadoConexionBalanza.conectado;

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico de balanza')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _puertoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Puerto COM',
                      border: OutlineInputBorder(),
                    ),
                    items: _puertos
                        .map(
                          (p) => DropdownMenuItem<String>(
                              value: p, child: Text(p)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _puertoSeleccionado = v),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Refrescar puertos',
                  onPressed: _refrescarPuertos,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _baudRate,
                    decoration: const InputDecoration(
                      labelText: 'Baud rate',
                      border: OutlineInputBorder(),
                    ),
                    items: _baudRates
                        .map(
                          (b) => DropdownMenuItem<int>(
                            value: b,
                            child: Text('$b bps'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _baudRate = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _toggleConexion,
                  icon: Icon(conectado ? Icons.link_off : Icons.link),
                  label: Text(conectado ? 'Desconectar' : 'Conectar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _bits,
                    decoration: const InputDecoration(
                      labelText: 'Bits datos',
                      border: OutlineInputBorder(),
                    ),
                    items: _bitsOpciones
                        .map(
                          (b) => DropdownMenuItem<int>(
                            value: b,
                            child: Text('$b'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _bits = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _paridad,
                    decoration: const InputDecoration(
                      labelText: 'Paridad',
                      border: OutlineInputBorder(),
                    ),
                    items: _paridadOpciones
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.key,
                            child: Text(p.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _paridad = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _stopBits,
                    decoration: const InputDecoration(
                      labelText: 'Stop bits',
                      border: OutlineInputBorder(),
                    ),
                    items: _stopBitsOpciones
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s,
                            child: Text('$s'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _stopBits = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: switch (_balanza.estado) {
                    EstadoConexionBalanza.conectado => Colors.green,
                    EstadoConexionBalanza.error => Colors.red,
                    EstadoConexionBalanza.conectando => Colors.orange,
                    EstadoConexionBalanza.desconectado => Colors.grey,
                  },
                ),
                const SizedBox(width: 8),
                Text('Estado: ${_balanza.estado.name}'),
              ],
            ),
            if (_balanza.errorMsg != null) ...[
              const SizedBox(height: 6),
              Text(
                _balanza.errorMsg!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _comandoController,
              decoration: const InputDecoration(
                labelText: 'Comando de lectura',
                hintText: 'Ej: W',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _aplicarConfiguracionLectura(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _intervaloMs,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo lectura',
                      border: OutlineInputBorder(),
                    ),
                    items: const [300, 500, 1000, 1500, 2000]
                        .map(
                          (ms) => DropdownMenuItem<int>(
                            value: ms,
                            child: Text('$ms ms'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _intervaloMs = v);
                      _aplicarConfiguracionLectura();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _terminador,
                    decoration: const InputDecoration(
                      labelText: 'Terminador',
                      border: OutlineInputBorder(),
                    ),
                    items: _terminadorOpciones
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t.key,
                            child: Text(t.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _terminador = v);
                      _aplicarConfiguracionLectura();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    value: _lecturaActiva,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lectura activa'),
                    onChanged: (v) {
                      setState(() => _lecturaActiva = v);
                      _aplicarConfiguracionLectura();
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _balanza.estado == EstadoConexionBalanza.conectado
                    ? _enviarComandoManual
                    : null,
                icon: const Icon(Icons.send),
                label: const Text('Enviar comando ahora'),
              ),
            ),
            const Spacer(),
            Center(
              child: StreamBuilder<double?>(
                stream: _balanza.pesosStream,
                builder: (context, snapshot) {
                  final value = snapshot.data ?? _balanza.ultimoPeso;
                  return Column(
                    children: [
                      Text(
                        value != null ? value.toStringAsFixed(3) : '---',
                        style: const TextStyle(
                          fontSize: 76,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Text(
                        'kg',
                        style: TextStyle(fontSize: 24, color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ultimasTramas.isEmpty
                    ? 'Sin tramas recibidas'
                    : _ultimasTramas.reversed.join('\n'),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
