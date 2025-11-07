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
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Probar F2
          if (event.logicalKey.keyLabel == 'F2') {
            print('🔍 F2 detectado - Abriendo facturación electrónica');
            Get.snackbar(
              'F2 Detectado',
              'Abriendo módulo de facturación electrónica',
              backgroundColor: Colors.blue,
              colorText: Colors.white,
            );
          }
          
          // ✅ NUEVO: Probar teclas S y N para impresión
          if (event.logicalKey.keyLabel == 'S' || event.logicalKey.keyLabel == 's') {
            print('✅ S detectado - Simulando impresión');
            Get.snackbar(
              'S Detectado',
              'Simulando impresión de recibo',
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );
          }
          
          if (event.logicalKey.keyLabel == 'N' || event.logicalKey.keyLabel == 'n') {
            print('❌ N detectado - Simulando no imprimir');
            Get.snackbar(
              'N Detectado',
              'Simulando no imprimir recibo',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test de Teclado'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prueba de Teclas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('• Presiona F2 para abrir facturación electrónica'),
              const SizedBox(height: 8),
              const Text('• Presiona S para simular imprimir recibo'),
              const SizedBox(height: 8),
              const Text('• Presiona N para simular no imprimir recibo'),
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                onPressed: () {
                  // Simular diálogo de impresión
                  _showTestPrintDialog();
                },
                icon: const Icon(Icons.print),
                label: const Text('Probar Diálogo de Impresión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ✅ NUEVO: Función para probar el diálogo de impresión
  void _showTestPrintDialog() {
    Get.dialog(
      Dialog(
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              print('🔍 Tecla presionada en test: ${event.logicalKey.keyLabel}');
              
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                print('✅ Enter detectado en test');
                Get.back();
                Get.snackbar('Test', 'Enter presionado', backgroundColor: Colors.green);
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                print('❌ Escape detectado en test');
                Get.back();
                Get.snackbar('Test', 'Escape presionado', backgroundColor: Colors.orange);
              } else if (event.logicalKey.keyLabel == 'S' || event.logicalKey.keyLabel == 's') {
                print('✅ S detectado en test');
                Get.back();
                Get.snackbar('Test', 'S presionado - Imprimiendo', backgroundColor: Colors.green);
              } else if (event.logicalKey.keyLabel == 'N' || event.logicalKey.keyLabel == 'n') {
                print('❌ N detectado en test');
                Get.back();
                Get.snackbar('Test', 'N presionado - No imprimir', backgroundColor: Colors.orange);
              }
            }
          },
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text('¡Venta Exitosa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('¿Desea imprimir el recibo?', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          Get.snackbar('Test', 'SÍ presionado', backgroundColor: Colors.green);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text('SÍ (S)'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          Get.snackbar('Test', 'NO presionado', backgroundColor: Colors.orange);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.black),
                        child: const Text('NO (N)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Presiona Enter/S para imprimir o Escape/N para continuar', 
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
} 