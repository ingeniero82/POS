import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Servicio para contacto comercial (WhatsApp).
class ContactService {
  static const String _keySalesPhone = 'sales_whatsapp_phone';
  // Numero por defecto (formato internacional sin +, espacios ni guiones).
  static const String _defaultSalesPhone = '573001234567';

  static Future<String> getSalesPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySalesPhone) ?? _defaultSalesPhone;
  }

  static Future<void> setSalesPhone(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.isEmpty) {
      throw Exception('Ingrese un numero valido');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySalesPhone, sanitized);
  }

  static Future<void> openWhatsAppForLicense({String source = 'App'}) async {
    final salesPhone = await getSalesPhone();
    final message = Uri.encodeComponent(
      'Hola, estoy usando Smart Seller en modo demo y quiero comprar la licencia. Origen: $source',
    );
    final url = Uri.parse('https://wa.me/$salesPhone?text=$message');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar(
        'No se pudo abrir WhatsApp',
        'Verifique que tenga navegador o WhatsApp instalado.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static Future<void> showEditWhatsAppDialog() async {
    final current = await getSalesPhone();
    final controller = TextEditingController(text: current);
    await Get.dialog(
      AlertDialog(
        title: const Text('Numero de WhatsApp para ventas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingrese el numero en formato internacional, solo numeros. Ejemplo: 573001112233',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numero WhatsApp',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await setSalesPhone(controller.text);
                Get.back();
                Get.snackbar(
                  'Guardado',
                  'Numero de WhatsApp actualizado.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
