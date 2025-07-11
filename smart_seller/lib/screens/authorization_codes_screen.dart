import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/permissions.dart';
import '../services/authorization_codes_service.dart';

class AuthorizationCodesScreen extends StatefulWidget {
  const AuthorizationCodesScreen({Key? key}) : super(key: key);

  @override
  State<AuthorizationCodesScreen> createState() => _AuthorizationCodesScreenState();
}

class _AuthorizationCodesScreenState extends State<AuthorizationCodesScreen> {
  List<AuthorizationCode> _codes = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  UserRole _selectedRole = UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final codes = await AuthorizationCodesService.getAllCodes();
      setState(() {
        _codes = codes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar códigos: $e')),
      );
    }
  }

  Future<void> _createNewCode() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final newCode = await AuthorizationCodesService.createCode(
        name: _nameController.text.trim(),
        role: _selectedRole,
        customCode: _codeController.text.trim().isEmpty 
            ? null 
            : _codeController.text.trim(),
      );

      _nameController.clear();
      _codeController.clear();
      _selectedRole = UserRole.admin;

      await _loadCodes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear código: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deactivateCode(AuthorizationCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar Código'),
        content: Text('¿Estás seguro de que quieres desactivar el código de ${code.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthorizationCodesService.deactivateCode(code.code);
        await _loadCodes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código desactivado exitosamente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al desactivar código: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar Códigos'),
        content: const Text('¿Estás seguro de que quieres reiniciar todos los códigos a los valores predefinidos? Esto eliminará todos los códigos personalizados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthorizationCodesService.resetToDefaults();
        await _loadCodes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Códigos reiniciados exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al reiniciar códigos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Códigos de Autorización'),
        actions: [
          IconButton(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar a valores predefinidos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Información sobre códigos predefinidos
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Códigos Predefinidos',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• ADMIN123 - Administrador Principal\n'
                        '• GERENTE456 - Gerente General\n'
                        '• SUPER789 - Supervisor',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                // Lista de códigos
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _codes.length,
                    itemBuilder: (context, index) {
                      final code = _codes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(code.role),
                            child: Icon(
                              _getRoleIcon(code.role),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(code.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Código: ${code.code}'),
                              Text('Código de barras: ${code.barcode}'),
                              Text('Rol: ${_getRoleName(code.role)}'),
                              Text('Creado: ${_formatDate(code.createdAt)}'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'deactivate') {
                                _deactivateCode(code);
                              } else if (value == 'copy_code') {
                                // Copiar código al portapapeles
                                // Implementar copia al portapapeles
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'copy_code',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy),
                                    SizedBox(width: 8),
                                    Text('Copiar código'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'deactivate',
                                child: Row(
                                  children: [
                                    Icon(Icons.block),
                                    SizedBox(width: 8),
                                    Text('Desactivar'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCodeDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Crear nuevo código',
      ),
    );
  }

  void _showCreateCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nuevo Código'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del autorizador',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleName(role)),
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
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Código personalizado (opcional)',
                  border: OutlineInputBorder(),
                  helperText: 'Dejar vacío para generar automáticamente',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createNewCode();
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.orange;
      case UserRole.cashier:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.cashier:
        return Icons.point_of_sale;
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.manager:
        return 'Gerente';
      case UserRole.cashier:
        return 'Cajero';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 