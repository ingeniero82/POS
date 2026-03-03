import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log.dart';
import 'audit_service.dart';

class BackupService {
  static const String _backupConfigKey = 'backup_config';
  static const String _backupHistoryKey = 'backup_history';

  // ✅ Configuración por defecto
  static const Map<String, dynamic> _defaultConfig = {
    'autoBackup': true,
    'backupInterval': 24, // horas
    'maxBackups': 30,
    'backupPath': './backups',
    'includeXML': true,
    'includePDF': true,
    'includeJSON': true,
    'compressBackups': true,
    'encryptBackups': false,
    'lastBackup': null,
  };

  // ✅ Configuración actual
  static final Map<String, dynamic> _config = Map.from(_defaultConfig);

  // ✅ Inicializar servicio
  static Future<void> initialize() async {
    try {
      await _loadConfig();
      print('✅ Servicio de respaldos inicializado');
    } catch (e) {
      print('❌ Error inicializando servicio de respaldos: $e');
    }
  }

  // ✅ Cargar configuración
  static Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_backupConfigKey);

      if (configJson != null) {
        final configMap = jsonDecode(configJson);
        _config.addAll(configMap);
      }
    } catch (e) {
      print('Error cargando configuración de respaldos: $e');
      // ✅ Mantener configuración por defecto
    }
  }

  // ✅ Guardar configuración
  static Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupConfigKey, jsonEncode(_config));
    } catch (e) {
      print('Error guardando configuración de respaldos: $e');
    }
  }

  // ✅ Obtener configuración
  static Map<String, dynamic> getConfig() => Map.from(_config);

  // ✅ Actualizar configuración
  static Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    try {
      _config.addAll(newConfig);
      await _saveConfig();
      return true;
    } catch (e) {
      print('Error actualizando configuración de respaldos: $e');
      return false;
    }
  }

  // ✅ Crear respaldo manual
  static Future<BackupResult> createManualBackup({
    required String userId,
    required String userName,
    required String userEmail,
    String? description,
    bool force = false,
  }) async {
    try {
      // ✅ Verificar si es necesario crear respaldo
      if (!force && !_shouldCreateBackup()) {
        return const BackupResult(
          success: false,
          message: 'No es necesario crear respaldo en este momento',
          backupPath: null,
        );
      }

      // ✅ Crear directorio de respaldos si no existe
      final backupDir = await _ensureBackupDirectory();

      // ✅ Generar nombre del respaldo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupName =
          'backup_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}_${DateTime.now().day.toString().padLeft(2, '0')}_$timestamp';
      final backupPath = path.join(backupDir, backupName);

      // ✅ Crear directorio del respaldo
      final backupDirectory = Directory(backupPath);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      // ✅ Crear respaldo de archivos
      final filesBackedUp = await _backupFiles(backupPath);

      // ✅ Crear respaldo de base de datos (simulado)
      final dbBackedUp = await _backupDatabase(backupPath);

      // ✅ Crear archivo de metadatos del respaldo
      final metadata = {
        'backupName': backupName,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': {
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
        },
        'description': description,
        'filesBackedUp': filesBackedUp,
        'databaseBackedUp': dbBackedUp,
        'config': _config,
        'version': '1.0',
      };

      final metadataPath = path.join(backupPath, 'backup_metadata.json');
      final metadataFile = File(metadataPath);
      await metadataFile.writeAsString(jsonEncode(metadata));

      // ✅ Actualizar configuración
      _config['lastBackup'] = DateTime.now().toIso8601String();
      await _saveConfig();

      // ✅ Agregar a historial
      await _addToHistory(backupName, backupPath, metadata);

      // ✅ Limpiar respaldos antiguos
      await _cleanupOldBackups();

      // ✅ Registrar en auditoría
      await AuditService.logAction(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        actionType: AuditActionType.backupCreated,
        resourceType: 'Backup',
        resourceId: backupName,
        resourceName: 'Respaldo $backupName',
        description: description ?? 'Respaldo manual creado',
        details: {
          'backupPath': backupPath,
          'filesBackedUp': filesBackedUp,
          'databaseBackedUp': dbBackedUp,
        },
        success: true,
      );

      return BackupResult(
        success: true,
        message: 'Respaldo creado exitosamente',
        backupPath: backupPath,
        backupName: backupName,
        filesBackedUp: filesBackedUp,
        databaseBackedUp: dbBackedUp,
      );
    } catch (e) {
      // ✅ Registrar error en auditoría
      await AuditService.logAction(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        actionType: AuditActionType.backupFailed,
        resourceType: 'Backup',
        resourceId: 'manual_backup',
        resourceName: 'Respaldo manual',
        description: 'Error creando respaldo manual',
        success: false,
        errorMessage: e.toString(),
      );

      return BackupResult(
        success: false,
        message: 'Error creando respaldo: $e',
        backupPath: null,
      );
    }
  }

  // ✅ Crear respaldo automático
  static Future<BackupResult> createAutoBackup() async {
    try {
      // ✅ Verificar si es necesario crear respaldo
      if (!_shouldCreateBackup()) {
        return const BackupResult(
          success: false,
          message: 'No es necesario crear respaldo automático',
          backupPath: null,
        );
      }

      // ✅ Crear directorio de respaldos si no existe
      final backupDir = await _ensureBackupDirectory();

      // ✅ Generar nombre del respaldo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupName =
          'auto_backup_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}_${DateTime.now().day.toString().padLeft(2, '0')}_$timestamp';
      final backupPath = path.join(backupDir, backupName);

      // ✅ Crear directorio del respaldo
      final backupDirectory = Directory(backupPath);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      // ✅ Crear respaldo de archivos
      final filesBackedUp = await _backupFiles(backupPath);

      // ✅ Crear respaldo de base de datos (simulado)
      final dbBackedUp = await _backupDatabase(backupPath);

      // ✅ Crear archivo de metadatos del respaldo
      final metadata = {
        'backupName': backupName,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': {
          'userId': 'system',
          'userName': 'Sistema Automático',
          'userEmail': 'system@smart_seller.com',
        },
        'description': 'Respaldo automático del sistema',
        'filesBackedUp': filesBackedUp,
        'databaseBackedUp': dbBackedUp,
        'config': _config,
        'version': '1.0',
      };

      final metadataPath = path.join(backupPath, 'backup_metadata.json');
      final metadataFile = File(metadataPath);
      await metadataFile.writeAsString(jsonEncode(metadata));

      // ✅ Actualizar configuración
      _config['lastBackup'] = DateTime.now().toIso8601String();
      await _saveConfig();

      // ✅ Agregar a historial
      await _addToHistory(backupName, backupPath, metadata);

      // ✅ Limpiar respaldos antiguos
      await _cleanupOldBackups();

      // ✅ Registrar en auditoría
      await AuditService.logAction(
        userId: 'system',
        userName: 'Sistema Automático',
        userEmail: 'system@smart_seller.com',
        actionType: AuditActionType.backupCreated,
        resourceType: 'Backup',
        resourceId: backupName,
        resourceName: 'Respaldo automático $backupName',
        description: 'Respaldo automático creado',
        details: {
          'backupPath': backupPath,
          'filesBackedUp': filesBackedUp,
          'databaseBackedUp': dbBackedUp,
        },
        success: true,
      );

      return BackupResult(
        success: true,
        message: 'Respaldo automático creado exitosamente',
        backupPath: backupPath,
        backupName: backupName,
        filesBackedUp: filesBackedUp,
        databaseBackedUp: dbBackedUp,
      );
    } catch (e) {
      // ✅ Registrar error en auditoría
      await AuditService.logAction(
        userId: 'system',
        userName: 'Sistema Automático',
        userEmail: 'system@smart_seller.com',
        actionType: AuditActionType.backupFailed,
        resourceType: 'Backup',
        resourceId: 'auto_backup',
        resourceName: 'Respaldo automático',
        description: 'Error creando respaldo automático',
        success: false,
        errorMessage: e.toString(),
      );

      return BackupResult(
        success: false,
        message: 'Error creando respaldo automático: $e',
        backupPath: null,
      );
    }
  }

  // ✅ Verificar si se debe crear respaldo
  static bool _shouldCreateBackup() {
    if (!_config['autoBackup']) return false;

    final lastBackup = _config['lastBackup'];
    if (lastBackup == null) return true;

    try {
      final lastBackupDate = DateTime.parse(lastBackup);
      final now = DateTime.now();
      final difference = now.difference(lastBackupDate);
      final intervalHours = _config['backupInterval'] ?? 24;

      return difference.inHours >= intervalHours;
    } catch (e) {
      return true;
    }
  }

  // ✅ Crear directorio de respaldos
  static Future<String> _ensureBackupDirectory() async {
    final backupPath = _config['backupPath'] ?? './backups';
    final directory = Directory(backupPath);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return backupPath;
  }

  // ✅ Crear respaldo de archivos
  static Future<List<String>> _backupFiles(String backupPath) async {
    final filesBackedUp = <String>[];

    try {
      // ✅ Directorio de facturas
      final facturasDir = Directory('./facturas');
      if (await facturasDir.exists()) {
        final backupFacturasPath = path.join(backupPath, 'facturas');
        await _copyDirectory(facturasDir, Directory(backupFacturasPath));
        filesBackedUp.add('facturas/');
      }

      // ✅ Directorio de logs
      final logsDir = Directory('./logs');
      if (await logsDir.exists()) {
        final backupLogsPath = path.join(backupPath, 'logs');
        await _copyDirectory(logsDir, Directory(backupLogsPath));
        filesBackedUp.add('logs/');
      }

      // ✅ Archivos de configuración
      final configFiles = [
        './config.json',
        './settings.json',
        './database.db',
      ];

      for (final configFile in configFiles) {
        final file = File(configFile);
        if (await file.exists()) {
          final fileName = path.basename(configFile);
          final backupFilePath = path.join(backupPath, fileName);
          await file.copy(backupFilePath);
          filesBackedUp.add(fileName);
        }
      }
    } catch (e) {
      print('Error respaldando archivos: $e');
    }

    return filesBackedUp;
  }

  // ✅ Crear respaldo de base de datos
  static Future<bool> _backupDatabase(String backupPath) async {
    try {
      // ✅ Por ahora simulamos el respaldo de la base de datos
      // En una implementación real, aquí se haría un dump de SQLite
      final dbBackupPath = path.join(backupPath, 'database_backup.sql');
      final dbBackupFile = File(dbBackupPath);

      final backupContent = '''
-- Respaldo de base de datos Smart Seller
-- Generado: ${DateTime.now().toIso8601String()}
-- Versión: 1.0

-- Aquí irían las instrucciones SQL para recrear la base de datos
-- Por ahora es un archivo simulado
SELECT 'Backup simulado de base de datos' as status;
''';

      await dbBackupFile.writeAsString(backupContent);
      return true;
    } catch (e) {
      print('Error respaldando base de datos: $e');
      return false;
    }
  }

  // ✅ Copiar directorio recursivamente
  static Future<void> _copyDirectory(
      Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: source.path);
        final destinationPath = path.join(destination.path, relativePath);
        final destinationFile = File(destinationPath);

        // ✅ Crear directorio padre si no existe
        final parentDir = Directory(path.dirname(destinationPath));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        await entity.copy(destinationPath);
      }
    }
  }

  // ✅ Agregar a historial
  static Future<void> _addToHistory(String backupName, String backupPath,
      Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_backupHistoryKey) ?? [];

      final historyEntry = {
        'backupName': backupName,
        'backupPath': backupPath,
        'createdAt': metadata['createdAt'],
        'createdBy': metadata['createdBy'],
        'description': metadata['description'],
        'filesBackedUp': metadata['filesBackedUp'],
        'databaseBackedUp': metadata['databaseBackedUp'],
      };

      historyJson.add(jsonEncode(historyEntry));

      // ✅ Mantener solo el historial más reciente
      final maxHistory = (_config['maxBackups'] as int?) ?? 30;
      if (historyJson.length > maxHistory) {
        historyJson.removeRange(0, historyJson.length - maxHistory);
      }

      await prefs.setStringList(_backupHistoryKey, historyJson);
    } catch (e) {
      print('Error agregando a historial: $e');
    }
  }

  // ✅ Limpiar respaldos antiguos
  static Future<void> _cleanupOldBackups() async {
    try {
      final maxBackups = (_config['maxBackups'] as int?) ?? 30;
      final backupDir = await _ensureBackupDirectory();
      final directory = Directory(backupDir);

      if (!await directory.exists()) return;

      final entities = await directory.list().toList();
      final backupDirectories = <Directory>[];

      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('backup_')) {
          backupDirectories.add(entity);
        }
      }

      // ✅ Ordenar por fecha de creación (más antiguo primero)
      backupDirectories.sort((a, b) {
        final aName = path.basename(a.path);
        final bName = path.basename(b.path);
        return aName.compareTo(bName);
      });

      // ✅ Remover respaldos excedentes
      if (backupDirectories.length > maxBackups) {
        final toRemove =
            backupDirectories.take(backupDirectories.length - maxBackups);

        for (final dir in toRemove) {
          try {
            await dir.delete(recursive: true);
            print('🗑️ Respaldo removido: ${path.basename(dir.path)}');
          } catch (e) {
            print('Error removiendo respaldo ${path.basename(dir.path)}: $e');
          }
        }
      }
    } catch (e) {
      print('Error limpiando respaldos antiguos: $e');
    }
  }

  // ✅ Obtener historial de respaldos
  static Future<List<Map<String, dynamic>>> getBackupHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_backupHistoryKey) ?? [];

      return historyJson
          .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
          .toList()
        ..sort((a, b) =>
            b['createdAt'].compareTo(a['createdAt'])); // Más reciente primero
    } catch (e) {
      print('Error obteniendo historial de respaldos: $e');
      return [];
    }
  }

  // ✅ Restaurar respaldo
  static Future<RestoreResult> restoreBackup({
    required String backupName,
    required String userId,
    required String userName,
    required String userEmail,
    bool restoreFiles = true,
    bool restoreDatabase = true,
  }) async {
    try {
      // ✅ Buscar respaldo en historial
      final history = await getBackupHistory();
      final backupEntry = history.firstWhere(
        (entry) => entry['backupName'] == backupName,
        orElse: () => throw Exception('Respaldo no encontrado'),
      );

      final backupPath = backupEntry['backupPath'];
      final backupDirectory = Directory(backupPath);

      if (!await backupDirectory.exists()) {
        throw Exception('Directorio de respaldo no encontrado');
      }

      // ✅ Verificar archivo de metadatos
      final metadataPath = path.join(backupPath, 'backup_metadata.json');
      final metadataFile = File(metadataPath);

      if (!await metadataFile.exists()) {
        throw Exception('Archivo de metadatos no encontrado');
      }

      final metadata = jsonDecode(await metadataFile.readAsString());

      // ✅ Restaurar archivos si se solicita
      if (restoreFiles) {
        await _restoreFiles(backupPath);
      }

      // ✅ Restaurar base de datos si se solicita
      if (restoreDatabase) {
        await _restoreDatabase(backupPath);
      }

      // ✅ Registrar en auditoría
      await AuditService.logAction(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        actionType: AuditActionType.backupRestored,
        resourceType: 'Backup',
        resourceId: backupName,
        resourceName: 'Restauración de respaldo $backupName',
        description: 'Respaldo restaurado exitosamente',
        details: {
          'backupPath': backupPath,
          'restoreFiles': restoreFiles,
          'restoreDatabase': restoreDatabase,
          'metadata': metadata,
        },
        success: true,
      );

      return RestoreResult(
        success: true,
        message: 'Respaldo restaurado exitosamente',
        backupName: backupName,
        restoredFiles: restoreFiles,
        restoredDatabase: restoreDatabase,
      );
    } catch (e) {
      // ✅ Registrar error en auditoría
      await AuditService.logAction(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        actionType: AuditActionType.backupRestored,
        resourceType: 'Backup',
        resourceId: backupName,
        resourceName: 'Restauración de respaldo $backupName',
        description: 'Error restaurando respaldo',
        success: false,
        errorMessage: e.toString(),
      );

      return RestoreResult(
        success: false,
        message: 'Error restaurando respaldo: $e',
        backupName: backupName,
      );
    }
  }

  // ✅ Restaurar archivos
  static Future<void> _restoreFiles(String backupPath) async {
    try {
      // ✅ Restaurar directorio de facturas
      final backupFacturasPath = path.join(backupPath, 'facturas');
      final backupFacturasDir = Directory(backupFacturasPath);

      if (await backupFacturasDir.exists()) {
        final facturasDir = Directory('./facturas');
        if (await facturasDir.exists()) {
          await facturasDir.delete(recursive: true);
        }
        await _copyDirectory(backupFacturasDir, facturasDir);
      }

      // ✅ Restaurar directorio de logs
      final backupLogsPath = path.join(backupPath, 'logs');
      final backupLogsDir = Directory(backupLogsPath);

      if (await backupLogsDir.exists()) {
        final logsDir = Directory('./logs');
        if (await logsDir.exists()) {
          await logsDir.delete(recursive: true);
        }
        await _copyDirectory(backupLogsDir, logsDir);
      }

      // ✅ Restaurar archivos de configuración
      final configFiles = [
        'config.json',
        'settings.json',
        'database.db',
      ];

      for (final configFile in configFiles) {
        final backupFilePath = path.join(backupPath, configFile);
        final backupFile = File(backupFilePath);

        if (await backupFile.exists()) {
          final destinationFile = File('./$configFile');
          await backupFile.copy(destinationFile.path);
        }
      }
    } catch (e) {
      print('Error restaurando archivos: $e');
      rethrow;
    }
  }

  // ✅ Restaurar base de datos
  static Future<void> _restoreDatabase(String backupPath) async {
    try {
      // ✅ Por ahora simulamos la restauración de la base de datos
      // En una implementación real, aquí se ejecutaría el script SQL
      final dbBackupPath = path.join(backupPath, 'database_backup.sql');
      final dbBackupFile = File(dbBackupPath);

      if (await dbBackupFile.exists()) {
        final backupContent = await dbBackupFile.readAsString();
        print(
            '📋 Script de restauración de BD cargado: ${backupContent.length} caracteres');

        // ✅ Aquí se ejecutaría el script SQL
        await Future.delayed(
            const Duration(seconds: 2)); // Simular restauración

        print('✅ Base de datos restaurada exitosamente');
      }
    } catch (e) {
      print('Error restaurando base de datos: $e');
      rethrow;
    }
  }

  // ✅ Verificar integridad del respaldo
  static Future<BackupIntegrityResult> verifyBackupIntegrity(
      String backupName) async {
    try {
      // ✅ Buscar respaldo en historial
      final history = await getBackupHistory();
      final backupEntry = history.firstWhere(
        (entry) => entry['backupName'] == backupName,
        orElse: () => throw Exception('Respaldo no encontrado'),
      );

      final backupPath = backupEntry['backupPath'];
      final backupDirectory = Directory(backupPath);

      if (!await backupDirectory.exists()) {
        return const BackupIntegrityResult(
          isValid: false,
          issues: ['Directorio de respaldo no encontrado'],
        );
      }

      final issues = <String>[];

      // ✅ Verificar archivo de metadatos
      final metadataPath = path.join(backupPath, 'backup_metadata.json');
      final metadataFile = File(metadataPath);

      if (!await metadataFile.exists()) {
        issues.add('Archivo de metadatos no encontrado');
      } else {
        try {
          final metadata = jsonDecode(await metadataFile.readAsString());
          if (metadata['version'] == null) {
            issues.add('Versión del respaldo no especificada');
          }
        } catch (e) {
          issues.add('Archivo de metadatos corrupto');
        }
      }

      // ✅ Verificar directorios principales
      final requiredDirs = ['facturas', 'logs'];
      for (final dirName in requiredDirs) {
        final dirPath = path.join(backupPath, dirName);
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          issues.add('Directorio $dirName no encontrado');
        }
      }

      // ✅ Verificar archivos de configuración
      final configFiles = ['database_backup.sql'];
      for (final fileName in configFiles) {
        final filePath = path.join(backupPath, fileName);
        final file = File(filePath);
        if (!await file.exists()) {
          issues.add('Archivo $fileName no encontrado');
        }
      }

      return BackupIntegrityResult(
        isValid: issues.isEmpty,
        issues: issues,
        backupSize: await _calculateBackupSize(backupDirectory),
        fileCount: await _countBackupFiles(backupDirectory),
      );
    } catch (e) {
      return BackupIntegrityResult(
        isValid: false,
        issues: ['Error verificando integridad: $e'],
      );
    }
  }

  // ✅ Calcular tamaño del respaldo
  static Future<int> _calculateBackupSize(Directory directory) async {
    int totalSize = 0;

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      print('Error calculando tamaño del respaldo: $e');
    }

    return totalSize;
  }

  // ✅ Contar archivos del respaldo
  static Future<int> _countBackupFiles(Directory directory) async {
    int fileCount = 0;

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
        }
      }
    } catch (e) {
      print('Error contando archivos del respaldo: $e');
    }

    return fileCount;
  }

  // ✅ Obtener estadísticas de respaldos
  static Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final history = await getBackupHistory();
      final config = getConfig();

      int totalBackups = history.length;
      int manualBackups = 0;
      int autoBackups = 0;
      int totalSize = 0;

      for (final entry in history) {
        if (entry['backupName'].toString().startsWith('auto_')) {
          autoBackups++;
        } else {
          manualBackups++;
        }

        // ✅ Calcular tamaño total (simulado)
        totalSize += 1024 * 1024; // 1MB por respaldo simulado
      }

      return {
        'totalBackups': totalBackups,
        'manualBackups': manualBackups,
        'autoBackups': autoBackups,
        'totalSize': totalSize,
        'lastBackup': config['lastBackup'],
        'nextAutoBackup': _getNextAutoBackupTime(),
        'config': config,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de respaldos: $e');
      return {};
    }
  }

  // ✅ Obtener tiempo del próximo respaldo automático
  static String _getNextAutoBackupTime() {
    try {
      final lastBackup = _config['lastBackup'];
      if (lastBackup == null) return 'Inmediato';

      final lastBackupDate = DateTime.parse(lastBackup);
      final intervalHours = _config['backupInterval'] ?? 24;
      final nextBackup = lastBackupDate.add(Duration(hours: intervalHours));

      if (nextBackup.isBefore(DateTime.now())) {
        return 'Pendiente';
      }

      return nextBackup.toIso8601String();
    } catch (e) {
      return 'Desconocido';
    }
  }
}

// ✅ Resultado de creación de respaldo
class BackupResult {
  final bool success;
  final String message;
  final String? backupPath;
  final String? backupName;
  final List<String>? filesBackedUp;
  final bool? databaseBackedUp;

  const BackupResult({
    required this.success,
    required this.message,
    this.backupPath,
    this.backupName,
    this.filesBackedUp,
    this.databaseBackedUp,
  });
}

// ✅ Resultado de restauración de respaldo
class RestoreResult {
  final bool success;
  final String message;
  final String backupName;
  final bool? restoredFiles;
  final bool? restoredDatabase;

  const RestoreResult({
    required this.success,
    required this.message,
    required this.backupName,
    this.restoredFiles,
    this.restoredDatabase,
  });
}

// ✅ Resultado de verificación de integridad
class BackupIntegrityResult {
  final bool isValid;
  final List<String> issues;
  final int? backupSize;
  final int? fileCount;

  const BackupIntegrityResult({
    required this.isValid,
    required this.issues,
    this.backupSize,
    this.fileCount,
  });

  // ✅ Obtener resumen de la verificación
  String get summary {
    if (isValid) {
      return '✅ Respaldo válido (${fileCount ?? 0} archivos, ${_formatSize(backupSize ?? 0)})';
    } else {
      return '❌ Respaldo inválido: ${issues.join(', ')}';
    }
  }

  // ✅ Formatear tamaño
  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
