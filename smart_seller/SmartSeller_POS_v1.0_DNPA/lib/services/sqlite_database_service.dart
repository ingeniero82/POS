import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/inventory_movement.dart';
import '../models/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert'; // Added for jsonDecode
import '../models/customer.dart'; // Added for Customer model
import '../models/client.dart'; // Added for Client model
import '../models/company_config.dart'; // Added for CompanyConfig model
import '../models/group.dart'; // Added for Group model
import 'security_service.dart'; // Added for password security

class SQLiteDatabaseService {
  static Database? _database;
  static const String defaultGroupName = 'Otros';

  // Getter público para acceder a la base de datos
  static Database? get database => _database;

  // Inicializar la base de datos
  static Future<void> initialize() async {
    print('🚀 Inicializando base de datos SQLite...');
    // Inicialización para escritorio (Windows, Linux, Mac)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Carpeta fija en AppData\Local\SmartSellerPOS (Windows) para que el usuario la encuentre si la busca
    final String appDirPath;
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      appDirPath = localAppData != null && localAppData.isNotEmpty
          ? join(localAppData, 'SmartSellerPOS')
          : join(
              (await getApplicationSupportDirectory()).path, 'SmartSellerPOS');
    } else {
      appDirPath =
          join((await getApplicationSupportDirectory()).path, 'SmartSellerPOS');
    }
    final appDir = Directory(appDirPath);
    if (!await appDir.exists()) await appDir.create(recursive: true);
    final path = join(appDir.path, 'smart_seller.db');

    // Migración única: si la BD está en Documentos, copiarla a la nueva ubicación
    final docsDir = await getApplicationDocumentsDirectory();
    final oldPath = join(docsDir.path, 'smart_seller.db');
    final oldFile = File(oldPath);
    if (await oldFile.exists() && !await File(path).exists()) {
      await oldFile.copy(path);
      print('✅ Base de datos migrada de Documentos a carpeta de aplicación');
    }

    _database = await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    print('✅ Base de datos SQLite abierta en: $path');

    // Crear usuario admin por defecto
    await migrateAddIsWeighted();
    await _createDefaultUser();

    // Ejecutar migración para agregar userCode si es necesario
    await migrateAddUserCode();

    // Asignar códigos a usuarios existentes que no los tienen
    await assignCodesToExistingUsers();

    // Listar todos los usuarios para depuración
    await debugListAllUsers();
    // Llama a la migración después de abrir la base de datos
    await migrateAddPricePerKg();
    await migrateAddWeightColumns();
    await migrateAddWeightedStockKgColumns();

    // Crear grupos por defecto si no existen
    await migrateAddGroupsTable();
    await ensureDefaultGroupsIfEmpty();

    // ✅ NUEVO: Migración para agregar columna category
    await migrateAddCategoryColumn();

    // ✅ FORZAR MIGRACIÓN: Asegurar que category existe
    await forceAddCategoryColumn();
    await ensureDefaultGroupExists();
    await normalizeProductCategories();

    // ✅ NUEVO: Asegurar que la tabla customers existe (SOLO CLIENTES)
    await ensureCustomersTableExists();

    // ✅ NUEVO: Migración para tablas de proveedores y contabilidad
    await migrateAddSuppliersTables();

    // ✅ Fase 1: precios de compra producto–proveedor (tabla aparte)
    await migrateAddProductSupplierPricesTable();
    // ✅ Fase 2: historial de precios por producto–proveedor
    await migrateAddProductSupplierPriceHistoryTable();

    // ✅ NUEVO: Migración para tablas de contabilidad
    await migrateAddAccountingTables();

    // ❌ NO cerrar sesiones de caja al iniciar: la caja solo se cierra con el
    // procedimiento manual de cierre/arqueo. Así se mantiene trazabilidad,
    // se evitan ventas "huérfanas" y múltiples turnos (Juan abre, María continúa).

    // ✅ NUEVO: Migración para cuentas por cobrar y pagar
    await migrateAddAccountsReceivablePayableTables();

    // ✅ Migrar company_config para agregar columnas de facturación (document_type, etc.)
    await _migrateCompanyConfigTable(_database!);

    // ✅ Asegurar columna payment_breakdown en sales (bases antiguas en PC del cliente)
    await _ensureSalesPaymentBreakdownColumn();
    // ✅ Asegurar columnas customer_id y client_id en sales (para reimpresión con nombre del cliente)
    await _ensureSalesCustomerClientColumns();

    // Código corto opcional (NULL si no se define; evita colisiones por truncar EAN).
    await migrateProductShortCodeNullable();
  }

  /// Agrega payment_breakdown a sales si no existe (para DB ya creadas sin esa columna).
  static Future<void> _ensureSalesPaymentBreakdownColumn() async {
    try {
      final info = await _database!.rawQuery('PRAGMA table_info(sales)');
      final hasColumn = info.any((c) =>
          ((c['name'] as String?) ?? '').toLowerCase() == 'payment_breakdown');
      if (!hasColumn) {
        await _database!
            .execute('ALTER TABLE sales ADD COLUMN payment_breakdown TEXT');
        print('✅ Columna payment_breakdown agregada a tabla sales');
      }
    } catch (e) {
      print('⚠️ Error verificando/agregando payment_breakdown: $e');
    }
  }

  /// Agrega customer_id y client_id a sales si no existen (para reimpresión con datos del cliente).
  static Future<void> _ensureSalesCustomerClientColumns() async {
    try {
      final info = await _database!.rawQuery('PRAGMA table_info(sales)');
      final names = (info
          .map((c) => ((c['name'] as String?) ?? '').toLowerCase())).toSet();
      if (!names.contains('customer_id')) {
        await _database!
            .execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');
        print('✅ Columna customer_id agregada a tabla sales');
      }
      if (!names.contains('client_id')) {
        await _database!
            .execute('ALTER TABLE sales ADD COLUMN client_id INTEGER');
        print('✅ Columna client_id agregada a tabla sales');
      }
    } catch (e) {
      print('⚠️ Error verificando/agregando customer_id/client_id: $e');
    }
  }

// ✅ NUEVO: Limpiar sesiones de caja abiertas al iniciar la aplicación
  static Future<void> _cleanupOpenCashSessions() async {
    try {
      print('🧹 Limpiando sesiones de caja abiertas...');

      // Obtener todas las sesiones abiertas
      final List<Map<String, dynamic>> openSessions = await _database!.query(
        'cash_sessions',
        where: 'status = ? AND is_active = ?',
        whereArgs: ['open', 1],
      );

      if (openSessions.isEmpty) {
        print('ℹ️ No hay sesiones de caja abiertas');
        return;
      }

      // Cerrar cada sesión abierta
      for (var sessionMap in openSessions) {
        final sessionId = sessionMap['id'] as int;
        final userId = sessionMap['user_id'] as int;

        await _database!.update(
          'cash_sessions',
          {
            'status': 'closed',
            'close_date': DateTime.now().toIso8601String(),
            'final_amount': 0.0,
            'total_income': 0.0,
            'total_expense': 0.0,
            'difference': 0.0,
            'closed_by_user_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
            'notes': 'Cerrada automáticamente al iniciar aplicación',
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );

        print('✅ Sesión de caja cerrada automáticamente: $sessionId');
      }

      print('✅ Todas las sesiones de caja abiertas han sido cerradas');
    } catch (e) {
      print('❌ Error limpiando sesiones de caja: $e');
    }
  }

// Crear las tablas
  static Future<void> _onCreate(Database db, int version) async {
    print('🔧 Creando tablas de la base de datos...');

    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        fullName TEXT NOT NULL,
        role TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        userCode TEXT
      )
    ''');

    // Tabla de grupos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de productos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        shortCode TEXT UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        minStock INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        imageUrl TEXT,
        ivaPercentage INTEGER NOT NULL DEFAULT 19,
        isWeighted INTEGER NOT NULL DEFAULT 0,
        pricePerKg REAL,
        weight REAL,
        minWeight REAL,
        maxWeight REAL,
        weightedStockInKg INTEGER NOT NULL DEFAULT 0,
        stockKg REAL NOT NULL DEFAULT 0
      )
    ''');

    // Tabla de movimientos de inventario
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        userId INTEGER NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Tabla de ventas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        user TEXT NOT NULL,
        paymentMethod TEXT,
        payment_breakdown TEXT,
        items TEXT NOT NULL,
        discount REAL DEFAULT 0.0,
        discountPercentage REAL DEFAULT 0.0,
        isReturn INTEGER DEFAULT 0,
        originalSaleId INTEGER,
        returnedAmount REAL DEFAULT 0.0,
        anulada INTEGER DEFAULT 0,
        anulada_at TEXT,
        anulada_por TEXT
      )
    ''');

    // Tabla de clientes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        city TEXT,
        documentNumber TEXT,
        documentType TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        pointsRate REAL NOT NULL DEFAULT 1.0,
        accumulatedPoints INTEGER NOT NULL DEFAULT 0,
        lastPurchase TEXT,
        totalPurchases REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Tabla de configuración de empresa
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        website TEXT,
        tax_id TEXT,
        header_text TEXT NOT NULL,
        footer_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de clientes para facturación electrónica DIAN
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        documentType TEXT NOT NULL,
        documentNumber TEXT UNIQUE NOT NULL,
        businessName TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        fiscalResponsibility TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        city TEXT,
        department TEXT,
        country TEXT,
        postalCode TEXT,
        contactPerson TEXT,
        notes TEXT
      )
    ''');

    print('✅ Tablas creadas exitosamente');
  }

  // Actualizar base de datos
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando base de datos de v$oldVersion a v$newVersion');

    // Migración de versión 1 a 2: Agregar tabla de configuración de empresa
    if (oldVersion < 2) {
      print('🔧 Verificando tabla company_config...');

      // Verificar si la tabla ya existe antes de crearla
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='company_config'");

      if (result.isEmpty) {
        print('🔧 Creando tabla company_config...');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS company_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name TEXT NOT NULL,
            address TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            website TEXT,
            tax_id TEXT,
            header_text TEXT NOT NULL,
            footer_text TEXT NOT NULL,
            document_type TEXT,
            nit_number TEXT,
            verification_digit TEXT,
            city TEXT,
            department TEXT,
            country TEXT,
            fiscal_regime TEXT,
            fiscal_responsibilities TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('✅ Tabla company_config creada');
      } else {
        print('✅ Tabla company_config ya existe, verificando columnas...');
        // Verificar si necesitamos agregar las nuevas columnas para facturación electrónica
        await _migrateCompanyConfigTable(db);
      }
    }

    // Migración de versión 2 a 3: Agregar campos de descuentos y devoluciones a tabla sales
    if (oldVersion < 3) {
      print(
          '🔧 Agregando campos de descuentos y devoluciones a tabla sales...');
      await migrateAddDiscountsAndReturns(db);
    }

    if (oldVersion < 4) {
      print('🔧 Agregando columna payment_breakdown para pago mixto...');
      await _migratePaymentBreakdown(db);
    }

    if (oldVersion < 5) {
      print('🔧 Agregando columna city a tabla customers...');
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN city TEXT');
        print('✅ Columna city agregada a customers');
      } catch (e) {
        print('ℹ️ Columna city ya existe en customers');
      }
    }

    // Migración versión 6: Anulación de ventas
    if (oldVersion < 6) {
      print('🔧 Agregando columnas de anulación a tabla sales...');
      try {
        await db
            .execute('ALTER TABLE sales ADD COLUMN anulada INTEGER DEFAULT 0');
        print('✅ Columna anulada agregada a sales');
      } catch (e) {
        print('ℹ️ Columna anulada ya existe en sales');
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN anulada_at TEXT');
        print('✅ Columna anulada_at agregada a sales');
      } catch (e) {
        print('ℹ️ Columna anulada_at ya existe en sales');
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN anulada_por TEXT');
        print('✅ Columna anulada_por agregada a sales');
      } catch (e) {
        print('ℹ️ Columna anulada_por ya existe en sales');
      }
    }
  }

  static Future<void> _migratePaymentBreakdown(Database db) async {
    try {
      await db.execute('ALTER TABLE sales ADD COLUMN payment_breakdown TEXT');
      print('✅ Columna payment_breakdown agregada');
    } catch (e) {
      print('ℹ️ Columna payment_breakdown ya existe');
    }
  }

  // ✅ NUEVO: Migración para agregar campos de descuentos y devoluciones
  static Future<void> migrateAddDiscountsAndReturns(Database db) async {
    try {
      final newColumns = [
        {'name': 'discount', 'type': 'REAL DEFAULT 0.0'},
        {'name': 'discountPercentage', 'type': 'REAL DEFAULT 0.0'},
        {'name': 'isReturn', 'type': 'INTEGER DEFAULT 0'},
        {'name': 'originalSaleId', 'type': 'INTEGER'},
        {'name': 'returnedAmount', 'type': 'REAL DEFAULT 0.0'},
      ];

      for (final column in newColumns) {
        try {
          await db.execute(
              'ALTER TABLE sales ADD COLUMN ${column['name']} ${column['type']}');
          print('✅ Columna ${column['name']} agregada a tabla sales');
        } catch (e) {
          print('ℹ️ Columna ${column['name']} ya existe en tabla sales');
        }
      }

      print('✅ Migración de sales completada');
    } catch (e) {
      print('❌ Error en migración de sales: $e');
    }
  }

  // Migrar tabla company_config para agregar campos de facturación electrónica
  static Future<void> _migrateCompanyConfigTable(Database db) async {
    try {
      // Lista de nuevas columnas a agregar
      final newColumns = [
        'document_type',
        'nit_number',
        'verification_digit',
        'city',
        'department',
        'country',
        'fiscal_regime',
        'fiscal_responsibilities'
      ];

      // Verificar cada columna y agregarla si no existe
      for (final column in newColumns) {
        try {
          await db
              .execute('ALTER TABLE company_config ADD COLUMN $column TEXT');
          print('✅ Columna $column agregada a company_config');
        } catch (e) {
          // La columna ya existe, continuar
          print('ℹ️ Columna $column ya existe en company_config');
        }
      }
      // Programa de puntos (fidelización): solo agregar columnas, no borrar nada
      try {
        await db.execute(
            'ALTER TABLE company_config ADD COLUMN points_enabled INTEGER DEFAULT 0');
        print('✅ Columna points_enabled agregada a company_config');
      } catch (e) {
        print('ℹ️ Columna points_enabled ya existe en company_config');
      }
      try {
        await db.execute(
            'ALTER TABLE company_config ADD COLUMN points_pesos_per_point REAL DEFAULT 10.0');
        print('✅ Columna points_pesos_per_point agregada a company_config');
      } catch (e) {
        print('ℹ️ Columna points_pesos_per_point ya existe en company_config');
      }
      try {
        await db.execute(
            'ALTER TABLE company_config ADD COLUMN points_pesos_base REAL DEFAULT 2000.0');
        print('✅ Columna points_pesos_base agregada a company_config');
      } catch (e) {
        print('ℹ️ Columna points_pesos_base ya existe en company_config');
      }
      try {
        await db.execute(
            'ALTER TABLE company_config ADD COLUMN points_per_base REAL DEFAULT 1.0');
        print('✅ Columna points_per_base agregada a company_config');
      } catch (e) {
        print('ℹ️ Columna points_per_base ya existe en company_config');
      }
      print('✅ Migración de company_config completada');
    } catch (e) {
      print('❌ Error en migración de company_config: $e');
    }
  }

  // Crear usuarios por defecto
  static Future<void> _createDefaultUser() async {
    print('🔧 Verificando si existen usuarios por defecto...');

    // Crear usuario admin si no existe
    final adminExists = await _database!.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
    );

    if (adminExists.isEmpty) {
      print('🔧 Creando usuario admin por defecto (dueño: acceso total)...');
      // Solo el dueño del programa: usuario admin + esta clave tienen todos los permisos.
      const defaultAdminPassword = 'ingeniero2026@';
      final hashedPassword = SecurityService.hashPassword(defaultAdminPassword);
      await _database!.insert('users', {
        'username': 'admin',
        'password': hashedPassword, // Ahora se guarda hasheada
        'fullName': 'Administrador',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': 1,
        'userCode': 'ADM-1001',
      });
      print(
          '✅ Usuario admin creado (admin / contraseña configurada para este ejecutable)');
    }

    // Usuario de mantenimiento del vendedor (rol maintenance): admon / 1234
    final admonExists = await _database!.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admon'],
    );

    if (admonExists.isEmpty) {
      print('🔧 Creando usuario de mantenimiento (vendedor)...');
      final hashedPassword = SecurityService.hashPassword('1234');
      await _database!.insert('users', {
        'username': 'admon',
        'password': hashedPassword,
        'fullName': 'Mantenimiento (vendedor)',
        'role': 'maintenance',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': 1,
        'userCode': 'MANT-VEND-01',
      });
      print('✅ Usuario admon creado (mantenimiento / 1234)');
    }
  }

  // ================== USUARIOS ==================

  // Buscar usuario por username y password
  static Future<User?> findUser(String username, String password) async {
    print('🔍 Buscando usuario: username="$username"');

    try {
      // Buscar usuario por username
      final results = await _database!.query(
        'users',
        where: 'username = ? AND isActive = ?',
        whereArgs: [username, 1],
      );

      if (results.isEmpty) {
        print('❌ Usuario no encontrado');
        return null;
      }

      final userData = results.first;
      final storedPassword = userData['password'] as String;

      // Verificar contraseña con soporte retrocompatible
      bool isValid;
      if (SecurityService.isHashed(storedPassword)) {
        // Contraseña está hasheada (sistema nuevo)
        final hashedPassword = SecurityService.hashPassword(password);
        isValid = (storedPassword == hashedPassword);
      } else {
        // Contraseña en texto plano (sistema antiguo - retrocompatibilidad)
        isValid = (password == storedPassword);
        // Si es válida y está en texto plano, migrar a hash
        if (isValid) {
          print('⚠️ Migrando contraseña a formato seguro...');
          await updateUserPassword(userData['id'] as int, password);
        }
      }

      if (!isValid) {
        print('❌ Contraseña incorrecta');
        return null;
      }

      // Crear objeto User
      final user = User()
        ..id = userData['id'] as int
        ..username = userData['username'] as String
        ..password = userData['password'] as String
        ..fullName = userData['fullName'] as String
        ..role = UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == userData['role'],
          orElse: () => UserRole.cashier,
        )
        ..createdAt = DateTime.parse(userData['createdAt'] as String)
        ..isActive = userData['isActive'] == 1
        ..userCode = (userData['userCode'] == null ||
                userData['userCode'] == '' ||
                userData['userCode'] == 'null')
            ? null
            : userData['userCode'] as String;

      print('✅ Usuario encontrado: ${user.fullName} (${user.username})');
      return user;
    } catch (e) {
      print('❌ Error en findUser: $e');
      return null;
    }
  }

  // Actualizar contraseña de un usuario
  static Future<void> updateUserPassword(
      int userId, String newPlainPassword) async {
    final hashedPassword = SecurityService.hashPassword(newPlainPassword);
    await _database!.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    print('✅ Contraseña actualizada a formato seguro para usuario $userId');
  }

  // Verificar si un usuario existe por username
  static Future<bool> userExists(String username) async {
    final results = await _database!.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim()],
    );
    return results.isNotEmpty;
  }

  // Verificar si un código de usuario ya existe
  static Future<bool> userCodeExists(String code) async {
    final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE userCode = ?', [code]);
    return (result.first['count'] as int) > 0;
  }

  // Obtener el siguiente ID para generar código automático
  static Future<int> getNextUserId() async {
    final result =
        await _database!.rawQuery('SELECT MAX(id) as maxId FROM users');
    final maxId = result.first['maxId'] as int?;
    return (maxId ?? 0) + 1;
  }

  // Obtener todos los usuarios
  static Future<List<User>> getAllUsers() async {
    final results = await _database!.query('users');
    return results.map((userData) {
      final user = User()
        ..id = userData['id'] as int
        ..username = userData['username'] as String
        ..password = userData['password'] as String
        ..fullName = userData['fullName'] as String
        ..role = UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == userData['role'],
          orElse: () => UserRole.cashier,
        )
        ..createdAt = DateTime.parse(userData['createdAt'] as String)
        ..isActive = userData['isActive'] == 1
        ..userCode = (userData['userCode'] == null ||
                userData['userCode'] == '' ||
                userData['userCode'] == 'null')
            ? null
            : userData['userCode'] as String;
      return user;
    }).toList();
  }

  // Crear usuario
  static Future<void> createUser(User user) async {
    // Hash de la contraseña antes de guardar
    final hashedPassword = SecurityService.hashPassword(user.password);

    await _database!.insert('users', {
      'username': user.username,
      'password': hashedPassword, // Ahora se guarda hasheada
      'fullName': user.fullName,
      'role': user.role.toString().split('.').last,
      'createdAt': user.createdAt.toIso8601String(),
      'isActive': user.isActive ? 1 : 0,
      'userCode': user.userCode,
    });
    print('✅ Usuario creado con contraseña segura');
  }

  // Actualizar usuario
  static Future<void> updateUser(User user) async {
    await _database!.update(
      'users',
      {
        'username': user.username,
        'password': user.password,
        'fullName': user.fullName,
        'role': user.role.toString().split('.').last,
        'isActive': user.isActive ? 1 : 0,
        'userCode': user.userCode,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // Activar/Desactivar usuario
  static Future<bool> toggleUserStatus(int userId) async {
    try {
      final results = await _database!.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) return false;

      final userData = results.first;
      final isAdmin = userData['username'] == 'admin';
      final isActive = userData['isActive'] == 1;

      // No permitir desactivar al admin
      if (isAdmin && isActive) {
        return false;
      }

      await _database!.update(
        'users',
        {'isActive': isActive ? 0 : 1},
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Error al cambiar estado del usuario: $e');
      return false;
    }
  }

  // Eliminar usuario
  static Future<bool> deleteUser(int userId) async {
    try {
      final results = await _database!.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) return false;

      final userData = results.first;
      if (userData['username'] == 'admin') {
        return false;
      }

      await _database!.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Error al eliminar usuario: $e');
      return false;
    }
  }

  // Función temporal para depuración - listar todos los usuarios
  static Future<void> debugListAllUsers() async {
    print('🔍 === LISTANDO TODOS LOS USUARIOS ===');
    try {
      final results = await _database!.query('users');
      print('Total de usuarios en la base de datos: ${results.length}');

      for (final userData in results) {
        print('   ID: ${userData['id']}');
        print('   Username: "${userData['username']}"');
        print('   Password: "${userData['password']}"');
        print('   FullName: "${userData['fullName']}"');
        print('   Role: ${userData['role']}');
        print('   Activo: ${userData['isActive']}');
        print('   Creado: ${userData['createdAt']}');
        print('   UserCode: "${userData['userCode'] ?? 'null'}"');
        print('   ---');
      }
    } catch (e) {
      print('❌ Error al listar usuarios: $e');
    }
    print('🔍 === FIN LISTA USUARIOS ===');
  }

  // Función para asignar códigos a usuarios existentes que no los tienen
  static Future<void> assignCodesToExistingUsers() async {
    print('🔧 Asignando códigos a usuarios existentes...');
    try {
      final results = await _database!
          .query('users', where: "userCode IS NULL OR userCode = ''");
      print('Usuarios sin código encontrados: ${results.length}');

      for (final userData in results) {
        final userId = userData['id'] as int;
        final role = userData['role'] as String;

        // Solo asignar códigos a administradores y gerentes
        if (role == 'admin' || role == 'manager') {
          String userCode;
          int attempts = 0;
          const maxAttempts = 10;

          do {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final random = (timestamp % 9000) + 1000;
            userCode = 'USR-$random';
            attempts++;

            if (attempts > maxAttempts) {
              userCode =
                  'USR-${timestamp.toString().substring(timestamp.toString().length - 4)}';
              break;
            }
          } while (await userCodeExists(userCode));

          await _database!.update(
            'users',
            {'userCode': userCode},
            where: 'id = ?',
            whereArgs: [userId],
          );

          print('✅ Código asignado a ${userData['username']}: $userCode');
        } else {
          print(
              'ℹ️ Usuario ${userData['username']} es cajero, no se asigna código');
        }
      }

      print('✅ Proceso de asignación de códigos completado');
    } catch (e) {
      print('❌ Error al asignar códigos: $e');
    }
  }

  // ================== PRODUCTOS ==================

  // Obtener todos los productos
  static Future<List<Product>> getAllProducts() async {
    await normalizeProductCategories();
    final results = await _database!
        .query('products', where: 'isActive = ?', whereArgs: [1]);
    return results.map((productData) {
      final product = Product.fromMap(productData);
      return product;
    }).toList();
  }

  /// Productos más vendidos en el POS (cuadrícula "Productos frecuentes").
  /// Prioriza `productId` en el JSON de ítems (ventas nuevas); si no existe, usa nombre+unidad.
  static Future<List<Product>> getFrequentProductsForPos({
    int limit = 12,
    int lookbackDays = 365,
  }) async {
    const sep = '\u001F';
    final allProducts = await getAllProducts();
    final Map<String, Product> byNameUnit = {};
    final Map<int, Product> byId = {};
    for (final p in allProducts) {
      byNameUnit['${p.name.trim()}$sep${p.unit.trim()}'] = p;
      if (p.id != null) byId[p.id!] = p;
    }

    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final results = await _database!.query(
      'sales',
      columns: ['items'],
      where: 'date >= ? AND IFNULL(anulada, 0) = 0 AND IFNULL(isReturn, 0) = 0',
      whereArgs: [cutoff.toIso8601String()],
    );

    final Map<int, int> qtyByProductId = {};
    final Map<String, int> qtyByNameUnit = {};
    for (final row in results) {
      final itemsStr = row['items'] as String?;
      if (itemsStr == null || itemsStr.isEmpty) continue;
      try {
        final itemsList = jsonDecode(itemsStr) as List<dynamic>;
        for (final raw in itemsList) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final q = item['quantity'];
          final n = q is int ? q : (q as num?)?.toInt() ?? 0;
          if (n <= 0) continue;
          final pid = (item['productId'] as num?)?.toInt();
          if (pid != null && pid > 0) {
            qtyByProductId[pid] = (qtyByProductId[pid] ?? 0) + n;
            continue;
          }
          final name = item['name']?.toString().trim() ?? '';
          final unit = item['unit']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final key = '$name$sep$unit';
          qtyByNameUnit[key] = (qtyByNameUnit[key] ?? 0) + n;
        }
      } catch (_) {}
    }

    final sortedIds = qtyByProductId.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedLegacy = qtyByNameUnit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Product> frequent = [];
    for (final e in sortedIds) {
      if (frequent.length >= limit) break;
      final p = byId[e.key];
      if (p == null) continue;
      if (frequent.any((x) => x.id == p.id)) continue;
      frequent.add(p);
    }
    for (final e in sortedLegacy) {
      if (frequent.length >= limit) break;
      final p = byNameUnit[e.key];
      if (p == null) continue;
      if (frequent.any((x) => x.id == p.id)) continue;
      frequent.add(p);
    }

    if (frequent.length < limit) {
      final rest = List<Product>.from(allProducts)
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final p in rest) {
        if (frequent.length >= limit) break;
        if (!frequent.any((x) => x.id == p.id)) frequent.add(p);
      }
    }

    return frequent.take(limit).toList();
  }

  // ✅ NUEVO: Obtener productos por grupo
  static Future<List<Product>> getProductsByGroup(String groupName) async {
    final results = await _database!.query('products',
        where: 'category = ? AND isActive = ?', whereArgs: [groupName, 1]);
    return results.map((productData) {
      final product = Product.fromMap(productData);
      return product;
    }).toList();
  }

  // ✅ NUEVO: Actualizar grupo de productos
  static Future<void> updateProductsGroup(
      String oldGroupName, String newGroupName) async {
    await _database!.update(
      'products',
      {
        'category': newGroupName,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'category = ? AND isActive = ?',
      whereArgs: [oldGroupName, 1],
    );
  }

  // Crear producto
  static Future<void> createProduct(Product product) async {
    await _database!.insert('products', product.toMap());
  }

  // Actualizar producto
  static Future<void> updateProduct(Product product) async {
    final updateData = product.toMap();
    updateData['updatedAt'] = DateTime.now().toIso8601String();

    await _database!.update(
      'products',
      updateData,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // Actualizar precio de producto
  static Future<void> updateProductPrice(int id, double newPrice) async {
    await _database!.update(
      'products',
      {
        'price': newPrice,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Eliminar producto
  static Future<void> deleteProduct(int id) async {
    await _database!.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Verificar si existe código de producto
  static Future<bool> existsProductCode(String code, {int? excludeId}) async {
    String whereClause = 'code = ? AND isActive = ?';
    List<dynamic> whereArgs = [code.trim(), 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final results = await _database!
        .query('products', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }

  /// True si otro producto activo ya usa este [shortCode].
  static Future<bool> existsProductShortCode(String shortCode,
      {int? excludeId}) async {
    final sc = shortCode.trim();
    if (sc.isEmpty) return false;
    String whereClause = 'shortCode = ? AND isActive = ?';
    List<dynamic> whereArgs = [sc, 1];
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    final results = await _database!
        .query('products', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }

  // ================== VENTAS ==================

  static Future<Map<String, dynamic>?> _productRowForSaleItem(
      SaleItem item) async {
    if (item.productId != null && item.productId! > 0) {
      final r = await _database!.query(
        'products',
        where: 'id = ?',
        whereArgs: [item.productId],
      );
      if (r.isNotEmpty) return r.first;
    }
    final r2 = await _database!.query(
      'products',
      where: 'name = ? AND unit = ? AND isActive = ?',
      whereArgs: [item.name, item.unit, 1],
    );
    return r2.isNotEmpty ? r2.first : null;
  }

  // Guardar venta. Asigna sale.id con el ID autoincremental (primera venta = 1, luego 2, 3...).
  static Future<void> saveSale(Sale sale) async {
    final id = await _database!.insert('sales', {
      'date': sale.date.toIso8601String(),
      'total': sale.total,
      'user': sale.user,
      'paymentMethod': sale.paymentMethod,
      'payment_breakdown': sale.paymentBreakdown != null
          ? jsonEncode(sale.paymentBreakdown!.map((p) => p.toMap()).toList())
          : null,
      'items': jsonEncode(sale.items.map((item) {
        final m = <String, dynamic>{
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'unit': item.unit,
          'discount': item.discount,
          'discountPercentage': item.discountPercentage,
          'ivaPercentage': item.ivaPercentage,
          'priceEditedInCart': item.priceEditedInCart,
          'originalUnitPrice': item.originalUnitPrice,
          'priceEditedAt': item.priceEditedAt?.toIso8601String(),
          'priceEditedBy': item.priceEditedBy,
          'priceEditedFromIva': item.priceEditedFromIva,
        };
        if (item.productId != null) m['productId'] = item.productId;
        if (item.weightKg != null) m['weightKg'] = item.weightKg;
        return m;
      }).toList()), // Guardar como JSON string
      // ✅ Cliente asociado (para reimpresión con nombre en ticket)
      'customer_id': sale.customerId,
      'client_id': sale.clientId,
      // ✅ NUEVO: Campos de descuentos y devoluciones
      'discount': sale.discount ?? 0.0,
      'discountPercentage': sale.discountPercentage ?? 0.0,
      'isReturn': sale.isReturn ? 1 : 0,
      'originalSaleId': sale.originalSaleId,
      'returnedAmount': sale.returnedAmount ?? 0.0,
    });
    sale.id = id;

    // Ajustar stock: venta normal = descontar; devolución = sumar (productos vuelven)
    final nowStr = DateTime.now().toIso8601String();
    for (final item in sale.items) {
      final row = await _productRowForSaleItem(item);
      if (row == null) continue;
      final product = Product.fromMap(row);
      if (product.isWeighted &&
          product.weightedStockInKg &&
          item.weightKg != null &&
          item.weightKg! > 0) {
        final kg = item.weightKg!;
        final currentKg = (row['stockKg'] as num?)?.toDouble() ?? 0.0;
        final newKg =
            sale.isReturn ? currentKg + kg : (currentKg - kg).clamp(0.0, 1e15);
        await _database!.update(
          'products',
          {'stockKg': newKg, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } else {
        int currentStock = row['stock'] as int;
        int newStock = sale.isReturn
            ? currentStock + item.quantity
            : (currentStock - item.quantity).clamp(0, 0x7fffffff);
        await _database!.update(
          'products',
          {'stock': newStock, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// Entradas en [inventory_movements] por devolución POS (el stock ya se
  /// actualizó en [saveSale]; aquí solo queda trazabilidad en Movimientos).
  static Future<void> logPosReturnInventoryMovements(
    Sale returnSale,
    int userId,
  ) async {
    if (!returnSale.isReturn || _database == null) return;
    final dateStr = returnSale.date.toIso8601String();
    final retId = returnSale.id;
    final origId = returnSale.originalSaleId;

    for (final item in returnSale.items) {
      final row = await _productRowForSaleItem(item);
      if (row == null) continue;
      final product = Product.fromMap(row);
      final pid = row['id'] as int;

      final desc = StringBuffer('Devolución POS');
      if (retId != null) desc.write(' · Mov. #$retId');
      if (origId != null) desc.write(' · Fact. orig. #$origId');

      late final int qty;
      if (product.isWeighted &&
          product.weightedStockInKg &&
          item.weightKg != null &&
          item.weightKg! > 0) {
        final g = (item.weightKg! * 1000).round();
        qty = math.max(1, g);
        desc.write(
            ' · +${item.weightKg!.toStringAsFixed(3)} kg (cantidad en gramos)');
      } else {
        qty = item.quantity;
        desc.write(' · +$qty ${item.unit}');
      }

      await _database!.insert('inventory_movements', {
        'productId': pid,
        'type': 'entrada',
        'quantity': qty,
        'reason': 'devolucion',
        'description': desc.toString(),
        'date': dateStr,
        'userId': userId,
      });
    }
  }

  /// Revierte puntos y total de compras del cliente de fidelización (misma
  /// regla que el POS al acumular) cuando la venta original llevaba cliente.
  static Future<void> applyCustomerBalanceAfterReturn(
    int? customerId,
    double returnedTotal,
  ) async {
    if (customerId == null || returnedTotal <= 0 || _database == null) return;

    final customer = await getCustomerById(customerId);
    if (customer == null) return;

    final configs = await getCompanyConfig();
    if (configs.isEmpty) return;
    final cfg = configs.first;

    var pointsToSubtract = 0;
    if (cfg.pointsEnabled && cfg.pointsPesosBase > 0) {
      pointsToSubtract =
          ((returnedTotal / cfg.pointsPesosBase).floor() * cfg.pointsPerBase)
              .toInt();
    }

    final newPoints =
        math.max(0, customer.accumulatedPoints - pointsToSubtract);
    final newTotal = math.max(0.0, customer.totalPurchases - returnedTotal);

    await updateCustomer(
      customer.copyWith(
        accumulatedPoints: newPoints,
        totalPurchases: newTotal,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // Obtener historial de ventas
  static Future<List<Sale>> getSales(
      {DateTime? date, DateTime? endDate, String? user}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      DateTime end;

      if (endDate != null) {
        // Rango de fechas (para reportes de semana, mes, etc.)
        end = DateTime(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
      } else {
        // Solo un día
        end = start.add(const Duration(days: 1));
      }

      whereClause = 'date >= ? AND date < ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }
    if (user != null && user.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'user = ?';
      whereArgs.add(user);
    }

    final results = await _database!.query(
      'sales',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return results.map((saleData) {
      List<PaymentPart>? paymentBreakdown;
      final pbStr = saleData['payment_breakdown'] as String?;
      if (pbStr != null && pbStr.isNotEmpty) {
        try {
          final list = jsonDecode(pbStr) as List<dynamic>?;
          paymentBreakdown = list
              ?.map((e) => PaymentPart.fromMap(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      final sale = Sale(
        id: saleData['id'] as int,
        date: DateTime.parse(saleData['date'] as String),
        total: saleData['total'] as double,
        user: saleData['user'] as String,
        paymentMethod: saleData['paymentMethod'] as String?,
        items: [],
        paymentBreakdown: paymentBreakdown,
        customerId: saleData['customer_id'] as int?,
        clientId: saleData['client_id'] as int?,
        // ✅ NUEVO: Leer campos de descuentos y devoluciones
        discount: saleData['discount'] as double?,
        discountPercentage: saleData['discountPercentage'] as double?,
        isReturn: (saleData['isReturn'] as int? ?? 0) == 1,
        originalSaleId: saleData['originalSaleId'] as int?,
        returnedAmount: saleData['returnedAmount'] as double?,
        isAnulada: (saleData['anulada'] as int? ?? 0) == 1,
        anuladaAt: saleData['anulada_at'] != null
            ? DateTime.tryParse(saleData['anulada_at'] as String)
            : null,
        anuladaPor: saleData['anulada_por'] as String?,
      );
      // Parsear items desde JSON string
      try {
        final itemsString = saleData['items'] as String?;
        if (itemsString != null && itemsString.isNotEmpty) {
          final List<dynamic> itemsList =
              itemsString.contains('[') ? jsonDecode(itemsString) : [];
          sale.items = itemsList
              .map((item) => SaleItem(
                    name: item['name'],
                    price: item['price'] is int
                        ? (item['price'] as int).toDouble()
                        : item['price'],
                    quantity: item['quantity'] is int
                        ? item['quantity']
                        : (item['quantity'] as double).toInt(),
                    unit: item['unit'],
                    discount: item['discount'] as double?,
                    discountPercentage: item['discountPercentage'] as double?,
                    ivaPercentage: item['ivaPercentage'] is int
                        ? item['ivaPercentage'] as int
                        : (item['ivaPercentage'] as num?)?.toInt() ?? 19,
                    productId: (item['productId'] as num?)?.toInt(),
                    weightKg: (item['weightKg'] as num?)?.toDouble(),
                    priceEditedInCart: item['priceEditedInCart'] == true,
                    originalUnitPrice:
                        (item['originalUnitPrice'] as num?)?.toDouble(),
                    priceEditedAt: item['priceEditedAt'] != null
                        ? DateTime.tryParse(item['priceEditedAt'] as String)
                        : null,
                    priceEditedBy: item['priceEditedBy'] as String?,
                    priceEditedFromIva: item['priceEditedFromIva'] == true,
                  ))
              .toList();
        } else {
          sale.items = [];
        }
      } catch (_) {
        sale.items = [];
      }
      return sale;
    }).toList();
  }

  /// Obtiene una venta por ID (para anulación o detalle).
  static Future<Sale?> getSaleById(int id) async {
    final results = await _database!.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    final saleData = results.first;
    List<PaymentPart>? paymentBreakdown;
    final pbStr = saleData['payment_breakdown'] as String?;
    if (pbStr != null && pbStr.isNotEmpty) {
      try {
        final list = jsonDecode(pbStr) as List<dynamic>?;
        paymentBreakdown = list
            ?.map((e) => PaymentPart.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final sale = Sale(
      id: saleData['id'] as int,
      date: DateTime.parse(saleData['date'] as String),
      total: saleData['total'] as double,
      user: saleData['user'] as String,
      paymentMethod: saleData['paymentMethod'] as String?,
      items: [],
      paymentBreakdown: paymentBreakdown,
      customerId: saleData['customer_id'] as int?,
      clientId: saleData['client_id'] as int?,
      discount: saleData['discount'] as double?,
      discountPercentage: saleData['discountPercentage'] as double?,
      isReturn: (saleData['isReturn'] as int? ?? 0) == 1,
      originalSaleId: saleData['originalSaleId'] as int?,
      returnedAmount: saleData['returnedAmount'] as double?,
      isAnulada: (saleData['anulada'] as int? ?? 0) == 1,
      anuladaAt: saleData['anulada_at'] != null
          ? DateTime.tryParse(saleData['anulada_at'] as String)
          : null,
      anuladaPor: saleData['anulada_por'] as String?,
    );
    try {
      final itemsString = saleData['items'] as String?;
      if (itemsString != null && itemsString.isNotEmpty) {
        final List<dynamic> itemsList =
            itemsString.contains('[') ? jsonDecode(itemsString) : [];
        sale.items = itemsList
            .map((item) => SaleItem(
                  name: item['name'],
                  price: item['price'] is int
                      ? (item['price'] as int).toDouble()
                      : item['price'],
                  quantity: item['quantity'] is int
                      ? item['quantity']
                      : (item['quantity'] as double).toInt(),
                  unit: item['unit'],
                  discount: item['discount'] as double?,
                  discountPercentage: item['discountPercentage'] as double?,
                  ivaPercentage: item['ivaPercentage'] is int
                      ? item['ivaPercentage'] as int
                      : (item['ivaPercentage'] as num?)?.toInt() ?? 19,
                  productId: (item['productId'] as num?)?.toInt(),
                  weightKg: (item['weightKg'] as num?)?.toDouble(),
                  priceEditedInCart: item['priceEditedInCart'] == true,
                  originalUnitPrice:
                      (item['originalUnitPrice'] as num?)?.toDouble(),
                  priceEditedAt: item['priceEditedAt'] != null
                      ? DateTime.tryParse(item['priceEditedAt'] as String)
                      : null,
                  priceEditedBy: item['priceEditedBy'] as String?,
                  priceEditedFromIva: item['priceEditedFromIva'] == true,
                ))
            .toList();
      }
    } catch (_) {
      sale.items = [];
    }
    return sale;
  }

  /// Indica si ya existe una devolución registrada para la factura original (evita duplicados).
  static Future<bool> hasReturnForSale(int originalSaleId) async {
    final rows = await _database!.query(
      'sales',
      columns: ['id'],
      where:
          'isReturn = 1 AND originalSaleId = ? AND (anulada IS NULL OR anulada = 0)',
      whereArgs: [originalSaleId],
    );
    return rows.isNotEmpty;
  }

  /// Anula una venta: marca como anulada y devuelve el stock al inventario.
  /// Requiere permiso cancelSales. Lanza si la venta no existe o ya está anulada.
  static Future<void> voidSale(int saleId, String anuladaPor) async {
    final sale = await getSaleById(saleId);
    if (sale == null) {
      throw Exception('Venta #$saleId no encontrada');
    }
    if (sale.isAnulada) {
      throw Exception('La venta #$saleId ya está anulada');
    }
    final now = DateTime.now().toIso8601String();
    await _database!.update(
      'sales',
      {
        'anulada': 1,
        'anulada_at': now,
        'anulada_por': anuladaPor,
      },
      where: 'id = ?',
      whereArgs: [saleId],
    );
    // Devolver stock por cada ítem
    for (final item in sale.items) {
      final row = await _productRowForSaleItem(item);
      if (row == null) continue;
      final product = Product.fromMap(row);
      if (product.isWeighted &&
          product.weightedStockInKg &&
          item.weightKg != null &&
          item.weightKg! > 0) {
        final kg = item.weightKg!;
        final currentKg = (row['stockKg'] as num?)?.toDouble() ?? 0.0;
        await _database!.update(
          'products',
          {'stockKg': currentKg + kg, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } else {
        int currentStock = row['stock'] as int;
        int newStock = currentStock + item.quantity;
        await _database!.update(
          'products',
          {'stock': newStock, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  // ================== MOVIMIENTOS DE INVENTARIO ==================

  // Guardar movimiento de inventario y actualizar stock del producto
  static Future<void> saveInventoryMovement(InventoryMovement movement) async {
    await _database!.insert('inventory_movements', {
      'productId': movement.productId,
      'type': movement.type.toString().split('.').last,
      'quantity': movement.quantity,
      'reason': movement.reason.toString().split('.').last,
      // La columna se llama description en la tabla; usamos este campo para
      // guardar las observaciones del movimiento.
      'description': movement.observations,
      'date': movement.date.toIso8601String(),
      'userId': movement.userId,
    });

    // Actualizar stock del producto según tipo de movimiento
    final productRows = await _database!.query(
      'products',
      where: 'id = ?',
      whereArgs: [movement.productId],
    );
    if (productRows.isNotEmpty) {
      final product = Product.fromMap(productRows.first);
      int newStock = product.stock;
      if (movement.type == MovementType.entrada) {
        newStock = product.stock + movement.quantity;
      } else if (movement.type == MovementType.salida) {
        newStock = (product.stock - movement.quantity).clamp(0, 0x7fffffff);
      }
      // Ajuste: se interpreta como corrección; opcionalmente no cambiar stock aquí
      if (newStock != product.stock) {
        await _database!.update(
          'products',
          {
            'stock': newStock,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [movement.productId],
        );
      }
    }
  }

  // Obtener movimientos de inventario
  static Future<List<InventoryMovement>> getAllInventoryMovements({
    int? productId,
    MovementType? type,
    MovementReason? reason,
  }) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (productId != null) {
      whereClause += 'productId = ?';
      whereArgs.add(productId);
    }

    if (type != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'type = ?';
      whereArgs.add(type.toString().split('.').last);
    }

    if (reason != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'reason = ?';
      whereArgs.add(reason.toString().split('.').last);
    }

    final results = await _database!.query(
      'inventory_movements',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return results.map((movementData) {
      final movement = InventoryMovement(
        productId: movementData['productId'] as int,
        type: MovementType.values.firstWhere(
          (e) => e.toString().split('.').last == movementData['type'],
          orElse: () => MovementType.entrada,
        ),
        quantity: movementData['quantity'] as int,
        reason: MovementReason.values.firstWhere(
          (e) => e.toString().split('.').last == movementData['reason'],
          orElse: () => MovementReason.venta,
        ),
        date: DateTime.parse(movementData['date'] as String),
        userId: movementData['userId'] as int,
        // Compatibilidad: leer descripción principal y, si no existe,
        // caer en una posible columna antigua 'observations'.
        observations: (movementData['description'] ??
            movementData['observations']) as String?,
      );
      movement.id = movementData['id'] as int;
      return movement;
    }).toList();
  }

  // Migración: agregar campo userCode si no existe
  static Future<void> migrateAddUserCode() async {
    final result = await _database!.rawQuery("PRAGMA table_info(users)");
    final hasUserCode = result.any((col) => col['name'] == 'userCode');
    if (!hasUserCode) {
      await _database!.execute('ALTER TABLE users ADD COLUMN userCode TEXT');
      print('✅ Migración: Campo userCode agregado a la tabla users');
    } else {
      print('ℹ️ La tabla users ya tiene el campo userCode');
    }
  }

  // Migración: agregar columna isWeighted si no existe
  static Future<void> migrateAddIsWeighted() async {
    // Verificar si la columna isWeighted existe
    final res = await _database!.rawQuery("PRAGMA table_info(products)");
    final exists = res.any((col) => col['name'] == 'isWeighted');
    if (!exists) {
      print('🛠️ Migrando tabla products: agregando columna isWeighted...');
      await _database!.execute(
          "ALTER TABLE products ADD COLUMN isWeighted INTEGER NOT NULL DEFAULT 0");
      print('✅ Columna isWeighted agregada');
    } else {
      print('✅ Columna isWeighted ya existe, no se requiere migración');
    }
  }

  // Migración: agregar campo pricePerKg si no existe
  static Future<void> migrateAddPricePerKg() async {
    final result = await _database!.rawQuery("PRAGMA table_info(products)");
    final hasPricePerKg = result.any((col) => col['name'] == 'pricePerKg');
    if (!hasPricePerKg) {
      await _database!
          .execute('ALTER TABLE products ADD COLUMN pricePerKg REAL');
      print('✅ Migración: Campo pricePerKg agregado a la tabla products');
    } else {
      print('ℹ️ La tabla products ya tiene el campo pricePerKg');
    }
  }

  /// Inventario para productos pesados: unidades ([stock]) o kilogramos ([stockKg]).
  static Future<void> migrateAddWeightedStockKgColumns() async {
    var result = await _database!.rawQuery("PRAGMA table_info(products)");
    if (!result.any((col) => col['name'] == 'weightedStockInKg')) {
      try {
        await _database!.execute(
            'ALTER TABLE products ADD COLUMN weightedStockInKg INTEGER NOT NULL DEFAULT 0');
        print('✅ Migración: weightedStockInKg agregado a products');
      } catch (e) {
        print('ℹ️ weightedStockInKg: $e');
      }
    }
    result = await _database!.rawQuery("PRAGMA table_info(products)");
    if (!result.any((col) => col['name'] == 'stockKg')) {
      try {
        await _database!.execute(
            'ALTER TABLE products ADD COLUMN stockKg REAL NOT NULL DEFAULT 0');
        print('✅ Migración: stockKg agregado a products');
      } catch (e) {
        print('ℹ️ stockKg: $e');
      }
    }
  }

  // Migración: agregar columnas weight, minWeight y maxWeight si no existen
  static Future<void> migrateAddWeightColumns() async {
    final result = await _database!.rawQuery("PRAGMA table_info(products)");
    final hasWeight = result.any((col) => col['name'] == 'weight');
    final hasMinWeight = result.any((col) => col['name'] == 'minWeight');
    final hasMaxWeight = result.any((col) => col['name'] == 'maxWeight');
    if (!hasWeight) {
      await _database!.execute('ALTER TABLE products ADD COLUMN weight REAL');
      print('✅ Migración: Campo weight agregado a la tabla products');
    }
    if (!hasMinWeight) {
      await _database!
          .execute('ALTER TABLE products ADD COLUMN minWeight REAL');
      print('✅ Migración: Campo minWeight agregado a la tabla products');
    }
    if (!hasMaxWeight) {
      await _database!
          .execute('ALTER TABLE products ADD COLUMN maxWeight REAL');
      print('✅ Migración: Campo maxWeight agregado a la tabla products');
    }
    final hasIvaPercentage =
        result.any((col) => col['name'] == 'ivaPercentage');
    if (!hasIvaPercentage) {
      await _database!.execute(
          'ALTER TABLE products ADD COLUMN ivaPercentage INTEGER NOT NULL DEFAULT 19');
      print('✅ Migración: Campo ivaPercentage agregado a la tabla products');
    }
  }

  /// Permite [shortCode] NULL en products (varios productos sin corto). SQLite UNIQUE acepta varios NULL.
  static Future<void> migrateProductShortCodeNullable() async {
    final db = _database!;
    final info = await db.rawQuery('PRAGMA table_info(products)');
    Map<String, Object?>? shortRow;
    for (final row in info) {
      if (row['name'] == 'shortCode') {
        shortRow = row;
        break;
      }
    }
    if (shortRow == null) return;
    final notNull = (shortRow['notnull'] as int? ?? 0) == 1;
    if (!notNull) {
      return;
    }

    print('🔧 Migrando products: shortCode opcional (NULL permitido)...');
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        await txn.execute('''
CREATE TABLE products_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  shortCode TEXT UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  price REAL NOT NULL,
  cost REAL NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  minStock INTEGER NOT NULL DEFAULT 0,
  category TEXT NOT NULL,
  unit TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isActive INTEGER NOT NULL DEFAULT 1,
  imageUrl TEXT,
  ivaPercentage INTEGER NOT NULL DEFAULT 19,
  isWeighted INTEGER NOT NULL DEFAULT 0,
  pricePerKg REAL,
  weight REAL,
  minWeight REAL,
  maxWeight REAL,
  weightedStockInKg INTEGER NOT NULL DEFAULT 0,
  stockKg REAL NOT NULL DEFAULT 0
)
''');
        await txn.execute('''
INSERT INTO products_new (
  id, code, shortCode, name, description, price, cost, stock, minStock,
  category, unit, createdAt, updatedAt, isActive, imageUrl,
  ivaPercentage, isWeighted, pricePerKg, weight, minWeight, maxWeight,
  weightedStockInKg, stockKg
)
SELECT
  id, code,
  CASE WHEN shortCode IS NULL OR TRIM(shortCode) = '' THEN NULL ELSE shortCode END,
  name, description, price, cost, stock, minStock,
  category, unit, createdAt, updatedAt, isActive, imageUrl,
  ivaPercentage, isWeighted, pricePerKg, weight, minWeight, maxWeight,
  weightedStockInKg, stockKg
FROM products
''');
        await txn.execute('DROP TABLE products');
        await txn.execute('ALTER TABLE products_new RENAME TO products');
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
    print('✅ Migración: shortCode opcional aplicada');
  }

  // ================== CLIENTES ==================

  // Crear cliente
  static Future<void> createCustomer(Customer customer) async {
    await _database!.insert('customers', customer.toMap());
  }

  // Obtener todos los clientes
  static Future<List<Customer>> getAllCustomers() async {
    final results = await _database!.query(
      'customers',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return results
        .map((customerData) => Customer.fromMap(customerData))
        .toList();
  }

  // Buscar cliente por ID
  static Future<Customer?> getCustomerById(int id) async {
    final results = await _database!.query(
      'customers',
      where: 'id = ? AND isActive = ?',
      whereArgs: [id, 1],
    );

    if (results.isNotEmpty) {
      return Customer.fromMap(results.first);
    }
    return null;
  }

  // Buscar cliente por email
  static Future<Customer?> getCustomerByEmail(String email) async {
    final results = await _database!.query(
      'customers',
      where: 'email = ? AND isActive = ?',
      whereArgs: [email, 1],
    );

    if (results.isNotEmpty) {
      return Customer.fromMap(results.first);
    }
    return null;
  }

  // Actualizar cliente
  static Future<void> updateCustomer(Customer customer) async {
    await _database!.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  // Eliminar cliente (marcar como inactivo)
  static Future<void> deleteCustomer(int id) async {
    await _database!.update(
      'customers',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualizar puntos del cliente
  static Future<void> updateCustomerPoints(
      int customerId, int accumulatedPoints) async {
    await _database!.update(
      'customers',
      {
        'accumulatedPoints': accumulatedPoints,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  // Actualizar total de compras del cliente
  static Future<void> updateCustomerTotalPurchases(
      int customerId, double total) async {
    await _database!.update(
      'customers',
      {
        'totalPurchases': total,
        'lastPurchase': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  // Cerrar base de datos
  static Future<void> close() async {
    await _database?.close();
  }

  // ================== CONFIGURACIÓN DE EMPRESA ==================

  // Obtener configuración de empresa
  static Future<List<CompanyConfig>> getCompanyConfig() async {
    final List<Map<String, dynamic>> results =
        await _database!.query('company_config');
    return results
        .map((configData) => CompanyConfig.fromMap(configData))
        .toList();
  }

  // Crear o actualizar configuración de empresa (siempre hay una sola)
  static Future<void> createOrUpdateCompanyConfig(CompanyConfig config) async {
    final existing = await _database!.query('company_config');

    if (existing.isEmpty) {
      // Crear nueva configuración
      await _database!.insert('company_config', config.toMap());
    } else {
      // Actualizar configuración existente
      await _database!.update(
        'company_config',
        config.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  // ================== CLIENTES FACTURACIÓN ELECTRÓNICA DIAN ==================

  // Crear cliente para facturación electrónica
  static Future<void> createClient(Client client) async {
    await _database!.insert('clients', client.toMap());
  }

  // Obtener todos los clientes para facturación electrónica
  static Future<List<Client>> getAllClients() async {
    final results = await _database!.query(
      'clients',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'businessName ASC',
    );

    return results.map((clientData) => Client.fromMap(clientData)).toList();
  }

  // Buscar cliente por ID
  static Future<Client?> getClientById(int id) async {
    final results = await _database!.query(
      'clients',
      where: 'id = ? AND isActive = ?',
      whereArgs: [id, 1],
    );

    if (results.isNotEmpty) {
      return Client.fromMap(results.first);
    }
    return null;
  }

  // Buscar cliente por número de documento
  static Future<Client?> getClientByDocument(String documentNumber) async {
    final results = await _database!.query(
      'clients',
      where: 'documentNumber = ? AND isActive = ?',
      whereArgs: [documentNumber, 1],
    );

    if (results.isNotEmpty) {
      return Client.fromMap(results.first);
    }
    return null;
  }

  // Actualizar cliente
  static Future<void> updateClient(Client client) async {
    await _database!.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  // Eliminar cliente (marcar como inactivo)
  static Future<void> deleteClient(int id) async {
    await _database!.update(
      'clients',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Buscar clientes por nombre de negocio
  static Future<List<Client>> searchClientsByBusinessName(
      String businessName) async {
    final results = await _database!.query(
      'clients',
      where: 'businessName LIKE ? AND isActive = ?',
      whereArgs: ['%$businessName%', 1],
      orderBy: 'businessName ASC',
    );

    return results.map((clientData) => Client.fromMap(clientData)).toList();
  }

  // Verificar si existe un cliente con el documento dado
  static Future<bool> clientDocumentExists(String documentNumber,
      {int? excludeId}) async {
    String whereClause = 'documentNumber = ? AND isActive = ?';
    List<dynamic> whereArgs = [documentNumber.trim(), 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final results = await _database!
        .query('clients', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }

  // ================== GRUPOS ==================

  // Crear grupo
  static Future<void> createGroup(Group group) async {
    await _database!.insert('groups', group.toMap());
  }

  // Obtener todos los grupos
  static Future<List<Group>> getAllGroups() async {
    await ensureDefaultGroupExists();
    final results = await _database!.query(
      'groups',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return results.map((groupData) => Group.fromMap(groupData)).toList();
  }

  // Buscar grupo por ID
  static Future<Group?> getGroupById(int id) async {
    final results = await _database!.query(
      'groups',
      where: 'id = ? AND isActive = ?',
      whereArgs: [id, 1],
    );

    if (results.isNotEmpty) {
      return Group.fromMap(results.first);
    }
    return null;
  }

  // Actualizar grupo
  static Future<void> updateGroup(Group group) async {
    if (group.id == null) {
      throw Exception('El grupo no tiene ID válido');
    }

    final existing = await getGroupById(group.id!);
    if (existing == null) {
      throw Exception('No se encontró el grupo a actualizar');
    }

    final oldName = existing.name.trim();
    final newName = group.name.trim();

    if (oldName.toLowerCase() == defaultGroupName.toLowerCase() &&
        newName.toLowerCase() != defaultGroupName.toLowerCase()) {
      throw Exception('El grupo "$defaultGroupName" no se puede renombrar');
    }

    await _database!.transaction((txn) async {
      await txn.update(
        'groups',
        group.toMap(),
        where: 'id = ?',
        whereArgs: [group.id],
      );

      if (oldName != newName) {
        await txn.update(
          'products',
          {
            'category': newName,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'category = ?',
          whereArgs: [oldName],
        );
      }
    });
  }

  // Eliminar grupo (marcar como inactivo) y mover productos a "Otros"
  static Future<void> deleteGroup(int id) async {
    final group = await getGroupById(id);
    if (group == null) {
      throw Exception('No se encontró el grupo');
    }

    if (group.name.trim().toLowerCase() == defaultGroupName.toLowerCase()) {
      throw Exception('El grupo "$defaultGroupName" no se puede eliminar');
    }

    await ensureDefaultGroupExists();
    final now = DateTime.now().toIso8601String();

    await _database!.transaction((txn) async {
      await txn.update(
        'products',
        {
          'category': defaultGroupName,
          'updatedAt': now,
        },
        where: 'category = ?',
        whereArgs: [group.name],
      );

      await txn.update(
        'groups',
        {'isActive': 0, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // Verificar si existe un grupo con el nombre dado
  static Future<bool> groupNameExists(String name, {int? excludeId}) async {
    String whereClause = 'name = ? AND isActive = ?';
    List<dynamic> whereArgs = [name.trim(), 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final results = await _database!
        .query('groups', where: whereClause, whereArgs: whereArgs);
    return results.isNotEmpty;
  }

  // Migración: agregar tabla de grupos si no existe
  static Future<void> migrateAddGroupsTable() async {
    print('🔄 Verificando tabla groups...');
    final result = await _database!.rawQuery("PRAGMA table_info(groups)");

    if (result.isEmpty) {
      print('🔧 Creando tabla groups...');
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          color TEXT NOT NULL,
          icon TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
      print('✅ Tabla groups creada exitosamente');
    } else {
      print('ℹ️ La tabla groups ya existe');
    }
  }

  /// Si no hay grupos activos (BD nueva o vacía), inserta el catálogo por defecto.
  /// Así el formulario de producto muestra el mismo desplegable que en otros equipos.
  static Future<void> ensureDefaultGroupsIfEmpty() async {
    try {
      final r = await _database!
          .rawQuery('SELECT COUNT(*) as c FROM groups WHERE isActive = 1');
      final n = (r.first['c'] as int?) ?? 0;
      if (n == 0) {
        print('📁 Sin grupos en BD: creando grupos por defecto...');
        await createDefaultGroups();
      }
    } catch (e) {
      print('⚠️ ensureDefaultGroupsIfEmpty: $e');
    }
  }

  static Future<void> ensureDefaultGroupExists() async {
    final existingDefault = await _database!.query(
      'groups',
      where: 'LOWER(name) = ?',
      whereArgs: [defaultGroupName.toLowerCase()],
      limit: 1,
    );

    if (existingDefault.isEmpty) {
      final now = DateTime.now().toIso8601String();
      await _database!.insert('groups', {
        'name': defaultGroupName,
        'description': 'Grupo por defecto para productos sin grupo específico',
        'color': '#9E9E9E',
        'icon': 'category',
        'createdAt': now,
        'updatedAt': now,
        'isActive': 1,
      });
      return;
    }

    final row = existingDefault.first;
    if ((row['isActive'] as int? ?? 0) != 1) {
      await _database!.update(
        'groups',
        {'isActive': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  static Future<void> normalizeProductCategories() async {
    await ensureDefaultGroupExists();
    await _database!.rawUpdate('''
      UPDATE products
      SET category = ?, updatedAt = ?
      WHERE category IS NULL
         OR TRIM(category) = ''
         OR LOWER(TRIM(category)) = 'sin grupo'
         OR LOWER(TRIM(category)) = 'sin categoría'
         OR LOWER(TRIM(category)) = 'sin categoria'
         OR category NOT IN (
              SELECT name
              FROM groups
              WHERE isActive = 1
         )
    ''', [defaultGroupName, DateTime.now().toIso8601String()]);
  }

  // Crear grupos por defecto
  static Future<void> createDefaultGroups() async {
    final defaultGroups = [
      Group(
        name: 'Frutas y Verduras',
        description: 'Productos frescos del campo',
        color: '#FF5722',
        icon: 'apple',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Lácteos',
        description: 'Productos derivados de la leche',
        color: '#2196F3',
        icon: 'local_drink',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Panadería',
        description: 'Productos de panadería y pastelería',
        color: '#FF9800',
        icon: 'bakery_dining',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Carnes',
        description: 'Productos cárnicos',
        color: '#795548',
        icon: 'set_meal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Bebidas',
        description: 'Bebidas y refrescos',
        color: '#4CAF50',
        icon: 'local_bar',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Abarrotes',
        description: 'Productos de abarrotes',
        color: '#9C27B0',
        icon: 'inventory',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Limpieza',
        description: 'Productos de limpieza',
        color: '#009688',
        icon: 'cleaning_services',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Cuidado Personal',
        description: 'Productos de cuidado personal',
        color: '#E91E63',
        icon: 'person',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Servicios',
        description: 'Servicios prestados',
        color: '#3F51B5',
        icon: 'miscellaneous_services',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Group(
        name: 'Otros',
        description: 'Otros productos',
        color: '#9E9E9E',
        icon: 'category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final group in defaultGroups) {
      await createGroup(group);
    }

    print('✅ Grupos por defecto creados');
  }

  // ✅ NUEVO: Migración para agregar columna category
  static Future<void> migrateAddCategoryColumn() async {
    try {
      print('🔧 Migrando: Agregando columna category a tabla products...');

      // Verificar si la columna category ya existe usando pragma
      final result = await _database!.rawQuery('PRAGMA table_info(products)');
      final hasCategory = result.any((column) => column['name'] == 'category');

      if (hasCategory) {
        print('ℹ️ La columna category ya existe');
        return;
      }

      // Agregar columna category
      await _database!.execute('''
        ALTER TABLE products 
        ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'
      ''');

      // Migrar datos existentes de groupName a category
      await _database!.execute('''
        UPDATE products 
        SET category = 'Otros'
        WHERE category IS NULL OR TRIM(category) = '' OR category = 'Sin Categoría'
      ''');

      print('✅ Columna category agregada exitosamente');
    } catch (e) {
      print('❌ Error en migración category: $e');
      // Si falla, intentar agregar la columna de forma más directa
      try {
        await _database!.execute('''
          ALTER TABLE products 
          ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'
        ''');
        print('✅ Columna category agregada en segundo intento');
      } catch (e2) {
        print('❌ Error crítico en migración category: $e2');
      }
    }
  }

  // ✅ FORZAR MIGRACIÓN: Asegurar que category existe
  static Future<void> forceAddCategoryColumn() async {
    try {
      print('🔧 Forzando migración: Verificando columna category...');

      // Intentar agregar la columna sin verificar (SQLite ignorará si ya existe)
      await _database!.execute('''
        ALTER TABLE products 
        ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'
      ''');

      // Actualizar productos existentes que no tengan category
      await _database!.execute('''
        UPDATE products 
        SET category = 'Otros' 
        WHERE category IS NULL OR TRIM(category) = ''
      ''');

      print('✅ Migración forzada completada');
    } catch (e) {
      print('❌ Error en migración forzada: $e');
    }
  }

  // ✅ NUEVO: Crear tabla customers si no existe (SOLO CLIENTES)
  static Future<void> ensureCustomersTableExists() async {
    try {
      print('🔧 Verificando tabla customers...');

      // Verificar si la tabla customers ya existe
      final result = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'");

      if (result.isNotEmpty) {
        print('✅ Tabla customers ya existe');
        return;
      }

      print('🔧 Creando tabla customers...');

      // Crear SOLO la tabla customers sin tocar nada más
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          city TEXT,
          documentNumber TEXT,
          documentType TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          pointsRate REAL NOT NULL DEFAULT 1.0,
          accumulatedPoints INTEGER NOT NULL DEFAULT 0,
          lastPurchase TEXT,
          totalPurchases REAL NOT NULL DEFAULT 0.0
        )
      ''');

      print('✅ Tabla customers creada exitosamente');
    } catch (e) {
      print('❌ Error creando tabla customers: $e');
      // Si falla, intentar recrear la tabla
      await forceRecreateCustomersTable();
    }
  }

  // ✅ NUEVO: Forzar recreación de tabla customers si hay problemas
  static Future<void> forceRecreateCustomersTable() async {
    try {
      print('🔧 Forzando recreación de tabla customers...');

      // Eliminar tabla si existe
      await _database!.execute('DROP TABLE IF EXISTS customers');

      // Crear tabla nueva
      await _database!.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          city TEXT,
          documentNumber TEXT,
          documentType TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          pointsRate REAL NOT NULL DEFAULT 1.0,
          accumulatedPoints INTEGER NOT NULL DEFAULT 0,
          lastPurchase TEXT,
          totalPurchases REAL NOT NULL DEFAULT 0.0
        )
      ''');

      print('✅ Tabla customers recreada exitosamente');
    } catch (e) {
      print('❌ Error crítico recreando tabla customers: $e');
    }
  }

  // ✅ NUEVO: Método público para verificar estado de la tabla customers
  static Future<Map<String, dynamic>> getCustomersTableStatus() async {
    try {
      final result = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'");

      final exists = result.isNotEmpty;

      if (exists) {
        // Verificar estructura de la tabla
        final columns =
            await _database!.rawQuery('PRAGMA table_info(customers)');
        final hasPointsRate = columns.any((col) => col['name'] == 'pointsRate');
        final hasAccumulatedPoints =
            columns.any((col) => col['name'] == 'accumulatedPoints');

        return {
          'exists': true,
          'hasPointsRate': hasPointsRate,
          'hasAccumulatedPoints': hasAccumulatedPoints,
          'columns': columns.length,
        };
      }

      return {
        'exists': false,
        'hasPointsRate': false,
        'hasAccumulatedPoints': false,
        'columns': 0,
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
        'hasPointsRate': false,
        'hasAccumulatedPoints': false,
        'columns': 0,
      };
    }
  }

  // ✅ FORZAR: Verificar que la tabla customers realmente existe
  static Future<void> _forceVerifyCustomersTable() async {
    try {
      print('🔧 Forzando verificación de tabla customers...');

      // Verificar si la tabla customers ya existe
      final result = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'");

      if (result.isNotEmpty) {
        print('✅ Tabla customers ya existe');
        return;
      }

      print('🔧 Creando tabla customers...');

      // Crear SOLO la tabla customers sin tocar nada más
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          city TEXT,
          documentNumber TEXT,
          documentType TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          pointsRate REAL NOT NULL DEFAULT 1.0,
          accumulatedPoints INTEGER NOT NULL DEFAULT 0,
          lastPurchase TEXT,
          totalPurchases REAL NOT NULL DEFAULT 0.0
        )
      ''');

      print('✅ Tabla customers creada exitosamente');
    } catch (e) {
      print('❌ Error forzando verificación de tabla customers: $e');
    }
  }

  // ========== MIGRACIONES PARA MÓDULO DE PROVEEDORES ==========

  // ✅ NUEVO: Migración para agregar tablas de proveedores
  static Future<void> migrateAddSuppliersTables() async {
    try {
      print('🔧 Migrando: Agregando tablas de proveedores...');

      // Verificar si las tablas ya existen
      final suppliersExists = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='suppliers'");

      if (suppliersExists.isNotEmpty) {
        print('✅ Tabla suppliers ya existe');
        return;
      }

      // Crear tabla de proveedores
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          document TEXT UNIQUE,
          document_type TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          city TEXT,
          department TEXT,
          postal_code TEXT,
          country TEXT DEFAULT 'Colombia',
          tax_regime TEXT,
          economic_activity TEXT,
          contact_person TEXT,
          contact_phone TEXT,
          contact_email TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');

      // Crear tabla de pagos a proveedores
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS supplier_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          description TEXT,
          user_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');

      // Crear tabla de entradas contables
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS accounting_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          category TEXT,
          date TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');

      print('✅ Tablas de proveedores creadas exitosamente');
    } catch (e) {
      print('❌ Error creando tablas de proveedores: $e');
    }
  }

  /// Fase 1: catálogo de precio de compra por producto y proveedor (único par).
  static Future<void> migrateAddProductSupplierPricesTable() async {
    try {
      final exists = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='product_supplier_prices'",
      );
      if (exists.isNotEmpty) {
        print('✅ Tabla product_supplier_prices ya existe');
        return;
      }

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS product_supplier_prices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          supplier_id INTEGER NOT NULL,
          supplier_reference TEXT,
          purchase_price REAL NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(product_id, supplier_id),
          FOREIGN KEY (product_id) REFERENCES products(id),
          FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
        )
      ''');
      print('✅ Tabla product_supplier_prices creada');
    } catch (e) {
      print('❌ Error creando product_supplier_prices: $e');
    }
  }

  /// Fase 2: historial de cambios de precio por producto y proveedor.
  static Future<void> migrateAddProductSupplierPriceHistoryTable() async {
    try {
      final exists = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='product_supplier_price_history'",
      );
      if (exists.isNotEmpty) {
        print('✅ Tabla product_supplier_price_history ya existe');
        return;
      }

      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS product_supplier_price_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          supplier_id INTEGER NOT NULL,
          purchase_price REAL NOT NULL,
          supplier_reference TEXT,
          changed_at TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products(id),
          FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
        )
      ''');
      print('✅ Tabla product_supplier_price_history creada');
    } catch (e) {
      print('❌ Error creando product_supplier_price_history: $e');
    }
  }

  // ✅ NUEVO: Verificar estado de las tablas de proveedores
  static Future<Map<String, dynamic>> getSuppliersTablesStatus() async {
    try {
      final suppliersExists = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='suppliers'");

      final paymentsExists = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='supplier_payments'");

      final accountingExists = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='accounting_entries'");

      return {
        'suppliers_exists': suppliersExists.isNotEmpty,
        'payments_exists': paymentsExists.isNotEmpty,
        'accounting_exists': accountingExists.isNotEmpty,
      };
    } catch (e) {
      return {
        'suppliers_exists': false,
        'payments_exists': false,
        'accounting_exists': false,
        'error': e.toString(),
      };
    }
  }

  // ✅ NUEVO: Migración para tablas de contabilidad
  static Future<void> migrateAddAccountingTables() async {
    try {
      print('🔄 Verificando tablas de contabilidad...');

      // Verificar si las tablas ya existen
      final accountingExists = await getAccountingTablesStatus();
      print('📋 Tablas contables existentes: $accountingExists');

      // Solo crear las tablas que faltan
      final requiredTables = [
        'accounting_entries',
        'cash_movements',
        'cash_sessions',
        'payment_methods',
        'transaction_categories'
      ];

      final missingTables = requiredTables
          .where((table) => !accountingExists.contains(table))
          .toList();

      if (missingTables.isEmpty) {
        print('✅ Todas las tablas de contabilidad ya existen');
        // Verificar columnas faltantes en accounting_entries
        print('🔧 Verificando columnas de accounting_entries...');

        // Verificar si existe la columna subcategory
        try {
          await _database!
              .rawQuery('SELECT subcategory FROM accounting_entries LIMIT 1');
          print('✅ Columna subcategory ya existe');
        } catch (e) {
          print('🔧 Agregando columna subcategory...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN subcategory TEXT');
          print('✅ Columna subcategory agregada');
        }

        // Verificar si existe la columna cash_session_id
        try {
          await _database!.rawQuery(
              'SELECT cash_session_id FROM accounting_entries LIMIT 1');
          print('✅ Columna cash_session_id ya existe');
        } catch (e) {
          print('🔧 Agregando columna cash_session_id...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN cash_session_id INTEGER');
          print('✅ Columna cash_session_id agregada');
        }

        // Verificar si existe la columna document_number
        try {
          await _database!.rawQuery(
              'SELECT document_number FROM accounting_entries LIMIT 1');
          print('✅ Columna document_number ya existe');
        } catch (e) {
          print('🔧 Agregando columna document_number...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN document_number TEXT');
          print('✅ Columna document_number agregada');
        }

        // Verificar si existe la columna reference
        try {
          await _database!
              .rawQuery('SELECT reference FROM accounting_entries LIMIT 1');
          print('✅ Columna reference ya existe');
        } catch (e) {
          print('🔧 Agregando columna reference...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN reference TEXT');
          print('✅ Columna reference agregada');
        }

        // Verificar si existe la columna related_entity
        try {
          await _database!.rawQuery(
              'SELECT related_entity FROM accounting_entries LIMIT 1');
          print('✅ Columna related_entity ya existe');
        } catch (e) {
          print('🔧 Agregando columna related_entity...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN related_entity TEXT');
          print('✅ Columna related_entity agregada');
        }

        // Verificar si existe la columna related_entity_id
        try {
          await _database!.rawQuery(
              'SELECT related_entity_id FROM accounting_entries LIMIT 1');
          print('✅ Columna related_entity_id ya existe');
        } catch (e) {
          print('🔧 Agregando columna related_entity_id...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN related_entity_id INTEGER');
          print('✅ Columna related_entity_id agregada');
        }

        // Verificar si existe la columna notes
        try {
          await _database!
              .rawQuery('SELECT notes FROM accounting_entries LIMIT 1');
          print('✅ Columna notes ya existe');
        } catch (e) {
          print('🔧 Agregando columna notes...');
          await _database!
              .execute('ALTER TABLE accounting_entries ADD COLUMN notes TEXT');
          print('✅ Columna notes agregada');
        }

        // Verificar si existe la columna payment_method
        try {
          await _database!.rawQuery(
              'SELECT payment_method FROM accounting_entries LIMIT 1');
          print('✅ Columna payment_method ya existe');
        } catch (e) {
          print('🔧 Agregando columna payment_method...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN payment_method TEXT');
          print('✅ Columna payment_method agregada');
        }

        // Verificar si existe la columna updated_at
        try {
          await _database!
              .rawQuery('SELECT updated_at FROM accounting_entries LIMIT 1');
          print('✅ Columna updated_at ya existe');
        } catch (e) {
          print('🔧 Agregando columna updated_at...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN updated_at TEXT');
          print('✅ Columna updated_at agregada');
        }
        return;
      }

      print('🔨 Creando tablas faltantes: $missingTables');

      // Crear tabla de entradas contables (si no existe)
      if (missingTables.contains('accounting_entries')) {
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS accounting_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT,
            subcategory TEXT,
            date TEXT NOT NULL,
            reference TEXT,
            payment_method TEXT,
            user_id INTEGER NOT NULL,
            cash_session_id INTEGER,
            related_entity TEXT,
            related_entity_id INTEGER,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            document_number TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (cash_session_id) REFERENCES cash_sessions (id)
          )
        ''');
        print('✅ Tabla accounting_entries creada');
      } else {
        // Verificar y agregar columnas faltantes a accounting_entries si ya existe
        print('🔧 Verificando columnas de accounting_entries...');

        // Verificar si existe la columna subcategory
        try {
          await _database!
              .rawQuery('SELECT subcategory FROM accounting_entries LIMIT 1');
          print('✅ Columna subcategory ya existe');
        } catch (e) {
          print('🔧 Agregando columna subcategory...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN subcategory TEXT');
          print('✅ Columna subcategory agregada');
        }

        // Verificar si existe la columna cash_session_id
        try {
          await _database!.rawQuery(
              'SELECT cash_session_id FROM accounting_entries LIMIT 1');
          print('✅ Columna cash_session_id ya existe');
        } catch (e) {
          print('🔧 Agregando columna cash_session_id...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN cash_session_id INTEGER');
          print('✅ Columna cash_session_id agregada');
        }

        // Verificar si existe la columna document_number
        try {
          await _database!.rawQuery(
              'SELECT document_number FROM accounting_entries LIMIT 1');
          print('✅ Columna document_number ya existe');
        } catch (e) {
          print('🔧 Agregando columna document_number...');
          await _database!.execute(
              'ALTER TABLE accounting_entries ADD COLUMN document_number TEXT');
          print('✅ Columna document_number agregada');
        }
      }

      // Crear tabla de movimientos de caja (si no existe)
      if (missingTables.contains('cash_movements')) {
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS cash_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            payment_method TEXT,
            date TEXT NOT NULL,
            user_id INTEGER NOT NULL,
            cash_session_id INTEGER,
            reference TEXT,
            reference_id INTEGER,
            category TEXT,
            created_at TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            document_number TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (cash_session_id) REFERENCES cash_sessions (id)
          )
        ''');
        print('✅ Tabla cash_movements creada');
      }

      // Crear tabla de sesiones de caja (si no existe)
      if (missingTables.contains('cash_sessions')) {
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS cash_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            open_date TEXT NOT NULL,
            close_date TEXT,
            initial_amount REAL NOT NULL,
            final_amount REAL,
            total_income REAL,
            total_expense REAL,
            difference REAL,
            user_id INTEGER NOT NULL,
            closed_by_user_id INTEGER,
            status TEXT NOT NULL DEFAULT 'open',
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (closed_by_user_id) REFERENCES users (id)
          )
        ''');
        print('✅ Tabla cash_sessions creada');
      }

      // Crear tabla de métodos de pago (si no existe)
      if (missingTables.contains('payment_methods')) {
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS payment_methods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            requires_change INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('✅ Tabla payment_methods creada');
      }

      // Crear tabla de categorías de transacciones (si no existe)
      if (missingTables.contains('transaction_categories')) {
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS transaction_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            parent_category TEXT,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('✅ Tabla transaction_categories creada');
      }

      // Insertar métodos de pago por defecto
      print('📝 Insertando métodos de pago por defecto...');
      await _insertDefaultPaymentMethods();

      // Insertar categorías por defecto
      print('📝 Insertando categorías por defecto...');
      await _insertDefaultTransactionCategories();

      print('✅ Tablas de contabilidad creadas exitosamente');
    } catch (e) {
      print('❌ Error al crear tablas de contabilidad: $e');
    }
  }

  // Verificar estado de las tablas de contabilidad
  static Future<List<String>> getAccountingTablesStatus() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return [];

      final List<String> existingTables = [];
      final tableNames = [
        'accounting_entries',
        'cash_movements',
        'cash_sessions',
        'payment_methods',
        'transaction_categories'
      ];

      for (final tableName in tableNames) {
        final result = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [tableName]);
        if (result.isNotEmpty) {
          existingTables.add(tableName);
        }
      }

      print('🔍 Tablas contables verificadas: $existingTables');
      return existingTables;
    } catch (e) {
      print('❌ Error al verificar tablas de contabilidad: $e');
      return [];
    }
  }

  // Insertar métodos de pago por defecto
  static Future<void> _insertDefaultPaymentMethods() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return;

      final defaultMethods = [
        {
          'name': 'Efectivo',
          'code': 'CASH',
          'type': 'cash',
          'requires_change': 1,
          'description': 'Pago en efectivo',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Tarjeta Débito',
          'code': 'DEBIT_CARD',
          'type': 'card',
          'requires_change': 0,
          'description': 'Pago con tarjeta débito',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Tarjeta Crédito',
          'code': 'CREDIT_CARD',
          'type': 'card',
          'requires_change': 0,
          'description': 'Pago con tarjeta crédito',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Transferencia',
          'code': 'TRANSFER',
          'type': 'transfer',
          'requires_change': 0,
          'description': 'Transferencia bancaria',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Cheque',
          'code': 'CHECK',
          'type': 'check',
          'requires_change': 0,
          'description': 'Pago con cheque',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];

      for (final method in defaultMethods) {
        await db.insert('payment_methods', method,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      print('✅ Métodos de pago por defecto insertados');
    } catch (e) {
      print('❌ Error al insertar métodos de pago: $e');
    }
  }

  // Insertar categorías por defecto
  static Future<void> _insertDefaultTransactionCategories() async {
    try {
      final db = SQLiteDatabaseService.database;
      if (db == null) return;

      final defaultCategories = [
        // Categorías de ingresos
        {
          'name': 'Ventas',
          'code': 'SALES',
          'type': 'income',
          'description': 'Ingresos por ventas de productos',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Abonos de Clientes',
          'code': 'CUSTOMER_PAYMENTS',
          'type': 'income',
          'description': 'Abonos de clientes',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Otros Ingresos',
          'code': 'OTHER_INCOME',
          'type': 'income',
          'description': 'Otros tipos de ingresos',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Facturas Electrónicas',
          'code': 'ELECTRONIC_INVOICE',
          'type': 'income',
          'description': 'Ingresos por facturas electrónicas',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Pagos de Facturas',
          'code': 'INVOICE_PAYMENT',
          'type': 'income',
          'description': 'Pagos recibidos de facturas pendientes',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        // Categorías de egresos
        {
          'name': 'Pagos a Proveedores',
          'code': 'SUPPLIER_PAYMENTS',
          'type': 'expense',
          'description': 'Pagos a proveedores',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Gastos Operativos',
          'code': 'OPERATIONAL',
          'type': 'expense',
          'description': 'Gastos operativos del negocio',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Gastos Administrativos',
          'code': 'ADMINISTRATIVE',
          'type': 'expense',
          'description': 'Gastos administrativos',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Devoluciones',
          'code': 'REFUNDS',
          'type': 'expense',
          'description': 'Devoluciones a clientes',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Devoluciones a Proveedores',
          'code': 'SUPPLIER_RETURNS',
          'type': 'expense',
          'description': 'Devoluciones de productos a proveedores',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Servicios Públicos',
          'code': 'UTILITIES',
          'type': 'expense',
          'description': 'Pago de servicios públicos (luz, agua, gas)',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Arriendo',
          'code': 'RENT',
          'type': 'expense',
          'description': 'Pago de arriendo del local',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Mantenimiento',
          'code': 'MAINTENANCE',
          'type': 'expense',
          'description': 'Gastos de mantenimiento y reparaciones',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Ajustes Contables',
          'code': 'ADJUSTMENTS',
          'type': 'expense',
          'description': 'Ajustes contables (notas crédito, débito)',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];

      // Limpiar categorías existentes para evitar duplicados
      await db.delete('transaction_categories');
      print('🗑️ Categorías existentes eliminadas');

      for (final category in defaultCategories) {
        await db.insert('transaction_categories', category,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      print('✅ Categorías por defecto insertadas');
    } catch (e) {
      print('❌ Error al insertar categorías: $e');
    }
  }

  // ✅ NUEVO: Migración para tablas de cuentas por cobrar y pagar
  static Future<void> migrateAddAccountsReceivablePayableTables() async {
    try {
      print('🔄 Verificando tablas de cuentas por cobrar y pagar...');

      // Verificar si las tablas ya existen
      final tables = await _database!.rawQuery("""
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name IN (
          'accounts_receivable', 
          'accounts_payable', 
          'receivable_payments', 
          'payable_payments'
        )
      """);

      final existingTables =
          tables.map((table) => table['name'] as String).toList();
      print('📋 Tablas de cuentas existentes: $existingTables');

      // Crear tabla accounts_receivable
      if (!existingTables.contains('accounts_receivable')) {
        await _database!.execute('''
          CREATE TABLE accounts_receivable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            customer_name TEXT NOT NULL,
            customer_document TEXT NOT NULL,
            total_amount REAL NOT NULL,
            paid_amount REAL NOT NULL DEFAULT 0,
            pending_amount REAL NOT NULL,
            invoice_number TEXT NOT NULL,
            invoice_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('✅ Tabla accounts_receivable creada');
      }

      // Crear tabla accounts_payable
      if (!existingTables.contains('accounts_payable')) {
        await _database!.execute('''
          CREATE TABLE accounts_payable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            supplier_name TEXT NOT NULL,
            supplier_document TEXT NOT NULL,
            total_amount REAL NOT NULL,
            paid_amount REAL NOT NULL DEFAULT 0,
            pending_amount REAL NOT NULL,
            invoice_number TEXT NOT NULL,
            invoice_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('✅ Tabla accounts_payable creada');
      }

      // Crear tabla receivable_payments
      if (!existingTables.contains('receivable_payments')) {
        await _database!.execute('''
          CREATE TABLE receivable_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accounts_receivable_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            payment_date TEXT NOT NULL,
            payment_method TEXT NOT NULL,
            reference TEXT,
            notes TEXT,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (accounts_receivable_id) REFERENCES accounts_receivable (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        print('✅ Tabla receivable_payments creada');
      }

      // Crear tabla payable_payments
      if (!existingTables.contains('payable_payments')) {
        await _database!.execute('''
          CREATE TABLE payable_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accounts_payable_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            payment_date TEXT NOT NULL,
            payment_method TEXT NOT NULL,
            reference TEXT,
            notes TEXT,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (accounts_payable_id) REFERENCES accounts_payable (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        print('✅ Tabla payable_payments creada');
      }

      print('✅ Tablas de cuentas por cobrar y pagar creadas exitosamente');
    } catch (e) {
      print('❌ Error al crear tablas de cuentas por cobrar y pagar: $e');
    }
  }
}
