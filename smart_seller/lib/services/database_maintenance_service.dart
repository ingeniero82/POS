import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'sqlite_database_service.dart';

/// Servicio de mantenimiento de base de datos
/// Optimiza, limpia y respalda la base de datos automáticamente
class DatabaseMaintenanceService {
  
  /// Optimizar la base de datos (VACUUM)
  /// IMPORTANTE: SOLO REORGANIZA, NUNCA BORRA DATOS
  /// 
  /// VACUUM: Reorganiza los datos para ocupar menos espacio
  ///         NO borra registros, solo elimina espacio vacío
  ///         Es como desfragmentar un disco duro
  /// 
  /// ANALYZE: Actualiza estadísticas para mejor rendimiento
  ///          NO toca los datos, solo mejora las consultas
  static Future<void> optimizeDatabase() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return;
      
      print('🔧 Optimizando base de datos (NO borra datos)...');
      
      // VACUUM reorganiza la base de datos y libera espacio
      // IMPORTANTE: NO borra registros, solo reorganiza
      await db.execute('VACUUM');
      
      // ANALYZE actualiza las estadísticas para mejor rendimiento
      // IMPORTANTE: NO toca los datos, solo mejora consultas
      await db.execute('ANALYZE');
      
      print('✅ Base de datos optimizada (sin borrar datos)');
    } catch (e) {
      print('❌ Error al optimizar base de datos: $e');
    }
  }
  
  /// Obtener el tamaño actual de la base de datos
  static Future<int> getDatabaseSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, 'smart_seller.db');
      final file = File(path);
      
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      print('❌ Error al obtener tamaño: $e');
      return 0;
    }
  }
  
  /// Obtener tamaño en formato legible (MB, GB)
  static Future<String> getDatabaseSizeFormatted() async {
    final size = await getDatabaseSize();
    if (size < 1024) {
      return '$size bytes';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
  
  /// Limpiar ventas antiguas (opcional - configurable)
  /// Por defecto mantiene los últimos 2 años
  static Future<int> cleanOldSales({int keepYears = 2}) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return 0;
      
      print('🧹 Limpiando ventas antiguas (manteniendo últimos $keepYears años)...');
      
      final cutoffDate = DateTime.now().subtract(Duration(days: keepYears * 365));
      final cutoffDateString = cutoffDate.toIso8601String();
      
      // Contar registros a eliminar
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales WHERE date < ?',
        [cutoffDateString]
      );
      final count = countResult.first['count'] as int;
      
      if (count == 0) {
        print('ℹ️ No hay ventas antiguas para eliminar');
        return 0;
      }
      
      // Eliminar ventas antiguas
      await db.delete(
        'sales',
        where: 'date < ?',
        whereArgs: [cutoffDateString],
      );
      
      // Eliminar items de ventas huérfanas
      await db.execute('''
        DELETE FROM sale_items 
        WHERE saleId NOT IN (SELECT id FROM sales)
      ''');
      
      print('✅ Eliminadas $count ventas antiguas');
      return count;
    } catch (e) {
      print('❌ Error al limpiar ventas antiguas: $e');
      return 0;
    }
  }
  
  /// Limpiar movimientos de inventario antiguos
  static Future<int> cleanOldInventoryMovements({int keepMonths = 12}) async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return 0;
      
      print('🧹 Limpiando movimientos de inventario antiguos...');
      
      final cutoffDate = DateTime.now().subtract(Duration(days: keepMonths * 30));
      final cutoffDateString = cutoffDate.toIso8601String();
      
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM inventory_movements WHERE date < ?',
        [cutoffDateString]
      );
      final count = countResult.first['count'] as int;
      
      if (count == 0) {
        print('ℹ️ No hay movimientos antiguos para eliminar');
        return 0;
      }
      
      await db.delete(
        'inventory_movements',
        where: 'date < ?',
        whereArgs: [cutoffDateString],
      );
      
      print('✅ Eliminados $count movimientos antiguos');
      return count;
    } catch (e) {
      print('❌ Error al limpiar movimientos: $e');
      return 0;
    }
  }
  
  /// Crear respaldo de la base de datos
  static Future<String?> createBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sourcePath = join(dir.path, 'smart_seller.db');
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        print('❌ Base de datos no encontrada');
        return null;
      }
      
      // Crear carpeta de respaldos
      final backupDir = Directory(join(dir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // Nombre del respaldo con fecha
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupPath = join(backupDir.path, 'smart_seller_backup_$timestamp.db');
      
      // Copiar archivo
      await sourceFile.copy(backupPath);
      
      print('✅ Respaldo creado: $backupPath');
      return backupPath;
    } catch (e) {
      print('❌ Error al crear respaldo: $e');
      return null;
    }
  }
  
  /// Limpiar respaldos antiguos (mantener solo los últimos N)
  static Future<void> cleanOldBackups({int keepCount = 10}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(dir.path, 'backups'));
      
      if (!await backupDir.exists()) return;
      
      final backups = await backupDir
          .list()
          .where((entity) => entity.path.endsWith('.db'))
          .toList();
      
      // Ordenar por fecha de modificación (más recientes primero)
      backups.sort((a, b) {
        final aStat = (a as File).statSync();
        final bStat = (b as File).statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      // Eliminar respaldos antiguos
      if (backups.length > keepCount) {
        for (var i = keepCount; i < backups.length; i++) {
          await backups[i].delete();
          print('🗑️ Eliminado respaldo antiguo: ${backups[i].path}');
        }
      }
    } catch (e) {
      print('❌ Error al limpiar respaldos: $e');
    }
  }
  
  /// Mantenimiento completo automático
  /// Se puede ejecutar periódicamente (semanal, mensual)
  static Future<Map<String, dynamic>> performFullMaintenance({
    bool optimize = true,
    bool cleanOldData = false,
    bool createBackup = true,
    int keepYears = 2,
  }) async {
    final results = <String, dynamic>{};
    
    try {
      print('🔧 Iniciando mantenimiento completo de base de datos...');
      
      // 1. Crear respaldo
      if (createBackup) {
        final backupPath = await DatabaseMaintenanceService.createBackup();
        results['backup'] = backupPath != null;
        await DatabaseMaintenanceService.cleanOldBackups();
      }
      
      // 2. Limpiar datos antiguos (opcional)
      if (cleanOldData) {
        final salesDeleted = await cleanOldSales(keepYears: keepYears);
        final movementsDeleted = await cleanOldInventoryMovements(keepMonths: keepYears * 6);
        results['salesDeleted'] = salesDeleted;
        results['movementsDeleted'] = movementsDeleted;
      }
      
      // 3. Optimizar base de datos
      if (optimize) {
        await optimizeDatabase();
        results['optimized'] = true;
      }
      
      // 4. Obtener tamaño final
      final size = await getDatabaseSizeFormatted();
      results['finalSize'] = size;
      
      print('✅ Mantenimiento completo finalizado');
      return results;
    } catch (e) {
      print('❌ Error en mantenimiento: $e');
      results['error'] = e.toString();
      return results;
    }
  }
  
  /// Obtener estadísticas de la base de datos
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return {};
      
      final stats = <String, dynamic>{};
      
      // Contar registros en cada tabla
      final tables = ['users', 'products', 'sales', 'sale_items', 'customers', 'inventory_movements'];
      
      for (final table in tables) {
        try {
          final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          stats[table] = result.first['count'] as int;
        } catch (e) {
          stats[table] = 0;
        }
      }
      
      // Tamaño de la base de datos
      stats['size'] = await getDatabaseSizeFormatted();
      stats['sizeBytes'] = await getDatabaseSize();
      
      return stats;
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {};
    }
  }
}

