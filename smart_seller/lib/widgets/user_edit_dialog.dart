import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user.dart';
import '../services/sqlite_database_service.dart';
import '../services/permissions_service.dart';
import '../models/permissions.dart';

class UserEditDialog extends StatefulWidget {
  final User user;
  
  const UserEditDialog({
    super.key,
    required this.user,
  });

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _userCodeController;
  
  late UserRole _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    // Pre-llenar los campos con los datos existentes
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _usernameController = TextEditingController(text: widget.user.username);
    _passwordController = TextEditingController();
    _userCodeController = TextEditingController(text: widget.user.userCode ?? '');
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _userCodeController.dispose();
    super.dispose();
  }

  Future<String> _generateUserCode() async {
    String userCode;
    int attempts = 0;
    const maxAttempts = 10;
    do {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 9000) + 1000;
      userCode = 'USR-$random';
      attempts++;
      if (attempts > maxAttempts) {
        userCode = 'USR-${timestamp.toString().substring(timestamp.toString().length - 4)}';
        break;
      }
    } while (await SQLiteDatabaseService.userCodeExists(userCode));
    return userCode;
  }

  Future<void> _updateUser() async {
    print('DEBUG: Iniciando actualización de usuario...');
    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Validación fallida.');
      Get.snackbar(
        'Error',
        'Por favor revisa los campos del formulario.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      // Verificar si el usuario cambió y si ya existe
      if (username != widget.user.username) {
        final userExists = await SQLiteDatabaseService.userExists(username);
        if (userExists) {
          print('DEBUG: El nombre de usuario ya existe.');
          Get.snackbar(
            'Error',
            'El nombre de usuario "$username" ya existe',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      // Actualizar los datos del usuario
      widget.user.username = username;
      widget.user.fullName = _fullNameController.text.trim();
      widget.user.role = _selectedRole;
      // Solo cambiar contraseña si se especificó
      if (_changePassword && _passwordController.text.trim().isNotEmpty) {
        widget.user.password = _passwordController.text.trim();
      }
      // Manejar código de usuario si el rol tiene permiso
      final hasUserCodePermission = PermissionsService.to.hasPermission(_selectedRole, Permission.allowUserCode);
      if (hasUserCodePermission) {
        final enteredCode = _userCodeController.text.trim();
        if (enteredCode.isNotEmpty) {
          // Validar formato
          if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(enteredCode)) {
            print('DEBUG: Formato de código inválido.');
            Get.snackbar(
              'Error',
              'El código de usuario solo puede contener letras mayúsculas, números y guiones',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
          // Validar unicidad (excepto para el mismo usuario)
          final codeExists = await SQLiteDatabaseService.userCodeExists(enteredCode);
          if (codeExists && enteredCode != (widget.user.userCode ?? '')) {
            print('DEBUG: Código de usuario ya existe.');
            Get.snackbar(
              'Error',
              'El código de usuario "$enteredCode" ya está en uso',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
          widget.user.userCode = enteredCode;
        } else {
          // Si deja vacío, generar uno automático
          widget.user.userCode = await _generateUserCode();
        }
      } else {
        widget.user.userCode = null;
      }
      // Guardar en la base de datos
      await SQLiteDatabaseService.updateUser(widget.user);
      print('DEBUG: Usuario actualizado correctamente.');
      Get.snackbar(
        'Éxito',
        'Usuario actualizado correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
      // Cerrar el diálogo después de un breve delay para que se vea la notificación
      await Future.delayed(const Duration(milliseconds: 600));
      bool closed = false;
      try {
        Navigator.of(context, rootNavigator: true).pop(true);
        closed = true;
      } catch (e) {
        print('DEBUG: Error al cerrar con Navigator: $e');
      }
      if (!closed) {
        try {
          Get.back(result: true);
        } catch (e) {
          print('DEBUG: Error al cerrar con Get.back: $e');
        }
      }
    } catch (e) {
      print('DEBUG: Error al actualizar usuario: $e');
      Get.snackbar(
        'Error',
        'Error al actualizar usuario: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
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
      case UserRole.cashier:
        return 'Cajero';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug prints
    print('DEBUG UserEditDialog: Rol seleccionado:  [33m [1m [4m [7m$_selectedRole [0m');
    print('DEBUG UserEditDialog: ¿Tiene permiso allowUserCode?:  [32m${PermissionsService.to.hasPermission(_selectedRole, Permission.allowUserCode)} [0m');
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
                Text(
                  'Editar Usuario',
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
            const SizedBox(height: 8),
            Text(
              'Editando: ${widget.user.fullName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
                    enabled: widget.user.username != 'admin',
                    decoration: InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: const Icon(Icons.alternate_email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: widget.user.username == 'admin' 
                          ? Colors.grey[200] 
                          : const Color(0xFFF6F8FA),
                      helperText: widget.user.username == 'admin' 
                          ? 'No se puede cambiar el usuario admin'
                          : null,
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

                  // Checkbox para cambiar contraseña
                  CheckboxListTile(
                    title: Text('Cambiar contraseña'),
                    value: _changePassword,
                    onChanged: (value) {
                      setState(() {
                        _changePassword = value ?? false;
                        if (!_changePassword) {
                          _passwordController.clear();
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  // Campo de contraseña (solo si se quiere cambiar)
                  if (_changePassword) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                      validator: _changePassword ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La nueva contraseña es obligatoria';
                        }
                        if (value.trim().length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      } : null,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Rol
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
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
                  if (PermissionsService.to.hasPermission(_selectedRole, Permission.allowUserCode))
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
                        helperText: 'Puedes escribirlo, escanearlo o dejarlo vacío para generar uno automático',
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
                  onPressed: _isLoading ? null : _updateUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          'Actualizar Usuario',
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