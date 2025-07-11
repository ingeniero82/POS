import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/authorization_service.dart';

class AuthorizationModal extends StatefulWidget {
  final String action;
  final Function(String) onAuthorized;
  final VoidCallback onCancelled;

  const AuthorizationModal({
    required this.action,
    required this.onAuthorized,
    required this.onCancelled,
    Key? key,
  }) : super(key: key);

  @override
  State<AuthorizationModal> createState() => _AuthorizationModalState();
}

class _AuthorizationModalState extends State<AuthorizationModal> {
  final TextEditingController _codeController = TextEditingController();
  final AuthorizationService _authService = AuthorizationService();
  bool _isLoading = false;
  bool _showBarcodeScanner = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono y título
            Icon(
              Icons.security,
              size: 48,
              color: Colors.orange[600],
            ),
            const SizedBox(height: 16),
            Text(
              _authService.getModalTitle(widget.action),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22315B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _authService.getModalDescription(widget.action),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Información adicional sobre códigos de usuario
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Puedes usar el código de usuario de un administrador o gerente autorizado (ej: USR-1234)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Opciones de autorización
            if (!_showBarcodeScanner) ...[
              // Botón para escanear código de barras
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showBarcodeScanner = true;
                    });
                    _scanBarcode();
                  },
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Escanear Código de Barras'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // O ingresar código manualmente
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'O',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Campo para ingresar código
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Código de Autorización',
                  hintText: 'Ingresa código de usuario o autorización',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.key),
                  helperText: 'Formato: USR-1234 (código de usuario) o ADMIN123 (código de autorización)',
                ),
                obscureText: false, // Cambiado a false para mejor UX
                onSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 16),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onCancelled();
                        Get.back();
                      },
                      child: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Autorizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Interfaz del escáner de código de barras
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Escaneando código de barras...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coloca el código de barras frente al escáner',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Botón para cancelar escaneo
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showBarcodeScanner = false;
                    });
                  },
                  child: const Text('Cancelar Escaneo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      Get.snackbar(
        'Código requerido',
        'Por favor ingresa el código de autorización',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isAuthorized = await _authService.verifyAuthorizationCode(
        _codeController.text.trim(),
        widget.action,
      );

      if (isAuthorized) {
        // Obtener información del autorizador para el log
        final authorizerInfo = await _authService.getAuthorizerInfo(_codeController.text.trim());
        
        // Registrar la autorización
        await _authService.logAuthorization(
          widget.action,
          _codeController.text.trim(),
          'Autorización exitosa - $authorizerInfo',
        );

        // Llamar al callback de autorización DESPUÉS de cerrar el modal
        Get.back();
        Future.delayed(Duration.zero, () {
          widget.onAuthorized(_codeController.text.trim());
        });
        // Se elimina el snackbar de éxito aquí para que el flujo sea directo
      } else {
        Get.snackbar(
          'Código inválido',
          'El código de autorización no es válido o no tienes permisos para esta acción',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al verificar autorización: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    // Simular escaneo de código de barras
    // En un sistema real, esto integraría con un escáner físico
    await Future.delayed(const Duration(seconds: 2));
    
    // Simular código escaneado (en producción esto vendría del escáner)
    final scannedCode = 'ADMIN001'; // Código de ejemplo
    
    try {
      final isAuthorized = await _authService.verifyBarcodeAuthorization(
        scannedCode,
        widget.action,
      );

      if (isAuthorized) {
        // Obtener información del autorizador para el log
        final authorizerInfo = await _authService.getAuthorizerInfo(scannedCode);
        
        // Registrar la autorización
        await _authService.logAuthorization(
          widget.action,
          scannedCode,
          'Autorización por código de barras - $authorizerInfo',
        );

        // Llamar al callback de autorización
        widget.onAuthorized(scannedCode);
        Get.back();
        
        Get.snackbar(
          'Autorización exitosa',
          'Código de barras autorizado correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        setState(() {
          _showBarcodeScanner = false;
        });
        
        Get.snackbar(
          'Código no autorizado',
          'El código de barras escaneado no tiene permisos para esta acción',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        _showBarcodeScanner = false;
      });
      
      Get.snackbar(
        'Error',
        'Error al procesar código de barras: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
} 