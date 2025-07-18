import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../modules/electronic_invoicing/screens/electronic_invoice_screen.dart';

class TestKeyboardScreen extends StatefulWidget {
  const TestKeyboardScreen({super.key});

  @override
  State<TestKeyboardScreen> createState() => _TestKeyboardScreenState();
}

class _TestKeyboardScreenState extends State<TestKeyboardScreen> {
  final FocusNode _focusNode = FocusNode();
  String _lastKeyPressed = 'Ninguna';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Teclado'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            setState(() {
              _lastKeyPressed = event.logicalKey.keyLabel;
            });
            
            print('🔍 Tecla presionada: ${event.logicalKey.keyLabel}');
            
            // Probar F2
            if (event.logicalKey.keyLabel == 'F2') {
              print('🔍 F2 detectado - Abriendo facturación electrónica');
              Get.snackbar(
                'F2 Detectado',
                'Abriendo módulo de facturación electrónica',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
              Get.to(() => const ElectronicInvoiceScreen());
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Prueba de Teclado',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Última tecla presionada: $_lastKeyPressed',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Instrucciones:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Presiona F2 para abrir facturación electrónica'),
                      const Text('• Presiona cualquier tecla para ver la detección'),
                      const Text('• Asegúrate de que esta ventana tenga el foco'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Get.to(() => const ElectronicInvoiceScreen());
                },
                child: const Text('Abrir Facturación Electrónica (Manual)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 