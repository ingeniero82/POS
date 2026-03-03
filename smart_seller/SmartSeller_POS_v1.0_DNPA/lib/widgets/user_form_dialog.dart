import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user.dart';
import '../models/permissions.dart';
import '../services/sqlite_database_service.dart';
import '../services/permissions_service.dart';
import '../services/auth_service.dart'; // Added import for AuthService

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userCodeController = TextEditingController();

  UserRole _selectedRole = UserRole.manager;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _userCodeController.dispose();
    super.dispose();
  }

  Future<String> _generateUserCode() async {
    // Genera un código único tipo USR-XXXX
    String userCode;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      // Usar timestamp para evitar conflictos
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 9000) + 1000; // Número entre 1000-9999
      userCode = 'USR-$random';
      attempts++;

      if (attempts > maxAttempts) {
        // Si no se puede generar un código único, usar timestamp completo
        userCode =
            'USR-${timestamp.toString().substring(timestamp.toString().length - 4)}';
        break;
      }
    } while (await SQLiteDatabaseService.userCodeExists(userCode));

    return userCode;
  }

  Future<void> _createUser() async {
    print('Intentando crear usuario...');
    if (!_formKey.currentState!.validate()) {
      print('Validación fallida');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      print('Verificando si existe el usuario: $username');

      // Verificar si el usuario ya existe
      final userExists = await SQLiteDatabaseService.userExists(username);
      print('¿Usuario existe?: $userExists');
      if (userExists) {
        Get.snackbar(
          'Error',
          'El nombre de usuario "$username" ya existe',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Manejar código de usuario
      String? userCode;
      final permissionsService = PermissionsService.to;

      if (permissionsService.hasPermission(
          _selectedRole, Permission.allowUserCode)) {
        final enteredCode = _userCodeController.text.trim();

        if (enteredCode.isNotEmpty) {
          // Validar formato del código ingresado
          if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(enteredCode)) {
            Get.snackbar(
              'Error',
              'El código de usuario solo puede contener letras mayúsculas, números y guiones',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          // Validar unicidad del código ingresado
          final codeExists =
              await SQLiteDatabaseService.userCodeExists(enteredCode);
          if (codeExists) {
            Get.snackbar(
              'Error',
              'El código de usuario "$enteredCode" ya está en uso',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          userCode = enteredCode;
        } else {
          // Generar código automático
          userCode = await _generateUserCode();
        }
      }

      // Crear nuevo usuario
      final newUser = User()
        ..username = username
        ..password = _passwordController.text.trim()
        ..fullName = _fullNameController.text.trim()
        ..role = _selectedRole
        ..createdAt = DateTime.now()
        ..isActive = true
        ..userCode = userCode;

      print('Guardando usuario en la base de datos...');
      // Guardar en la base de datos
      await SQLiteDatabaseService.createUser(newUser);
      print('Usuario guardado correctamente');

      Get.snackbar(
        'Éxito',
        'Usuario creado correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      print('Intentando cerrar con Navigator...');
      Navigator.of(context, rootNavigator: true).pop(true);
      print('¿Se cerró el diálogo?');
    } catch (e, st) {
      print('Error al crear usuario: $e');
      print(st);
      Get.snackbar(
        'Error',
        'Error al crear usuario: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.cashier:
        return 'Cajero';
      case UserRole.maintenance:
        return 'Mantenimiento';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Verificar permisos del usuario actual
    final currentUser = AuthService.to.currentUser;
    final permissionsService = PermissionsService.to;
    final hasUserCodePermission = permissionsService.hasPermission(
        _selectedRole, Permission.allowUserCode);

    print('🔍 DEBUG - UserFormDialog:');
    print('   Usuario actual: ${currentUser?.username} (${currentUser?.role})');
    print('   Rol seleccionado: $_selectedRole');
    print('   ¿Tiene permiso allowUserCode?: $hasUserCodePermission');
    print(
        '   Permisos del rol $_selectedRole: ${permissionsService.getRolePermissions(_selectedRole)}');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Crear Nuevo Usuario',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22315B),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Formulario
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Nombre completo
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre completo es obligatorio';
                      }
                      if (value.trim().length < 3) {
                        return 'El nombre debe tener al menos 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nombre de usuario
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: const Icon(Icons.alternate_email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre de usuario es obligatorio';
                      }
                      if (value.trim().length < 3) {
                        return 'El usuario debe tener al menos 3 caracteres';
                      }
                      if (value.contains(' ')) {
                        return 'El usuario no puede contener espacios';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La contraseña es obligatoria';
                      }
                      if (value.trim().length < 4) {
                        return 'La contraseña debe tener al menos 4 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Rol
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Rol del Usuario',
                      prefixIcon: const Icon(Icons.admin_panel_settings),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FA),
                    ),
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(_getRoleText(role)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Código de Usuario (solo si el rol tiene permiso)
                  if (PermissionsService.to
                      .hasPermission(_selectedRole, Permission.allowUserCode))
                    TextFormField(
                      controller: _userCodeController,
                      decoration: InputDecoration(
                        labelText: 'Código de Usuario (opcional)',
                        prefixIcon: const Icon(Icons.qr_code),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FA),
                        helperText:
                            'Puedes escribirlo, escanearlo o dejarlo vacío para generar uno automático',
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(value.trim())) {
                            return 'Solo letras mayúsculas, números y guiones';
                          }
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Get.back(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                          'Crear Usuario',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
