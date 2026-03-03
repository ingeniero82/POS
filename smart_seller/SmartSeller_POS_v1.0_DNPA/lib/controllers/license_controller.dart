import 'package:get/get.dart';
import '../services/license_service.dart';

/// Controla si la licencia actual es demo (para mostrar el aviso en la UI).
class LicenseController extends GetxController {
  final isDemo = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isDemo.value = await LicenseService.isDemoLicense();
  }
}
