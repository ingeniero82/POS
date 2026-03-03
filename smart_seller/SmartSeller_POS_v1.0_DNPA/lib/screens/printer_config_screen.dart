import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/print_service.dart';

/// Pantalla para que mantenimiento configure la impresora del POS sin tocar código.
/// Lista impresoras, permite elegir una, guardar, configurar formato del ticket y ver vista previa.
class PrinterConfigScreen extends StatefulWidget {
  const PrinterConfigScreen({super.key});

  @override
  State<PrinterConfigScreen> createState() => _PrinterConfigScreenState();
}

class _PrinterConfigScreenState extends State<PrinterConfigScreen> {
  final PrintService _printService = PrintService.instance;
  List<Map<String, dynamic>> _printers = [];
  String? _selectedPrinterName;
  String? _savedPrinterName;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _reconnecting = false;

  // Formato del recibo
  int _paperWidth = 48;
  int _marginLeft = 0;
  int _colDesc = 16;
  int _colCant = 6;
  int _colPrice = 10;
  int _colSubtotal = 10;
  int _spacePriceCant = 1;
  bool _savingFormat = false;

  final _marginLeftCtrl = TextEditingController();
  final _spacePriceCantCtrl = TextEditingController();
  final _colDescCtrl = TextEditingController();
  final _colCantCtrl = TextEditingController();
  final _colPriceCtrl = TextEditingController();
  final _colSubtotalCtrl = TextEditingController();

  @override
  void dispose() {
    _marginLeftCtrl.dispose();
    _spacePriceCantCtrl.dispose();
    _colDescCtrl.dispose();
    _colCantCtrl.dispose();
    _colPriceCtrl.dispose();
    _colSubtotalCtrl.dispose();
    super.dispose();
  }

  void _syncFormatToControllers() {
    _marginLeftCtrl.text = '$_marginLeft';
    _spacePriceCantCtrl.text = '$_spacePriceCant';
    _colDescCtrl.text = '$_colDesc';
    _colCantCtrl.text = '$_colCant';
    _colPriceCtrl.text = '$_colPrice';
    _colSubtotalCtrl.text = '$_colSubtotal';
  }

  ReceiptFormat get _currentFormat => ReceiptFormat(
        paperWidth: _paperWidth,
        marginLeft: _marginLeft,
        colDesc: _colDesc,
        colCant: _colCant,
        colPrice: _colPrice,
        colSubtotal: _colSubtotal,
        spaceBetweenPriceAndCant: _spacePriceCant,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _savedPrinterName = await _printService.getSavedPrinterName();
      final list = await _printService.listPrinters();
      final fmt = await _printService.getReceiptFormat();
      setState(() {
        _printers = list;
        _selectedPrinterName = _savedPrinterName;
        if (_selectedPrinterName == null && _printers.isNotEmpty) {
          _selectedPrinterName = _printers.first['name'] as String?;
        }
        _paperWidth = fmt.paperWidth;
        _marginLeft = fmt.marginLeft;
        _colDesc = fmt.colDesc;
        _colCant = fmt.colCant;
        _colPrice = fmt.colPrice;
        _colSubtotal = fmt.colSubtotal;
        _spacePriceCant = fmt.spaceBetweenPriceAndCant.clamp(1, 4);
        _loading = false;
      });
      _syncFormatToControllers();
    } catch (e) {
      setState(() => _loading = false);
      Get.snackbar('Error', 'No se pudo cargar la lista de impresoras: $e');
    }
  }

  Future<void> _save() async {
    if (_selectedPrinterName == null || _selectedPrinterName!.isEmpty) {
      Get.snackbar('Aviso', 'Seleccione una impresora');
      return;
    }
    setState(() => _saving = true);
    try {
      await _printService.setSavedPrinterName(_selectedPrinterName);
      _savedPrinterName = _selectedPrinterName;
      Get.snackbar('Guardado',
          'Impresora "$_selectedPrinterName" guardada. Reconecte para aplicar.');
      setState(() => _saving = false);
    } catch (e) {
      setState(() => _saving = false);
      Get.snackbar('Error', 'No se pudo guardar: $e');
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      final ok = await _printService.printTestReceipt();
      if (ok) {
        Get.snackbar('Éxito', 'Recibo de prueba enviado a la impresora');
      } else {
        Get.snackbar(
          'Sin impresión',
          'Impresora no conectada o en simulación. Configure y pulse Reconectar.',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al imprimir: $e');
    }
    setState(() => _testing = false);
  }

  Future<void> _reconnect() async {
    setState(() => _reconnecting = true);
    try {
      await _printService.setSavedPrinterName(_selectedPrinterName);
      final ok = await _printService.reconnect();
      if (ok) {
        Get.snackbar('Éxito', 'Impresora reconectada');
      } else {
        Get.snackbar(
          'Aviso',
          'No se pudo conectar. En Windows, asegúrese de que la impresora esté instalada y encendida.',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al reconectar: $e');
    }
    setState(() => _reconnecting = false);
  }

  Future<void> _saveFormat() async {
    setState(() => _savingFormat = true);
    try {
      await _printService.setReceiptFormat(
        paperWidth: _paperWidth,
        marginLeft: _marginLeft,
        colDesc: _colDesc,
        colCant: _colCant,
        colPrice: _colPrice,
        colSubtotal: _colSubtotal,
        spaceBetweenPriceAndCant: _spacePriceCant,
      );
      Get.snackbar('Guardado', 'Formato del ticket guardado.');
    } catch (e) {
      Get.snackbar('Error', 'No se pudo guardar formato: $e');
    }
    setState(() => _savingFormat = false);
  }

  void _applySuggestedColumns() {
    final suggested = PrintService.suggestedFormatForPaperWidth(
      _paperWidth,
      marginLeft: _marginLeft,
    );
    setState(() {
      _colDesc = suggested.colDesc;
      _colCant = suggested.colCant;
      _colPrice = suggested.colPrice;
      _colSubtotal = suggested.colSubtotal;
    });
    _syncFormatToControllers();
    Get.snackbar(
        'Ajustado', 'Columnas sugeridas para el ancho de papel aplicadas.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de impresora POS'),
        backgroundColor: const Color(0xFF6C47FF),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado actual',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _printService.isConnected
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: _printService.isConnected
                                    ? Colors.green
                                    : Colors.orange,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _printService.isConnected
                                          ? 'Impresora conectada'
                                          : 'Modo simulación (no imprime)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Impresora: ${_printService.printerName}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Puerto: ${_printService.printerPort}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elegir impresora',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (!Platform.isWindows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'La selección por nombre está disponible en Windows. En otros sistemas se usa USB o puerto serie.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (_printers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'No se detectaron impresoras. En Windows, instale el driver de la impresora POS.',
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPrinterName,
                              decoration: const InputDecoration(
                                labelText: 'Impresora',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.print),
                              ),
                              items: _printers
                                  .map((p) {
                                    final name = p['name'] as String?;
                                    if (name == null) return null;
                                    return DropdownMenuItem<String>(
                                      value: name,
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  })
                                  .whereType<DropdownMenuItem<String>>()
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedPrinterName = v),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    _saving || _selectedPrinterName == null
                                        ? null
                                        : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save),
                                label: const Text('Guardar impresora'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _reconnecting ? null : _reconnect,
                                icon: _reconnecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh),
                                label: const Text('Reconectar'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _testing ? null : _testPrint,
                                icon: _testing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.print),
                                label: const Text('Probar impresión'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formato del ticket',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: kStandardPaperWidths
                                    .any((w) => w.chars == _paperWidth)
                                ? _paperWidth
                                : kStandardPaperWidths.first.chars,
                            decoration: const InputDecoration(
                              labelText: 'Ancho de papel',
                              border: OutlineInputBorder(),
                            ),
                            items: kStandardPaperWidths
                                .map((w) => DropdownMenuItem<int>(
                                      value: w.chars,
                                      child: Text(w.label),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _paperWidth = v ?? 48),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _marginLeftCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Margen izq. (car.)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(
                                      () => _marginLeft = int.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _spacePriceCantCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Espacio Precio/Cant',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(() =>
                                      _spacePriceCant =
                                          (int.tryParse(v) ?? 1).clamp(1, 4)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _colDescCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Col. descripción',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(
                                      () => _colDesc = int.tryParse(v) ?? 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _colCantCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Col. cant.',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(
                                      () => _colCant = int.tryParse(v) ?? 6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _colPriceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Col. precio',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(
                                      () => _colPrice = int.tryParse(v) ?? 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _colSubtotalCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Col. subtotal',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => setState(() =>
                                      _colSubtotal = int.tryParse(v) ?? 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _applySuggestedColumns,
                                icon: const Icon(Icons.tune),
                                label: const Text('Ajustar columnas al ancho'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _savingFormat ? null : _saveFormat,
                                icon: _savingFormat
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save),
                                label: const Text('Guardar formato'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vista previa del ticket',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: SelectableText(
                              PrintService.buildReceiptPreview(_currentFormat),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Mantenimiento',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Seleccione la impresora del punto de venta en la lista.\n'
                            '2. Pulse "Guardar impresora".\n'
                            '3. Pulse "Reconectar" para que el POS use esta impresora.\n'
                            '4. Use "Probar impresión" para verificar.\n\n'
                            'Si no imprime: verifique que la impresora esté encendida, conectada y con driver instalado en Windows. '
                            'Puede configurarla también como impresora predeterminada en Windows.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
