import '../models/user.dart';
import '../services/sqlite_database_service.dart';
/// Usuario de mantenimiento del vendedor (misma lógica que [_createDefaultUser] en SQLite).
class MaintenanceUserSetup {
  static const maintenanceUsername = 'admon';
  static const maintenanceDefaultPassword = '1234';

  static Future<bool> ensureMaintenanceUser() async {
    try {
      final existing =
          await SQLiteDatabaseService.findUser(maintenanceUsername, maintenanceDefaultPassword);
      if (existing != null) {
        return true;
      }

      final any = await SQLiteDatabaseService.userExists(maintenanceUsername);
      if (any) {
        return true;
      }

      final maintenanceUser = User()
        ..username = maintenanceUsername
        ..password = maintenanceDefaultPassword
        ..fullName = 'Mantenimiento (vendedor)'
        ..role = UserRole.maintenance
        ..isActive = true
        ..createdAt = DateTime.now()
        ..userCode = 'MANT-VEND-01';

      await SQLiteDatabaseService.createUser(maintenanceUser);
      return true;
    } catch (e) {
      print('❌ Error asegurando usuario mantenimiento: $e');
      return false;
    }
  }
}
