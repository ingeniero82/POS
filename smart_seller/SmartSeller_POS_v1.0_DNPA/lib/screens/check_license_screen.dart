import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/license_service.dart';

/// Pantalla inicial que solo comprueba la licencia y redirige.
/// No modifica login ni dashboard.
class CheckLicenseScreen extends StatefulWidget {
  const CheckLicenseScreen({super.key});

  @override
  State<CheckLicenseScreen> createState() => _CheckLicenseScreenState();
}

class _CheckLicenseScreenState extends State<CheckLicenseScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final activated = await LicenseService.isActivated();
      if (!mounted) return;
      if (activated) {
        Get.offAllNamed('/login');
      } else {
        Get.offAllNamed('/activation');
      }
    } catch (_) {
      if (!mounted) return;
      Get.offAllNamed('/activation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
