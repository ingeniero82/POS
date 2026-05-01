import 'package:get/get.dart';
import '../services/license_service.dart';

/// Controla si la licencia actual es demo (para mostrar el aviso en la UI).
class LicenseController extends GetxController {
  final isDemo = false.obs;
  final isExpired = false.obs;
  final daysLeft = 0.obs;
  final expirationDateText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final activated = await LicenseService.isActivated();
    final expirationDate = await LicenseService.getDemoExpirationDate();
    final formattedDate = expirationDate == null
        ? ''
        : '${expirationDate.day.toString().padLeft(2, '0')}/${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}';
    final demoLicense = await LicenseService.isDemoLicense();
    isDemo.value = activated && demoLicense;
    isExpired.value = demoLicense && (await LicenseService.isDemoExpired());
    daysLeft.value = isDemo.value ? await LicenseService.getDemoDaysLeft() : 0;
    expirationDateText.value = isDemo.value ? formattedDate : '';
  }

  Future<void> refreshStatus() async => _load();
}
