import '../models/user.dart';
import '../services/sqlite_database_service.dart';

/// Servicio para configurar usuarios de mantenimiento del sistema
class MaintenanceUserSetup {
  /// Crear usuario de mantenimiento por defecto
  /// Usuario: maintenance
  /// Contraseña: maint123
  /// Rol: maintenance
  static Future<bool> createDefaultMaintenanceUser() async {
    try {
      // Verificar si ya existe un usuario de mantenimiento
      final existingUser =
          await SQLiteDatabaseService.findUser('maintenance', 'maint123');
      if (existingUser != null) {
        print('✅ Usuario de mantenimiento ya existe');
        return true;
      }

      // Crear usuario de mantenimiento
      final maintenanceUser = User()
        ..username = 'maintenance'
        ..password = 'maint123'
        ..fullName = 'Usuario de Mantenimiento'
        ..role = UserRole.maintenance
        ..isActive = true
        ..createdAt = DateTime.now()
        ..userCode = 'MAINT-001';

      // Guardar en la base de datos
      await SQLiteDatabaseService.createUser(maintenanceUser);

      // Verificar que se creó correctamente
      final createdUser =
          await SQLiteDatabaseService.findUser('maintenance', 'maint123');
      if (createdUser != null) {
        print('✅ Usuario de mantenimiento creado exitosamente');
        print('   Usuario: maintenance');
        print('   Contraseña: maint123');
        print('   Rol: maintenance');
        return true;
      } else {
        print('❌ Error creando usuario de mantenimiento');
        return false;
      }
    } catch (e) {
      print('❌ Error en setup de usuario de mantenimiento: $e');
      return false;
    }
  }

  /// Verificar si existe al menos un usuario de mantenimiento
  static Future<bool> hasMaintenanceUser() async {
    try {
      // Buscar cualquier usuario con rol de mantenimiento
      final users = await SQLiteDatabaseService.getAllUsers();
      return users.any((user) => user.role == UserRole.maintenance);
    } catch (e) {
      print('❌ Error verificando usuarios de mantenimiento: $e');
      return false;
    }
  }

  /// Obtener información del usuario de mantenimiento
  static Future<User?> getMaintenanceUser() async {
    try {
      final users = await SQLiteDatabaseService.getAllUsers();
      return users.firstWhere((user) => user.role == UserRole.maintenance);
    } catch (e) {
      print('❌ Error obteniendo usuario de mantenimiento: $e');
      return null;
    }
  }

  /// Cambiar contraseña del usuario de mantenimiento
  static Future<bool> changeMaintenancePassword(String newPassword) async {
    try {
      final maintenanceUser = await getMaintenanceUser();
      if (maintenanceUser == null) {
        print('❌ No se encontró usuario de mantenimiento');
        return false;
      }

      maintenanceUser.password = newPassword;

      await SQLiteDatabaseService.updateUser(maintenanceUser);

      // Verificar que se actualizó correctamente
      final updatedUser =
          await SQLiteDatabaseService.findUser('maintenance', newPassword);
      if (updatedUser != null) {
        print('✅ Contraseña de mantenimiento actualizada');
        return true;
      } else {
        print('❌ Error actualizando contraseña');
        return false;
      }
    } catch (e) {
      print('❌ Error cambiando contraseña: $e');
      return false;
    }
  }
}
