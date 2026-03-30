import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/balanza_service.dart';

class BalanzaDiagnosticoScreen extends StatefulWidget {
  const BalanzaDiagnosticoScreen({super.key});

  @override
  State<BalanzaDiagnosticoScreen> createState() =>
      _BalanzaDiagnosticoScreenState();
}

class _BalanzaDiagnosticoScreenState extends State<BalanzaDiagnosticoScreen> {
  final BalanzaService _balanza = BalanzaService();
  final List<int> _baudRates = const [2400, 4800, 9600, 19200, 38400];

  List<String> _puertos = <String>[];
  String? _puertoSeleccionado;
  int _baudRate = 9600;

  @override
  void initState() {
    super.initState();
    _balanza.addListener(_onServiceChanged);
    _refrescarPuertos();
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
    await _balanza.conectar(
      puerto: _puertoSeleccionado!,
      baudRate: _baudRate,
    );
  }

  @override
  void dispose() {
    _balanza.removeListener(_onServiceChanged);
    _balanza.dispose();
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
                          (p) =>
                              DropdownMenuItem<String>(value: p, child: Text(p)),
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
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
