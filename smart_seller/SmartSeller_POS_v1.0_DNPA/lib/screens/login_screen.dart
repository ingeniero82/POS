import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/license_controller.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Error',
        'Por favor completa todos los campos',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AuthService.to.login(username, password);

      if (!mounted) return;

      if (success) {
        final user = AuthService.to.currentUser;
        Get.snackbar(
          'Éxito',
          'Bienvenido ${user?.fullName ?? username}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 1),
        );
        // Navegar al dashboard (no hacer setState después: la pantalla se destruye)
        Get.offAllNamed('/dashboard');
        return;
      }

      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Usuario o contraseña incorrectos',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      Get.snackbar(
        'Error',
        'Ocurrió un error inesperado: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseController = Get.find<LicenseController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo y título alineados a la izquierda
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo smart.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22315B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, size: 48, color: Color(0xFF22315B)),
                  ),
                ),
                const SizedBox(width: 18),
                const Text(
                  'smart seller',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF22315B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Obx(() {
              if (!licenseController.isDemo.value) return const SizedBox.shrink();
              final status = licenseController.isExpired.value
                  ? 'Demo vencida. Solicite activacion comercial.'
                  : 'Demo activa: ${licenseController.daysLeft.value} dia(s) restantes'
                      '${licenseController.expirationDateText.value.isNotEmpty ? ' (vence ${licenseController.expirationDateText.value})' : ''}.';
              return Container(
                width: 420,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Obx(() {
              if (!licenseController.isDemo.value) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Get.toNamed('/activation'),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Activar licencia de compra'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ContactService.openWhatsAppForLicense(
                        source: 'Login',
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Comprar licencia por WhatsApp'),
                    ),
                  ],
                ),
              );
            }),
            // Formulario centrado y compacto
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FB),
                borderRadius: BorderRadius.circular(22),
              ),
              width: 340,
              child: Column(
                children: [
                  // Campo usuario
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'usuario',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color: Color(0xFF22315B),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // Campo contraseña
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'contraseña',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Color(0xFF22315B),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF22315B),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // Botón login
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22315B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Desarrollo Losoft 2025 Version 1.0',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF22315B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
