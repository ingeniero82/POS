import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/license_controller.dart';

/// Aviso visible cuando la licencia es de tipo demo (muestras en local).
/// Así queda claro que es modo demostración y no licencia de producción.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<LicenseController>();
      if (!controller.isDemo.value) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.amber.shade700,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Modo demostración — Solo para muestras. No es licencia de producción.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    });
  }
}
