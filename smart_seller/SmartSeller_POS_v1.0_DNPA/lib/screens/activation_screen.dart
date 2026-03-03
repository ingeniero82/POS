import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/license_service.dart';

/// Pantalla de activación de licencia. Se muestra solo si la app no está activada.
/// No modifica login ni el resto del flujo.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  String _machineId = '';
  bool _loading = true;
  bool _activating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMachineId();
  }

  Future<void> _loadMachineId() async {
    final id = await LicenseService.getMachineId();
    if (mounted) {
      setState(() {
        _machineId = id;
        _loading = false;
      });
    }
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ingrese la clave de activación');
      return;
    }
    setState(() {
      _error = null;
      _activating = true;
    });
    final ok = await LicenseService.validateAndSave(key);
    if (!mounted) return;
    setState(() => _activating = false);
    if (ok) {
      Get.offAllNamed('/login');
    } else {
      setState(() => _error = 'Clave incorrecta. La clave debe generarse para el ID de ESTE equipo (el de arriba).');
    }
  }

  Future<void> _clearAndRetry() async {
    await LicenseService.clearStoredLicense();
    setState(() {
      _error = null;
      _keyController.clear();
    });
    Get.snackbar('Listo', 'Puede pegar una nueva clave.');
  }

  void _copyMachineId() {
    if (_machineId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _machineId));
    Get.snackbar('Copiado', 'ID de equipo copiado al portapapeles');
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.key, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Activación de licencia',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Smart Seller POS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      'ID de este equipo (envíelo al proveedor para obtener su clave):',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _copyMachineId,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _machineId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.copy, size: 20, color: Colors.grey.shade700),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Clave de activación',
                        hintText: 'Ej.: DEMO-XXXXXXXXXX o ID_EQUIPO-XXXXXXXXXX',
                        helperText: 'Pegue la clave completa (incluyendo DEMO- o el ID al inicio).',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _activate(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _activating ? null : _activate,
                      child: _activating
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Activar'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'La clave se genera con el ID de este equipo. El proveedor debe usar GenerarClaveEquipo.bat y pegar el ID de arriba.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _clearAndRetry,
                      child: const Text('Borrar e intentar con otra clave'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
