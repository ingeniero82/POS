import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/permissions.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../controllers/permissions_controller.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PermissionsController());
    
    // Verificar si el usuario tiene permisos para modificar configuración
    if (!AuthService.to.hasPermission(Permission.modifySettings)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Acceso Denegado',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22315B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No tienes permisos para acceder a la gestión de permisos',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C47FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF22315B)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Gestión de Permisos',
          style: TextStyle(
            color: Color(0xFF22315B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF22315B)),
            onPressed: () => Get.offAllNamed('/dashboard'),
            tooltip: 'Ir al Dashboard',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C47FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestión de Permisos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22315B),
                        ),
                      ),
                      Text(
                        'Configuración de roles y permisos del sistema',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botones de acción
                Row(
                  children: [
                    Obx(() => ElevatedButton.icon(
                      onPressed: controller.isLoading.value ? null : controller.resetToDefault,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restaurar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Obx(() => ElevatedButton.icon(
                      onPressed: controller.isLoading.value ? null : controller.savePermissions,
                      icon: controller.isLoading.value 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                      label: Text(controller.isLoading.value ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C47FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Información del usuario actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usuario Actual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22315B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF6C47FF).withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF6C47FF),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(() => Text(
                              AuthService.to.currentUserName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            Obx(() => Text(
                              AuthService.to.currentUserRole,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )),
                          ],
                        ),
                      ),
                      // Verificar si es admin
                      Obx(() {
                        final isAdmin = AuthService.to.currentUser?.role == UserRole.admin;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAdmin ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isAdmin ? 'Administrador' : 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Tabla de permisos por rol
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Permisos por Rol',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22315B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C47FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Modo Edición',
                            style: TextStyle(
                              color: Color(0xFF6C47FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Haz clic en los checkboxes para modificar los permisos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _EditablePermissionsTable(controller: controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditablePermissionsTable extends StatelessWidget {
  final PermissionsController controller;

  const _EditablePermissionsTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Table(
      border: TableBorder.all(
        color: Colors.grey.withOpacity(0.2),
        width: 1,
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        // Header de la tabla
        TableRow(
          decoration: BoxDecoration(
            color: const Color(0xFF6C47FF).withOpacity(0.1),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Permiso',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Gerente',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Cajero',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22315B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        
        // Filas de permisos
        ...Permission.values.map((permission) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                RolePermissions.getPermissionDescription(permission),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            _EditablePermissionCell(
              hasPermission: controller.hasPermission(UserRole.admin, permission),
              onChanged: (value) => controller.togglePermission(UserRole.admin, permission),
              isDisabled: true, // Admin siempre tiene todos los permisos
            ),
            _EditablePermissionCell(
              hasPermission: controller.hasPermission(UserRole.manager, permission),
              onChanged: (value) => controller.togglePermission(UserRole.manager, permission),
            ),
            _EditablePermissionCell(
              hasPermission: controller.hasPermission(UserRole.cashier, permission),
              onChanged: (value) => controller.togglePermission(UserRole.cashier, permission),
            ),
          ],
        )).toList(),
      ],
    ));
  }
}

class _EditablePermissionCell extends StatelessWidget {
  final bool hasPermission;
  final ValueChanged<bool?> onChanged;
  final bool isDisabled;

  const _EditablePermissionCell({
    required this.hasPermission,
    required this.onChanged,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Checkbox(
          value: hasPermission,
          onChanged: isDisabled ? null : onChanged,
          activeColor: const Color(0xFF6C47FF),
          checkColor: Colors.white,
        ),
      ),
    );
  }
} 