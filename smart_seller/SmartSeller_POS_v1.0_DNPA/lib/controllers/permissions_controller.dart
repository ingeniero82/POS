import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/permissions.dart';
import '../models/user.dart';
import '../services/permissions_service.dart';

class PermissionsController extends GetxController {
  // Permisos editables por rol
  final RxMap<UserRole, Set<Permission>> editablePermissions = <UserRole, Set<Permission>>{}.obs;
  
  // Estado de carga
  final RxBool isLoading = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadPermissions();
  }
  
  void _loadPermissions() {
    // Cargar los permisos actuales del servicio
    final permissionsService = Get.find<PermissionsService>();
    editablePermissions.value = Map.from(permissionsService.currentPermissions);
  }
  
  // Verificar si un rol tiene un permiso específico
  bool hasPermission(UserRole role, Permission permission) {
    return editablePermissions[role]?.contains(permission) ?? false;
  }
  
  // Cambiar un permiso específico
  void togglePermission(UserRole role, Permission permission) {
    final currentPermissions = editablePermissions[role] ?? {};
    final newPermissions = Set<Permission>.from(currentPermissions);
    
    if (newPermissions.contains(permission)) {
      newPermissions.remove(permission);
    } else {
      newPermissions.add(permission);
    }
    
    editablePermissions[role] = newPermissions;
  }
  
  // Guardar cambios
  Future<bool> savePermissions() async {
    isLoading.value = true;
    
    try {
      // Simular delay de guardado
      await Future.delayed(const Duration(seconds: 1));
      
      // Guardar usando el servicio de permisos
      final permissionsService = Get.find<PermissionsService>();
      final success = await permissionsService.saveAllPermissions(editablePermissions);
      
      if (success) {
        Get.snackbar(
          'Éxito',
          'Permisos guardados correctamente',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        throw Exception('Error al guardar permisos');
      }
      
      return success;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error al guardar permisos: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
  
  // Restaurar permisos por defecto
  void resetToDefault() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restaurar Permisos'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres restaurar todos los permisos a sus valores por defecto? Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              // Restaurar usando el servicio
              final permissionsService = Get.find<PermissionsService>();
              await permissionsService.restoreDefaultPermissions();
              _loadPermissions(); // Recargar en el controlador
              Get.snackbar(
                'Restaurado',
                'Permisos restaurados a valores por defecto',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
  
  // Obtener estadísticas de permisos
  Map<String, int> getPermissionStats() {
    final stats = <String, int>{};
    
    for (final role in UserRole.values) {
      final count = editablePermissions[role]?.length ?? 0;
      stats[role.name] = count;
    }
    
    return stats;
  }
} 