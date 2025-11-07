import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _useSQLiteKey = 'use_sqlite';
  static const String _migrationCompletedKey = 'migration_completed';
  
  // Verificar si usar SQLite
  static Future<bool> shouldUseSQLite() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSQLiteKey) ?? false;
  }
  
  // Habilitar SQLite
  static Future<void> enableSQLite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSQLiteKey, true);
  }
  
  // Deshabilitar SQLite (volver a Isar)
  static Future<void> disableSQLite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSQLiteKey, false);
  }
  
  // Marcar migración como completada
  static Future<void> markMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationCompletedKey, true);
  }
  
  // Verificar si la migración está completada
  static Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationCompletedKey) ?? false;
  }
  
  // Obtener información de configuración
  static Future<Map<String, dynamic>> getConfigInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'useSQLite': prefs.getBool(_useSQLiteKey) ?? false,
      'migrationCompleted': prefs.getBool(_migrationCompletedKey) ?? false,
    };
  }
} 